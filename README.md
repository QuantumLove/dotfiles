# METR Development Environment - Claude Code Setup

> **AI-Augmented Development Environment**
> Cross-platform dotfiles management with Claude Code agents, commands, and intelligent automation for METR platform development.

## Quick Start

```bash
# Install prerequisites
brew install claude-code chezmoi jq gh

# Deploy dotfiles
chezmoi init --apply QuantumLove/dotfiles

# Verify setup
claude --version
ls ~/.claude/agents/        # Should show 11 agents
ls ~/.claude/commands/      # Should show 17 commands

# Start using Claude Code
claude
```

## What's Included

### 🤖 11 Specialized Agents (4,665 lines)

1. **code-reviewer** - Expert code review with METR standards and STRIDE integration
2. **security-specialist** - STRIDE threat modeling for METR platform
3. **orchestrator** - Multi-part work coordination with Linear tracking
4. **adversary** - Critical code critic challenging design decisions
5. **performance-engineer** - Data-driven performance optimization
6. **bug-finder** - Systematic debugging and root cause analysis
7. **code-architect** - System design and ADR creation
8. **dev4-deployment-manager** - METR dev4 deployment automation
9. **pr-review-responder** - Autonomous PR feedback implementation
10. **proficiency-coach** - Interactive learning system for this setup
11. **chezmoi-manager** - Self-managing dotfiles agent

### ⚡ 17 Essential Commands (2,859 lines)

**AWS & Cloud**
- `/aws-switch` - Switch AWS profiles with verification
- `/aws-preflight` - Pre-flight checks before AWS operations
- `/ecr-login` - ECR Docker authentication

**DevContainers**
- `/dev-open` - Open VSCode DevContainer (worktree-aware, unique naming)

**Kubernetes**
- `/k8s-reset` - Reset Kubernetes cluster to clean state

**Git Workflow**
- `/start-work` - Quick worktree + issue + branch setup
- `/push-pr` - Create PR with standardized formatting
- `/load-issue` - Fetch issue context via Linear/GitHub MCP
- `/review` - Invoke Code Reviewer agent
- `/sync-main` - Safe branch synchronization with rebase
- `/test-and-fix` - Iterative test failure resolution
- `/safe-ship` - Comprehensive pre-deployment checks
- `/security-check` - STRIDE threat analysis
- `/deploy-dev` - Deploy to METR dev4 environment

**Utilities**
- `/load-env` - Load .env files with secret detection
- `/mcp-check` - Verify MCP authentication status
- `/mcp-setup-1password` - Interactive credential setup

## Usage Examples

### Code Review

```bash
claude
/review                  # Review staged changes
/safe-ship               # Run all quality checks
/push-pr                 # Create pull request
```

### Security Analysis

```bash
claude
/security-check          # Quick scan
@security-specialist "Analyze auth changes"  # Deep analysis
```

### Deployment

```bash
claude
/aws-preflight          # Check credentials
/safe-ship              # Pre-deployment validation
/deploy-dev             # Deploy to dev4
```

## Installation

See the full installation guide and documentation in the complete README above. For detailed implementation details, see `dev-setup-plan.md`.

## Resources

- **Claude Code**: https://docs.anthropic.com/claude-code
- **chezmoi**: https://chezmoi.io
- **Full Documentation**: See README sections above
- **Implementation Plan**: `dev-setup-plan.md` (10,000+ lines)

---

*Built with ❤️ using Claude Code and chezmoi* | *Last updated: 2025-01-15*
