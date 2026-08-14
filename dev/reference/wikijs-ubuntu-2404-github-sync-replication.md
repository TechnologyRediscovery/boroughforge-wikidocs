---
title: Replicating the Wiki.js Documentation Server on Ubuntu 24.04
description: Step-by-step setup for a new Ubuntu 24.04 VPS running Wiki.js with Docker, PostgreSQL, HTTPS, and GitHub-backed Git storage
published: false
date: 2026-08-14T00:00:00.000Z
tags: wikijs, docker, github, documentation, sysadmin
editor: markdown
dateCreated: 2026-08-14T00:00:00.000Z
---

# Replicating the Wiki.js Documentation Server on Ubuntu 24.04

FROM ECD's old openai chat GPT export during Aug 2026 rebuild--used for only the git link config

This guide documents how to reproduce the Wiki.js documentation server on a fresh Ubuntu 24.04 VPS.

The target architecture is:

```text
Ubuntu 24.04 VPS
  Docker Engine
    db container: PostgreSQL
    wiki container: Wiki.js
    wiki-update-companion container
  GitHub repository used as Wiki.js Git storage
  Wiki.js Git storage configured for bidirectional sync
```

The current codeNforce/BoroughForge documentation workflow uses:

```text
GitHub Wiki.js repo
  TechnologyRediscovery/boroughforge-wikidocs

Wiki.js
  renders the GitHub-backed documentation tree

GitLab CI
  optionally mirrors code-aware draft docs into the GitHub Wiki.js repo

Local VS Code editing
  humans clone the GitHub Wiki.js repo, edit Markdown, commit, push, and let Wiki.js sync
```

## Assumptions

This guide assumes:

- The VPS is running Ubuntu 24.04 LTS.
- You have a sudo-capable Linux user on the VPS.
- A DNS `A` record already points your documentation hostname to the VPS.
- You have a dedicated GitHub repository for Wiki.js storage.
- You are not pointing Wiki.js directly at the main application source repository.
- You want Git-backed Wiki.js storage using SSH deploy keys.
- You are using the current stable Wiki.js 2 container line, not the legacy DigitalOcean Ubuntu 20.04 marketplace image.

Replace these sample values with your real values:

```text
docs.example.org
admin@example.org
TechnologyRediscovery/boroughforge-wikidocs
git@github.com:TechnologyRediscovery/boroughforge-wikidocs.git
```

## 1. Confirm the server OS

```bash
lsb_release -a
```

Explanation:

- `lsb_release` prints Linux distribution information.
- `-a` asks for all available fields.
- You want to confirm the server is actually Ubuntu 24.04 before following this guide.

Expected result should include something like:

```text
Description:    Ubuntu 24.04.x LTS
Codename:       noble
```

## 2. Update the base system

```bash
sudo apt update
sudo apt upgrade -y
```

Explanation:

- `sudo` runs the command with administrative privileges.
- `apt update` refreshes the local package index from Ubuntu repositories.
- `apt upgrade -y` installs available package updates.
- `-y` answers yes to ordinary package-manager prompts.

Reboot if the kernel or major system packages were upgraded:

```bash
sudo reboot
```

Explanation:

- `reboot` restarts the VPS.
- This is commonly needed after kernel updates.
- Reconnect over SSH after the server comes back.

## 3. Remove conflicting Docker packages

```bash
sudo apt remove -y docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc
```

Explanation:

- Ubuntu may provide older or differently packaged Docker-related packages.
- Docker's official repository provides its own `docker-ce`, CLI, Compose plugin, Buildx plugin, and `containerd.io`.
- Removing conflicting packages avoids mixing Ubuntu-packaged Docker with Docker-packaged Docker.
- It is fine if `apt` reports that some packages are not installed.

## 4. Install Docker Engine from Docker's official apt repository

Install prerequisites:

```bash
sudo apt update
sudo apt install -y ca-certificates curl
```

Explanation:

- `ca-certificates` lets the system verify HTTPS certificates when downloading from package repositories.
- `curl` downloads Docker's repository signing key.
- These are required before adding Docker's external repository.

