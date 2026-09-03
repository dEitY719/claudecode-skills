#!/bin/sh
# install-statusline.sh — install the bundled statusline scripts into the
# Claude config dir and point settings.json's statusLine at them.
#
# Standalone: the two assets ship inside this skill. No dotfiles checkout.
set -eu

usage() {
    cat <<'EOF'
Usage: install-statusline.sh [--dry-run]

Install the bundled statusline-command.sh + statusline-tokens.sh into
${CLAUDE_CONFIG_DIR:-$HOME/.claude}/ and set settings.json's statusLine
block to run it.

  --dry-run   print what would happen, write nothing
  -h, --help  this text

An existing destination file that differs from the bundled asset is saved
as <name>.bak before being replaced. Every unrelated settings.json key
(hooks, env, model, permissions, ...) is preserved.

Requires jq and bash 4.4+ (statusline-command.sh uses associative arrays).
EOF
}

dry_run=0
case "${1-}" in
-h | --help | help)
    usage
    exit 0
    ;;
"") ;;
--dry-run) dry_run=1 ;;
*)
    printf 'error: unknown argument "%s"\n\n' "$1" >&2
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

skill_dir=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
assets="$skill_dir/assets"

target_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$target_dir/settings.json"

# Absolute, already-expanded path: Claude Code does not reliably expand `~`
# in statusLine.command, so the literal target dir is written out.
command_path="$target_dir/statusline-command.sh"

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

# Read-to-temp + mv: a jq failure can never truncate the real settings file.
tmp=$(mktemp "$target_dir/.settings.json.XXXXXX")
trap 'rm -f "$tmp"' EXIT INT TERM
jq --arg cmd "$command_path" \
    '.statusLine = {"type": "command", "command": $cmd}' \
    "$settings" >"$tmp"
mv "$tmp" "$settings"
trap - EXIT INT TERM

printf 'statusLine.command = %s\n' "$(jq -r '.statusLine.command' "$settings")"
printf 'file: %s\n' "$settings"
printf 'Restart Claude Code to pick it up.\n'
