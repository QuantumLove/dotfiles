# oh-my-openagent (pinned)

`omo` — the agent layer over OpenCode. Already in daily use; this records the
pin rather than introducing the dependency.

## Not forked, deliberately

Same reasoning as `oh-my-pi`: nothing here needs a source patch, and upstream
merges contributions. See `docs/vendored/oh-my-pi.md` for the full argument and
the trigger condition that would change the answer.

## Pinned source

- Package: `oh-my-openagent` (npm)
- Version: **4.19.4**
- Pinned: 2026-09-01
- Delivery: `npm install -g` in `mega-container/Dockerfile`

## Why npm and not mise

mise's npm backend does not run postinstall scripts, and these packages need
them to fetch their platform-native binaries. The Dockerfile comment above the
install line records the same thing. That is why the version pin lives on the
Dockerfile line rather than in `config.toml`.

## Local changes vs upstream

None. Configuration lives in `dot_omo/omo.jsonc`, which is ours; the package is
unmodified.

## Verify

```bash
npm ls -g oh-my-openagent            # must print 4.19.4
```

## How to upgrade

1. Read the changelog. Agent defaults change between releases — that is what
   produced the model-drift incident this pin exists to prevent.
2. Bump the version on the `npm install -g` line in `mega-container/Dockerfile`.
3. Update **Version** and **Pinned** above.
4. Rebuild, then run `mega-assert`. `omo-agent-models` is the check that catches
   a release quietly reintroducing its own defaults.
