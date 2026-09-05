# claudecode-skills

Two skills that configure **Claude Code itself** — the prompt-cache TTL and the
status line — by patching `settings.json` without losing a single unrelated
key. Packaged as one plugin named `claudecode`, installable on six coding-agent
harnesses.

Everything they need ships inside the plugin. A machine that has never cloned
`dEitY719/dotfiles` gets the same result as one that has.

## Skills

| Skill | Invoke | What it does |
|-------|--------|--------------|
| `cache-ttl` | `/claudecode:cache-ttl [1h\|5m]` | Flips `env.ENABLE_PROMPT_CACHING_1H` — sets it to `"1"` for a 1-hour prompt cache, deletes it (and an emptied `.env`) to go back to the 5-minute default. Prints the before -> after value. |
| `statusline-setup` | `/claudecode:statusline-setup [--dry-run]` | Copies the bundled `statusline-command.sh` + `statusline-tokens.sh` into the Claude config dir, makes them executable, and sets `.statusLine` to run the installed path. Backs up a modified destination file first. |

Both target `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, so a multi-account setup
configures each account by exporting that variable before the call.

### Visual guides and worked examples (GitHub Pages)

Landing page: <https://deity719.github.io/claudecode-skills/>

- `cache-ttl` — [visual guide](https://deity719.github.io/claudecode-skills/skill-guides/cache-ttl.html) · [usage example](https://deity719.github.io/claudecode-skills/skill-output/cache-ttl-usage.html) (settings.json to settings.json, one env key)
- `statusline-setup` — [visual guide](https://deity719.github.io/claudecode-skills/skill-guides/statusline-setup.html) · [usage example](https://deity719.github.io/claudecode-skills/skill-output/statusline-setup-usage.html) (bundled assets to installed status line)

## Safety contract

Both scripts behave identically at the edges, and the tests enforce it:

- **`jq` or nothing.** No `jq` on PATH prints install guidance and exits 3.
  There is no `sed` / `python` fallback — a half-parsed JSON edit that "usually
  works" is worse than a refusal.
- **Invalid JSON is never overwritten.** A `settings.json` that fails
  `jq -e .` is copied to `settings.json.bak` and the script exits 4 having
  written nothing.
- **Lossless merge.** `hooks`, `model`, `permissions`, `statusLine`, `env` —
  everything unrelated survives. Writes go through a temp file in the target
  directory and an atomic `mv`, so a `jq` failure cannot truncate the real file.
- **One key each.** `cache-ttl` touches `env.ENABLE_PROMPT_CACHING_1H`;
  `statusline-setup` touches `statusLine`. Neither touches anything else.

Restart Claude Code for either change to take effect.

## Prerequisites

- `jq`
- **bash 4.4+** for `statusline-setup` — `statusline-command.sh` uses
  associative arrays. macOS ships bash 3.2; `brew install bash` first.

## Install

### Claude Code

```
/plugin marketplace add dEitY719/claudecode-skills
/plugin install claudecode@claudecode-skills
```

### Codex

```
codex plugin install dEitY719/claudecode-skills
```

### Kimi CLI

```
kimi plugin install dEitY719/claudecode-skills
```

### Hermes Agent

```
hermes plugins install dEitY719/claudecode-skills
```

### OpenCode

See [`.opencode/INSTALL.md`](.opencode/INSTALL.md).

### Gemini CLI / Antigravity

```
gemini extensions install https://github.com/dEitY719/claudecode-skills
```

Antigravity (`agy`) shares `~/.gemini`, so it inherits the install.

## Harness support

Both skills are one `Bash` call over a bundled POSIX-sh script, so they port
cleanly everywhere. The per-harness tool mappings are documented once, in
[`dEitY719/harness-skills/references/`](https://github.com/dEitY719/harness-skills/tree/main/references)
(#1410 F-5).

| Skill | Claude Code | Codex | Kimi | Gemini / Antigravity | Hermes | OpenCode |
|-------|:-----------:|:-----:|:----:|:--------------------:|:------:|:--------:|
| `cache-ttl` | full | full | full | full | full | full |
| `statusline-setup` | full | full | full | full | full | full |

The status line only renders inside Claude Code, but installing it from another
harness works — the scripts do not care who runs them.

## Layout

Manifests live at the repo root and all point at one flat `skills/` directory:

```
.
├── skills/
│   ├── cache-ttl/{SKILL.md, scripts/set-cache-ttl.sh}
│   └── statusline-setup/{SKILL.md, scripts/, assets/, references/}
├── tests/run.sh                                    POSIX-sh, no framework
├── .claude-plugin/{marketplace,plugin}.json        Claude Code
├── .codex-plugin/plugin.json                       Codex
├── .kimi-plugin/plugin.json                        Kimi CLI
├── .hermes-plugin/{plugin.yaml,__init__.py}        Hermes Agent
├── .opencode/plugins/claudecode.js + INSTALL.md    OpenCode
├── .agents/plugins/marketplace.json                Antigravity
├── gemini-extension.json + GEMINI.md               Gemini CLI
├── package.json
├── CLAUDE.md · AGENTS.md -> CLAUDE.md
└── LICENSE
```

Only Claude Code understands a nested `plugins/<name>/skills/` layout. The other
five harnesses resolve manifests at the repo root and a skills tree at
`./skills/`, so this repo keeps everything flat. See [`CLAUDE.md`](CLAUDE.md) for
the full rationale and contribution rules.

The `.kimi-plugin/` manifest is pre-provisioned: Kimi CLI is not installed on the
maintainer's machines yet, and shipping the manifest now costs nothing and saves
a migration later.

## Tests

```sh
sh tests/run.sh
```

Plain POSIX sh, no framework. It points `CLAUDE_CONFIG_DIR` at a temp directory
and asserts every bullet of the safety contract above, printing `PASS`/`FAIL`
per case and exiting non-zero on the first failure.

## CI

[`.github/workflows/validate.yml`](.github/workflows/validate.yml) calls the
reusable workflow owned by
[`dEitY719/harness-skills`](https://github.com/dEitY719/harness-skills/blob/main/.github/workflows/skill-check.yml)
(#1410 D-10) — manifest parsing, required files, skill frontmatter,
progressive-disclosure line limits, the Codex description budget, version
agreement, shellcheck, and an emoji gate.

There are no checks defined in this repo. To change what is validated here, open
a PR against `harness-skills`.

The emoji gate is passed `allow-emoji-paths: skills/statusline-setup/assets/`:
those two files are verbatim third-party payload and their rendered status line
uses emoji glyphs. Nothing else in the repo may carry one.

## Provenance

`skills/statusline-setup/assets/statusline-{command,tokens}.sh` are a snapshot of
[`dEitY719/dotfiles`](https://github.com/dEitY719/dotfiles)
`claude/statusline-{command,tokens}.sh` at commit `b23e4d9`. They **do not track
upstream** — re-bundling when dotfiles changes is a deliberate manual act, and
that drift is an explicit Non-Goal of dotfiles #1751 rather than a defect.

`statusline-tokens.sh` is byte-identical to its source. `statusline-command.sh`
carries one deliberate deviation: upstream hard-codes an organisation-internal
user id and usage-API host in its Bedrock cost segment, so the bundled copy
reads them from `CLAUDE_STATUSLINE_USAGE_ID` / `CLAUDE_STATUSLINE_USAGE_API`
(plus optional `CLAUDE_STATUSLINE_BUDGET`, default 175) and keeps the segment
off unless both are set. An unconfigured install makes no network call.

You do not export those by hand. Claude Code injects `settings.json`'s `env`
block into the status line command's environment, so the skill asks for the two
values when the machine needs them and `install-statusline.sh --usage-id ID
--usage-api URL [--budget N]` writes them into `env` with the same lossless jq
merge it uses for `statusLine`. An omitted flag leaves that key untouched.

This repo answers dotfiles #1751. It is a sibling of `authoring-skills`,
`harness-skills`, and the other split-out plugin repos from the #1410 migration.

## License

MIT. See [LICENSE](LICENSE).
