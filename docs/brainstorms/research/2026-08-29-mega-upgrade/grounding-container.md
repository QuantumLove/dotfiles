# Grounding: mega-container setup streamlining

Two identical trees: `/Users/rafael/mega-container/` (applied) and
`/Users/rafael/.local/share/chezmoi/mega-container/` (source). `diff -rq` on
Dockerfile, entrypoint.sh, start.sh/rebuild.sh, docker-compose.yml: **no content
drift** — only chezmoi naming (`dot_config`→`.config`, `executable_*`→bare).

## 1. Boot path, step by step

- `~/mega-container/start.sh:7-14` — cd to `$MEGA_DIR`, errors if missing ("Run chezmoi apply first").
- `start.sh:19-25` — pull `OP_SERVICE_ACCOUNT_TOKEN` from macOS Keychain via `security find-generic-password`; exit 1 if empty.
- `start.sh:30` — `docker compose up -d`.
- `start.sh:36-54` — poll `docker compose logs mega` up to 300×2s=10min for `"=== Bootstrap Complete ==="`; scrapes Tailscale login URL from logs and prints it once.
- `start.sh:57-66` — checks `tailscale status` inside container; if unauth'd, prints one-time manual command.
- Inside container, `entrypoint.sh` (`ENTRYPOINT` in Dockerfile:200) runs under `set -euo pipefail`:
  - `entrypoint.sh:8-38` — start `tailscaled`, poll up to 10x1s, `tailscale up --ssh` blocks on first-boot login (persists in `tailscale-state` volume thereafter).
  - `:41-52` — chown `$HOME/code`, opencode dir, tmux-snapshots dir if root-owned (Docker creates named volumes as root).
  - `:55-58` — chmod 666 docker.sock.
  - `:63-73` — fail fast if `docker compose`/`docker buildx` plugins broken.
  - `:76-91` — connect to `minikube` docker network via `hostname` as container ID (if minikube network exists).
  - `:94-101` — QEMU binfmt install for cross-platform builds; **fails hard** if this fails.
  - `:104-227` — sequential FAIL-FAST 1Password reads: OP token check → Anthropic key → OpenAI key → Gemini key → GitHub PAT → Datadog API+App key → GWS creds (soft-fail) → Docker Hub + dhi.io login. Each `op read` failure is `exit 1` except GWS.
  - `:229-266` — SSH agent check, retry loop (5× 2s), fail if `ssh-add -l` never succeeds; populates `~/.ssh/authorized_keys` from `ssh-add -L`, fails if empty.
  - `:268-271` — starts sshd (fallback; Tailscale SSH primary).
  - `:276` — resolves Tailscale hostname for opencode CORS.
  - `:283-313` — `chezmoi init`/`chezmoi apply --force` (must run **before** opencode web starts, else opencode/omo pin to defaults for container lifetime); injects `ANTHROPIC_API_KEY` into `~/.claude.json`.
  - `:316-329` — starts `opencode web` on 127.0.0.1:4096 with CORS for the Tailscale hostname, polls up to 30x1s, fails if not up.
  - `:332-336` — `tailscale serve --bg` exposes it; fails hard if this fails.
  - `:340-350` — starts supercronic in a restart loop (`while true`) for durability saves; soft-warns if missing.
  - `:355-358` — `tmux-boot-restore` restores last saved tmux/opencode session set (no-op if none saved).
  - `:365-370` — `mise reshim` + `mise doctor`; fails hard on doctor failure.
  - `:374-379` — `tt init` (time-tracker), fails if `tt` missing.
  - `:383-391` — verifies `sqlite3`/`column` present.
  - `:393` — prints `"=== Bootstrap Complete ==="` (this is what `start.sh`/`rebuild.sh` poll for).
  - `:397-400` — runs `mega-doctor --quick`, **non-fatal** (only warns).
  - `:403` — `exec "$@"` (CMD is `sleep infinity`).
- `rebuild.sh` differs from `start.sh`: verifies 1Password token *actually authenticates* before building (`rebuild.sh:32-41`, "fail in seconds instead of 5+ min into build"); runs `chezmoi apply "$MEGA_DIR"` to sync applied dir from source (`:47-51`, "without this a bump committed to source silently builds the OLD toolchain"); `docker compose build --pull` (`:57`); `docker compose up -d --force-recreate` (`:63`); same bootstrap-wait loop but errors out with log tail if not booted in time (`:94-99`); then runs **full** `mega-doctor` (not `--quick`) and fails the script if it reports failures (`:104-110`).

## 2. Duplicated / defined-twice information

