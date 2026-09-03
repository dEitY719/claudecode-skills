/**
 * claudecode plugin for OpenCode.ai
 *
 * Auto-registers the skills directory via the config hook (no symlinks needed).
 *
 * Like the sibling authoring plugin, this one injects no per-session bootstrap
 * context. Both skills are task-triggered — you reach for one when Claude
 * Code's prompt-cache TTL or status line needs changing — so OpenCode's native
 * `skill` tool discovering them is all that is needed.
 */

import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export const ClaudeCodePlugin = async () => {
  const claudecodeSkillsDir = path.resolve(__dirname, '../../skills');

  return {
    // Inject skills path into live config so OpenCode discovers claudecode
    // skills without requiring manual symlinks or config file edits.
    // This works because Config.get() returns a cached singleton — modifications
    // here are visible when skills are lazily discovered later.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(claudecodeSkillsDir)) {
        config.skills.paths.push(claudecodeSkillsDir);
      }
    },
  };
};
