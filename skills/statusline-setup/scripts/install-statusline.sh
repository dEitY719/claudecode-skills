#!/bin/sh
# install-statusline.sh — install the bundled statusline scripts into the
# Claude config dir and point settings.json's statusLine at them.
#
# Standalone: the two assets ship inside this skill. No dotfiles checkout.
set -eu

usage() {
    cat <<'EOF'
Usage: install-statusline.sh [--dry-run] [--usage-id ID] [--usage-api URL]
                             [--budget N]

Install the bundled statusline-command.sh + statusline-tokens.sh into
${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ and set settings.json's statusLine
block to run it.

  --dry-run        print what would happen, write nothing
  --usage-id ID    set env.CLAUDE_STATUSLINE_USAGE_ID
  --usage-api URL  set env.CLAUDE_STATUSLINE_USAGE_API
  --budget N       set env.CLAUDE_STATUSLINE_BUDGET (positive integer)
  -h, --help       this text

The three env keys drive the Bedrock cost segment, which stays off unless
both --usage-id and --usage-api are set. Claude Code injects settings.json's
`env` block into the status line command's environment, so they belong there
and not in a shell rc file. Omitting a flag leaves that key exactly as it is —
a value you already have is never cleared.

An existing destination file that differs from the bundled asset is saved
as <name>.bak before being replaced. Every unrelated settings.json key
(hooks, model, permissions, other env entries, ...) is preserved.

Requires jq and bash 4.4+ (statusline-command.sh uses associative arrays).
EOF
}

bad_arg() {
    printf 'error: %s\n\n' "$1" >&2
    usage >&2
    exit 2
}

need_value() {
    # $1 = flag name, $2 = remaining arg count including the flag itself
    [ "$2" -ge 2 ] || bad_arg "$1 needs a value"
}

dry_run=0
usage_id=''
usage_id_set=0
usage_api=''
usage_api_set=0
budget=''
budget_set=0

while [ $# -gt 0 ]; do
    case "$1" in
    -h | --help | help)
        usage
        exit 0
        ;;
    --dry-run) dry_run=1 ;;
    --usage-id)
        need_value --usage-id $#
        usage_id=$2
        usage_id_set=1
        shift
        ;;
    --usage-api)
        need_value --usage-api $#
        usage_api=$2
        usage_api_set=1
        shift
        ;;
    --budget)
        need_value --budget $#
        case "$2" in
        '' | *[!0-9]*) bad_arg "--budget must be a positive integer, got \"$2\"" ;;
        esac
        [ "$2" -gt 0 ] || bad_arg "--budget must be a positive integer, got \"$2\""
        budget=$2
        budget_set=1
        shift
        ;;
    *) bad_arg "unknown argument \"$1\"" ;;
    esac
    shift
done

if ! command -v jq >/dev/null 2>&1; then
    printf 'error: jq is required and was not found on PATH.\n' >&2
    printf '  Debian/Ubuntu: sudo apt install jq\n' >&2
    printf '  macOS:         brew install jq\n' >&2
    printf '  Fedora:        sudo dnf install jq\n' >&2
    printf 'Refusing to edit JSON without it.\n' >&2
    exit 3
fi

skill_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
assets="$skill_dir/assets"

target_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$target_dir/settings.json"

# Absolute, already-expanded path: Claude Code does not reliably expand `~`
# in statusLine.command, so the literal target dir is written out.
command_path="$target_dir/statusline-command.sh"

# Value of an env key already in settings.json, or empty. Never fatal: a
# missing or unreadable file just means "not configured yet".
existing_env() {
    [ -f "$settings" ] || return 0
    jq -r --arg k "$1" '.env[$k] // empty' "$settings" 2>/dev/null || true
}

# The cost segment needs the id and the API URL together. Warn — but do not
# fail — when only one of them will end up set.
warn_partial() {
    [ $((usage_id_set + usage_api_set)) -eq 1 ] || return 0
    _have_id=$usage_id_set
    _have_api=$usage_api_set
    if [ "$_have_id" -eq 0 ] && [ -n "$(existing_env CLAUDE_STATUSLINE_USAGE_ID)" ]; then
        _have_id=1
    fi
    if [ "$_have_api" -eq 0 ] && [ -n "$(existing_env CLAUDE_STATUSLINE_USAGE_API)" ]; then
        _have_api=1
    fi
    [ "$_have_id" -eq 0 ] || [ "$_have_api" -eq 0 ] || return 0
    if [ "$_have_id" -eq 0 ]; then
        _missing='--usage-id'
    else
        _missing='--usage-api'
    fi
    printf 'warning: the Bedrock cost segment needs the usage id and the usage\n' >&2
    printf '  API URL together; %s is still unset, so the segment stays off.\n' "$_missing" >&2
    printf '  Writing what was given anyway; re-run with %s to turn it on.\n' "$_missing" >&2
}

