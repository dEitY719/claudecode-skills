# Locating and running the bundled script

Every invocation of `set-cache-ttl.sh` — Step 2 and the `--help` route alike —
goes through the block below. It is the only place this skill spells the path.

```sh
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || {                                                # tier 5
    printf '[claudecode:cache-ttl] CLAUDE_PLUGIN_ROOT is unset, so the bundled script cannot be located. On Claude Code this is a broken install; on any other harness export CLAUDE_PLUGIN_ROOT=<the directory you read SKILL.md from> first.\n' >&2
    return 1 2>/dev/null || exit 1
}
_CC="$CLAUDE_PLUGIN_ROOT/skills/cache-ttl/scripts/set-cache-ttl.sh"                  # tier 2
[ -r "$_CC" ] || {                                                                   # tier 5
    printf '[claudecode:cache-ttl] %s is not readable — broken install.\n' "$_CC" >&2
    return 1 2>/dev/null || exit 1
}
```

Then run one of:

```sh
sh "$_CC" 1h        # set env.ENABLE_PROMPT_CACHING_1H to "1"
sh "$_CC" 5m        # delete the key (5-minute default cache)
sh "$_CC" --help    # the help route
```

`CLAUDE_CONFIG_DIR` still prefixes the call when a multi-account setup needs it:
`CLAUDE_CONFIG_DIR=~/.claude-work1 sh "$_CC" 1h`.

## Why the guard, and not `${CLAUDE_PLUGIN_ROOT:-.}`

A `:-.` default splices the **current working directory** into the path when
the variable is unset, and these skills run inside whatever project the user
happens to be in. `harness-skills#22` retired that tier for the whole family:
`$PWD` is caller-controlled, so a repository under review could supply the
very file the skill is about to execute. There is no check that helps —
anything the target repo can satisfy is not a check — so the answer is to
have no tier that guesses. The full ladder and its reasoning:
[`harness-skills/references/plugin-root.md`](https://github.com/dEitY719/harness-skills/blob/main/references/plugin-root.md).

**Only Claude Code sets `CLAUDE_PLUGIN_ROOT` for you.** On Codex, Gemini CLI,
Kimi, Hermes and OpenCode the agent exports it itself, from the directory it
read this skill out of — that path is always known, because reading the skill
is how the run started:

```sh
export CLAUDE_PLUGIN_ROOT=~/.codex/plugins/claudecode-skills
```

That is the contract, not a workaround. Falling through to the cwd was never
equivalent to it: it worked only when the user happened to be standing in this
repo, and silently ran something else when they were not.
