# Claude Code Session Persistence

This document explains how Claude Code sessions persist across different environments (host, DevContainers, and between containers).

## Overview

Claude Code sessions can now be seamlessly resumed across:
- ✅ Host → DevContainer
- ✅ DevContainer → Host
- ✅ DevContainer A → DevContainer B
- ✅ Multiple concurrent environments

## How It Works

### Shared Directories

The following Claude directories are mounted into DevContainers:

#### Session Data (Read/Write)
- `~/.claude/session-env` - Active session environments
- `~/.claude/todos` - Todo lists across all sessions
- `~/.claude/projects` - Project-specific session data
- `~/.claude/cache` - Various caches
- `~/.claude/paste-cache` - Paste history
- `~/.claude/stats-cache.json` - Usage statistics

#### Configuration (Read-Only)
- `~/.claude/agents` - Agent definitions
- `~/.claude/commands` - Command definitions
- `~/.claude/skills` - Skill definitions
- `~/.claude/settings.json` - Claude settings
- `~/.claude/mcp.json` - MCP configuration

### Volume Mounts

The DevContainer configuration automatically adds these mounts:

```json
{
  "mounts": [
    // Session persistence
    {
      "source": "${localEnv:HOME}/.claude/session-env",
      "target": "/home/vscode/.claude/session-env",
      "type": "bind"
    },
    // ... other session directories ...

    // Read-only configuration
    {
      "source": "${localEnv:HOME}/.claude/agents",
      "target": "/home/vscode/.claude/agents",
      "type": "bind",
      "readonly": true
    }
    // ... other config directories ...
  ]
}
```

## Usage Examples

### Scenario 1: Continue work in DevContainer

```bash
# On host
claude
# Start working on a feature, create todos, etc.

# Switch to DevContainer
/dev-open

# In DevContainer
claude
# Your session continues exactly where you left off!
# - Same conversation context
# - Same todo list
# - Same project state
```

### Scenario 2: Work across multiple containers

```bash
# In inspect-action DevContainer
claude
/start-work LIN-123
# Do some work...

# Switch to mp4-deploy DevContainer
cd ~/code/mp4-deploy
/dev-open

# In mp4-deploy DevContainer
claude
# Can reference work from inspect-action session
# Todo list shows items from both projects
```

### Scenario 3: Concurrent sessions

```bash
# Terminal 1 (Host)
claude
# Working on documentation

# Terminal 2 (DevContainer)
claude
# Working on code

# Both sessions share:
# - Todo lists (updates visible in both)
# - Learning history
# - Project contexts
```

## Benefits

1. **Seamless Workflow** - No need to recreate context when switching environments
2. **Unified Todo List** - Track tasks across all environments in one place
3. **Shared Learning** - Improvements captured anywhere benefit all environments
4. **Project Continuity** - Project-specific context follows you

## Technical Details

### Directory Structure

```
~/.claude/
├── session-env/          # Session environments (one per active session)
│   ├── session-abc123/
│   └── session-def456/
├── todos/                # Todo lists (shared across all sessions)
│   ├── todo-uuid1.json
│   └── todo-uuid2.json
├── projects/             # Project-specific data
│   ├── -Users-rafaelcarvalho-code-inspect-action/
│   └── -Users-rafaelcarvalho-code-mp4-deploy/
├── cache/                # Various caches
├── paste-cache/          # Paste history
└── stats-cache.json      # Usage statistics
```

### Session Resolution

Claude determines which session to resume based on:
1. Current working directory
2. Project mapping in `~/.claude/projects/`
3. Session ID if explicitly provided

### Data Safety

- **Configuration is read-only** in containers to prevent accidental modification
- **Session data is shared** but Claude handles concurrent access safely
- **Each session has unique ID** to prevent conflicts

## Troubleshooting

### Session not resuming?

```bash
# Check if directories are mounted
docker inspect <container-name> | jq '.[0].Mounts'

# Verify Claude directories exist
ls -la ~/.claude/
```

### Permission issues?

```bash
# Fix ownership if needed
sudo chown -R $USER:$USER ~/.claude/
```

### Clear session data?

```bash
# Remove old sessions (safe)
rm -rf ~/.claude/session-env/*

# Clear todos (careful!)
rm -rf ~/.claude/todos/*
```

## Configuration

### Manual DevContainer Setup

If not using `/dev-open`, add to your `.devcontainer/devcontainer.json`:

```json
{
  "mounts": [
    // Existing mounts...

    // Add Claude session persistence
    "source=${localEnv:HOME}/.claude/session-env,target=/home/vscode/.claude/session-env,type=bind",
    "source=${localEnv:HOME}/.claude/todos,target=/home/vscode/.claude/todos,type=bind",
    "source=${localEnv:HOME}/.claude/projects,target=/home/vscode/.claude/projects,type=bind",
    // ... other Claude directories ...
  ]
}
```

### Disable Session Sharing

To isolate a DevContainer's Claude sessions:

```json
{
  // Remove Claude mounts or create container-specific directories
  "mounts": [
    // Don't include Claude directories
  ]
}
```

## Security Considerations

1. **Credentials** - MCP tokens are passed via environment variables, not mounted files
2. **Read-only configs** - Prevents accidental damage to Claude setup
3. **Project isolation** - Each project has its own context in `projects/`
4. **No git data shared** - Git credentials remain environment-specific

## Future Enhancements

- Session branching for experimental work
- Session snapshots for rollback
- Cloud sync for remote development
- Session analytics and insights

---

With session persistence, Claude Code becomes a truly unified assistant across your entire development environment!