# METR Development Environment Setup - Implementation Plan

**Philosophy:** Build a comprehensive, AI-augmented development environment that reduces friction across all workflows while maintaining safety and flexibility.

**Core Insight:** The most valuable automation comes from well-structured Claude Code agents, commands, and contextual awareness. Infrastructure (chezmoi) exists mainly to manage and deploy the Claude Code layer.

**Key Principle:** Everything is a Claude command. No shell functions, no aliases. If I need to run something, I use Claude commands in the Claude terminal.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    chezmoi (Priority 1)                     │
│  Cross-platform dotfiles management                          │
│  Location: ~/.local/share/chezmoi                           │
│  Repo: QuantumLove/dotfiles                                 │
│                                                              │
│  Responsibilities:                                           │
│  ✅ Deploy Claude configs to ~/.claude/                     │
│  ✅ Deploy Claude plugins to ~/.claude-plugin/              │
│  ✅ Detect environment (host vs DevContainer)               │
│  ✅ Adapt configs based on environment                      │
│  ❌ NO Claude Code installation                             │
│  ❌ NO shell functions                                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Claude Code Layer (Priority 2)                  │
│                                                             │
│  ~/.claude/                                                 │
│  ├── agents/           (11 agents)                          │
│  │   ├── code-reviewer.md                                   │
│  │   ├── security-specialist.md                             │
│  │   ├── orchestrator.md                                    │
│  │   └── chezmoi-manager.md ... +7 more                    │
│  │                                                          │
│  ├── commands/         (25+ commands)                       │
│  │   ├── aws-*           (AWS workflows)                    │
│  │   ├── k8s-*           (Kubernetes)                       │
│  │   ├── dev-*           (DevContainer management)         │
│  │   ├── load-issue      (Linear integration)              │
│  │   ├── push-pr         (Git workflow)                     │
│  │   ├── track-learning  (Continuous improvement)          │
│  │   └── ... +more                                          │
│  │                                                          │
│  ├── skills/                                                │
│  │   └── worktree/      (Git worktree management)          │
│  │       ├── SKILL.md                                       │
│  │       ├── scripts/                                       │
│  │       └── templates/                                     │
│  │                                                          │
│  ├── hooks/                                                 │
│  │   ├── notify.sh                 (Notification system)   │
│  │   ├── notify-stop.sh            (Task completion)       │
│  │   ├── notify-permission.sh      (Approval needed)       │
│  │   └── notify-notification.sh    (General alerts)        │
│  │                                                          │
│  ├── settings.json                                          │
│  ├── mcp.json         (MCP server configuration)           │
│  ├── status-line.sh   (Dynamic status display)             │
│  └── LEARNING.md      (Continuous improvement log)         │
│                                                             │
│  ~/.local/bin/                                              │
│  └── claude-notify-daemon.py  (HTTP notification server)    │
│                                                             │
│  ~/.warp/launch_configurations/                             │
│  ├── metr-dev.yaml                                          │
│  ├── metr-deploy.yaml                                       │
│  └── metr-security.yaml                                     │
└─────────────────────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. No Shell Functions
All functionality is implemented as Claude commands, not shell functions or aliases. This ensures consistency across environments and makes the system more discoverable.

### 2. Session Persistence
Claude sessions persist across host and DevContainers through mounted directories. This enables seamless workflow transitions without losing context.

### 3. Automated Authentication
1Password service account tokens eliminate interactive authentication, enabling fully automated workflows.

### 4. Worktree-First Development
Git worktrees with unique DevContainer names enable true parallel development without conflicts.

### 5. Continuous Learning
The system improves over time by capturing and applying learnings from usage patterns.

---

## Implementation Checklist

### Phase 1: Core Infrastructure - DONE ✓
- [x] Create `.chezmoi.toml.tmpl` with environment detection
- [x] Set up directory structure
- [x] Create validation scripts
- [x] Create core configuration files (settings.json, mcp.json, status-line.sh)

### Phase 2: Agents - DONE ✓
- [x] Create 11 specialized agents (completed)
- [x] Total: 4,665 lines of agent definitions
- [x] Each agent has proper METR context and formatting

### Phase 3: Commands - DONE ✓
- [x] Create all 17 commands initially
- [x] safe-ship (comprehensive pre-deployment checks)
- [x] sync-main (safely sync main branch)
- [x] test-and-fix (iterative test fixing)
- [x] security-check (STRIDE threat analysis)
- [x] deploy-dev (METR dev4 deployment)

### Phase 4: Advanced Features - DONE ✓
- [x] Create comprehensive README.md documentation
- [x] Create templates (CLAUDE.md, LEARNING.md)
- [x] Add dev-list, dev-clean, tf-apply commands
- [x] Set up .zshrc with 1Password integration
- [x] Commit all changes

