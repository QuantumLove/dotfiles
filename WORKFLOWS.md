# Claude Code Workflows

This document describes common development workflows using the Claude Code setup with all custom commands, agents, and integrations.

## Table of Contents

1. [Git Worktree Development Workflow](#git-worktree-development-workflow)
2. [Session Persistence Workflow](#session-persistence-workflow)
3. [Continuous Improvement Workflow](#continuous-improvement-workflow)
4. [Daily Development Workflow](#daily-development-workflow)
5. [Security Review Workflow](#security-review-workflow)
6. [Deployment Workflow](#deployment-workflow)

---

## Git Worktree Development Workflow

The worktree workflow enables parallel development with isolated environments for each feature branch.

### Starting New Work

```bash
# 1. Create a new worktree for your feature
/worktree create fix-auth-bug

# This creates:
# - New worktree at ../inspect-action-fix-auth-bug
# - New branch: fix-auth-bug
# - Linked Linear/GitHub issue (if provided)

# 2. Open in DevContainer with unique name
cd ../inspect-action-fix-auth-bug
/dev-open

# This creates a DevContainer named: inspect-action-fix-auth-bug
# Multiple worktrees can have DevContainers running simultaneously

# Your Claude session continues seamlessly in the DevContainer!
# All todos, context, and conversation history are preserved
```

### Development Cycle

```bash
# In your worktree DevContainer
# 1. Make changes
claude "implement the auth fix we discussed"

# 2. Run tests
/test-and-fix

# 3. Security check before committing
/security-check

# 4. Ship when ready
/safe-ship
```

### Managing Multiple Worktrees

```bash
# List all worktrees and their DevContainers
/dev-list

# Example output:
# 🌳 Git Worktrees:
#   main           → ~/code/inspect-action
#   fix-auth-bug   → ~/code/inspect-action-fix-auth-bug  ← current
#   add-feature    → ~/code/inspect-action-add-feature
#
# 🐳 Running DevContainers:
#   inspect-action-fix-auth-bug    (3 hours ago)
#   inspect-action-add-feature     (1 day ago)

# Clean up finished work
/worktree cleanup fix-auth-bug
# Removes worktree, closes DevContainer, archives branch
```

### Switching Between Worktrees

Using Warp launch configurations:

```bash
# Open all active development environments
warp-cli launch metr-dev

# This opens 4 tabs:
# - inspect-action (main)
# - mp4-deploy
# - metr-iam
# - Claude Code
```

---

## Session Persistence Workflow

Claude Code sessions seamlessly persist across host and DevContainers, allowing you to continue work without losing context.

### How It Works

Your Claude state is automatically shared:
- **Session context** - Conversation history and project state
- **Todo lists** - Unified task tracking across environments
- **Learning logs** - Captured improvements available everywhere
- **Project mappings** - Correct context for each project

### Cross-Environment Development

```bash
# Start on host
claude
claude "let's implement OAuth for the login system"
# Claude creates todos and starts planning

# Switch to DevContainer for implementation
/dev-open

# In DevContainer - session continues!
claude
# Claude: "I see we're implementing OAuth. Let me continue where we left off..."
# All todos and context are preserved
```

### Working Across Multiple Projects

```bash
# Terminal 1: inspect-action DevContainer
claude "debug the authentication timeout issue"
# Claude tracks this in todos

# Terminal 2: mp4-deploy DevContainer
claude "what am I working on?"
# Claude: "You have 2 active tasks:
#   1. [in_progress] Debug auth timeout in inspect-action
#   2. [pending] Deploy OAuth changes"
```

### Session Management

```bash
# View all active sessions
ls ~/.claude/session-env/

# Check todos across all environments
ls ~/.claude/todos/

# Your project contexts
ls ~/.claude/projects/
```

### Benefits

1. **No Context Loss** - Switch environments freely
2. **Unified Todos** - One task list across all environments
3. **Shared Learning** - Improvements apply everywhere
4. **Project Awareness** - Claude knows which project you're in

See [SESSION_PERSISTENCE.md](SESSION_PERSISTENCE.md) for technical details.

---

## Continuous Improvement Workflow

Capture learnings from development sessions to improve your Claude Code configuration.

### During Development

When Claude makes mistakes or learns something new:

```bash
# Claude makes an error about AWS permissions
User: "Actually, in staging we need to use assume-role, not direct credentials"

# Claude should suggest:
claude "I've learned something important about your staging environment. Let me run /track-learning to capture this."

# This triggers learning analysis
/track-learning
```

### Review and Apply Learnings

```bash
# Review pending learnings
/track-learning --review-pending

# Output:
# 📋 Deferred Learnings:
#
# [HIGH] AWS staging uses assume-role
#   Prevents authentication errors in staging deployments
#
# [MEDIUM] Python tests require --no-cov in CI
#   Speeds up CI runs by 40%

# Apply learnings
/track-learning

# This updates:
# - Global: ~/.claude/LEARNING.md
# - Project: .claude/CLAUDE.md
# - Commands: Updates relevant command docs
# - Agents: Enhances agent knowledge
```

### Learning Categories

**HIGH Priority** (Apply immediately):
- Security constraints discovered
- Repeated mistakes (2+ times)
- User corrections

**MEDIUM Priority** (Apply weekly):
- Environment-specific patterns
- Performance optimizations
- Workflow improvements

**LOW Priority** (Apply monthly):
- Personal preferences
- Minor optimizations
- Style guidelines

### Sharing Learnings

```bash
# After applying learnings, share globally
cd ~/.local/share/chezmoi
git add -A
git commit -m "feat: Add staging authentication learnings"
git push

# Other team members get updates
chezmoi update
```

---

## Daily Development Workflow

A typical day with Claude Code:

### Morning Setup

```bash
# 1. Update Claude Code and configurations
/claude-update --check

# 2. Validate everything is working
/claude-validate

# 3. Check MCP integrations
/mcp-check

# 4. Open development environment
warp-cli launch metr-dev
```

### During Development

```bash
# Get context from Linear
/load-issue LIN-123

# Start work
/start-work LIN-123 implement-oauth

# Let Claude help
claude "implement OAuth based on the loaded issue"

# Regular commits
claude "commit the OAuth implementation"

# Push and create PR
/push-pr
```

### End of Day

```bash
# Review learnings
/track-learning

# Clean up stopped containers
/dev-clean

# Backup configuration (weekly)
/claude-backup --name weekly-$(date +%Y%m%d)
```

---

## Security Review Workflow

For security-sensitive changes:

### Pre-Implementation

```bash
# 1. Run security agent for threat modeling
claude "use the security-specialist agent to analyze this OAuth implementation plan"

# 2. Review STRIDE threats
cat .claude/security-review.md
```

### During Implementation

```bash
# Regular security checks
/security-check

# Before each commit
/security-check --pre-commit
```

### Pre-Deployment

```bash
# Full security audit
/security-check full

# Use security-focused Warp workspace
warp-cli launch metr-security

# Review with security specialist
claude "have the security-specialist review all changes in this PR"
```

---

## Deployment Workflow

Deploying to METR dev4 environment:

### Preparation

```bash
# 1. Open deployment workspace
warp-cli launch metr-deploy

# 2. Run preflight checks
/aws-preflight

# 3. Sync with main
/sync-main
```

### Build and Push

```bash
# In build tab
cd ~/code/inspect-action
docker build -t hawk:dev .
/ecr-login
./scripts/build-and-push.sh
```

### Deploy

```bash
# In deploy tab
cd ~/code/mp4-deploy
/tf-apply hawk dev4

# Or use automated deployment
/deploy-dev --component hawk
```

### Validation

```bash
# Check deployment
kubectl get pods -n metr-dev
kubectl logs -n metr-dev deployment/hawk

# Run smoke tests
/deploy-dev --smoke-test
```

---

## Quick Reference

### Most Used Commands

```bash
/start-work ISSUE-ID    # Begin new feature
/safe-ship              # Complete pre-deployment checks
/push-pr                # Create pull request
/test-and-fix           # Run tests, auto-fix failures
/dev-open               # Open DevContainer for worktree
```

### Maintenance Commands

```bash
/claude-update          # Update Claude and configs
/claude-validate        # Validate setup
/claude-backup          # Backup configuration
/claude-diagnostics     # Troubleshoot issues
```

### Learning Commands

```bash
/track-learning         # Analyze session for learnings
/track-learning --stats # Show learning metrics
```

### Emergency Commands

```bash
# Something went wrong
/claude-diagnostics --report

# Restore from backup
/claude-backup --restore latest

# Clean up everything
/dev-clean --all
/k8s-reset
```

---

## Tips and Best Practices

1. **Always use worktrees** for feature development - never work on main directly
2. **Run security checks** before every commit on security-sensitive code
3. **Track learnings** when Claude makes mistakes or discovers patterns
4. **Use agents proactively** - they're specialized for specific tasks
5. **Backup weekly** before major updates or experiments
6. **Validate after updates** to catch issues early
7. **Document project-specific patterns** in `.claude/CLAUDE.md`

---

## Troubleshooting

### MCP Not Working
```bash
/mcp-check
/claude-diagnostics --test-mcp
```

### DevContainer Conflicts
```bash
/dev-list
/dev-clean
```

### Performance Issues
```bash
claude "run the performance-engineer agent to analyze this issue"
```

### Can't Find Commands
```bash
claude list my available commands
/claude-validate
```

For more help, see the [README](README.md) or run `/claude-diagnostics --report` for support.