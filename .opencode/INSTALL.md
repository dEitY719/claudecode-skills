# Installing claudecode for OpenCode

## Prerequisites

- [OpenCode.ai](https://opencode.ai) installed
- `jq` on PATH (both skills refuse to edit JSON without it)

## Installation

Add the plugin to the `plugin` array in your `opencode.json` (global or
project-level):

```json
{
  "plugin": ["claudecode-skills@git+https://github.com/dEitY719/claudecode-skills.git"]
}
```

Restart OpenCode. The plugin installs through OpenCode's plugin manager and
registers both skills.

OpenCode uses its own plugin install. If you also use Claude Code, Codex, or
another harness, install this plugin separately for each one.

## Usage

Use OpenCode's native `skill` tool:

```
use skill tool to list skills
use skill tool to load cache-ttl
```

Note that these skills configure *Claude Code*. Running them from OpenCode is
legal and works — the bundled scripts are plain POSIX sh and do not care who
invokes them — but nothing renders until Claude Code itself runs.

## Tool mapping

The authoritative OpenCode tool mapping for every `dEitY719/*-skills` repo is
owned by the sibling repo
[`dEitY719/harness-skills`](https://github.com/dEitY719/harness-skills/blob/main/references/opencode-tools.md)
(dotfiles #1410 F-5). Read it there when a skill names a tool you do not
recognise; this repo keeps no copy on purpose. Short version:

- "Run a shell command" -> `bash`. This is the whole job for both skills.
- "Read a file" -> `read`
- "Ask the user" -> OpenCode has no dedicated ask tool; stop and ask in your
  reply, then wait. `cache-ttl` asks when the requested mode is neither `1h`
  nor `5m` — do not guess a default.
- "Invoke a skill" -> OpenCode's native `skill` tool

`apply_patch` is **not** used by either skill. Never edit `settings.json`
directly; run the bundled script.

## Troubleshooting

### Plugin not loading

1. Check logs: `opencode run --print-logs "hello" 2>&1 | grep -i claudecode`
2. Verify the plugin line in your `opencode.json`
3. Make sure you are running a recent version of OpenCode

### Skills not found

1. Use the `skill` tool to list what was discovered
2. Check that the plugin is loading (see above)

### A script exited non-zero

That is the design, not a bug. Exit 3 means `jq` is missing; exit 4 means
`settings.json` is invalid JSON and a `.bak` copy was saved without writing
anything. Fix the cause; do not work around it with `sed` or `python`.

## Getting Help

Report issues: https://github.com/dEitY719/claudecode-skills/issues
