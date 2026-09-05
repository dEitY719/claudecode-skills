---
name: cache-ttl
description: >-
  Flip Claude Code's prompt-cache TTL between 5 minutes and 1 hour by patching
  env.ENABLE_PROMPT_CACHING_1H in settings.json. Use on "프롬프트 캐시 1시간으로",
  "cache TTL 5분으로 되돌려", "/claudecode:cache-ttl". Do NOT use to edit any
  other setting, or to change the model (that is `/model`).
compatibility:
  tools: Bash, Read
metadata:
  model_recommendation:
    tier: haiku
    reason: "runs one bundled shell script with a two-value argument; no analysis"
    claude: prefer
    non_claude: advisory-only
---

# Prompt Cache TTL Switch

Writes one key in `settings.json`. Everything else in that file is preserved.

## Help

If the argument is `-h`, `--help`, or `help`, run
`sh "${CLAUDE_PLUGIN_ROOT:-.}/skills/cache-ttl/scripts/set-cache-ttl.sh" --help`
and print its output verbatim, then stop.

## Step 1: Pick the mode

| User says | Mode |
|---|---|
| "1시간", "1h", "long cache", "extend the cache" | `1h` |
| "5분", "5m", "기본값", "back to default", "turn it off" | `5m` |
| nothing recognisable | ask which one; do not guess |

## Step 2: Run the script

```
sh "${CLAUDE_PLUGIN_ROOT:-.}/skills/cache-ttl/scripts/set-cache-ttl.sh" 1h
sh "${CLAUDE_PLUGIN_ROOT:-.}/skills/cache-ttl/scripts/set-cache-ttl.sh" 5m
```

No argument means `5m`. The script targets
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`, so a multi-account setup
switches accounts by exporting `CLAUDE_CONFIG_DIR` before the call.

Do **not** hand-write `jq` or `sed` against `settings.json` instead. The script
is the contract; a one-off edit is how an unrelated key gets dropped.

## Step 3: Report

Print the script's before -> after line as-is and add one sentence: the change
takes effect after Claude Code restarts.

## What the script does

- `1h` -> `.env.ENABLE_PROMPT_CACHING_1H = "1"`
- `5m` -> deletes that key, and drops `.env` entirely if it becomes empty
- missing `settings.json` -> creates `{}` first, then patches
- reads to a temp file and `mv`s it into place, so a `jq` failure cannot
  truncate the real file

## Failure modes — read the exit, do not work around it

| Exit | Meaning | Correct response |
|---|---|---|
| 2 | argument was neither `1h` nor `5m` | re-read Step 1 and re-run |
| 3 | `jq` not on PATH | relay the install hint the script printed; stop |
| 4 | `settings.json` is not valid JSON | a `.bak` copy was saved and nothing was written; tell the user to fix the JSON |

Never fall back to `sed`, `python -c`, or a hand-written rewrite when the
script refuses. Refusing to touch broken JSON is the feature.

## Constraints

- Touches exactly one key. Never edit `model`, `hooks`, `permissions`, or
  `statusLine` from this skill.
- Requires `jq`. There is no degraded mode.
- Self-contained: the script depends on nothing outside this skill directory.

## Related Skills

`claudecode:statusline-setup` installs the status line into the same
`settings.json` using the same lossless merge.