Create the apt keyring directory:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
```

Explanation:

- `install -d` creates a directory.
- `-m 0755` sets permissions: owner can read/write/enter; group and others can read/enter.
- `/etc/apt/keyrings` is the conventional location for repository signing keys on modern Ubuntu systems.

Download Docker's signing key:

```bash
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
```

Explanation:

- `curl` downloads the Docker repository GPG key.
- `-f` fails on HTTP errors.
- `-s` runs silently.
- `-S` still shows errors when silent mode is active.
- `-L` follows redirects.
- `-o` writes the output to the specified file.
- The key is saved as `/etc/apt/keyrings/docker.asc`.

Make the key readable by apt:

```bash
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

Explanation:

- `chmod a+r` gives all users read permission.
- `apt` must be able to read the key to verify Docker packages.

Add Docker's apt source:

```bash
sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<'EOF'
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF
```

Explanation:

- `tee` writes the heredoc content to `/etc/apt/sources.list.d/docker.sources`.
- `> /dev/null` suppresses echoing the file contents back to the terminal.
- `Types: deb` declares a binary package repository.
- `URIs` is Docker's Ubuntu package repository.
- `Suites: noble` selects Ubuntu 24.04.
- `Components: stable` selects the stable package channel.
- `Architectures: amd64` is correct for ordinary x86_64 VPS instances.
- `Signed-By` tells apt which signing key verifies this repository.

If your VPS is not `amd64`, replace `amd64` with the output of:

```bash
dpkg --print-architecture
```

Refresh apt and install Docker:

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Explanation:

- `docker-ce` is Docker Community Edition engine.
- `docker-ce-cli` is the Docker command-line client.
- `containerd.io` is the container runtime package bundled by Docker.
- `docker-buildx-plugin` supports extended image builds.
- `docker-compose-plugin` provides modern `docker compose` support.

Check Docker service status:

```bash
sudo systemctl status docker
```

Explanation:

- `systemctl status docker` shows whether the Docker daemon is loaded, enabled, and running.
- If the service is inactive, start it:

```bash
sudo systemctl start docker
```

Verify Docker works:

```bash
sudo docker run hello-world
```

Explanation:

- Docker downloads a small test image.
- It starts a short-lived container.
- The container prints a confirmation message and exits.
- This verifies that Docker can pull and run containers.

## 5. Configure the firewall

Allow SSH, HTTP, and HTTPS:

```bash
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
```

Explanation:

- `ufw allow ssh` allows port 22, so you do not lock yourself out.
- `ufw allow http` allows port 80 for HTTP and Let's Encrypt HTTP challenges.
- `ufw allow https` allows port 443 for HTTPS.

Enable UFW:

```bash
sudo ufw --force enable
```

Explanation:

- `ufw enable` activates the firewall.
- `--force` avoids an interactive confirmation prompt.

Check status:

```bash
sudo ufw status verbose
```

Explanation:

- This confirms which ports are open.
- At minimum, SSH, HTTP, and HTTPS should be allowed.

Docker warning:

Docker publishes container ports using its own iptables rules. Docker and UFW can interact in non-obvious ways. For this simple public Wiki.js host, allowing only SSH/HTTP/HTTPS at UFW and publishing only those Docker ports is the intended layout.

## 6. Create a Wiki.js installation directory and database secret

Create the installation directory:

```bash
sudo mkdir -p /etc/wiki
```

Explanation:

- `/etc/wiki` stores host-side configuration material for the Wiki.js deployment.
- `-p` avoids an error if the directory already exists.

Generate a database password:

```bash
openssl rand -base64 32 | sudo tee /etc/wiki/.db-secret > /dev/null
```

Explanation:

- `openssl rand -base64 32` generates 32 random bytes encoded as base64 text.
- `tee` writes the generated secret to `/etc/wiki/.db-secret`.
- `> /dev/null` prevents printing the secret to the terminal output.

Lock down the secret file:

```bash
sudo chmod 600 /etc/wiki/.db-secret
```

Explanation:

- `600` means only the owner can read and write the file.
- This file contains the PostgreSQL password used by the Wiki.js application.

## 7. Create a Docker network and PostgreSQL volume

Create an internal Docker network:

```bash
sudo docker network create wikinet
```

Explanation:

