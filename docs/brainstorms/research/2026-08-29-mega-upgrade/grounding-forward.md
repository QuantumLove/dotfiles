# `sjawhar/forward` — grounding research

Repo: `sjawhar/forward` (Rust, personal tool; workspace also contains the
formerly-separate `secretsd`). No root `README.md` — closest is
`crates/secrets/README.md` plus `docs/design/*.md`.

## 1. What does it actually do?

Confirmed, with one correction: it's two roles bolted into one Rust workspace,
not one tool that grew a second feature.

- **`forward` binary** (`crates/forward`): opens devbox URLs/files in the
  laptop browser, and lets the laptop reach devbox-only loopback services
  (mainly OAuth callbacks). `crates/forward/src/main.rs`: `about = "Open devbox
  URLs and files in the laptop browser, and let the devbox reach it"`.
- **`secrets`/`secretsd`** (`crates/secrets`, ex-`sjawhar/secretsd`, merged
  in): YubiKey-gated secrets broker; touches forwarding only via its own PC/SC
  (smartcard) tunnel over Tailscale.

**Arbitrary TCP port forwarding is explicitly NOT a feature.** The only
dynamic forwarding is a narrow OAuth-callback bridge, capped and denylisted.
`docs/design/2026-08-23-pcsc-channel.md`:
> "The devbox socket is intentionally not configurable. It is a compatibility
> contract with the existing PC/SC consumers, not a general-purpose socket
> forwarder."

CLI surface is exactly `forward open|url|serve|daemon|doctor|browser grant`
(`crates/forward/src/main.rs`). No `forward port <N>`/`expose` command exists —
a `forward tunnel` subcommand was explicitly rejected in
`docs/design/2026-07-28-tailnet-native-transport.md`: "This design retires
the need for it."

## 2. Architecture — what runs where

Each "channel" is a fixed-purpose direct TCP link over the tailnet:

| Channel | Port | Devbox | Laptop |
|---|---|---|---|
| URL open | 12800 | `forward open/url` connects to peer | `forward daemon` listens |
| File preview | 12802 | `forward serve` listens | browser fetches directly |
| OAuth callback hop | 12801 | `forward serve` armed hop | `forward daemon` listens |
| Browser relay (drive Chrome) | 12803 | — | `forward daemon` fronts it |
| PC/SC (YubiKey) | 12804 | `forward serve` dials peer | `forward daemon` feeds pcscd |
| Browser grant feed / Pulse audio | 12805/12806 | `forward serve` listens/dials | laptop dials / `forward daemon` listens |

Discovery is **static config**: `crates/forward/src/config.rs` requires a
literal `peer` IP ("a non-loopback listen address requires an explicit peer")
— no hostnames, no MagicDNS. You hardcode each machine's tailnet IP.

Transport used to ride one SSH master (`RemoteForward`/`LocalForward`).
`docs/design/2026-07-28-tailnet-native-transport.md` documents ripping that
out after real outages: `ssh -O cancel` on one expired dynamic forward
silently tore down *all* forwards on the same SSH host block (YubiKey channel
included) while `ssh -O check` kept reporting healthy. Post-redesign, every
channel is a **direct Tailscale/WireGuard connection** dialing tailnet IPs.

Supervision: **no systemd units ship for `forward` itself** — only
`systemd/secretsd.service`+`.socket` exist, for the secrets broker,
socket-activated, requiring `loginctl enable-linger`. `forward serve`/`daemon`
have no packaged unit anywhere in the repo; you wire your own.

## 3. Dynamic forwarding "on demand"?

No user-facing "expose port N now" command. The only dynamic behavior: `forward
open` parses a URL for a `redirect_uri` loopback port and auto-arms up to
`MAX_DYNAMIC_FORWARDS = 4` ports for `forward_ttl_secs` (default 300s) via a
local Unix-socket "ARM" protocol (`crates/forward/src/bridge/arming.rs`),
solely so OAuth logins from a devbox CLI complete in the laptop browser.
Denylist blocks ports <1024, forward's own service ports, and common dev/DB
ports (Docker, Redis, Postgres, MySQL, debuggers). Not repurposable to forward
an arbitrary devbox web server port.

## 4. Dependencies / portability — critical for Rafael's setup

- **Runtime**: Rust, `std` + `nix` (no tokio), `rust-version = "1.88"`.
- **Hard Linux dependency, not just a systemd convention**:
  `crates/hygiene/src/hardening.rs` uses `nix::sys::prctl::set_dumpable`
  (Linux-only) and `mlockall`. `main.rs` calls
  `hygiene::hardening::apply_no_core_dumps()` **unconditionally on every
  subcommand**, including laptop-side `forward open/url/daemon`, and
  hard-exits on failure: `"forward: refusing to start without core-dump
  suppression"`. Unlikely to even build, let alone run, on macOS as shipped.
- Assumes `XDG_RUNTIME_DIR`/`/run/user/<uid>` (pam_systemd-provided) — not
  guaranteed in a Docker container without systemd as PID 1. `secretsd` further
  assumes systemd user units, `loginctl enable-linger`, `/run/pcscd/pcscd.comm`,
  polkit's `access_pcsc` (`docs/design/2026-08-23-pcsc-channel.md`).
- **Verdict**: built for "systemd Linux devbox talking to systemd Linux
  laptop over Tailscale." Rafael's devbox (Docker container) is workable with
  manual supervision, but his **macOS laptop** is the harder blocker — the
  Linux-only hardening call sits in every code path, not just the daemon.

## 5. What a minimal own-built version needs

Forward's only reusable idea for "I keep having to do manual ssh port
forwarding" is: *a thin CLI that manages `-L`/`-R` flags for you*, with
TTL/auto-cleanup. Everything else (YubiKey broker, Chrome remote control,
PulseAudio bridge, capability tokens) is unrelated machinery for Sjawhar's own
workflow.

Minimal useful subset: `mega-forward <port>` that runs `ssh -O forward -L
<port>:localhost:<port> raf-dev` against a persistent `ControlMaster`, plus
`mega-forward --stop <port>` (`ssh -O cancel`) — no daemon, no config schema,
no Rust.

What Rafael already has, compared:

- **`ssh -L`/`-R` + `LocalForward` in `~/.ssh/config`**: zero new code, but
  static — edit + reconnect for a new port. Fine for 1-2 stable ports, annoying
  ad hoc.
- **Tailscale `serve`/`funnel`**: already used for opencode web on `raf-dev`.
  Strictly better for "reach a port on raf-dev from my Mac" — no tunnel to
  manage, survives reconnects, `serve --bg <port>`/`serve reset` is a
  one-liner. Likely the real answer for HTTP-shaped cases.
- **VS Code/devcontainer auto-forwarding**: convenient only inside that
  editor, not a terminal/CLI solution.

**Recommendation**: don't adopt `forward` — bespoke Linux-systemd tool solving
a much bigger problem than port forwarding, whose core hardening code doesn't
port to macOS. Lean on `tailscale serve`/`funnel` for HTTP-shaped ports, and
add one tiny wrapper (`mega-forward add/rm <port>`) around `ssh -O forward -L`
for anything else — a 20-30 line shell function, not a Rust workspace.
