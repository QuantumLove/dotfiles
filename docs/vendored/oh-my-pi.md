# oh-my-pi (pinned)

`omp` — a coding agent, forked from Mario Zechner's Pi. Runs alongside Claude
Code and OpenCode rather than replacing either.

## Not forked, deliberately

The origin document called for a fork carrying our own patches. An inventory of
this setup found nothing that needs one: every wanted behaviour — the guard
adapter, the working-directory redirect, publishing cwd to tmux — is expressible
through the documented extension API. A fork with no patches is a pin with a
merge chore attached, against an upstream that releases roughly daily.

Both upstreams also merge contributions, which is the condition that makes
deferring safe. That is not universally true in this ecosystem: sjawhar forks
`opencode` because its upstream auto-closes PRs older than a month with a bot,
and he resubmitted the same fix four times. If `can1357/oh-my-pi` starts
behaving that way, fork then.

**The trigger is observable, not remembered.** The pin check asserts the
installed artifact matches the pinned release, so a local patch applied ad hoc
via `/hot-patch` shows up as a mismatch and forces the fork-or-upstream
decision. Nothing here depends on recalling this note.

## Pinned source

- Repo: https://github.com/can1357/oh-my-pi (28k+ stars)
- Version: **18.0.11**
- Commit: `b8ce33a58911`
- Pinned: 2026-09-01
- Delivery: mise `github:` backend, `mega-container/dot_config/mise/config.toml`

## Local changes vs upstream

None. This is an unmodified upstream release.

## Verify

```bash
omp --version                        # must print 18.0.11
mise ls | grep oh-my-pi              # must show the pinned version, not latest
```

## How to upgrade

1. Read the changelog between the pinned version and the target. Releases are
   near-daily; most are not worth taking.
2. Bump `version` in `mega-container/dot_config/mise/config.toml`.
3. Update **Version**, **Commit** and **Pinned** above.
4. Rebuild and run `mega-assert --deep`. The model and pin checks are what catch
   a bump that changed agent defaults underneath the config.

## Notes

- `exe = "omp"` and no `matching` filter: upstream ships bare per-platform
  binaries and this container is **arm64**. An architecture filter naming
  `linux-x64` would reduce the candidate set to zero and fail the build.
- Bun is bundled in the standalone binary, but extensions are evaluated by Bun
  in-process — so extension code must be Bun-compatible even though nothing
  installs Bun for it.
- Upstream re-execs its own binary to spawn subagents. Do not prune replaced
  versions while a session is live.