- `wikinet` is a private Docker network for Wiki.js and PostgreSQL.
- Containers on the same Docker network can reach each other by container hostname.
- The Wiki.js container will reach PostgreSQL at host name `db`.

Create a persistent PostgreSQL data volume:

```bash
sudo docker volume create pgdata
```

Explanation:

- `pgdata` stores PostgreSQL database files outside the lifecycle of the database container.
- If the `db` container is replaced, the database contents remain in the volume.
- Do not delete this volume unless you intentionally want to destroy the database.

## 8. Create the PostgreSQL container

```bash
sudo docker create \
  --name=db \
  -e POSTGRES_DB=wiki \
  -e POSTGRES_USER=wiki \
  -e POSTGRES_PASSWORD_FILE=/etc/wiki/.db-secret \
  -v /etc/wiki/.db-secret:/etc/wiki/.db-secret:ro \
  -v pgdata:/var/lib/postgresql/data \
  --restart=unless-stopped \
  -h db \
  --network=wikinet \
  postgres:17
```

Explanation:

- `docker create` creates the container definition but does not start it yet.
- `--name=db` names the container `db`.
- `-e POSTGRES_DB=wiki` creates a database named `wiki`.
- `-e POSTGRES_USER=wiki` creates a PostgreSQL user named `wiki`.
- `-e POSTGRES_PASSWORD_FILE=/etc/wiki/.db-secret` tells PostgreSQL to read the password from a file.
- `-v /etc/wiki/.db-secret:/etc/wiki/.db-secret:ro` mounts the host secret file inside the container as read-only.
- `-v pgdata:/var/lib/postgresql/data` stores PostgreSQL data in the named Docker volume `pgdata`.
- `--restart=unless-stopped` restarts the container after reboot or Docker restart unless an admin deliberately stopped it.
- `-h db` sets the container hostname to `db`.
- `--network=wikinet` attaches the container to the private Wiki.js network.
- `postgres:17` uses the PostgreSQL 17 container image.

## 9. Create the Wiki.js container

Set shell variables for the public hostname and admin email:

```bash
WIKI_DOMAIN="docs.example.org"
LETSENCRYPT_EMAIL="admin@example.org"
```

Explanation:

- These variables are used only in the current shell session.
- Replace the sample values before running the `docker create` command below.
- The domain must already point to the VPS public IP.

Create the Wiki.js container:

```bash
sudo docker create \
  --name=wiki \
  -e DB_TYPE=postgres \
  -e DB_HOST=db \
  -e DB_PORT=5432 \
  -e DB_USER=wiki \
  -e DB_NAME=wiki \
  -e DB_PASS_FILE=/etc/wiki/.db-secret \
  -e UPGRADE_COMPANION=1 \
  -e SSL_ACTIVE=1 \
  -e LETSENCRYPT_DOMAIN="$WIKI_DOMAIN" \
  -e LETSENCRYPT_EMAIL="$LETSENCRYPT_EMAIL" \
  -v /etc/wiki/.db-secret:/etc/wiki/.db-secret:ro \
  --restart=unless-stopped \
  -h wiki \
  --network=wikinet \
  -p 80:3000 \
  -p 443:3443 \
  ghcr.io/requarks/wiki:2
```

Explanation:

- `--name=wiki` names the container `wiki`.
- `DB_TYPE=postgres` tells Wiki.js to use PostgreSQL.
- `DB_HOST=db` tells Wiki.js to connect to the PostgreSQL container by hostname.
- `DB_PORT=5432` is the PostgreSQL default port.
- `DB_USER=wiki` is the database user created in the PostgreSQL container.
- `DB_NAME=wiki` is the database name.
- `DB_PASS_FILE=/etc/wiki/.db-secret` tells Wiki.js to read the database password from the mounted secret file.
- `UPGRADE_COMPANION=1` enables interaction with the Wiki.js update companion.
- `SSL_ACTIVE=1` enables the built-in HTTPS listener.
- `LETSENCRYPT_DOMAIN` is the hostname for certificate issuance.
- `LETSENCRYPT_EMAIL` is the contact email used for Let's Encrypt registration notices.
- `-v /etc/wiki/.db-secret:/etc/wiki/.db-secret:ro` mounts the database secret read-only.
- `--restart=unless-stopped` makes Docker restart the container after VPS reboot unless manually stopped.
- `-h wiki` sets the container hostname.
- `--network=wikinet` puts Wiki.js on the same Docker network as PostgreSQL.
- `-p 80:3000` maps host port 80 to Wiki.js HTTP port 3000 inside the container.
- `-p 443:3443` maps host port 443 to Wiki.js HTTPS port 3443 inside the container.
- `ghcr.io/requarks/wiki:2` pins the Wiki.js major version instead of using `latest`.

