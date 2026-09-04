---
name: statusline-setup
description: >-
  Install the bundled Claude Code status line — model, git branch, context and
  token usage — into the Claude config dir and point settings.json's statusLine
  at it. Use on "상태줄 설치해줘", "statusline 세팅", "/claudecode:statusline-setup".
  Do NOT use to write a custom status line from scratch, or to edit any other
  settings key.
compatibility:
  tools: Bash, Read
metadata:
  model_recommendation:
    tier: haiku
    reason: "copies two bundled assets and runs one script; no authoring, no analysis"
    claude: prefer
    non_claude: advisory-only
---

# Status Line Installer

Copies two bundled scripts into the Claude config dir and sets `statusLine`
(plus, on request, three `env` keys) in `settings.json`. Everything else in that
file is preserved.

## Help

If the argument is `-h`, `--help`, or `help`, run
`scripts/install-statusline.sh --help` and print its output verbatim, then stop.

## Step 1: Check the prerequisites

- `jq` on PATH — the script exits 3 with an install hint otherwise.
- **bash 4.4 or newer** — `statusline-command.sh` uses associative arrays.
  Check with `bash --version`. macOS ships bash 3.2; tell the user to
  `brew install bash` rather than installing a status line that will not run.

## Step 2: Ask for the Bedrock cost values, if this machine needs them

Only when `~/.dotfiles-setup-mode` reads `internal` and
`.env.CLAUDE_STATUSLINE_USAGE_ID` is absent from
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`: ask the user for the usage
id and the usage-API URL (and a budget, if not the default 175), then pass them
as flags in Step 3. Otherwise skip this step.

**You** ask — the script never prompts. It runs non-interactively, so a `read`
in it would hang. In Claude Code use `AskUserQuestion`; a harness with no ask
tool stops and asks in its reply, then waits for the answer.

## Step 3: Preview, then install

```
sh skills/statusline-setup/scripts/install-statusline.sh --dry-run
sh skills/statusline-setup/scripts/install-statusline.sh \
    --usage-id ID --usage-api URL [--budget N]
```

Run `--dry-run` first when the user already has a status line, and show them the
output before writing. Target is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, so a
multi-account setup installs per account by exporting `CLAUDE_CONFIG_DIR` first.
Do **not** hand-write `jq` against `settings.json` or copy the assets yourself.

## Step 4: Report

Print the resulting `statusLine.command` and any `env.CLAUDE_STATUSLINE_*` line
the script echoed, and say the status line appears after Claude Code restarts.

## What the script does

- copies both assets side by side and `chmod +x` them, backing up a differing
  destination as `<name>.bak` first — `statusline-command.sh` sources the tokens
  helper as a sibling of its own resolved path, so they cannot be separated
- writes `.statusLine` (absolute path: Claude Code does not reliably expand `~`
  there) plus whichever `env.CLAUDE_STATUSLINE_*` flag was passed, in one
  read-to-temp + `mv` so a `jq` failure cannot truncate the file
- an omitted flag leaves that key alone; only one usage flag warns and exits 0

## Failure modes — read the exit, do not work around it

| Exit | Meaning | Correct response |
|---|---|---|
| 2 | unknown argument, missing flag value, or a `--budget` that is not a positive integer | fix the invocation; see `--help` |
| 3 | `jq` not on PATH | relay the install hint the script printed; stop |
| 4 | `settings.json` is not valid JSON | a `.bak` was saved and nothing was written; tell the user to fix the JSON |
| 5 | a bundled asset is missing | the skill install is damaged; reinstall the plugin |

## Constraints

- Touches `statusLine` and the three `CLAUDE_STATUSLINE_*` keys under `env`,
  nothing else. Never edit `model`, `hooks`, `permissions`, or another `env`
  entry from this skill.
- Self-contained: no dotfiles checkout, no network, no file outside this skill.
- The assets are a **point-in-time snapshot** of `dEitY719/dotfiles` (commit
  `b23e4d9`) carrying one sanctioned deviation, and they do not track upstream.
  Never patch a copied asset in place. Full rules, and why the cost segment
  reads its id and host from `env`: `references/re-bundling.md`.

## Related Skills

`claudecode:cache-ttl` edits the same `settings.json` with the same lossless
merge.