- **Plugin install loop duplicated**: `private_dot_claude/run_onchange_after_install-plugins.sh.tmpl:52-60` (chezmoi-triggered, reads `plugin-list.txt`, runs `claude plugin install`) vs. `private_dot_claude/commands/hot-patch.md.tmpl` Step 5 (`:97-110`) — same read-loop over the same file, reimplemented inline in the hot-patch skill instead of calling the existing script.
- **Tool version pinning split across two files by design**: Dockerfile `ARG *_VERSION` lines (`Dockerfile:19-27`, comment: "single source of truth... The /upgrade-tools skill edits these lines") vs. `mise config.toml` `[tools]` block for mise-managed runtimes — Dockerfile comment explicitly says mise tools "live in `.config/mise/config.toml`" (`Dockerfile:16`), and `upgrade-tools.md.tmpl:26` confirms it bumps both files. Not accidental duplication, but two separate single-sources-of-truth that a human/agent must know to touch together.
- **npm-global tool list duplicated in spirit**: Dockerfile:194 installs `opencode-ai @anthropic-ai/claude-code oh-my-openagent @googleworkspace/cli yarn` via npm, with a comment in mise config.toml explaining *why* they're not in mise (`"mise's npm backend doesn't run postinstall scripts"`) — the exclusion list is asserted in two places (Dockerfile comment `:189-192` and mise config.toml comment).
- **Tailscale login/serve commands repeated verbatim** in README.md Quick Start (`:39-40`), TROUBLESHOOTING.md SSH connection refused (`:114-115`), and start.sh output (`:61-65`) — three copies of `tailscale up --ssh --hostname=raf-dev --accept-routes`.
- **`mega-container` dir instructions duplicated between README.md "Files" table** (`:134-143`) and Dockerfile inline comments — both describe what each file does.
- Two near-identical bootstrap-wait polling loops (300 iterations, 2s sleep, log-scraping for the Tailscale URL and `"Bootstrap Complete"`) exist almost verbatim in `start.sh:37-54` and `rebuild.sh:72-90`.

## 3. Known-broken / fragile / manual-step items (self-admitted)

- TROUBLESHOOTING.md: 1Password SSH agent socket "is a directory instead of a socket file" — requires quitting 1Password, `rm -rf` the broken path, reopening, re-verifying settings (`TROUBLESHOOTING.md:5-30`).
- TROUBLESHOOTING.md: cgroup v1 vs v2 container-ID bug, "Fixed in commit fe89d53" — historical bug note left in docs (`:34-45`).
- TROUBLESHOOTING.md: chezmoi fails outright if any referenced 1Password secret is missing; manual fix is either creating the secret or editing the template to add `2>/dev/null || echo ""` (`:48-66`).
- TROUBLESHOOTING.md: "Tailscale serve config drifted → re-run `sudo tailscale serve --bg ...`" manual remediation (`:98-101`).
- README.md: "**IMPORTANT: Never use `docker compose down -v`**" — destructive footgun called out twice (README `:122-123`, `:132`, and docker-compose.yml volume comment `:46-48`).
- README/rebuild.sh: first-time Tailscale auth is an interactive, manual, blocking step (`README.md:39-42`, `entrypoint.sh:31-38`).
- entrypoint.sh has 5 separate `exit 1` "FAIL FAST" secret fetches (Anthropic, OpenAI, Gemini, GitHub, Datadog) each requiring the item to exist by exact name in the 1Password Development vault (`entrypoint.sh:121-196`) — one missing item blocks the whole boot.
- SSH agent retry loop, 5 attempts × 2s, fails hard with a manual troubleshooting hint pointing at Docker Desktop's magic socket path (`entrypoint.sh:233-250`).
- `hot-patch.md.tmpl` Troubleshooting section: "chezmoi apply fails with '1Password not authenticated'" has 3 manual fallback options including editing `~/.claude.json` by hand (`:152-166`).
- `run_once_install.sh` (chezmoi root) is a stub — just echoes, has commented-out example code, does nothing real (`run_once_install.sh:1-19`).
- PLAN.md frontmatter says `status: phase-4-complete`, phases completed 2026-02-24 to 2026-02-26; the plan predates opencode web, tailscale serve, supercronic durability, and time-tracker (`tt`) — none of which appear in PLAN.md's "Files to Create/Modify" or architecture section, meaning the master plan is stale relative to the actual entrypoint.
- CONTINUOUS_IMPROVEMENT.md describes a `/track-learning` command and `LEARNING.md` learning-tracking system with example metrics ("70% reduction in deployment errors") — no `/track-learning` command or `LEARNING.md` file was found via search; this doc appears aspirational/template rather than describing an implemented system.
- `mega-doctor` warns itself about fragility: "duplicates double-run cron → save races" if >1 supercronic instance (`executable_mega-doctor:138`), and "boot-restore not wired... a rebuild won't auto-restore sessions" if the entrypoint grep fails (`:140-144`).

## 4. Wall-clock cost signals