Note:

The official Wiki.js Docker documentation recommends pinning the major version instead of using the `latest` tag. Do not use `latest` for this service unless you have a deliberate upgrade and rollback plan.

## 10. Create the Wiki.js update companion container

```bash
sudo docker create \
  --name=wiki-update-companion \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --restart=unless-stopped \
  -h wiki-update-companion \
  --network=wikinet \
  ghcr.io/requarks/wiki-update-companion:latest
```

Explanation:

- `--name=wiki-update-companion` names the helper container.
- `-v /var/run/docker.sock:/var/run/docker.sock:ro` gives the companion read-only access to Docker's socket.
- `--restart=unless-stopped` restarts it after reboot unless manually stopped.
- `--network=wikinet` places it on the same Docker network.
- `ghcr.io/requarks/wiki-update-companion:latest` uses the update companion image.

Security note:

Mounting the Docker socket is powerful. Even read-only socket access should be treated as privileged. This follows the Wiki.js pattern, but avoid adding arbitrary extra containers with Docker socket access.

## 11. Start the containers

Start PostgreSQL first:

```bash
sudo docker start db
```

Explanation:

- Starts the database container.
- Wiki.js depends on this service being available.

Start Wiki.js:

```bash
sudo docker start wiki
```

Explanation:

- Starts the Wiki.js application container.
- On first start, it initializes its database schema.

Start the update companion:

```bash
sudo docker start wiki-update-companion
```

Explanation:

- Starts the update companion helper container.

View the containers:

```bash
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

Explanation:

- Shows running containers in a compact table.
- Confirms that `db`, `wiki`, and `wiki-update-companion` are running.

Follow Wiki.js logs:

```bash
sudo docker logs -f wiki
```

Explanation:

- `docker logs` prints logs from a container.
- `-f` follows the log stream live.
- Watch for database connection errors, HTTPS/certificate messages, and startup completion messages.

## 12. Complete the Wiki.js setup wizard

Open the site in a browser:

```text
https://docs.example.org/
```

If HTTPS is not available yet, temporarily try:

```text
http://docs.example.org/
```

Complete the setup wizard:

- Create the first admin user.
- Confirm site title and hostname.
- Log in to the admin area.

If the first load fails:

- Wait a few minutes and retry.
- Check logs with `sudo docker logs -f wiki`.
- Confirm DNS points to the VPS.
- Confirm ports 80 and 443 are open.
- Confirm the containers are running.

## 13. Generate a dedicated SSH key for Wiki.js GitHub sync

Run as your normal VPS user, not inside the container:

```bash
mkdir -p ~/.ssh/wikijs
chmod 700 ~/.ssh
chmod 700 ~/.ssh/wikijs
```

Explanation:

- Creates a dedicated directory for Wiki.js-related SSH keys.
- `chmod 700` allows only your user to access the directories.
- The key does not need to be created inside the Docker container because the private key contents will be pasted into Wiki.js.

Generate a dedicated keypair:

```bash
ssh-keygen \
  -t rsa \
  -b 4096 \
  -C "wikijs@docs.example.org boroughforge-wikidocs" \
  -f ~/.ssh/wikijs/boroughforge-wikidocs \
  -N ""
