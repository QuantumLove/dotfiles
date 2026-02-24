# Claude Setup TODOs

Ideas and improvements for the Claude/AI development setup.

## High Priority

- [ ] **Vulnerability Management Agent** - Agent that monitors security advisories, CVEs, and dependency vulnerabilities across repos. Auto-creates issues or PRs for critical updates.

## Medium Priority

- [ ] **Add Gemini API key to OpenCode** - Enable Gemini models in mega-container
- [ ] **Add OpenAI API key to OpenCode** - Enable GPT models in mega-container
- [ ] **Add Copilot key to OpenCode** - Enable GitHub Copilot fallback
- [ ] **Update /start-work for codebase review** - Make it understand when we just want to explore/review code vs. start a new feature
- [ ] **Better notifications** - Improve notification system for long-running tasks, approvals, etc.

- [ ] **End of day ritual** - Learn from sessions and improve setup. Skill that analyzes today's Claude sessions, extracts learnings, and suggests improvements to skills/CLAUDE.md/workflows.

- [ ] **Fork and customize compound-engineering** - Make it more effective for personal workflow. Trim unnecessary agents, tune prompts, add missing capabilities.

- [ ] **Notification system / Approval queue** - System for batching approval requests instead of interrupting. Could be a queue that accumulates while AFK, then review all at once.

- [x] **Phone access for long-running sessions** - ~~Alert when a session has been running >10min~~ SOLVED: mega-container allows direct SSH from phone via Tailscale. Use `ssh mega-dev` + `tmux attach` to check on sessions.

## Ideas to Explore

- [ ] Session summarization on disconnect
- [ ] Auto-commit learnings to `docs/solutions/`
- [ ] MCP health dashboard
- [ ] Cost tracking per session/project

---

*Last updated: 2026-02-24*
