# laptopguard

Two Bash scripts that protect personal data on a Linux laptop. Built for cycle 1 of the TUMO Labs Guided Self-Learning cybersecurity track.

| File | What it does |
|---|---|
| `backup.sh` | Makes an encrypted backup of the home folder with restic, on this computer and optionally off-site. Keeps 7 daily, 4 weekly, and 12 monthly snapshots |
| `security-check.sh` | Reports failed login attempts, open ports, and new user accounts |
| `n8n-export` | Saves every n8n workflow as a JSON file once a day, so the backup holds readable copies |
| `anacrontab` | The daily jobs, so a day missed while the laptop was off catches up |
| `excludes.txt` | Lists what the backup skips, such as caches and things that reinstall |
| `docs/` | Public home page and privacy policy, which Google requires for the Drive connection; [restore proof](docs/restore-proof.png) |

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

## Schedule

Cron alone skips a run when the laptop is off or asleep, so cron starts **anacron**, which runs each
job once a day and catches up missed days. Run `crontab -e` and add:

```text
@reboot /usr/sbin/anacron -s -t $HOME/Github/laptopguard/anacrontab -S $HOME/.anacron
0 * * * * /usr/sbin/anacron -s -t $HOME/Github/laptopguard/anacrontab -S $HOME/.anacron
```

`anacrontab` runs `backup.sh` (with the Google Drive copy) 5 minutes after start and
`security-check.sh` 10 minutes after, both logging to `~/laptopguard.log`.

## n8n workflows

n8n runs in Docker on this laptop, only on `127.0.0.1:5678`, with its data in `~/n8n-data`
(a folder in my home, so `backup.sh` already includes it, encrypted):

```bash
sudo docker run -d --name n8n --restart unless-stopped -p 127.0.0.1:5678:5678 \
  -v ~/n8n-data:/home/node/.n8n docker.n8n.io/n8nio/n8n
```

The live database can change in the middle of a backup, so once a day `n8n-export` also writes
every workflow to `~/n8n-data/workflows-export/` as a separate JSON file, a clean copy that is
easy to read and restore (n8n: Workflows → Import from File). Install it once:

```bash
sudo install -m 755 -o root -g root n8n-export /etc/cron.daily/n8n-export
```

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

All scripts pass ShellCheck with zero warnings:

```bash
shellcheck backup.sh security-check.sh n8n-export
```

## Limits

- The local copy is on the same disk, so it does not protect against losing the computer. The off-site copy does.
- Without the password, no backup can be restored.
- The system and installed apps are not backed up.
- Reading failed logins may need the `adm` group or `sudo`.
- n8n credentials are in the backup only in encrypted form, together with their key in `~/n8n-data/config`: restore both together.

## Safety

This repository contains no real notes, passwords, keys, or client data. All tests use invented notes.
