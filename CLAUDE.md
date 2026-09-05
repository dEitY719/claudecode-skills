# claudecode-skills — Contributor Guidelines

This file is the AI context document for this repo. `AGENTS.md` is a symlink to
it, so Claude Code, Codex, Gemini CLI, and every other harness read the same
text. Edit `CLAUDE.md`; never replace the symlink with a second copy.

## What this repo is

A single-plugin skill marketplace. The plugin is named `claudecode` and it
bundles two skills that configure **Claude Code itself** by patching
`settings.json`:

| Skill | Role |
|-------|------|
| `cache-ttl` | Flip the prompt-cache TTL between 5 minutes and 1 hour (`env.ENABLE_PROMPT_CACHING_1H`). |
| `statusline-setup` | Install the bundled `statusline-command.sh` + `statusline-tokens.sh` and point `.statusLine` at them. |

Both write, and both write to exactly one key. Neither touches `model`,
`permissions`, or `hooks` — do not blur that line when editing one.

## Standalone is the hard requirement (dotfiles #1751 NF-1)

These skills must work on a PC that has **never cloned `dEitY719/dotfiles`**.
Every file a skill needs ships inside its own directory:

- `skills/cache-ttl/scripts/set-cache-ttl.sh`
- `skills/statusline-setup/scripts/install-statusline.sh`
- `skills/statusline-setup/assets/statusline-{command,tokens}.sh`

No skill may reference a path outside its own directory at runtime, source a
`shell-common/` helper, or read `$DOTFILES_ROOT`. There is no `ux_lib` here:
output is plain `printf`. If you find yourself adding a dependency to make a
script prettier, you are breaking NF-1.

**A `SKILL.md` invokes its bundled script through `${CLAUDE_PLUGIN_ROOT:-.}`**,
never by a repo-relative path:

```
sh "${CLAUDE_PLUGIN_ROOT:-.}/skills/cache-ttl/scripts/set-cache-ttl.sh" 1h
```

Installed from the marketplace the skill lives under the plugin root while the
working directory is the user's own project, so a bare
`sh skills/<name>/scripts/<x>.sh` resolves against that project and fails.
`--help` routes included.

Only Claude Code sets `CLAUDE_PLUGIN_ROOT`. The Codex, Gemini, Kimi, Hermes and
OpenCode packagings this repo also ships fall through to `:-.`, so a bundled
script must stay runnable from the repo root.

## The statusline assets are a snapshot, not a link

`skills/statusline-setup/assets/statusline-{command,tokens}.sh` are a
**point-in-time copy** of `dEitY719/dotfiles`
`claude/statusline-{command,tokens}.sh` at commit `b23e4d9`. They do not track
upstream. When dotfiles changes those files, this repo does not notice.

That drift is an explicit **Non-Goal of dotfiles #1751**, not a defect. Re-bundling is a
deliberate manual act: copy both files over, re-apply the one sanctioned
deviation below, bump the commit SHA in every file that carries it, and
re-run `tests/run.sh`. The authoritative checklist — including which files
those are — is `skills/statusline-setup/references/re-bundling.md`.

### The one sanctioned deviation from the original

`statusline-tokens.sh` is byte-identical. `statusline-command.sh` is **not**:
its Bedrock cost segment hard-codes an organisation-internal user id and usage
API host upstream, and this repo is public. The bundled copy reads both from
the environment instead — `CLAUDE_STATUSLINE_USAGE_ID`,
`CLAUDE_STATUSLINE_USAGE_API`, and the optional `CLAUDE_STATUSLINE_BUDGET`
(default 175) — and the segment stays off unless both are set, so an
unconfigured install renders the status line with no cost figure and reaches no
network. **Re-apply this on every re-bundle**; a straight copy of upstream
would republish those identifiers. Apart from that block, never hand-edit an
asset.

Those three variables are **not** exported from a shell rc file. Claude Code
injects `settings.json`'s `env` block into the status line command's
environment — the same route `cache-ttl` uses for `ENABLE_PROMPT_CACHING_1H` —
so `install-statusline.sh` takes `--usage-id` / `--usage-api` / `--budget` and
writes them into `env` through its lossless jq merge. The script never prompts
for them: it runs non-interactively, so `SKILL.md` makes the *harness* ask and
pass them as flags.

The two files must stay side by side wherever they land:
`statusline-command.sh` sources `statusline-tokens.sh` as a sibling of its own
resolved path. It also needs **bash 4.4+** (associative arrays); that is stated
as a prerequisite in `SKILL.md`, not worked around.

## Rules for the shell helpers

Both scripts follow the same contract; keep them in step.

