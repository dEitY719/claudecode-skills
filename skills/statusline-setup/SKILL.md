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

Copies two bundled scripts into the Claude config dir and sets one
`settings.json` key. Everything else in that file is preserved.

## Help

If the argument is `-h`, `--help`, or `help`, run
`scripts/install-statusline.sh --help` and print its output verbatim, then stop.

## Step 1: Check the prerequisites

- `jq` on PATH — the script exits 3 with an install hint otherwise.
- **bash 4.4 or newer** — `statusline-command.sh` uses associative arrays.
  Check with `bash --version`. macOS ships bash 3.2; tell the user to
  `brew install bash` rather than installing a status line that will not run.

## Step 2: Preview, then install

```
sh skills/statusline-setup/scripts/install-statusline.sh --dry-run
sh skills/statusline-setup/scripts/install-statusline.sh
```

Run `--dry-run` first when the user already has a status line configured, and
show them what it says before writing. On a machine with no status line, go
straight to the install.

Target is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, so a multi-account setup
installs per account by exporting `CLAUDE_CONFIG_DIR` before each call.

Do **not** hand-write `jq` against `settings.json` or copy the assets yourself.

## Step 3: Report

Print the resulting `statusLine.command` path and say the status line appears
after Claude Code restarts.

## What the script does

- copies `assets/statusline-command.sh` and `assets/statusline-tokens.sh` into
  the config dir and `chmod +x` on both — they must stay side by side, because
  `statusline-command.sh` sources the tokens helper as a sibling of its own
  resolved path
- if a destination file exists and differs, saves `<name>.bak` first and says so
- sets `.statusLine = {"type":"command","command":"<abs path>"}` with an
  absolute, already-expanded path (Claude Code does not reliably expand `~`
  there), via a read-to-temp + `mv` so a `jq` failure cannot truncate the file
- `--dry-run` prints every one of those steps and writes nothing

## Failure modes — read the exit, do not work around it

| Exit | Meaning | Correct response |
|---|---|---|
| 2 | unknown argument | only `--dry-run` and `--help` exist |
| 3 | `jq` not on PATH | relay the install hint the script printed; stop |
| 4 | `settings.json` is not valid JSON | a `.bak` was saved and nothing was written; tell the user to fix the JSON |
| 5 | a bundled asset is missing | the skill install is damaged; reinstall the plugin |

## Constraints

- Touches exactly one settings key (`statusLine`). Never edit `model`, `env`,
  `hooks`, or `permissions` from this skill.
- Self-contained: no dotfiles checkout, no network, nothing outside this skill
  directory.
- The two assets are a **point-in-time snapshot** of `dEitY719/dotfiles`
  `claude/statusline-*.sh` (commit `b23e4d9`). They do not track upstream —
  re-bundling when dotfiles changes is a manual, deliberate act. Never patch a
  copied asset in place; edit `assets/` and re-run the installer.
- One sanctioned deviation from upstream: the Bedrock cost segment reads
  `CLAUDE_STATUSLINE_USAGE_ID` / `CLAUDE_STATUSLINE_USAGE_API` from the
  environment instead of the hard-coded internal values upstream carries, and
  stays off unless both are set. Re-apply it on every re-bundle.

## Related Skills

`claudecode:cache-ttl` edits the same `settings.json` with the same lossless
merge.