for f in statusline-command.sh statusline-tokens.sh; do
    [ -f "$assets/$f" ] || {
        printf 'error: bundled asset missing: %s\n' "$assets/$f" >&2
        exit 5
    }
done

[ "$dry_run" -eq 1 ] || mkdir -p "$target_dir"

# statusline-command.sh sources statusline-tokens.sh as a sibling of its own
# resolved path, so both must land in the same directory.
for f in statusline-command.sh statusline-tokens.sh; do
    src="$assets/$f"
    dst="$target_dir/$f"
    if [ -f "$dst" ] && ! cmp -s "$src" "$dst"; then
        if [ "$dry_run" -eq 1 ]; then
            printf 'would back up %s -> %s.bak\n' "$dst" "$dst"
        else
            cp "$dst" "$dst.bak"
            printf 'backed up existing %s -> %s.bak\n' "$f" "$f"
        fi
    fi
    if [ "$dry_run" -eq 1 ]; then
        printf 'would install %s (mode 755)\n' "$dst"
    else
        cp "$src" "$dst"
        chmod +x "$dst"
        printf 'installed %s\n' "$dst"
    fi
done

if [ "$dry_run" -eq 1 ]; then
    printf 'would set .statusLine.command = %s in %s\n' "$command_path" "$settings"
    [ "$usage_id_set" -eq 0 ] ||
        printf 'would set .env.CLAUDE_STATUSLINE_USAGE_ID = %s\n' "$usage_id"
    [ "$usage_api_set" -eq 0 ] ||
        printf 'would set .env.CLAUDE_STATUSLINE_USAGE_API = %s\n' "$usage_api"
    [ "$budget_set" -eq 0 ] ||
        printf 'would set .env.CLAUDE_STATUSLINE_BUDGET = %s\n' "$budget"
    warn_partial
    printf 'dry run: nothing written.\n'
    exit 0
fi

if [ ! -f "$settings" ]; then
    printf '{}\n' >"$settings"
    printf 'created %s (was missing)\n' "$settings"
elif ! jq -e . "$settings" >/dev/null 2>&1; then
    cp "$settings" "$settings.bak"
    printf 'error: %s is not valid JSON.\n' "$settings" >&2
    printf 'Saved a copy to %s.bak and made no changes. Fix it by hand.\n' "$settings" >&2
    exit 4
fi

warn_partial

# One filter, built up from whichever flags were given. A flag that was not
# passed contributes nothing, so its key keeps whatever value it already had.
filter='.statusLine = {"type": "command", "command": $cmd}'
set -- --arg cmd "$command_path"
if [ "$usage_id_set" -eq 1 ]; then
    set -- "$@" --arg usage_id "$usage_id"
    filter="$filter | .env.CLAUDE_STATUSLINE_USAGE_ID = \$usage_id"
fi
if [ "$usage_api_set" -eq 1 ]; then
    set -- "$@" --arg usage_api "$usage_api"
    filter="$filter | .env.CLAUDE_STATUSLINE_USAGE_API = \$usage_api"
fi
if [ "$budget_set" -eq 1 ]; then
    set -- "$@" --arg budget "$budget"
    filter="$filter | .env.CLAUDE_STATUSLINE_BUDGET = \$budget"
fi

# Read-to-temp + mv: a jq failure can never truncate the real settings file.
tmp=$(mktemp "$target_dir/.settings.json.XXXXXX")
trap 'rm -f "$tmp"' EXIT INT TERM
jq "$@" "$filter" "$settings" >"$tmp"
mv "$tmp" "$settings"
trap - EXIT INT TERM

printf 'statusLine.command = %s\n' "$(jq -r '.statusLine.command' "$settings")"
for k in CLAUDE_STATUSLINE_USAGE_ID CLAUDE_STATUSLINE_USAGE_API CLAUDE_STATUSLINE_BUDGET; do
    v=$(existing_env "$k")
    [ -z "$v" ] || printf 'env.%s = %s\n' "$k" "$v"
done
printf 'file: %s\n' "$settings"
printf 'Restart Claude Code to pick it up.\n'
