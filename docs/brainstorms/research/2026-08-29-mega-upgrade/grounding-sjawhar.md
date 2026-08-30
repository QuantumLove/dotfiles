# Sami Jawhar (sjawhar) — dev-environment research

Found: https://github.com/sjawhar (110 public repos). Primary repo:
**`sjawhar/dotfiles`** (Python-tagged, 4 stars, updated 2026-08-29, active daily).
Related: `sjawhar/forward` (remote access, absorbed `secretsd`), `sjawhar/secretsd`
(now **archived**), `sjawhar/knives` (fork/PR fleet tracker), `sjawhar/jj` (custom fork).
No `.devcontainer/devcontainer.json` anywhere in his repos, no nix/home-manager repo.

## Technology used to define the environment

- Not nix, not devcontainer.json, not asdf. Stack: bash dotfiles repo + **mise** for
  every tool version + a Docker image (`devpod/Dockerfile`) for a remote box + a
  cloud-init script as a bare-VM alternative.
- `install.sh` sources per-tool scripts in order: `installers/{shell,mailbox,mise,
  docker,sops,jj,tmux,nvim,claude,opencode,omp,secretsd}.sh`, all idempotent via
  shared helpers in `installers/lib.sh` (`ensure_link`, `ensure_clone`,
  `ensure_command`, `ensure_json`).
- Config files are **symlinked from the repo**, never copied.
- `devpod/Dockerfile` + `devpod/config.toml` (`[devbox].user_data`) provision a
  *remote* box, not a local VS Code dev container; per `devpod/AGENTS.md` this path is
  currently "dormant."

## Secrets handling

- **sops + age**, human tier gated to two **YubiKey-backed age** recipients via
  path-ordered `creation_rules` in `.sops.yaml` (`secrets.human.env`,
  `secrets.human.d/*.env` sit above the broader agent-tier default rule).
- A custom **`secretsd`** daemon (own repo, now merged into `forward`) runs as a
  systemd **socket-activated user service**, resolving secrets from ordered
  "source roots" (`~/.config/secretsd/config.toml`): a shared dotfiles root, then an
  optional private-repo root. A key found in two roots is refused, not resolved.
- YubiKey touch policy tuned explicitly (`always`, 2s anti-piggyback cooldown).
- `SOPS_AGE_KEY` is forwarded over SSH (`SendEnv`) from the laptop; the sops installer
  no-ops entirely if it's absent, and never regenerates an existing `.sops.yaml`.
- Headless devbox reaches the physical YubiKey over a PC/SC-over-Tailscale tunnel:
  `forward-serve` (devbox) ⇄ laptop `forward-daemon`, both systemd-supervised.

## Reproducibility / pinning / lockfiles

- `mise.toml` pins every tool version exactly ("All versions pinned for
  reproducibility"), plus a `minimum_release_age = "14d"` supply-chain soak window for
  third-party releases — with his own repos hand-listed in
  `minimum_release_age_excludes` since mise needs exact match, no globs.
- Deliberate version holds are documented inline where a tool's next bump is a known
  breaking migration (bun's lockfile v2 rewrite, Node LTS vs. Current).
- His own tools install from GitHub at a **pinned tag/SHA**, verified via mise's
  GitHub build-provenance attestation check on install; local checkouts/symlinks are
  explicitly prototyping-only and "never land."
- `devpod/AGENTS.md` flags a manual sync hazard: tool versions live in both the
  Dockerfile `ARG`s and the `config.toml` `user_data` binary installs, and both must
  be bumped together.
- Portability rule: no committed file may contain an absolute path; committed
  symlinks may only point inside the repo with relative targets. Per-machine state is
  generated at install time, never committed.

## Multi-machine / remote access

- Own **`forward`** CLI/daemon: "Open devbox URLs and files in the laptop browser over
  the devbox SSH tunnel" — later absorbed the secrets-broker role too.
- Devbox file links resolve through `forward url <path>` → `http://localhost:12802/...`
  instead of `file://`, since `file://` would resolve against the wrong filesystem.
- Remote VM path uses **Tailscale**: devpod image runs `tailscaled` in userspace mode
  with a SOCKS5 proxy (`:1055`) and HTTP proxy (`:1080`), then execs `sshd`; a
  `proxy.sh` helper exports `HTTP_PROXY`/`ALL_PROXY`/`NO_PROXY` for routing through it.
  `sshd_config` is patched to accept `SOPS_AGE_KEY` via `AcceptEnv`.
- systemd user lingering must stay enabled on the devbox or user services die once the
  SSH session ends — called out explicitly as a gotcha.
- `knives` (separate tool): tracks "branch vs origin vs upstream, pull request and CI
  state, dated releases, and which agent is holding what" across many forked repos.

## Pre-commit / CI / branch-protection / git hooks

- Primary VCS is **jj** (custom fork adding workspace-cli, LFS ignore-filters), git
  kept only for interop; `fsmonitor.backend = "watchman"` for perf, LFS wired through
  jj's filter mechanism.
- **Mandatory dual-tool commit signing**: one SSH-format key
  (`~/.ssh/jj-signing`) configured identically for jj (`signing.behavior = "own"`) and
  git (`gpg.format = ssh`, `commit.gpgsign = true`), sharing one allowed-signers file.
  Both tools are configured to **fail to commit** rather than commit unsigned, paired
  with GitHub vigilant mode, since an unsigned commit under vigilant mode would look
  like impersonation.
- Two git identities (personal vs. work) switched via a `git-identity` helper script.
- Git credential helper is `gh auth git-credential` for github.com/gist — no stored
  PATs.
- CI is minimal: one workflow, `envoy-typecheck.yml`, path-filtered `tsc --noEmit` for
  the `envoy/` subdirectory only. No repo-wide pre-commit config found.
- Stated commit-hygiene practice: batch a session into 1-2 coherent commits per topic
  before pushing, rather than many small ones; pushes straight to `main` in this repo
  (no PRs).

## Notable deliberate design choices

- Single source of truth via symlinks, not copies, for every config file.
- Layered, cache-mounted Docker builds for the devpod image (separate download vs.
  mise builder stages, BuildKit cache mounts for apt/mise, `COPY --link` between
  stages) for fast, reproducible rebuilds.
- Agent-aware tool config: jj switches its diff formatter to plain git-diff format
  when `AGENT`/`OPENCODE`/`CLAUDECODE` env vars are set (color-words output isn't
  agent-parseable), and a custom editor wrapper refuses to launch interactively
  without a TTY, forcing agents onto flag-based commit messages instead of hanging.
- Installer scripts branch behavior by installed daemon SemVer so one script script
  stays correct across upgrade *and* rollback of a systemd-managed dependency.
- Config/drop-in writes go through a write-to-`.new` + `cmp` + swap pattern, so a
  systemd restart (and a YubiKey touch prompt) only fires when something actually
  changed.
- Explicit personal/company boundary: company infra repos must never reference the
  personal dotfiles checkout, and the dotfiles install isn't part of standard company
  machine provisioning.

## Not found / out of scope

- No devcontainer.json, no nix flake / home-manager repo, in any repo checked.
- `secretsd`'s standalone history wasn't fetched separately — `dotfiles` and `forward`
  already cover its config and rationale.
- No local clone was needed; everything was pulled via `gh api` (contents/metadata).
