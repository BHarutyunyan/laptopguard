#!/usr/bin/env bash
# backup.sh: encrypted backup of a home folder with restic, on this computer and off-site.
# Each run stores only what changed, and every snapshot restores as a complete copy.
# Keeps 7 daily, 4 weekly, and 12 monthly snapshots.

set -uo pipefail
export PATH="/usr/local/bin:/usr/bin:/bin:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SOURCE_DIR="${SOURCE_DIR:-$HOME}"
LOCAL_REPO="${LOCAL_REPO:-$HOME/Backups/laptopguard}"
REMOTE_REPO="${REMOTE_REPO:-}"
EXCLUDE_FILE="${EXCLUDE_FILE:-$SCRIPT_DIR/excludes.txt}"
export RESTIC_PASSWORD_FILE="${RESTIC_PASSWORD_FILE:-$HOME/.config/laptopguard/password}"
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-12}"

fail() {
    echo "Error: $1" >&2
    exit 1
}

command -v restic > /dev/null 2>&1 || fail "restic is not installed."
[[ -d "$SOURCE_DIR" ]] || fail "source folder not found: $SOURCE_DIR"
[[ -f "$EXCLUDE_FILE" ]] || fail "exclude file not found: $EXCLUDE_FILE"
[[ -s "$RESTIC_PASSWORD_FILE" ]] || fail "password file missing or empty: $RESTIC_PASSWORD_FILE"

backup_to() {
    local repo="$1"

    if ! restic -r "$repo" cat config > /dev/null 2>&1; then
        echo "Setting up repository: $repo"
        restic -r "$repo" init > /dev/null || return 1
    fi

    restic -r "$repo" backup --quiet --exclude-file "$EXCLUDE_FILE" "$SOURCE_DIR"
    local result=$?
    # Code 3 means the backup finished but some files, such as locked ones, could not be read.
    if [[ $result -eq 3 ]]; then
        echo "Warning: some files could not be read. The rest were saved."
    elif [[ $result -ne 0 ]]; then
        return 1
    fi

    restic -r "$repo" forget --quiet --prune \
        --keep-daily "$KEEP_DAILY" \
        --keep-weekly "$KEEP_WEEKLY" \
        --keep-monthly "$KEEP_MONTHLY" || return 1

    echo "Saved to: $repo"
}

mkdir -p "$(dirname "$LOCAL_REPO")"
backup_to "$LOCAL_REPO" || fail "local backup failed."

if [[ -n "$REMOTE_REPO" ]]; then
    backup_to "$REMOTE_REPO" || fail "off-site backup failed. The local backup is safe."
else
    echo "Note: REMOTE_REPO is not set, so there is no off-site copy."
fi
