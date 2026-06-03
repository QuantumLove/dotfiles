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

**Currently Optional Secrets** (soft-fail at boot, surfaced as warnings by `mega-doctor`):
- `Slack User Token` — Slack MCP disabled if missing
- `GWS Credentials JSON` — morning-triage / Gmail access disabled if missing

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

### OpenCode web returns 502 from the Tailscale URL

**Symptoms:**
- `https://raf-dev.koi-moth.ts.net` shows 502 or "Bad Gateway"
- Container is `(healthy)` but the URL doesn't work

**Diagnose:**
```bash
ssh raf-dev
tail -50 ~/.local/state/opencode-web.log     # opencode web's own log
tailscale serve status                       # should show / → http://127.0.0.1:4096
curl -sf http://127.0.0.1:4096/ >/dev/null && echo "local OK" || echo "local FAIL"
mega-doctor                                  # one-shot summary
```

**Common causes:**
- `opencode web` crashed → restart container (`./start.sh` from host)
- Tailscale serve config drifted → re-run `sudo tailscale serve --bg http://127.0.0.1:4096`
- API key missing → check `~/.secrets_env` and 1Password

---

### Container marked `(unhealthy)` in `docker ps`

The healthcheck probes: tailscale, sshd, cron, opencode web port, claude + opencode binaries.

```bash
mega-doctor   # tells you which specific check failed
docker compose logs mega | tail -50
```

---

## Verification Checklist

```bash
mega-doctor   # comprehensive: binaries, secrets, mounts, MCPs, opencode web, tailscale serve
```

Returns 0 if all critical checks pass. Warnings are printed but don't fail the script.
