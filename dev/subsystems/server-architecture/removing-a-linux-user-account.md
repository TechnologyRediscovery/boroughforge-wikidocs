---
title: Removing a Linux User Account on the Production Server
description: Safe, ordered procedure for removing a departed operator's Unix account from an Ubuntu production host, with interrogation, locking, audit, archive, deletion, and verification steps.
published: true
date: 2026-09-07T00:00:00.000Z
tags: sysadmin, ubuntu, offboarding, users, production
editor: markdown
dateCreated: 2026-09-07T00:00:00.000Z
---

# Removing a Linux User Account on the Production Server

This page documents the procedure for permanently removing an operator's Unix account from a CNF production host running Ubuntu Server. The procedure is written for the common case of a departing subcontractor, employee, or vendor who had shell access to a CNF-managed VPS.

The safe order of operations is:

**interrogate → lock → audit → archive → delete → verify**

Deletion is deliberately the last step. `userdel -r` and `deluser --remove-home` are irreversible; running them first turns a routine offboarding into a data-loss incident when it turns out the account owned a cron job, held keys in someone else's `authorized_keys`, or had a running process nobody remembered.

## Audience and prerequisites

You are the CNF administrator or a delegated operator with `sudo` on the target host. You have the departing user's Unix username. You have already revoked or scheduled revocation of the account's access to adjacent systems (see [Beyond the box](#beyond-the-box) below).

## Conventions in this document

Every command in this document is annotated with what it does and marked with one of three risk levels:

- 🔵 **READ** — inspects state, changes nothing on disk.
- 🟡 **REVERSIBLE** — changes system state, but can be undone with an inverse command.
- 🔴 **DESTRUCTIVE** — writes to disk irreversibly, or removes files/records that cannot be reconstructed without a backup.

Set the departing username in a shell variable at the start of the session so every subsequent command references the same value. This eliminates a class of typo-induced disasters:

```bash
OLD_USER=departing_username    # replace with the real account name; used throughout
```

---

## Phase 1: Interrogation (read-only)

Before touching anything, build a full picture of the account: its UID, group memberships, home directory, login history, and whether it's currently logged in.

Prefer `getent` over reading `/etc/passwd` directly. `getent` consults the Name Service Switch (NSS), so it also surfaces accounts sourced from LDAP or SSSD if those are configured. Reading `/etc/passwd` only shows local-file accounts and can produce a false negative on systems using directory services.[^1]

```bash
# 🔵 READ: list all accounts NSS knows about
getent passwd

# 🔵 READ: fetch just the departing user's passwd entry
getent passwd "$OLD_USER"

# 🔵 READ: show UID, primary GID, and all supplementary group memberships
id "$OLD_USER"

# 🔵 READ: terser view of group memberships only
groups "$OLD_USER"

# 🔵 READ: list all groups on the system
getent group

# 🔵 READ: check membership of security-critical groups
getent group sudo        # sudo grants
getent group adm         # log-reading privilege
getent group docker      # equivalent to root on the host — see docker section below
```

### Distinguishing human accounts from system accounts

Ubuntu allocates UIDs below 1000 to system accounts (daemons, service users). Human accounts live at UID 1000 and above. To list only human accounts:

```bash
# 🔵 READ: filter /etc/passwd for accounts with UID >= 1000, excluding the nobody account
awk -F: '$3 >= 1000 && $1 != "nobody" { print $1, $3, $6, $7 }' /etc/passwd
```

The `-F:` argument sets the field separator to colon (the `/etc/passwd` format). `$3` is UID, `$6` is home directory, `$7` is login shell.

### Login history and current sessions

```bash
# 🔵 READ: consolidated view — last login, password status, running processes
lslogins "$OLD_USER"

# 🔵 READ: full login history from /var/log/wtmp
last "$OLD_USER" | head -20

# 🔵 READ: most recent login timestamp for a specific user
lastlog -u "$OLD_USER"

# 🔵 READ: is the user logged in right now?
who | grep "^$OLD_USER "
w  | grep "^$OLD_USER "     # same info plus current command
```

---

## Phase 2: Lock (reversible)

Lock the account before doing anything else. Locking is instant, blocks new logins, and is fully reversible if you discover during the audit that the account still owns critical resources.

```bash
# 🟡 REVERSIBLE: disable password authentication AND expire the account
sudo usermod --lock --expiredate 1 "$OLD_USER"
```

The two switches serve different purposes and both matter:

- `--lock` (equivalent: `-L`) prepends `!` to the password hash in `/etc/shadow`, which invalidates password authentication but does **not** block SSH key authentication.
- `--expiredate 1` (equivalent: `-e 1`) sets the account expiry to 1970-01-02 (one second past the Unix epoch). An expired account is blocked at the PAM `account` stage, which stops SSH key logins as well.

For a departing subcontractor who almost certainly connected via SSH keys, only the combination is sufficient. `--lock` alone is a common and dangerous mistake.[^2]

An equivalent using `chage`:

```bash
# 🟡 REVERSIBLE: alternative expiry syntax; sets account expiry to the epoch
sudo chage -E 0 "$OLD_USER"
```

To reverse the lock (if you discover you need to during the audit):

```bash
# 🟡 REVERSIBLE: undo both the lock and the expiry
sudo usermod --unlock --expiredate "" "$OLD_USER"
```

### Terminate live sessions and processes

If the user has any live sessions or long-running processes, `userdel` will refuse to complete (or, worse, succeed with `--force` and orphan the processes under a numeric UID that gets recycled by the next `useradd`).

```bash
# 🔵 READ: check for running processes owned by the user
sudo ps -u "$OLD_USER"

# 🟡 REVERSIBLE: send SIGTERM to all processes owned by the user (they get to clean up)
sudo pkill -u "$OLD_USER"

sleep 5

# 🔴 DESTRUCTIVE: send SIGKILL to any survivors — no cleanup, no shutdown hooks run
sudo pkill -KILL -u "$OLD_USER"

# 🔵 READ: confirm nothing survives
sudo ps -u "$OLD_USER"
```

`pkill` is marked destructive at the `-KILL` step because SIGKILL cannot be caught or ignored, and processes killed this way don't run shutdown handlers. For interactive shells and typical daemons this is fine; for something writing to a database file it could corrupt state. Prefer the polite SIGTERM first.

---

## Phase 3: Audit the wider footprint (read-only)

This is the phase most walkthroughs skip. It is the phase that matters most, because a Unix account almost never lives entirely within its own home directory. Do all of the following before archiving or deleting.

### SSH access

```bash
# 🔵 READ: what keys did this user have inbound access with?
sudo cat "/home/$OLD_USER/.ssh/authorized_keys" 2>/dev/null

# 🔵 READ: does the user's key appear in anyone else's authorized_keys?
# Extract the key comment or fingerprint from the file above, then:
sudo grep -rl "user@hostname-or-comment" \
    /home/*/.ssh/authorized_keys \
    /root/.ssh/authorized_keys 2>/dev/null
```

The second search matters: contractors sometimes get added to shared or service accounts (`www-data`, deploy users, `postgres`), and `userdel` will not touch those entries.

### Sudo grants

```bash
# 🔵 READ: any sudoers entries granting privilege to this user or their groups?
sudo grep -rE "(^|[^a-zA-Z0-9_])$OLD_USER([^a-zA-Z0-9_]|$)" \
    /etc/sudoers /etc/sudoers.d/ 2>/dev/null
```

The regex boundaries (`[^a-zA-Z0-9_]`) prevent false matches inside longer usernames — searching for `bob` with plain `grep` would also match `bobby` and `alice-bob`.

### Scheduled jobs

```bash
# 🔵 READ: user's personal crontab
sudo crontab -l -u "$OLD_USER" 2>/dev/null

# 🔵 READ: confirm no crontab file exists in the spool
sudo ls -la /var/spool/cron/crontabs/ | grep "$OLD_USER"

# 🔵 READ: system cron entries that run as this user
sudo grep -rE "(^|\s)$OLD_USER(\s|$)" \
    /etc/crontab /etc/cron.d/ /etc/cron.hourly/ \
    /etc/cron.daily/ /etc/cron.weekly/ /etc/cron.monthly/ 2>/dev/null

# 🔵 READ: systemd timers or user-scoped services
systemctl list-units --all --type=service,timer | grep -i "$OLD_USER"
sudo ls "/home/$OLD_USER/.config/systemd/user/" 2>/dev/null
```

### File ownership beyond the home directory

This is the audit query that most often surfaces surprises: files owned by the departing user in `/etc`, `/var`, `/opt`, `/srv`, or elsewhere.

```bash
# 🔵 READ: files owned by the departing user anywhere on the root filesystem,
# EXCLUDING their home directory (which the archive step below will handle)
sudo find / -xdev \( -user "$OLD_USER" -o -group "$OLD_USER" \) \
    -not -path "/home/$OLD_USER/*" 2>/dev/null
```

Switches explained:

- `-xdev` restricts the search to a single filesystem (won't cross into `/mnt`, `/proc`, or other mounts). If you have `/var` on a separate mount, run `find` again against that mount point.
- `\( -user X -o -group X \)` matches files owned by the user OR the group. The parentheses are escaped because they're shell metacharacters.
- `-not -path "/home/$OLD_USER/*"` excludes the home directory from results (you already know about that; you want the surprises).
- `2>/dev/null` suppresses "permission denied" messages from directories `find` can't traverse. Rerun without this redirect if you want to confirm nothing was silently skipped.

**Files found by this query need a decision before deletion:**

- Reassign ownership with `chown` if the file is a shared resource that should persist under a different owner (e.g., a WildFly deployment script that should now belong to the `wildfly` user).
- Delete deliberately if the file is truly orphaned and disposable.
- Do neither only if you're prepared to have that file left owned by a bare numeric UID after Phase 5, which a future `useradd` will silently inherit.

### Mail spool

```bash
# 🔵 READ: is there queued or historical mail for this user?
sudo ls -la "/var/spool/mail/$OLD_USER" 2>/dev/null
sudo ls -la "/var/mail/$OLD_USER" 2>/dev/null   # some Ubuntu configs use this path
```

### CNF-specific: PostgreSQL role

If the departing user was ever granted a PostgreSQL role on the CNF database, the Unix account removal does not touch it. Check separately:

```bash
# 🔵 READ: list PostgreSQL roles; look for any matching the departing username
sudo -u postgres psql -c '\du' | grep -i "$OLD_USER"
```

Role revocation is a separate procedure — see [PostgreSQL role management](/reference/postgresql-roles) (companion page).

### CNF-specific: Docker group membership

If the host runs Docker and the departing user was in the `docker` group, that grant is **equivalent to root on the host** — a member of `docker` can mount `/` into a container as read-write. Confirmation is already covered above under group interrogation; if the user was in `docker`, treat the audit with correspondingly higher care and check for any container images, volumes, or Compose projects they left behind:

```bash
# 🔵 READ: containers, images, volumes potentially left by the user
docker ps -a --filter "label=owner=$OLD_USER"
docker images --filter "label=owner=$OLD_USER"
docker volume ls
```

The `--filter "label=owner=…"` only works if your team has been labeling resources at creation time. If not, you're doing a manual review.

---

## Phase 4: Archive (creates data, doesn't destroy)

For any CNF production system with a records-retention posture — which includes anything touching PA municipal data subject to Right-to-Know — archive the home directory and mail spool before deletion rather than destroy them outright.

```bash
# 🟡 REVERSIBLE (creates a new file; deletes nothing)
# Create a gzipped tarball of the home directory and mail spool
sudo tar -czf "/root/offboard-${OLD_USER}-$(date +%F).tar.gz" \
    "/home/$OLD_USER" \
    "/var/spool/mail/$OLD_USER" \
    2>/dev/null
```

Options explained:

- `-c` create a new archive
- `-z` compress with gzip
- `-f <path>` write the archive to the named file
- `$(date +%F)` embeds today's date in ISO-8601 format (YYYY-MM-DD) into the filename, which makes the archive self-dating

**Verify the archive is readable before you rely on it:**

```bash
# 🔵 READ: list the archive contents to confirm it was written and is readable
sudo tar -tzf "/root/offboard-${OLD_USER}-"*.tar.gz | head -30
```

Options: `-t` list contents (test), `-z` decompress on the fly, `-f` read from named file.

An archive that fails this test is worthless. Do not proceed to Phase 5 until this succeeds.

### Where the archive should actually live

`/root` is fine as a staging location, but a tarball sitting on the same disk as the source it was meant to preserve is not a backup by any meaningful definition. Copy the archive to your air-gapped storage or your off-site backup target (Backblaze B2, external drive, whatever the CNF backup architecture currently specifies) before Phase 5. See [Backup targets and retention](/reference/backups) (companion page).

---

## Phase 5: Delete (destructive)

Only after Phases 1–4 are complete.

### Preferred: `deluser` (Debian/Ubuntu-native)

```bash
# 🔴 DESTRUCTIVE: remove the account and the home directory
sudo deluser --remove-home "$OLD_USER"
```

`deluser` is the Debian-family wrapper around the lower-level `userdel`. It reads `/etc/deluser.conf`, respects Debian's group-per-user convention, and is the recommended tool on Ubuntu per the `userdel(8)` man page itself, which states: *"On Debian, administrators should usually use deluser(8) instead."*

Options:

- `--remove-home` removes the user's home directory and mail spool. Without this switch, the account is removed but home and mail remain in place, owned by the now-orphaned numeric UID.

### Equivalent lower-level command

```bash
# 🔴 DESTRUCTIVE: equivalent using the POSIX-lineage tool
sudo userdel --remove "$OLD_USER"
```

Options:

- `--remove` (equivalent: `-r`) removes the home directory and mail spool.

Both commands automatically remove the user from all supplementary groups. If the user's primary group is named identically to the user (Ubuntu's default "user-private group" scheme) and has no other members, that group is also removed.

### What NOT to use

```bash
# ❌ DO NOT USE without understanding the specific failure it is bypassing
sudo userdel --force --remove "$OLD_USER"
```

`--force` (`-f`) removes the account even if the user is still logged in or has running processes. It leaves those processes orphaned under the freed UID. Only use `--force` when you have deliberately investigated *why* the normal removal is failing and decided the risk of orphaned processes is acceptable.

---

## Phase 6: Verify (read-only)

```bash
# 🔵 READ: NSS lookup should return nothing (exit code 2)
getent passwd "$OLD_USER"; echo "exit: $?"

# 🔵 READ: id should fail with "no such user"
id "$OLD_USER"

# 🔵 READ: home directory should be gone
sudo ls -la "/home/$OLD_USER" 2>&1 | head -3

# 🔵 READ: mail spool should be gone
sudo ls -la "/var/spool/mail/$OLD_USER" 2>&1 | head -3

# 🔵 READ: the closing assertion — any files on this filesystem now
# owned by a UID with no matching passwd entry?
sudo find / -xdev -nouser -o -nogroup 2>/dev/null | head
```

The final `find -nouser -o -nogroup` is the operation that turns this procedure from "remove the account" into "remove the account without leaving landmines." If it returns anything unexpected, the UID is now free for the next `useradd` to reuse — and any file left behind will silently transfer to whoever gets that UID next. Reassign ownership with `chown` or delete deliberately before you consider the offboarding complete.

---

## Tradeoffs and alternative approaches

### Delete vs. disable indefinitely

The procedure above deletes the account. An alternative is to disable it indefinitely while keeping the record in `/etc/passwd`:

```bash
# 🟡 REVERSIBLE: permanent-disable pattern
sudo usermod --lock --expiredate 1 --shell /usr/sbin/nologin "$OLD_USER"
```

Arguments for **delete**:

- Fewer accounts to audit and reason about over time.
- No stale home directories accumulating disk usage.
- No risk of the account being un-locked and re-enabled by accident or by a compromised admin.

Arguments for **disable**:

- The UID is preserved, so any files elsewhere owned by that UID remain traceable to a named account rather than becoming orphaned numbers.
- Audit logs referencing the username continue to resolve to a `passwd` entry.
- No archive step required.
- Reversible if the offboarding turns out to be temporary (contract renewed, employee returns).

The right choice depends on the retention policy that applies to the specific data on the box. For a subcontractor whose data has been archived per Phase 4, delete is defensible. For an accounting or compliance-adjacent system where audit trails need to resolve names indefinitely, disable is more conservative.

### `deluser` vs. `userdel`

`deluser` is Debian's Perl wrapper; `userdel` is the shadow-utils tool that Ubuntu inherits from the wider Linux ecosystem.

Use `deluser` when:

- You are on Debian or Ubuntu (native tool, respects `/etc/deluser.conf`, better default behavior for user-private groups).
- You want the tool that the Ubuntu maintainers actually recommend.

Use `userdel` when:

- You are writing a script that must run on both Debian-family and Red Hat–family systems.
- You need a specific option that `deluser` does not expose (rare; most operational needs are covered by both).

Both are safe when used with `--remove-home` / `--remove`. The `userdel` man page directs Debian admins to `deluser` for good reason.

### Keep the home directory vs. remove it

An intermediate option is to remove the account but preserve the home directory:

```bash
# 🔴 DESTRUCTIVE: remove the account only; leaves /home/OLD_USER intact
#                 (but now owned by an orphaned numeric UID)
sudo deluser "$OLD_USER"    # no --remove-home
```

This is almost always the wrong choice. The home directory is left owned by a UID with no matching passwd entry, which:

- Confuses future audits (files show as `1004 1004` instead of `wwalk wwalk`).
- Silently transfers ownership if `useradd` allocates the same UID to a new account.
- Provides no benefit over archiving the home directory first and then removing it cleanly.

If you want the data preserved, archive it (Phase 4) and remove the home directory (Phase 5). Do not use "leave it in place" as a substitute for a real archive.

### Backup of the account state itself

`/etc/passwd`, `/etc/shadow`, `/etc/group`, and `/etc/gshadow` are edited in place by `deluser`/`userdel`. Ubuntu's shadow-utils tooling writes a backup to `/etc/passwd-`, `/etc/shadow-`, etc. (trailing hyphen) before modifying the live file, which gives you a one-generation rollback if the deletion turns out to have been a mistake caught within minutes:

```bash
# 🔵 READ: compare the current file to the pre-modification backup
sudo diff /etc/passwd /etc/passwd-
sudo diff /etc/group  /etc/group-
```

These backups are overwritten on the next modification, so they are not a substitute for real backups.

---

## Beyond the box

Account removal on the Unix host is necessary but not sufficient for offboarding. A production offboarding procedure treats the Unix account as one item, not the deliverable. Adjacent revocations that `deluser` does nothing about:

- **DigitalOcean control panel access** — team member removal at the account level.
- **GitLab access** — see [GitLab access management](/how-to/gitlab-access) (companion page).
- **PostgreSQL roles** — `DROP ROLE` for any database roles held by the user (see [PostgreSQL role management](/reference/postgresql-roles)).
- **Application-level accounts** — CNF admin accounts inside the app itself, if applicable.
- **Shared credentials** — rotate any shared secrets the user had access to (API tokens, service account passwords, `.env` files with embedded credentials). This includes: Resend API keys, Help Scout API tokens, Backblaze B2 application keys, MuniciPay credentials, and any SSH keys stored on shared machines.
- **Third-party services** — Google Workspace membership, any SaaS the user was a named seat on.

Each of these is a separate procedure. This document only covers the Unix host.

---

## Related pages

- [Offboarding checklist (full)](/how-to/offboarding-checklist) — the complete cross-system procedure this page is one part of
- [SSH key management on production](/how-to/ssh-key-management)
- [PostgreSQL role management](/reference/postgresql-roles)
- [Backup targets and retention](/reference/backups)
- [GitLab access management](/how-to/gitlab-access)

---

[^1]: `getent` queries the NSS layer, which is configured in `/etc/nsswitch.conf`. On a stock Ubuntu server the `passwd:` line reads `files systemd`, meaning `getent` returns results from `/etc/passwd` plus any accounts registered with systemd's `nss-systemd` (used by transient dynamic users). On a host joined to LDAP, Active Directory, or SSSD, the same line will include `ldap`, `sss`, or `winbind`, and only `getent` will see those accounts. Reading `/etc/passwd` directly is a habit worth breaking for this reason alone.

[^2]: The distinction between "lock" and "expire" is a frequent source of incident reports. `passwd -l`, `usermod -L`, and setting the shadow password to `!` are all equivalent password-only locks. None of them affect SSH public-key authentication, because sshd doesn't consult the password hash when a key is offered. Account expiry via `usermod -e` or `chage -E` is evaluated by the PAM `account` stack (`pam_unix.so` reads the `sp_expire` field in `/etc/shadow`) and is enforced regardless of authentication method. The safe pattern is to always apply both, in the order shown in Phase 2.
