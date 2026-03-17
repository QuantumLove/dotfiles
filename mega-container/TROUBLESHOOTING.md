# Mega-Container Troubleshooting

## Common Issues

### SSH Agent "communication with agent failed"

**Symptoms:**
- Container keeps restarting
- Logs show `ERROR: SSH agent not available after 5 attempts`
- `ssh-add -l` inside container returns "communication with agent failed"

**Root Cause:**
The 1Password SSH agent socket (`~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock`) is broken - it's a directory instead of a socket file.

**Solution:**
1. Quit 1Password completely (Cmd+Q or menu bar → Quit)
2. Remove the broken directory:
   ```bash
   rm -rf ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
   ```
3. Reopen 1Password
4. Verify SSH agent is enabled: Settings → Developer → "Use the SSH agent"
5. Test it works: `SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock ssh-add -l`
6. Restart the container: `cd ~/mega-container && docker compose down && docker compose up -d`

**Verification:**
```bash
# Should show socket file (srw-------), NOT directory (drwx------)
ls -la ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
```

---

### Container stuck at "Connecting to minikube network..."

**Symptoms:**
- Container keeps restarting
- Logs show "Connecting to minikube network..." then restart

**Root Cause:**
The entrypoint was using cgroup v1 parsing (`/proc/self/cgroup`) to get container ID, but cgroup v2 (used by OrbStack) doesn't include container ID in that format.

**Solution:**
Fixed in commit fe89d53 - now uses `hostname` which is the container ID in Docker.

---

### Chezmoi fails on missing 1Password secrets

**Symptoms:**
- `chezmoi: .claude.json: exit status 1`
- Logs show `[ERROR] could not read secret 'op://Development/XXX/credential'`

**Root Cause:**
A required 1Password item doesn't exist in the Development vault.

**Solution:**
1. Check which secret is missing from the error message
2. Either:
   - Create the missing item in 1Password (Development vault)
   - Or make the secret optional in `modify_dot_claude.json.tmpl` (add `2>/dev/null || echo ""`)

**Currently Optional Secrets:**
- `Slack User Token` - TODO: make required once Slack MCP is configured

---

### Docker not running after reboot

**Symptoms:**
- Container commands fail with "Cannot connect to the Docker daemon"

**Solution:**
```bash
open -a OrbStack
# Wait a few seconds for Docker to start
docker info
```

---

## Verification Checklist

After starting the container, verify all services:

```bash
# Container is healthy
docker compose ps  # Should show "healthy"

# Bootstrap completed
docker compose logs mega | grep "Bootstrap Complete"

# SSH into container works
ssh raf-dev

# Inside container:
claude --version
gh auth status
op account get
docker info
tailscale status
```