- `rebuild.sh:56` comment: "Building image (this can take 5-10 minutes)".
- Bootstrap-wait loops allow up to 300×2s = **10 minutes** for first boot (both `start.sh:37` and `rebuild.sh:72`), primarily to accommodate interactive Tailscale login.
- `rebuild.sh` explicitly separates itself from `start.sh` by doing `docker compose build --pull` (refreshes base Debian layer + invalidates caches on version bump) and `--force-recreate` (`rebuild.sh:53-63`) — every rebuild re-pulls the base image.
- Full `mega-doctor` (non-`--quick`) includes an MCP probe with up to 2 attempts and a 30s `timeout` each plus a 3s sleep between (`executable_mega-doctor:197-212`), and an "External auth (slow)" section (AWS/kubectl/ssh-agent checks) skipped only in `--quick` mode.
- `--deep` mode adds a full tmux-resurrect save→kill→restore round trip (`executable_mega-doctor:220-241`).
- docker-compose healthcheck: `interval: 30s, timeout: 5s, retries: 3, start_period: 90s` (`docker-compose.yml:37-42`) — container not marked healthy for up to 90s+ after start regardless.
- Dockerfile builds `tmux` from source (`Dockerfile:78-81`, "Debian's 3.3a has a restore race") — one of several compiled/downloaded-per-build steps (also supercronic, 1Password CLI via apt, helm/gh/lazygit/pulumi/aws-cli/docker-cli/compose/buildx all fetched via curl at build time, no layer caching mentioned for these beyond Docker's own layer cache).

## 5. What `mega-doctor` checks (source: `private_dot_local/bin/executable_mega-doctor`)

Modes: `--quick` (skip MCP/AWS, ~1s, used by entrypoint), `--no-mcp`, `--deep` (adds tmux-resurrect round-trip), default full (~10-20s).
Sections in order: Binaries (`claude opencode chezmoi mise git tmux jq op`) → Container tools (`helm gh pulumi docker aws kubectl tflint gitleaks age sops bun tailscale`) → Claude Code version + plugin count → OpenCode version + `omo.jsonc` model checks (opus-5-fast expected, warns on stray sonnet/non-fast-opus, warns on legacy config files) → Secrets in env (7 required vars, 1 soft-fail) → Mounts & services (docker socket, `~/.aws`, `~/.kube`, `~/code`, sshd, tailscale state) → Durability/tmux (version ≥3.5, supercronic running/single-instance, crontab present, tmux-resurrect installed, `ws()` helpers, save-age freshness, boot-restore wiring, `--in-place` resume, `TMUX_TMPDIR` pinning) → OpenCode web (curl :4096, tailscale serve status/reachability) → External auth (AWS STS, kubectl context, ssh-agent key count) → MCP probe (`claude mcp list`, 2 attempts) → optional `--deep` round-trip. Exit code 0 only if `$FAIL -eq 0`.

## 6. Secrets / 1Password bootstrapping and failure modes

- Host-side: `OP_SERVICE_ACCOUNT_TOKEN` must be in macOS Keychain (`security find-generic-password`); both `start.sh` and `rebuild.sh` fail immediately if absent. `rebuild.sh` additionally live-verifies the token via `op account get` before building (comment: "a stale/expired token otherwise fails 5+ minutes into the build").
- Container-side: entrypoint fetches, in strict order, and fails hard on any miss: Anthropic API Key, OpenAI API Key, Google Gemini API Key, GitHub Classic PAT, Datadog API Key + App Key, Docker Hub username+PAT — each read from `op://Development/<Item>/credential` (or `/username`, `/PAT Read`) with an explicit "Ensure '<Item>' exists in the Development vault with a '<field>' field" error message.
- GWS (Gmail) credentials are the one **soft-fail**: `entrypoint.sh:199-208` — missing creds just print a warning ("morning-triage will not work") rather than aborting boot.
- All fetched secrets are appended to `~/.secrets_env` (`chmod 600`), and `.bash_profile` is patched post-`chezmoi apply` to source it if not already wired (`entrypoint.sh:302-305`) — this patch step exists because chezmoi may overwrite `.bash_profile` and drop the sourcing line.
- SSH agent auth is separate from 1Password secret-fetching: relies on Docker Desktop's magic host-services socket forwarding the *host's* 1Password SSH agent (`docker-compose.yml:22-23`, mount `/run/host-services/ssh-auth.sock:/ssh-agent:ro`); TROUBLESHOOTING.md documents this breaking when the host agent socket degrades into a directory.
- Rotation is manual and undocumented beyond a checkbox: PLAN.md Security Checklist item "Set reminder for 1Password Service Account rotation (90 days)" is unchecked (`PLAN.md:1809-1815`), and MEMORY.md (agent's own memory, not repo) separately notes the 90-day token expiry as a known gotcha.