```

Explanation:

- `ssh-keygen` creates an SSH keypair.
- `-t rsa` creates an RSA key.
- `-b 4096` sets the key size to 4096 bits.
- `-C` adds a human-readable comment.
- `-f` chooses the output file path.
- `-N ""` creates the key without a passphrase.
- No passphrase is used because Wiki.js must use the key non-interactively.

Lock down the files:

```bash
chmod 600 ~/.ssh/wikijs/boroughforge-wikidocs
chmod 644 ~/.ssh/wikijs/boroughforge-wikidocs.pub
```

Explanation:

- Private keys should be mode `600`: readable and writable only by owner.
- Public keys can be mode `644`: readable by others.

Show the public key:

```bash
cat ~/.ssh/wikijs/boroughforge-wikidocs.pub
```

Explanation:

- Copy this public key into GitHub as a deploy key.
- This public key is safe to share with GitHub.
- Do not paste the private key into GitHub.

## 14. Add the public key to GitHub as a deploy key

In GitHub, open the dedicated Wiki.js documentation repository:

```text
TechnologyRediscovery/boroughforge-wikidocs
```

Navigate to:

```text
Settings → Deploy keys → Add deploy key
```

Use a title such as:

```text
Wiki.js docs.example.org
```

Paste the public key from:

```bash
cat ~/.ssh/wikijs/boroughforge-wikidocs.pub
```

Enable:

```text
Allow write access
```

Explanation:

- Read access lets Wiki.js pull from GitHub.
- Write access lets Wiki.js push browser-created or browser-edited pages back into GitHub.
- The deploy key is scoped to this one repository, which is safer than using a personal SSH key.

## 15. Test the SSH key from the VPS

```bash
GIT_SSH_COMMAND="ssh -i ~/.ssh/wikijs/boroughforge-wikidocs -o IdentitiesOnly=yes" \
  git ls-remote git@github.com:TechnologyRediscovery/boroughforge-wikidocs.git
```

Explanation:

- `GIT_SSH_COMMAND=...` tells Git exactly which SSH key to use for this one command.
- `ssh -i` specifies the private key file.
- `-o IdentitiesOnly=yes` prevents SSH from trying unrelated keys.
- `git ls-remote` checks whether Git can access the remote repository.
- This does not clone the repo; it only asks the remote for references.

Possible first-run prompt:

```text
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Type:

```text
yes
```

If the command fails with `Permission denied (publickey)`, check that:

- The public key was added to the correct GitHub repo.
- The repo URL is correct.
- The deploy key is enabled.
- The private key used by the test matches the public key uploaded to GitHub.

Compare private/public match:

```bash
ssh-keygen -y -f ~/.ssh/wikijs/boroughforge-wikidocs
cat ~/.ssh/wikijs/boroughforge-wikidocs.pub
```

Explanation:

- `ssh-keygen -y` derives the public key from the private key.
- Its output should match the `.pub` file.

## 16. Configure Wiki.js Git storage

In Wiki.js, go to:

```text
Administration → Storage → Git
```

Use these settings:

```text
Authentication Type: SSH
Repository URI: git@github.com:TechnologyRediscovery/boroughforge-wikidocs.git
Branch: main
Sync Direction: Bi-directional
SSH Private Key Mode: contents
```

For the private key, run this on the VPS:

```bash
cat ~/.ssh/wikijs/boroughforge-wikidocs
```

Explanation:

- This prints the private key block.
- Copy the full block, including the first and last lines:

```text
-----BEGIN OPENSSH PRIVATE KEY-----
...
-----END OPENSSH PRIVATE KEY-----
```

Paste that full private key block into the Wiki.js private key contents field.

Important settings:

- Use SSH mode, not HTTPS mode.
- Use `contents`, not `path`, for the private key mode.
- The repository URI must start with `git@github.com:`, not `https://`.
- Leave username/password blank when using SSH key authentication.

Apply the storage settings.

## 17. Run the first Wiki.js Git sync

If the Wiki.js site already has pages that are not in GitHub, run:

```text
Add Untracked Changes
```

Then run:

```text
Force Sync
```

Explanation:

- `Add Untracked Changes` exports existing Wiki.js database pages into the local Git working copy so they can be committed.
- `Force Sync` manually triggers synchronization instead of waiting for the periodic interval.
- After the sync, check the GitHub repository to verify that files appeared.

If the GitHub repository already contains Markdown files you want imported into Wiki.js, use the Git import/sync action from the Wiki.js storage screen and verify that pages appear in the navigation tree.

## 18. Verify bidirectional sync

### Test Wiki.js to GitHub

