---
name: statusline-setup
description: >-
  Install this repo's bundled Claude Code status line (model, branch, context,
  tokens) and set settings.json's statusLine. Use on "상태줄 설치해줘",
  "statusline 세팅", "/claudecode:statusline-setup". Custom status lines: the
  built-in `statusline-setup` agent.
license: MIT
compatibility:
  tools: Bash, Read
  network: optional
metadata:
  model_recommendation:
    tier: haiku
    reason: "copies two bundled assets and runs one script; no authoring, no analysis"
    claude: prefer
    non_claude: advisory-only
---

# Status Line Installer

Copies two bundled scripts into the Claude config dir and sets `statusLine`
(plus, on request, three `env` keys) in `settings.json`, preserving every other key.

## Help

If the argument is `-h`, `--help`, or `help`, read `references/help.md` and
follow it, then stop.

## Step 1: Check the prerequisites

- `jq` on PATH — the script exits 3 with an install hint otherwise.
- **bash 4.4 or newer** — `statusline-command.sh` uses associative arrays; macOS
  ships bash 3.2, so tell the user to `brew install bash` before installing.

## Step 2: Ask for the Bedrock cost values, if this machine needs them

Only when **the user asked for the cost segment** or `~/.dotfiles-setup-mode`
reads `internal`, and `.env.CLAUDE_STATUSLINE_USAGE_ID` is absent from
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`: ask for the usage id, the
usage-API URL, and a budget if not the default 175. Otherwise skip this step
silently and install with no cost segment.

**You** ask — the script never prompts (a `read` would hang); pass the answers as Step 3 flags.

## Step 3: Preview, then install

```
sh "${CLAUDE_PLUGIN_ROOT:-.}/skills/statusline-setup/scripts/install-statusline.sh" --dry-run
sh "${CLAUDE_PLUGIN_ROOT:-.}/skills/statusline-setup/scripts/install-statusline.sh" \
    [--usage-id ID --usage-api URL] [--budget N]   # flags only if Step 2 asked
```

| Option | Description | Default |
|---|---|---|
| `--dry-run` | print what would happen, write nothing | off |
| `--usage-id ID` | set `env.CLAUDE_STATUSLINE_USAGE_ID` | unset — key left as-is |
| `--usage-api URL` | set `env.CLAUDE_STATUSLINE_USAGE_API` | unset — key left as-is |
| `--budget N` | set `env.CLAUDE_STATUSLINE_BUDGET`, positive integer | unset — key left as-is; the status line renders 175 |

Run `--dry-run` first with the same flags — a bare one hides the `env` keys —
and show that output before writing. Target is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`;
export it to install per account. Never hand-write `jq` or copy the assets yourself.

## Step 4: Report

On exit 0, prefix `[OK]` to the script's own output and relay it verbatim:

```
[OK] statusLine.command = /home/you/.claude/statusline-command.sh
env.CLAUDE_STATUSLINE_USAGE_ID = <id>
file: /home/you/.claude/settings.json
Restart Claude Code to pick it up.
```

An `env.*` line appears only for a key that is set. On a non-zero exit print
`[FAIL] exit=<n>` and relay stderr verbatim. Internals: `references/behaviour.md`.

## Failure modes — read the exit, do not work around it

| Exit | Meaning | Correct response |
|---|---|---|
| 2 | unknown argument, missing flag value, or a `--budget` that is not a positive integer | fix the invocation; see `--help` |
| 3 | `jq` not on PATH | relay the install hint the script printed; stop |
| 4 | `settings.json` is not valid JSON | a `.bak` was saved and nothing was written; tell the user to fix the JSON |
| 5 | a bundled asset is missing | the skill install is damaged; reinstall the plugin |

## Constraints

- Touches `statusLine` and the three `CLAUDE_STATUSLINE_*` keys under `env`,
  nothing else — never `model`, `hooks`, `permissions`, or another `env` entry.
- Self-contained: no dotfiles checkout, no file outside this skill; the status
  line calls the usage API only when `--usage-id` and `--usage-api` were given.
- The assets are a **point-in-time snapshot** of `dEitY719/dotfiles` (commit
  `b23e4d9`) with one sanctioned deviation; they do not track upstream. Never
  patch a copied asset in place. Full rules: `references/re-bundling.md`.

## Related Skills

`claudecode:cache-ttl` edits the same `settings.json` with the same lossless merge.
