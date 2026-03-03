# Future Plans

## Phase 4: Testing & QoL Polish (ONGOING)

Most of Phase 4 code is complete. What remains is iterative testing and permission tuning.

### Ongoing Tasks

- [ ] 4.1.2 Note annoying permission prompts during usage
- [ ] 4.1.3 Relax specific permissions iteratively
- [ ] 4.2.3 Test /start-work workflow

### Phase 4 Test Procedure

**Test 4.A: Permission Auto-Allow**
```bash
# Test git commit (should be auto-allowed)
cd ~/code/test-repo
echo "test" > test.txt
git add test.txt

# In Claude Code:
> Commit this file with message "test: permission check"

# Expected: Commits WITHOUT asking for permission
```

**Test 4.B: Permission Prompts for Sensitive Actions**
```bash
# In Claude Code:
> Run tofu apply on dev4

# Expected: ASKS for permission
# "Allow Bash(tofu apply *)? [y/N]"
```

**Test 4.C: start-work Skill in Container**
```bash
/start-work eng-999 "Test feature"

# Expected:
# 1. Creates worktree at ~/code/eng-999-test-feature
# 2. Initializes git branch
# 3. Shows: "Ready to work in ~/code/eng-999-test-feature"
```

**Test 4.D: Full Workflow Simulation**
```bash
# 1. Start work
/start-work eng-888 "Add feature X"

# 2. Check context
/where-am-i

# 3. Make changes and commit
echo "feature code" > feature.py
git add feature.py
# Ask Claude to commit - should auto-allow

# 4. Create PR
/pr-create
# Expected: PR with [ENG-888] tag

# 5. Cleanup
gh pr close --delete-branch
git worktree remove ~/code/eng-888-add-feature-x
```

**Test 4.E: Session Persistence Across Devices**
```bash
# From laptop:
ssh raf-dev
tmux new -s work
cd ~/code/some-project
/where-am-i

# Detach: Ctrl+B, D

# From phone (Tailscale app):
ssh raf-dev
tmux attach -t work

# Expected: Same directory, same context, tmux history preserved
```

### Phase 4 Success Criteria

- [ ] `git commit` auto-allowed (no prompt)
- [ ] `tofu apply` prompts for permission
- [ ] MCP write operations prompt for permission
- [ ] `/start-work` creates worktree correctly
- [ ] CLAUDE.md context is available in sessions
- [ ] Full workflow (start → code → commit → PR) works smoothly
- [ ] tmux sessions persist across device switches

---

## Phase 5: Multi-Backend Support (FUTURE)

**Goal:** Same setup works on K8s and VMs

**Only proceed after Phases 1-4 proven stable**

> **Reference:** See [METR/platform#8](https://github.com/METR/platform/pull/8) - Sami's rootless DinD approach for k8s.

### Key Difference: Docker Access on K8s

On k8s, there's no Docker socket to mount. Use DinD sidecar instead:

```yaml
# k8s/mega-container.yaml
services:
  dind:
    image: docker:24.0-dind-rootless
    command: ["dockerd-entrypoint.sh"]
    securityContext:
      privileged: true  # Required for DinD
    nodeSelector:
      dind: "true"  # Route to dedicated Ubuntu nodes
    env:
      - DOCKER_TLS_CERTDIR=""  # Disable TLS for localhost

  mega:
    # ... existing config ...
    env:
      - DOCKER_HOST=tcp://localhost:2375  # Connect to DinD sidecar
    # NO socket mount - uses DinD instead
    dependsOn:
      - dind
```

### Infrastructure Requirements (from Sami's PR)

- Karpenter NodePool with `dind: "true"` label
- EC2NodeClass with Ubuntu 22.04 AMI
- Nodes need: c7i-flex or similar (Nitro), 4-8 CPUs

### Tasks

- [ ] 5.1 Evaluate DevPod vs plain K8s manifests
- [ ] 5.2 Create k8s manifest with DinD sidecar pattern
- [ ] 5.3 Request `dind=true` NodePool from platform team (or reuse Sami's)
- [ ] 5.4 Test Docker builds work via DinD (`DOCKER_HOST=tcp://localhost:2375`)
- [ ] 5.5 Configure resource allocation for K8s
- [ ] 5.6 Document differences: socket mount (local) vs DinD (k8s)

### Architecture (Future K8s)

```
┌─────────────────────────────────────────────────────────────┐
│  Kubernetes Pod                                              │
│  ┌───────────────────┬───────────────────────────────────┐  │
│  │  DinD Sidecar     │  Dev Container                    │  │
│  │  ─────────────────│  ─────────────────────────────────│  │
│  │  • docker:dind    │  • DOCKER_HOST=tcp://localhost    │  │
│  │  • privileged     │  • All dev tools                  │  │
│  │  • TLS disabled   │  • Tailscale for SSH access       │  │
│  └───────────────────┴───────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### VM Backend (Alternative)

For cloud VMs (EC2, GCP, etc.):
- Docker runs natively (no DinD needed)
- Tailscale installed directly
- 1Password CLI with service account
- Consider 1Password SSH Agent over Unix socket forwarding
