# claudecode — skill index

Two skills that configure Claude Code itself by patching `settings.json`. Each
lives in this extension's `skills/` directory. They are task-triggered: load
the one that matches the job by reading its `SKILL.md`, then follow it.

| Skill | Read | Use when |
|-------|------|----------|
| `cache-ttl` | `@./skills/cache-ttl/SKILL.md` | The prompt cache should live 1 hour instead of the default 5 minutes, or should go back to 5 minutes. |
| `statusline-setup` | `@./skills/statusline-setup/SKILL.md` | Claude Code needs the bundled status line (model, git branch, context and token usage) installed and wired into `settings.json`. |

## Picking between them

They edit different keys of the same file and never overlap:

- `env.ENABLE_PROMPT_CACHING_1H` -> `cache-ttl`
- `statusLine` -> `statusline-setup`
- anything else in `settings.json` (`model`, `permissions`, `hooks`) -> neither
  of these. Use Claude Code's own `/model` and `/config`, or edit by hand.

Both write. Neither is read-only, and neither has a "check" mode other than
`statusline-setup --dry-run`.

## Standalone by design

Every file these skills need ships inside the extension — the two shell helpers
under `skills/*/scripts/` and the two status line assets under
`skills/statusline-setup/assets/`. Nothing is fetched, and no `dEitY719/dotfiles`
checkout is required. Do not "helpfully" substitute a path from some other repo.

## Tool mapping for Gemini CLI

Both skills are thin wrappers over one bundled shell script each. On Gemini CLI
the actions they name resolve to:

- "Run a shell command" -> `run_shell_command` (this is the whole job)
- "Read a file" -> `read_file`
- "Ask the user" -> `ask_user`

`write_file` and `replace` are **not** used by either skill. Do not reach for
them against `settings.json`.

The full mapping, including every capability gap and its workaround, is owned by
the sibling repo `dEitY719/harness-skills` at `references/gemini-tools.md`
(dotfiles #1410 F-5) — read it there; this repo keeps no copy. On Antigravity
read that repo's `references/antigravity-tools.md` instead: `agy` shares
`~/.gemini` but not Gemini CLI's tool names.

## Prerequisites and capability gaps

- **`jq` is mandatory.** Missing `jq` exits 3 with install guidance. There is no
  degraded mode, and inventing one with `sed` or `python` is forbidden.
- **`statusline-setup` needs bash 4.4+** on the machine that will *run* the
  status line (associative arrays). macOS ships bash 3.2; say so rather than
  installing something that will not run.
- **Multi-account**: both scripts target `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`.
  Export `CLAUDE_CONFIG_DIR` before the call to configure a non-default account.
- The status line itself is a Claude Code feature. Installing it from another
  harness is legal and works, but nothing will render until Claude Code runs.

## Safety rules

- **Never hand-write JSON edits.** Run the bundled script. A one-off `jq` or
  `sed` line typed into the transcript is how an unrelated key gets dropped.
- **A non-zero exit is a stop, not a prompt to improvise.** Exit 3 (no `jq`) and
  exit 4 (invalid JSON, `.bak` saved) both mean: relay the message and stop.
- **Preview before overwriting.** When the user already has a status line, run
  `install-statusline.sh --dry-run` first and show them the output.
- **Never fabricate the result.** Report the path and values the script actually
  printed, not what you expect them to be.