- **Target dir is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`** (dotfiles #1751 F-5). Never
  hard-code `~/.claude` — multi-account setups switch by exporting that var.
- **`jq` or nothing.** Missing `jq` prints install guidance and exits 3. There
  is no `sed` / `python -c` fallback, and adding one is a regression: a
  half-parsed JSON edit that "usually works" is worse than a refusal.
- **Never overwrite invalid JSON.** A `settings.json` that fails `jq -e .` is
  copied to `settings.json.bak` and the script exits 4 without writing.
- **Lossless merge only.** Every unrelated key survives. Write through
  `mktemp` in the target dir + `mv`, so a `jq` failure cannot truncate the real
  file and the replace is atomic on the same filesystem.
- **Plain `printf` for output**, `-h|--help` on every script, and a distinct
  exit code per failure class (2 usage, 3 no jq, 4 bad JSON, 5 missing asset).

`.statusLine.command` is written as an absolute, already-expanded path. Claude
Code does not reliably expand `~` there — do not "tidy" it back into a tilde.

## Layout: root manifests, one flat `skills/`

This repo deliberately does **not** use the nested `plugins/<name>/skills/`
"mono" layout. Every harness manifest sits at the repo root and points at a
single flat `./skills/` directory:

```
.claude-plugin/{marketplace,plugin}.json   Claude Code
.codex-plugin/plugin.json                  Codex
.kimi-plugin/plugin.json                   Kimi CLI
.hermes-plugin/{plugin.yaml,__init__.py}   Hermes Agent
.opencode/plugins/claudecode.js            OpenCode
.agents/plugins/marketplace.json           Antigravity
gemini-extension.json + GEMINI.md          Gemini CLI
skills/<name>/SKILL.md                     the skills themselves
```

Only Claude Code understands the nested mono layout. The other five harnesses
resolve manifests at the repo root and a skills tree at `./skills/`, so nesting
would silently cut this plugin down to Claude-Code-only. **Do not move the
manifests under a `plugins/` directory.**

## Shared assets live in `harness-skills` — link, never copy

Two things this repo depends on are owned by `dEitY719/harness-skills`
(dotfiles #1410 F-5 / D-10):

1. **Per-harness tool mappings** — `references/{codex,kimi,gemini,antigravity,hermes,opencode}-tools.md`.
   This repo carries no `references/` tree of its own; `GEMINI.md`,
   `.opencode/INSTALL.md`, and `.kimi-plugin/plugin.json` link there instead.
   If you are about to paste one in, stop and add a link — one tool rename must
   stay one edit, not fifteen (NF-2).
2. **The CI workflow** — `.github/workflows/skill-check.yml`. This repo's
   `validate.yml` calls it with `plugin-name: claudecode`. Do not re-inline the
   checks here; to change what is checked, open a PR against `harness-skills`.

## Rules for changing skills

- **Skill directory name is the identity.** `skills/<name>/` must match the
  `name:` field in that skill's `SKILL.md` frontmatter, and that field is the
  **bare** name (`cache-ttl`), never namespaced (`claudecode:cache-ttl`). CI
  fails on a `:` in `name:`. The harness supplies the prefix at invocation.
- **Invocation form in prose is namespaced** — `/claudecode:cache-ttl`.
- **Progressive disclosure.** `SKILL.md` stays under 100 lines (CI enforces
  it). Detail goes in that skill's own `references/`, never inlined back.
- **Description budget.** CI sums every skill description and fails past 5,440
  characters — Codex's context budget — and rejects any single description over
  1,024.
- **Prefer fixing the script over describing the fix in prose.** The SKILL.md
  is a short procedure that runs a real helper; the model must not hand-write
  `jq` against `settings.json` at runtime.

## Tests

`tests/run.sh` is a plain POSIX-sh script — no framework, no fixtures. It
points `CLAUDE_CONFIG_DIR` at a temp dir and asserts the contract above: both
flips, unrelated-key survival, the invalid-JSON refusal and its `.bak`, the
statusline install and its `statusLine.command`, the backup-on-modified path,
and `--dry-run` writing nothing. Run it before every commit that touches a
script or an asset:

```sh
sh tests/run.sh
```

It exits non-zero on the first failed assertion. A new behaviour without a new
assertion is not finished.

## Emojis

Not in prose, manifests, or workflow files — token efficiency, same rule as the
upstream dotfiles repo. The gate bans any codepoint at or above `U+1F000` plus
`U+FE0F`; typographic marks such as `✓ ✗` sit below that and are fine.

**One exception:** `skills/statusline-setup/assets/` is verbatim third-party
payload whose rendered status line uses emoji glyphs. Editing them out would
break the snapshot contract above, so CI's emoji gate is passed
`allow-emoji-paths: skills/statusline-setup/assets/` for exactly that reason.
Do not widen the allowlist; do not add emoji anywhere else.

## Version bumps

The version appears in seven manifests: `.claude-plugin/marketplace.json`,
`.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`,
`.kimi-plugin/plugin.json`, `.hermes-plugin/plugin.yaml`,
`gemini-extension.json`, and `package.json`. CI checks that they agree — bump
all of them together. Versioning is independent per repo (dotfiles #1410 D-9); this repo
does not move in lockstep with its siblings.
