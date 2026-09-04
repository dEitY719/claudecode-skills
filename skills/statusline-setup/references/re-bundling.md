# Re-bundling the statusline assets

`skills/statusline-setup/assets/statusline-command.sh` and
`statusline-tokens.sh` are a **point-in-time snapshot** of `dEitY719/dotfiles`
`claude/statusline-{command,tokens}.sh` at commit `b23e4d9`. They do not track
upstream: when dotfiles changes those files, this repo does not notice. That
drift is an explicit Non-Goal of dotfiles #1751, not a defect.

Re-bundling is a deliberate manual act:

1. Copy both files over from the dotfiles checkout.
2. Re-apply the one sanctioned deviation below.
3. Bump the commit SHA in `CLAUDE.md`, `SKILL.md`, `README.md` and this file.
4. Re-run `sh tests/run.sh`.

Never patch an installed copy in place — edit `assets/` and re-run the
installer.

## The one sanctioned deviation

`statusline-tokens.sh` is byte-identical to its source. `statusline-command.sh`
is not: upstream hard-codes an organisation-internal user id and usage-API host
in its Bedrock cost segment, and this repo is public. The bundled copy reads
both from the environment instead — `CLAUDE_STATUSLINE_USAGE_ID`,
`CLAUDE_STATUSLINE_USAGE_API`, and the optional `CLAUDE_STATUSLINE_BUDGET`
(default 175) — and the segment stays off unless the first two are non-empty, so
an unconfigured install renders the status line with no cost figure and makes no
network call.

The same block's `~/.dotfiles-setup-mode` gate is widened here too: upstream
requires the file to read `internal`, while this copy also accepts it being
absent or empty. That file is a dotfiles artefact and a standalone install of
this plugin has none, so the upstream form would lock every colleague out of
the segment with no error explaining why. A file that reads something else
(`external`) is still honoured as an explicit "not this machine".

Those variables reach the script through `settings.json`'s `env` block, which
Claude Code injects into the status line command's environment. That is why
`install-statusline.sh` writes them there with `--usage-id` / `--usage-api` /
`--budget`, rather than telling the user to export them from a shell rc file.
The sibling `cache-ttl` skill relies on the same mechanism for
`ENABLE_PROMPT_CACHING_1H`.

**Re-apply this deviation on every re-bundle.** A straight copy of upstream
would republish those internal identifiers.
