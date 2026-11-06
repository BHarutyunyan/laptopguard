# laptopguard

Two Bash scripts that protect personal data on a Linux laptop. Built for cycle 1 of the TUMO Labs Guided Self-Learning cybersecurity track.

| File | What it does |
|---|---|
| `backup.sh` | Makes an encrypted backup of the home folder with restic, on this computer and optionally off-site. Keeps 7 daily, 4 weekly, and 12 monthly snapshots |
| `security-check.sh` | Reports failed login attempts, open ports, and new user accounts |
| `excludes.txt` | Lists what the backup skips, such as caches and things that reinstall |
| `docs/` | Public home page and privacy policy, which Google requires for the Drive connection |

Each backup stores only what changed, and every snapshot restores as a complete copy.

## Requirements

- [restic](https://restic.net)
- [rclone](https://rclone.org), only for an off-site copy

## Install

```bash
git clone https://github.com/YOUR-USERNAME/laptopguard.git
cd laptopguard
chmod +x backup.sh security-check.sh
```

Create a password file. Keep a copy of the password away from this computer, because without it no backup can be opened.

```bash
mkdir -p ~/.config/laptopguard
read -rs -p "Backup password: " P; echo
printf '%s\n' "$P" > ~/.config/laptopguard/password
unset P
chmod 600 ~/.config/laptopguard/password
```

## Use

```bash
./backup.sh
./security-check.sh
```

For an off-site copy, set `REMOTE_REPO` to a restic repository, such as `rclone:gdrive:laptopguard-backups`.

On its first run, `security-check.sh` saves the current accounts as a baseline. Later runs warn about any account that is not in it.

## Settings

| Variable | Script | Default |
|---|---|---|
| `SOURCE_DIR` | `backup.sh` | `$HOME` |
| `LOCAL_REPO` | `backup.sh` | `$HOME/Backups/laptopguard` |
| `REMOTE_REPO` | `backup.sh` | Empty: no off-site copy |
| `EXCLUDE_FILE` | `backup.sh` | `excludes.txt` next to the script |
| `RESTIC_PASSWORD_FILE` | `backup.sh` | `$HOME/.config/laptopguard/password` |
| `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY` | `backup.sh` | `7`, `4`, `12` |
| `AUTH_LOG` | `security-check.sh` | `/var/log/auth.log` |
| `PASSWD_FILE` | `security-check.sh` | `/etc/passwd` |
| `STATE_DIR` | `security-check.sh` | `$HOME/.local/state/laptopguard` |

## Schedule with cron

Run `crontab -e` and add:

```text
0 21 * * * REMOTE_REPO=rclone:gdrive:laptopguard-backups $HOME/Github/laptopguard/backup.sh >> $HOME/laptopguard.log 2>&1
30 21 * * * $HOME/Github/laptopguard/security-check.sh >> $HOME/laptopguard.log 2>&1
```

Cron skips a run if the laptop is off at that time.

## Restore

Set the repository and password file, then list the snapshots:

```bash
export RESTIC_PASSWORD_FILE=~/.config/laptopguard/password
restic -r ~/Backups/laptopguard snapshots
```

Restore one file from a chosen snapshot:

```bash
restic -r ~/Backups/laptopguard restore SNAPSHOT-ID --target ~/restore --include /full/path/to/note.md
```

Use `latest` for the newest snapshot. If this computer is lost, use the off-site repository with `-r rclone:gdrive:laptopguard-backups`, and the same password.

## Checks

Both scripts pass ShellCheck with zero warnings:

```bash
shellcheck backup.sh security-check.sh
```

## Limits

- The local copy is on the same disk, so it does not protect against losing the computer. The off-site copy does.
- Without the password, no backup can be restored.
- The system and installed apps are not backed up.
- Reading failed logins may need the `adm` group or `sudo`.

## Safety

This repository contains no real notes, passwords, keys, or client data. All tests use invented notes.
