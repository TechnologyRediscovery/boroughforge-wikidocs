---
title: WD Elements 6TB — Safe Unplug Procedure
description: Step-by-step procedure for safely disconnecting the WD Elements backup drive from tangoonefour after a backup run. Covers unmounting, cache flush, open file handle verification, and kernel device release confirmation.
published: true
date: 2026-09-07
tags: [backup, hardware, storage, operations]
editor: markdown
dateCreated: 2026-09-07
---

# WD Elements 6TB — Safe Unplug Procedure

## Drive layout reference

| Partition | Label | Mount point | Filesystem |
|---|---|---|---|
| `/dev/sda1` | `cnfadmin` | `/mnt/cnfpg_backup` | XFS |
| `/dev/sda2` | `WinCompat` | `/mnt/cnfwinstorage` | exFAT |

---

## Full safe-unplug sequence

```bash
# 1. Unmount both partitions
sudo umount /mnt/cnfpg_backup
sudo umount /mnt/cnfwinstorage

# 2. Flush the kernel write-back cache to all storage devices.
# XFS flushes on unmount, but sync is belt-and-suspenders confirmation
# that nothing destined for the drive remains in the page cache.
sudo sync

# 3. Check for processes still holding open file descriptors on the device.
# A process that opened a file before unmount may still hold a handle after.
# Clean result: no output.
lsof | grep sda

# 4. Confirm the block device has no active mount points.
lsblk /dev/sda
# Clean result: sda and its partitions listed, MOUNTPOINTS column blank.

# 5. Confirm neither partition appears in the mounted filesystem table.
df -h
# Clean result: no /dev/sda entries anywhere in the output.
```

**All five checks clean → safe to unplug physically.**

---

## What each check is doing

**`umount`** tells the kernel to flush pending writes, tear down the filesystem structures in memory, and release the mount point. The drive is not safe to unplug until both partitions are unmounted.

**`sync`** flushes all dirty pages from the kernel's write-back cache to their respective block devices — not just the WD Elements but all attached storage. It is a no-op if the cache is already clean, and costs nothing. Run it anyway.

**`lsof | grep sda`** lists all open file descriptors referencing anything on the block device. A process that had a file open on the drive before unmount retains the file descriptor even after unmount — the filesystem is gone but the kernel object is not fully released until the last descriptor is closed. No output means no such handles exist.

**`lsblk /dev/sda`** confirms the kernel's block device enumeration. If the MOUNTPOINTS column is blank for both partitions, the kernel confirms nothing is mounted. If this command returns an error, the kernel has already released the device entirely — also safe.

**`df -h`** is the human-readable confirmation. If `/dev/sda1` or `/dev/sda2` appear anywhere in the output, something is still mounted. If absent, the unmounts are confirmed.

---

## Offline discipline

After physically unplugging, store the drive away from the machine it backs up. A drive that remains plugged in or sitting on the same desk surface as the machine is not meaningfully air-gapped — ransomware with filesystem write access can reach a mounted drive, and physical proximity increases the chance of being plugged back in casually without going through this procedure.

The backup is only as good as the discipline around keeping it offline between runs.

---

## If `umount` returns "target is busy"

The filesystem cannot be unmounted because a process has it open. Find the culprit:

```bash
# Show which processes are using the mount point:
sudo fuser -mv /mnt/cnfpg_backup
sudo fuser -mv /mnt/cnfwinstorage
# -m: include all processes accessing the filesystem
# -v: verbose — show process name, PID, and access type

# If the offending process is safe to stop, stop it, then retry umount.
# If it is a shell with its working directory inside the mount:
# cd out of the directory first, then retry.
```

Common cause: a terminal session whose working directory is inside the mount point. `cd ~` and retry `umount`.

Do not use `umount -f` (force) or `umount -l` (lazy) on the backup drive. Force unmount can leave the filesystem in an inconsistent state. Lazy unmount detaches the filesystem from the namespace but defers the actual teardown — the drive will appear unmounted but the kernel may still be finishing writes. Neither is appropriate for a drive you are about to physically remove.