Create or edit a small test page in the Wiki.js browser UI.

Then run:

```text
Administration → Storage → Git → Force Sync
```

Check GitHub for a new commit or changed file.

### Test GitHub to Wiki.js

Clone the GitHub repo locally:

```bash
git clone git@github.com:TechnologyRediscovery/boroughforge-wikidocs.git
cd boroughforge-wikidocs
```

Create a test page:

```bash
mkdir -p system
nano system/git-sync-smoke-test.md
```

Example page:

```markdown
---
title: Git Sync Smoke Test
description: Temporary page confirming GitHub-to-Wiki.js sync
published: false
date: 2026-08-14T00:00:00.000Z
tags:
editor: markdown
dateCreated: 2026-08-14T00:00:00.000Z
---

# Git Sync Smoke Test

This page was committed directly to the GitHub Wiki.js repository.

If Wiki.js imports this page, GitHub-to-Wiki.js sync is working.
```

Commit and push:

```bash
git add system/git-sync-smoke-test.md
git commit -m "Add Git sync smoke test"
git push origin main
```

Explanation:

- `git add` stages the file.
- `git commit` creates a local commit.
- `git push origin main` pushes the commit to GitHub.

Then force sync in Wiki.js or wait for the scheduled sync interval.

Confirm the page appears in Wiki.js.

## 19. Recommended repository conventions

Use the GitHub Wiki.js repository as the canonical documentation source.

Recommended layout:

```text
dev/
sysadmin/
users/
properties/
permitting/
inspections/
cecases/
resources/
  screenshots/
  diagrams/
  downloads/
drafts/
  gitlabrepo/
```

Recommended image syntax:

```markdown
![Property profile screenshot](/resources/screenshots/properties/property-profile-home.png =800x)
```

Explanation:

- Root-absolute paths beginning with `/resources/...` are less fragile than relative paths.
- `=800x` requests a width of 800 pixels while preserving aspect ratio.
- Use lowercase, hyphen-separated filenames.
- Keep screenshots reasonably sized before committing.

## 20. Optional GitLab CI draft-mirror integration

If the main codebase is hosted on GitLab and you want code-aware documentation drafts, use a separate GitLab CI SSH key.

Generate a second keypair:

```bash
ssh-keygen \
  -t ed25519 \
  -C "gitlab-ci-to-boroughforge-wikidocs" \
  -f ~/.ssh/wikijs/gitlab-ci-to-bfwikidocs \
  -N ""
```

Explanation:

- This key is separate from the Wiki.js key.
- `ed25519` is compact and suitable for modern SSH use.
- This allows GitLab CI access to be revoked independently of Wiki.js access.

Set permissions:

```bash
chmod 600 ~/.ssh/wikijs/gitlab-ci-to-bfwikidocs
chmod 644 ~/.ssh/wikijs/gitlab-ci-to-bfwikidocs.pub
```

Add the public key to the same GitHub repository as a deploy key with write access.

In GitLab:

```text
Project → Settings → CI/CD → Variables
```

Add:

```text
Key: GITHUB_WIKIDOCS_SSH_KEY
Type: File
Value: full private key contents
Protected: off for feature branch testing
Masked: off
```

Explanation:

- A GitLab file-type variable stores the private key as a temporary file during the job.
- Raw OpenSSH private keys contain newlines, so they generally cannot be masked as ordinary GitLab variables.
- Do not print this file variable in CI logs.

A GitLab CI job can then mirror:

```text
docs/wikijs-drafts/
```

into:

```text
drafts/gitlabrepo/<branch-slug>/
```

in the GitHub Wiki.js repository.

## 21. Common failure modes

### Wiki.js prepends HTTPS to an SSH URL

Symptom:

```text
fatal: unable to access 'https://git@github.com:OWNER/REPO.git/'
```

Cause:

- Wiki.js Git storage is set to HTTPS/basic auth instead of SSH.

Fix:

- Set Authentication Type to SSH.
- Use repository URI:

```text
git@github.com:TechnologyRediscovery/boroughforge-wikidocs.git
```

### Wiki.js says identity file is not accessible

Symptom:

```text
Warning: Identity file not accessible: No such file or directory
Permission denied (publickey)
```

