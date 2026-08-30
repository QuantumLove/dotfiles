# Grounding: OhMyPi

## Verdict (confident, not a guess)

"OhMyPi" = **`can1357/oh-my-pi`**, binary/CLI name **`omp`**, npm org `@oh-my-pi/pi-coding-agent`,
site https://omp.sh. It is a **fork of Pi**, not a config framework layered on top of a base agent.
"Pi" itself = **pi-coding-agent**, the base project by Mario Zechner (`@mariozechner`), repo
`badlogic/pi-mono` (https://github.com/badlogic/pi-mono). Confirmed via oh-my-pi README:

> "Fork of [Pi](https://github.com/badlogic/pi-mono) by [@mariozechner](https://github.com/mariozechner)"
> repo:can1357/oh-my-pi:README.md

**oh-my-pi and oh-my-openagent are not siblings by the same author.** oh-my-openagent is
`code-yeongyu/oh-my-openagent` (owner: code-yeongyu / Sisyphus Labs). oh-my-pi is
`can1357/oh-my-pi` (owner: can1357). Different people, different projects. The two *are*
cross-referencing each other, though — oh-my-openagent's README credits oh-my-pi as direct
inspiration for one feature:

> "🔗 Hash-Anchored Edit Tool | Ultimate | Hashline (`LINE#ID`) edit/read tagging. ... Inspired by
> [oh-my-pi](https://github.com/can1357/oh-my-pi)." — repo:code-yeongyu/oh-my-openagent:README.md

And oh-my-openagent's own ROADMAP explicitly lists Pi as a future integration target (not shipped
yet): "We are restructuring the codebase to support multiple agent harnesses (OpenCode, Codex,
Pi, Claude Code, and others)." — repo:code-yeongyu/oh-my-openagent:README.md (top banner + ROADMAP link)

code-yeongyu also ships separate small repos porting omo tooling *to* the Pi ecosystem:
`code-yeongyu/pi-ast-grep` and `code-yeongyu/pi-lsp-client` ("Faithful port of the ... tools from
oh-my-openagent" for "the pi coding agent") — these target Pi/omp as a host, evidence the
ecosystems are converging but still separate today.

## What oh-my-pi (omp) actually is

Not an oh-my-zsh-style config layer — it's a full standalone coding-agent CLI/TUI, TypeScript +
Rust (~80k LOC Rust core), positioned as a superset/hardened fork of Pi:

> "The most capable agent surface that ships... **60+** providers · **31** built-in tools · **14**
> lsp ops · **28** dap ops · **~80k** lines of Rust core." — repo:can1357/oh-my-pi:README.md

Feature highlights from the README: in-process code execution with tool-calling back into the
agent (Python/Bun), LSP wired into every write (rename goes through `workspace/willRenameFiles`),
drives real debuggers (lldb/dlv/debugpy via DAP), "time-traveling stream rules" (regex-triggered
mid-stream rule injection), first-class subagents (`task` → isolated worktrees, typed results,
Agent Hub UI), an "advisor" second-model reviewer role, `/collab` live session sharing via relay
+ QR, chained web search across 23 providers, and native in-process ripgrep/glob/bash (`brush`)
so it doesn't shell out — runs natively on macOS/Linux/**Windows** (no WSL needed).

GitHub metadata (`gh api repos/can1357/oh-my-pi`): 28,306 stars, 2,825 forks, MIT license,
language TypeScript, topics include `ai-coding-agent`, `anthropic`, `claude`, `mcp`,
`multi-provider`, `rust`, `tui`. Created 2025-12-31, actively pushed as of 2026-08-29.

## Install (Debian-based container — concrete requirements)

- **Primary installer (works on any Linux incl. Debian):**
  `curl -fsSL https://omp.sh/install | sh` — repo:can1357/oh-my-pi:README.md
  - Alpine/musl only needs `apk add libstdc++ libgcc` first (not relevant to glibc/Debian).
- **Alternative: Bun global install (recommended by upstream):**
  `bun install -g @oh-my-pi/pi-coding-agent` — requires **Bun ≥ 1.3.14**.
- **Homebrew:** `brew install can1357/tap/omp` (macOS/Linuxbrew).
- **Nix:** `nix run github:can1357/oh-my-pi` or flake install; ships `homeManagerModules.default`.
- **mise (matches Rafael's toolchain style):** `mise use -g github:can1357/oh-my-pi`.
- Shell completions generated live: `eval "$(omp completions zsh)"` / bash / fish.
- **Secrets/config:** none of these steps require an API key to *install*; providers (Anthropic,
  OpenAI, etc. — "60+ providers") are configured post-install, analogous to oh-my-openagent's
  provider-auth step. No `omp`-specific config file format was found documented in the README
  excerpt fetched (would need `docs/` in the repo, not fetched, for exact schema — flag as
  unverified beyond what's quoted above).

## Coexistence with oh-my-openagent (omo)

They are not mutually exclusive or a replacement pair today: omo runs as a plugin *inside*
OpenCode or Codex CLI (`~/.omo/omo.jsonc`, per Rafael's own
`/Users/rafael/.local/share/chezmoi/dot_omo/omo.jsonc`); oh-my-pi/omp is a **separate, standalone
agent binary** (`omp`) that would sit alongside OpenCode/Codex, not inside them. Adopting omp
would mean running a third agent CLI, not swapping omo's config. omo's roadmap says Pi support is
planned for omo-as-plugin-inside-Pi, but that is not shipped — so today there is no "omo running
on top of omp" path to configure.

## Confusable near-matches (ruled out / flagged as distinct)

- `ifiokjr/monopi` — "Like oh-my-zsh for pi" — **this is the oh-my-zsh-style config framework
  Rafael's context predicted**, but it targets **upstream Pi** (`badlogic/pi-mono`), not
  `can1357/oh-my-pi`. Different maintainer (ifiokjr), different target. Install: `npx @monopi/monopi`.
  repo:ifiokjr/monopi:README.md. Not called "OhMyPi" anywhere in its README.
- `bparlan/omp-agent` (aka `bparlan/aef`) — uses the same "OhMyPi (OMP)" name but for an unrelated
  Python-based "Agentic Engineering Framework" (spec-driven dev lifecycle), 37 stars, "Under
  Development." Likely a naming collision/personal project, not the mainstream OhMyPi.
  repo:bparlan/omp-agent:README.md
- Numerous low-star repos (`ayu-exorcist/oh-my-pi`, `apoc/omp-desktop`, GUIs/TUIs/plugins) are
  third-party tools built *around* `can1357/oh-my-pi`, not competing definitions.

## Local footprint check (Rafael's machine / chezmoi repo)

- `~/.pi`, `~/.config/pi`, `~/.omp` — do not exist.
- `which pi` / `which omp` — not found.
- `grep -rl "oh-my-pi\|ohmypi\|omp\.sh\|pi-coding-agent" ~/.local/share/chezmoi` — **zero matches**.
- `dot_omo/omo.jsonc` (existing omo setup) only configures `[opencode]` agents/categories for
  oh-my-openagent — no Pi/omp references. file:/Users/rafael/.local/share/chezmoi/dot_omo/omo.jsonc

**Conclusion: zero existing OhMyPi/Pi footprint on Rafael's machine or in chezmoi.** Adopting it
would be a from-scratch install of a new, separate coding-agent binary, not a migration of the
existing omo config.
