---
name: mega:where-am-i
description: Quick orientation - environment, project, branch, current task
allowed-tools: Bash(git *), Bash(hostname), Bash(cat *), Read
---

# /where-am-i

Quick context for orientation when starting a session or switching projects.

## Output Format

```
/where-am-i
───────────
Environment: mega-container (via Tailscale)
Project: inspect-ai
Branch: feature/new-scorer
Working on: Adding parallel evaluation support
```

## Implementation

Gather and display:

1. **Environment**: Check hostname or `$CONTAINER_NAME` env var
   - If hostname contains "mega" or CONTAINER_NAME is set: "mega-container (via Tailscale)"
   - Otherwise: "host"

2. **Project**: Parse from git or directory
   ```bash
   basename $(git remote get-url origin 2>/dev/null | sed 's/\.git$//') || basename $(pwd)
   ```

3. **Branch**: Current git branch
   ```bash
   git branch --show-current
   ```

4. **Working on**: Read from `.current-task` file if exists
   ```bash
   cat .current-task 2>/dev/null || echo "No task set"
   ```

## Task Tracking

Users can set their current task:
```bash
echo "Adding parallel evaluation support" > .current-task
```

This file is gitignored and purely for session context.