### Phase 5: Git Worktree Skill - DONE ✓
- [x] Create worktree skill with DevContainer support
- [x] Add helper scripts and templates
- [x] Integrate with development workflow

### Phase 6: Notification Hooks - DONE ✓
- [x] Create notification hook scripts
- [x] Implement Python notification daemon
- [x] Set up LaunchAgent for auto-start
- [x] Add installation script

### Phase 7: Context7 Integration - SKIPPED
- [ ] ~~Configure Context7 MCP server~~ (User doesn't have Context7)
- [ ] ~~Set up credentials in 1Password~~ (Not applicable)
- [ ] ~~Test PR analysis features~~ (Not applicable)

### Phase 8: Final Deployment - DONE ✓
- [x] Apply all changes with chezmoi
- [x] Remove Context7 from all configurations
- [x] Create track-learning command (21st command)
- [x] Create Warp launch configurations (3 configs: metr-dev, metr-deploy, metr-security)
- [x] Write comprehensive README (completed)
- [x] Create maintenance commands (4 commands: claude-update, claude-validate, claude-backup, claude-diagnostics)
- [x] Write validation test script (validation scripts created)
- [x] Add troubleshooting guide (in README)
- [x] Document worktree workflows (WORKFLOWS.md created)
- [x] Document continuous improvement workflows (CONTINUOUS_IMPROVEMENT.md created)

### Phase 9: Polish - COMPLETE ✅
- [x] Create Warp launch configurations (3 files: metr-dev, metr-deploy, metr-security)
- [x] Write comprehensive README (completed)
- [x] Create maintenance commands (4 commands: claude-update, claude-validate, claude-backup, claude-diagnostics)
- [x] Write validation test script (validation scripts created)
- [x] Add troubleshooting guide (in README)
- [x] Document worktree workflows (WORKFLOWS.md created)
- [x] Document continuous improvement workflows (CONTINUOUS_IMPROVEMENT.md created)

**Phase 6: Continuous Improvement ★ NEW** ✅ COMPLETE
- [x] Create `templates/CLAUDE.md.template` (54 lines - project context template)
- [x] Create `templates/LEARNING.md.template` (38 lines - learning log template)
- [x] Create `/track-learning` command (187 lines)
- [ ] Add CLAUDE.md to dev-one project - USER TODO
- [ ] Add LEARNING.md to dev-one project - USER TODO
- [ ] Test `/track-learning` command - USER TODO
- [x] Verify learning detection in agents (built into all agents)
- [ ] Document first learning and update - USER TODO

**Phase 7: MCP & Authentication** ⚠️ USER ACTION REQUIRED
- [x] Install 1Password CLI (user confirmed)
- [ ] Store credentials in 1Password vault - USER ACTION REQUIRED (see above)
- [x] Configure .zshrc to load credentials via `op read`
- [x] Update DevContainer configs with remoteEnv (in dev-open command)
- [ ] Test MCP authentication in host - USER TODO
- [ ] Test MCP authentication in DevContainer - USER TODO

**Phase 8: Cross-Environment**
- [ ] Test complete setup on macOS
- [ ] Test complete setup in inspect-action DevContainer
- [ ] Test complete setup in mp4-deploy DevContainer
- [ ] Test DevContainer opening from worktrees
- [ ] Test notifications across environments
- [ ] Document any environment-specific workarounds
- [ ] Fix any cross-environment issues

---

## Testing Strategy

### Integration Testing Overview
The system requires comprehensive testing across multiple environments and scenarios. Full testing strategy is implemented in validation scripts and the `/claude-validate` command.

### Test Categories
1. **Foundation**: Environment detection, file deployment, permissions
2. **Agent Loading**: All 11 agents load and respond correctly
3. **Command Execution**: All 25+ commands work as expected
4. **MCP Integration**: Linear and GitHub APIs authenticate and function
5. **Cross-Environment**: Sessions persist between host and containers
6. **Worktree Workflows**: Parallel development with unique containers
7. **Notification System**: Alerts work across environments

---

## Summary Stats

- **Total Agents**: 11 (4,665 lines)
- **Total Commands**: 25+ (5,000+ lines)
- **Total Skills**: 1 (worktree management)
- **Documentation**: 4 comprehensive guides
- **Configuration Files**: 5 core files
- **Total Implementation**: ~15,000+ lines

The implementation transforms development workflow into an AI-first approach where Claude Code acts as an intelligent assistant across all tasks, from code review to deployment, with full session persistence and automated authentication.