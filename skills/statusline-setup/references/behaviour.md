# What `install-statusline.sh` does

Reference detail for Step 4's report. The script is the contract; this file
only explains what it already does, so nothing here is a second procedure.

- Copies both assets side by side into `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`
  and `chmod +x` them, backing up a differing destination as `<name>.bak`
  first. `statusline-command.sh` sources the tokens helper as a sibling of its
  own resolved path, so the two files cannot be separated.
- Writes `.statusLine` as an **absolute** path — Claude Code does not reliably
  expand `~` there — plus whichever `env.CLAUDE_STATUSLINE_*` flag was passed,
  in one read-to-temp + `mv` so a `jq` failure cannot truncate `settings.json`.
- An omitted flag leaves that key exactly as it is; a value already present is
  never cleared. Passing only one of `--usage-id` / `--usage-api` warns and
  still exits 0, because the counterpart may already be in `settings.json`.
- Prints `statusLine.command`, one `env.<KEY> = <value>` line per key that is
  set, the settings file path, and the restart reminder. Step 4 prefixes `[OK]`
  to that output; it does not reformat it.