Cause:

- Wiki.js is treating the private key as a file path.

Fix:

- Set SSH Private Key Mode to `contents`.
- Paste the full private key block into the private key contents field.

### GitHub denies public key

Symptom:

```text
git@github.com: Permission denied (publickey)
```

Cause:

- The matching public key is not attached to the GitHub repo.
- The key is attached to the wrong repo.
- The deploy key does not have write access.
- Wiki.js is using the wrong private key.

Fix:

- Re-run the `git ls-remote` test from the VPS.
- Compare public key from private key:

```bash
ssh-keygen -y -f ~/.ssh/wikijs/boroughforge-wikidocs
```

- Confirm the matching public key is installed as a GitHub deploy key.

### GitLab CI says `error in libcrypto`

Symptom:

```text
Load key "/root/.ssh/id_ed25519": error in libcrypto
```

Cause:

- The GitLab variable contains malformed key contents.
- The public key was pasted instead of the private key.
- The private key lost newlines or got corrupt line endings.

Fix:

- Recreate the GitLab CI variable as a file-type variable.
- Paste the full private key block.
- Normalize line endings in CI if necessary:

```bash
tr -d '\r' < "$GITHUB_WIKIDOCS_SSH_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-keygen -lf ~/.ssh/id_ed25519
```

## 22. Routine operations commands

List containers:

```bash
sudo docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
```

Explanation:

- Shows all containers, their images, status, and port mappings.

View Wiki.js logs:

```bash
sudo docker logs --tail 100 wiki
```

Explanation:

- Shows the last 100 log lines from the Wiki.js container.

Follow Wiki.js logs live:

```bash
sudo docker logs -f wiki
```

Explanation:

- Streams logs until interrupted with `Ctrl+C`.

Restart Wiki.js:

```bash
sudo docker restart wiki
```

Explanation:

- Stops and starts the Wiki.js container.
- Useful after configuration changes or suspected certificate/sync issues.

Restart all Wiki.js stack containers:

```bash
sudo docker restart db wiki wiki-update-companion
```

Explanation:

- Restarts PostgreSQL, Wiki.js, and the update companion.
- Do not do this during active edits if avoidable.

Inspect environment variables:

```bash
sudo docker inspect wiki --format '{{range .Config.Env}}{{println .}}{{end}}'
```

Explanation:

- Prints environment variables configured on the Wiki.js container.
- Useful for confirming DB settings and HTTPS settings.

Check ports:

```bash
sudo ss -ltnp | grep -E ':80|:443|:5432'
```

Explanation:

- `ss` shows listening network sockets.
- This checks whether HTTP, HTTPS, and PostgreSQL are listening.

## 23. Basic backup command

Create a PostgreSQL custom-format dump:

```bash
sudo docker exec -t db pg_dump -U wiki -d wiki -Fc > wiki-$(date +%F).dump
```

Explanation:

- `docker exec -t db` runs a command inside the `db` container.
- `pg_dump` dumps the PostgreSQL database.
- `-U wiki` connects as user `wiki`.
- `-d wiki` dumps database `wiki`.
- `-Fc` creates PostgreSQL's custom-format dump, suitable for `pg_restore`.
- `> wiki-$(date +%F).dump` writes the dump to a dated file on the VPS host.

List the dump:

```bash
ls -lh wiki-*.dump
```

Explanation:

- Confirms that the backup file exists and shows its size.

## 24. Restore warning

Do not test restores on production without a fresh backup and a written rollback plan.

A restore generally involves:

- Stopping Wiki.js.
- Restoring the PostgreSQL dump into a clean or target database.
- Restarting Wiki.js.
- Verifying pages, users, assets, and Git storage settings.

Document and rehearse restores on a test VPS before relying on this service for production documentation.

## 25. Sources and reference docs

Official docs consulted while preparing this runbook:

- Docker Engine on Ubuntu: https://docs.docker.com/engine/install/ubuntu/
- Wiki.js Ubuntu install guide: https://docs.requarks.io/install/ubuntu
- Wiki.js Docker install guide: https://docs.requarks.io/install/docker
- Wiki.js Git storage guide: https://docs.requarks.io/storage/git
