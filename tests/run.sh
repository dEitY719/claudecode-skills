#!/bin/sh
# tests/run.sh — no framework, no fixtures. Exits non-zero on first failure.
set -eu

repo=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cache_ttl="$repo/skills/cache-ttl/scripts/set-cache-ttl.sh"
statusline="$repo/skills/statusline-setup/scripts/install-statusline.sh"

command -v jq >/dev/null 2>&1 || {
    echo "FAIL setup: jq not installed"
    exit 1
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT INT TERM

pass() { printf 'PASS %s\n' "$1"; }
fail() {
    printf 'FAIL %s: %s\n' "$1" "$2"
    exit 1
}

fresh() {
    CLAUDE_CONFIG_DIR="$work/cfg"
    export CLAUDE_CONFIG_DIR
    rm -rf "$CLAUDE_CONFIG_DIR"
    mkdir -p "$CLAUDE_CONFIG_DIR"
}

# --- cache-ttl -------------------------------------------------------------

t="cache-ttl 1h sets the key to \"1\""
fresh
sh "$cache_ttl" 1h >/dev/null
v=$(jq -r '.env.ENABLE_PROMPT_CACHING_1H' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "1" ] || fail "$t" "got '$v'"
pass "$t"

t="cache-ttl 5m removes the key and the now-empty .env"
sh "$cache_ttl" 5m >/dev/null
v=$(jq -r 'has("env")' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "false" ] || fail "$t" ".env survived: $(cat "$CLAUDE_CONFIG_DIR/settings.json")"
pass "$t"

t="cache-ttl default arg is 5m"
sh "$cache_ttl" 1h >/dev/null
sh "$cache_ttl" >/dev/null
v=$(jq -r '.env.ENABLE_PROMPT_CACHING_1H // "(unset)"' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "(unset)" ] || fail "$t" "got '$v'"
pass "$t"

t="cache-ttl preserves unrelated keys through both flips"
fresh
cat >"$CLAUDE_CONFIG_DIR/settings.json" <<'EOF'
{"model":"sonnet","hooks":{"Stop":[{"matcher":"*"}]},"env":{"KEEP_ME":"yes"}}
EOF
sh "$cache_ttl" 1h >/dev/null
sh "$cache_ttl" 5m >/dev/null
v=$(jq -r '[.model, .hooks.Stop[0].matcher, .env.KEEP_ME] | join(",")' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "sonnet,*,yes" ] || fail "$t" "got '$v'"
pass "$t"

t="cache-ttl on invalid JSON: .bak written, non-zero exit, file untouched"
fresh
printf '{ this is not json' >"$CLAUDE_CONFIG_DIR/settings.json"
if sh "$cache_ttl" 1h >/dev/null 2>&1; then
    fail "$t" "exited 0 on invalid JSON"
fi
[ -f "$CLAUDE_CONFIG_DIR/settings.json.bak" ] || fail "$t" "no .bak written"
grep -q 'this is not json' "$CLAUDE_CONFIG_DIR/settings.json" || fail "$t" "original was overwritten"
pass "$t"

t="cache-ttl rejects a bogus argument"
fresh
if sh "$cache_ttl" 30m >/dev/null 2>&1; then
    fail "$t" "accepted '30m'"
fi
pass "$t"

# --- statusline-setup ------------------------------------------------------

t="install-statusline installs both scripts executable"
fresh
sh "$statusline" >/dev/null
for f in statusline-command.sh statusline-tokens.sh; do
    [ -x "$CLAUDE_CONFIG_DIR/$f" ] || fail "$t" "$f missing or not executable"
done
pass "$t"

t="install-statusline points statusLine.command at the installed script"
v=$(jq -r '.statusLine.command' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "$CLAUDE_CONFIG_DIR/statusline-command.sh" ] || fail "$t" "got '$v'"
[ "$(jq -r '.statusLine.type' "$CLAUDE_CONFIG_DIR/settings.json")" = "command" ] ||
    fail "$t" "statusLine.type is not 'command'"
pass "$t"

t="install-statusline preserves unrelated keys"
fresh
printf '{"model":"opus","env":{"KEEP_ME":"yes"}}\n' >"$CLAUDE_CONFIG_DIR/settings.json"
sh "$statusline" >/dev/null
v=$(jq -r '[.model, .env.KEEP_ME] | join(",")' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "opus,yes" ] || fail "$t" "got '$v'"
pass "$t"

t="install-statusline backs up a modified destination file"
printf '# locally hacked\n' >"$CLAUDE_CONFIG_DIR/statusline-command.sh"
sh "$statusline" >/dev/null
[ -f "$CLAUDE_CONFIG_DIR/statusline-command.sh.bak" ] || fail "$t" "no .bak written"
grep -q 'locally hacked' "$CLAUDE_CONFIG_DIR/statusline-command.sh.bak" ||
    fail "$t" ".bak does not hold the old content"
cmp -s "$repo/skills/statusline-setup/assets/statusline-command.sh" \
    "$CLAUDE_CONFIG_DIR/statusline-command.sh" || fail "$t" "asset was not reinstalled"
pass "$t"

t="install-statusline --dry-run writes nothing"
fresh
sh "$statusline" --dry-run >/dev/null
if [ -e "$CLAUDE_CONFIG_DIR/statusline-command.sh" ]; then fail "$t" "installed a file"; fi
if [ -e "$CLAUDE_CONFIG_DIR/settings.json" ]; then fail "$t" "created settings.json"; fi
pass "$t"

t="install-statusline on invalid JSON: .bak written, non-zero exit"
fresh
printf '{ nope' >"$CLAUDE_CONFIG_DIR/settings.json"
if sh "$statusline" >/dev/null 2>&1; then
    fail "$t" "exited 0 on invalid JSON"
fi
[ -f "$CLAUDE_CONFIG_DIR/settings.json.bak" ] || fail "$t" "no .bak written"
pass "$t"

t="install-statusline --usage-id/--usage-api write both env keys"
fresh
sh "$statusline" --usage-id u123 --usage-api https://example.invalid/usage >/dev/null
v=$(jq -r '[.env.CLAUDE_STATUSLINE_USAGE_ID, .env.CLAUDE_STATUSLINE_USAGE_API] | join(",")' \
    "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "u123,https://example.invalid/usage" ] || fail "$t" "got '$v'"
pass "$t"

t="install-statusline --budget writes env.CLAUDE_STATUSLINE_BUDGET"
fresh
sh "$statusline" --budget 250 >/dev/null
v=$(jq -r '.env.CLAUDE_STATUSLINE_BUDGET' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "250" ] || fail "$t" "got '$v'"
pass "$t"

t="install-statusline usage flags preserve unrelated keys and a sibling env entry"
fresh
cat >"$CLAUDE_CONFIG_DIR/settings.json" <<'EOF'
{"model":"opus","permissions":{"allow":["Bash"]},"hooks":{"Stop":[{"matcher":"*"}]},
 "env":{"ENABLE_PROMPT_CACHING_1H":"1","KEEP_ME":"yes"}}
EOF
sh "$statusline" --usage-id u1 --usage-api https://example.invalid/u --budget 42 >/dev/null
v=$(jq -r '[.model, .permissions.allow[0], .hooks.Stop[0].matcher,
            .env.ENABLE_PROMPT_CACHING_1H, .env.KEEP_ME, .env.CLAUDE_STATUSLINE_BUDGET]
           | join(",")' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "opus,Bash,*,1,yes,42" ] || fail "$t" "got '$v'"
pass "$t"

t="install-statusline leaves an existing env value untouched when the flag is omitted"
sh "$statusline" --budget 99 >/dev/null
v=$(jq -r '[.env.CLAUDE_STATUSLINE_USAGE_ID, .env.CLAUDE_STATUSLINE_USAGE_API,
            .env.CLAUDE_STATUSLINE_BUDGET] | join(",")' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "u1,https://example.invalid/u,99" ] || fail "$t" "got '$v'"
pass "$t"

t="install-statusline warns but still writes when only one usage flag is given"
fresh
out=$(sh "$statusline" --usage-id lonely 2>&1) || fail "$t" "non-zero exit"
case "$out" in *warning:*) ;; *) fail "$t" "no warning printed" ;; esac
v=$(jq -r '.env.CLAUDE_STATUSLINE_USAGE_ID' "$CLAUDE_CONFIG_DIR/settings.json")
[ "$v" = "lonely" ] || fail "$t" "value not written: '$v'"
pass "$t"

