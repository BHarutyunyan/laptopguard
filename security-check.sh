#!/usr/bin/env bash
# security-check.sh: reports failed login attempts, open ports, and new user accounts.
# It only reads system information and changes nothing except its own baseline file.

set -uo pipefail

AUTH_LOG="${AUTH_LOG:-/var/log/auth.log}"
PASSWD_FILE="${PASSWD_FILE:-/etc/passwd}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/laptopguard}"
BASELINE="$STATE_DIR/known-users.txt"

mkdir -p "$STATE_DIR"

echo "Security check: $(date '+%Y-%m-%d %H:%M:%S') on $(hostname)"

echo
echo "== Failed login attempts =="
if [[ -r "$AUTH_LOG" ]]; then
    failed="$(grep -E 'Failed password|authentication failure' "$AUTH_LOG" || true)"
    if [[ -z "$failed" ]]; then
        echo "None found."
    else
        echo "Total: $(printf '%s\n' "$failed" | wc -l)"
        echo "Latest:"
        printf '%s\n' "$failed" | tail -n 5
    fi
elif journal="$(journalctl --no-pager --quiet --since '7 days ago' 2>/dev/null)" && [[ -n "$journal" ]]; then
    failed="$(printf '%s\n' "$journal" | grep -E 'Failed password|authentication failure' || true)"
    if [[ -z "$failed" ]]; then
        echo "None found in the part of the system journal this user can read, last 7 days."
    else
        echo "Total in the last 7 days: $(printf '%s\n' "$failed" | wc -l)"
        echo "Latest:"
        printf '%s\n' "$failed" | tail -n 5
    fi
else
    echo "Could not read $AUTH_LOG. Run with sudo, or add your user to the adm group."
fi

echo
echo "== Open ports =="
if command -v ss > /dev/null 2>&1; then
    ports="$(ss -H -tuln 2>/dev/null | awk '{print $1, $5}' | sort -u)"
    if [[ -z "$ports" ]]; then
        echo "None listening."
    else
        printf '%s\n' "$ports"
    fi
else
    echo "The ss command is not available."
fi

echo
echo "== New user accounts =="
# LC_ALL=C gives sort and comm the same byte order on every system.
current="$(cut -d: -f1 "$PASSWD_FILE" | LC_ALL=C sort)"
if [[ ! -f "$BASELINE" ]]; then
    printf '%s\n' "$current" > "$BASELINE"
    echo "First run: saved $(wc -l < "$BASELINE") accounts as the baseline."
else
    new_users="$(LC_ALL=C comm -13 <(LC_ALL=C sort "$BASELINE") <(printf '%s\n' "$current"))"
    if [[ -z "$new_users" ]]; then
        echo "None."
    else
        echo "WARNING: new accounts since the baseline:"
        printf '%s\n' "$new_users"
    fi
fi
