#!/bin/sh
# set-cache-ttl.sh — flip Claude Code's prompt-cache TTL between 5 minutes and
# 1 hour by patching env.ENABLE_PROMPT_CACHING_1H in settings.json.
#
# Standalone: depends on nothing but POSIX sh and jq. No dotfiles checkout.
set -eu

usage() {
    cat <<'EOF'
Usage: set-cache-ttl.sh [1h|5m]

Flip Claude Code's prompt-cache TTL by patching
env.ENABLE_PROMPT_CACHING_1H in settings.json.

  1h          set the key to "1"  (1-hour cache)
  5m          delete the key       (default 5-minute cache)
  (no arg)    same as 5m
  -h, --help  this text

Target file: ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json
Every unrelated key (hooks, statusLine, model, permissions, ...) is preserved.
Restart Claude Code for the change to take effect.
EOF
}

mode=5m
case "${1-}" in
-h | --help | help)
    usage
    exit 0
    ;;
"") mode=5m ;;
1h | 5m) mode=$1 ;;
*)
    printf 'error: unknown argument "%s" (expected 1h or 5m)\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

if ! command -v jq >/dev/null 2>&1; then
    printf 'error: jq is required and was not found on PATH.\n' >&2
    printf '  Debian/Ubuntu: sudo apt install jq\n' >&2
    printf '  macOS:         brew install jq\n' >&2
    printf '  Fedora:        sudo dnf install jq\n' >&2
    printf 'Refusing to edit JSON without it.\n' >&2
    exit 3
fi

target_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$target_dir/settings.json"

mkdir -p "$target_dir"
if [ ! -f "$settings" ]; then
    printf '{}\n' >"$settings"
    printf 'created %s (was missing)\n' "$settings"
elif ! jq -e . "$settings" >/dev/null 2>&1; then
    cp "$settings" "$settings.bak"
    printf 'error: %s is not valid JSON.\n' "$settings" >&2
    printf 'Saved a copy to %s.bak and made no changes. Fix it by hand.\n' "$settings" >&2
    exit 4
fi

before=$(jq -r '.env.ENABLE_PROMPT_CACHING_1H // "(unset)"' "$settings")

# Read-to-temp + mv: a jq failure can never truncate the real settings file.
tmp=$(mktemp "$target_dir/.settings.json.XXXXXX")
trap 'rm -f "$tmp"' EXIT INT TERM

if [ "$mode" = 1h ]; then
    jq '.env.ENABLE_PROMPT_CACHING_1H = "1"' "$settings" >"$tmp"
else
    jq 'if (.env | type) == "object"
        then (.env |= del(.ENABLE_PROMPT_CACHING_1H))
             | (if (.env | length) == 0 then del(.env) else . end)
        else . end' "$settings" >"$tmp"
fi

mv "$tmp" "$settings"
trap - EXIT INT TERM

after=$(jq -r '.env.ENABLE_PROMPT_CACHING_1H // "(unset)"' "$settings")

printf 'cache TTL: %s -> %s  (env.ENABLE_PROMPT_CACHING_1H: %s -> %s)\n' \
    "$([ "$before" = "1" ] && echo 1h || echo 5m)" \
    "$([ "$mode" = 1h ] && echo 1h || echo 5m)" \
    "$before" "$after"
printf 'file: %s\n' "$settings"
printf 'Restart Claude Code to pick it up.\n'