t="install-statusline does not warn when the counterpart is already in settings.json"
out=$(sh "$statusline" --usage-api https://example.invalid/u 2>&1) || fail "$t" "non-zero exit"
case "$out" in *warning:*) fail "$t" "warned despite a complete pair" ;; esac
pass "$t"

t="install-statusline rejects a non-integer --budget with exit 2"
fresh
rc=0
sh "$statusline" --budget abc >/dev/null 2>&1 || rc=$?
[ "$rc" = "2" ] || fail "$t" "exit was $rc, expected 2"
if [ -e "$CLAUDE_CONFIG_DIR/settings.json" ]; then fail "$t" "wrote settings.json anyway"; fi
pass "$t"

t="install-statusline rejects a zero and a negative --budget"
for b in 0 -5; do
    if sh "$statusline" --budget "$b" >/dev/null 2>&1; then
        fail "$t" "accepted '$b'"
    fi
done
pass "$t"

t="install-statusline --dry-run with the new flags writes nothing"
fresh
out=$(sh "$statusline" --dry-run --usage-id u1 --usage-api https://example.invalid/u --budget 7)
case "$out" in *CLAUDE_STATUSLINE_USAGE_ID*) ;; *) fail "$t" "did not preview the env keys" ;; esac
if [ -e "$CLAUDE_CONFIG_DIR/settings.json" ]; then fail "$t" "created settings.json"; fi
if [ -e "$CLAUDE_CONFIG_DIR/statusline-command.sh" ]; then fail "$t" "installed a file"; fi
pass "$t"

printf '\nall tests passed\n'
