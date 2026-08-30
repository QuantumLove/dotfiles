# Grounding: recurring mega-container / chezmoi pain (session evidence)

## Data coverage caveat
Only ONE Claude Code project directory exists for this work:
`~/.claude/projects/-Users-rafael--local-share-chezmoi/` (10 `.jsonl` files).
All retained session files fall inside **2026-08-24 to 2026-08-29** (about 6 days) —
there is no older local session history to mine (likely rotated/pruned). No
`*mega-container*`-encoded project directory exists separately; all mega-container
work happens from the chezmoi cwd. Frequency counts below are therefore a
**lower bound** scoped to one week, corroborated by 6 months of git log where
possible. jq was used to extract only `type=="user"` text content, filtering
out system-reminders, caveats, local-commands, and task-notifications.

---

## Ranked recurring problems (evidence-only)

### 1. OrbStack breaks / raf-dev (mega-container) becomes unreachable — 4 occasions
Date range: 2026-08-24 to 2026-08-28 (4 separate sessions in 5 days).
- 77304fcd...jsonl (08-24 21:48): "raf-dev is somehow unreachable. debug and fix this"
- 3582326e...jsonl (08-26 21:04): "The dev container, mega container, seems to be inaccessible. Can you debug and fix it?" (invoked `systematic-debugging` skill)
- fa328bee...jsonl (08-27 15:54): "Orb stack is broken in my laptop. Can you just spin it up again, fix the problem, and ensure my dev container is working and accessible?"
- 2e1a664e...jsonl (08-28 21:10): "Orb stack broke so my dev container is broken. Can you please fix it?"
Corroboration: auto-memory already documents this as a known pattern —
"OrbStack virtio-net wedge — raf-dev drops off Tailscale after Mac sleep/wake;
fix is orb stop/start, never orb reset." **This is asked about on 4 separate
days in one week — the single most repeated complaint in the data.**

### 2. opencode/omo agent model misconfiguration — 3+ occasions (session) + 4 same-week commits
Date range: 2026-08-24 to 2026-08-29.
- 6f5cfc05...jsonl (08-24 12:34): "we keep bumping into the problem where the general sub agent uses a google model (but we cant use google models) so we need to register al[l models]..." — explicit admission of recurrence.
- 6f5cfc05...jsonl (08-24 12:34): "another problem we need to fix: we want the latest model on opencode ... Latest opus I mean, not fable. And the fast version."
- 77304fcd...jsonl (08-24 23:55): "I see that my agents are using Sunnet 5 but they should be using Opus 5 fast."
- 77304fcd...jsonl (08-25 01:09): "so will new rebuilds in the future have the right models?"
- 77304fcd...jsonl (08-25 01:41): "my models are using claude opus 5 now instead of the fast variant for some reason"
- 77304fcd...jsonl (08-25 01:43): "so is all working now? will everything be right next rebuild?"
Corroboration: 4 separate commits chasing the same class of bug, spanning
5 days after the sessions above: `4a2e090` (feat: default all agents to
claude-opus-5-fast; drop deprecated omo config), `24193e1` (fix: pin omo
agents to opus-5-fast, stop nano fallthrough), `f6f1704` (fix: move remaining
opus-5 agents to the fast variant), `2f07e7c` (fix(mega-doctor): check
omo.jsonc instead of the deleted oh-my-openagent.json). **Each "fix" commit
did not fully resolve it — it kept resurfacing under a different guise
(wrong model → google fallthrough → sonnet not opus → nano fallthrough →
stale config file check).**

### 3. Anxiety/uncertainty that fixes survive a rebuild — 2 occasions (session), 1 dedicated commit
- 77304fcd...jsonl (08-25 01:09): "so will new rebuilds in the future have the right models?"
- 77304fcd...jsonl (08-25 01:43): "so is all working now? will everything be right next rebuild?"
Corroboration: auto-memory "mega-container rebuild source drift — rebuild.sh
builds from the applied dir; run chezmoi apply before rebuilding" documents
this as a known class of bug; commit `8262436` "feat(mega-container): add
/upgrade-tools skill + harden rebuild/doctor" and `5ea12ba` "fix(mega-container):
apply chezmoi before starting opencode web" both target rebuild-time drift.
This is a meta-pattern underlying problem #2 as well: fixes applied live
don't reliably survive the next rebuild.

### 4. git push to main rejected mid-session (chezmoi repo) — 1 occasion, resolved quickly
- 6f5cfc05...jsonl (08-24 12:21): push rejected ("fetch first"), user retries: "the push to main did not work" (08-24 12:22), succeeds on 3rd retry (12:24). Single occurrence, not recurring across sessions — noted for completeness only.

### 5. 1Password gate blocking chezmoi apply / bootstrap — 1 explicit session mention
- 6f5cfc05...jsonl (08-24 11:23): "1password unlocked, should be okay now" (implies apply had been blocked on 1Password auth).
Corroboration: auto-memory documents this as a recurring class —
"mega-container SSH-agent gate — bootstrap crash-loops if 1Password app
isn't running/unlocked on host (common after reboot)" — but the 1-week
session window only surfaces it once directly.

### Adjacent but not mega-container fixes (excluded from ranking)
- "my wispr flow build is broken" (6f5cfc05, 08-24 12:45) — unrelated Mac app, not mega-container/chezmoi plumbing.
- Bitwarden CLI SSO unlock friction (3807d553, 08-24 20:34–21:11) — a chezmoi *feature add* ("add bw cli to my chez-moi"), not a fix/debug request.

---

## Git log corroboration (not session-sourced, contextual only)
`git log --oneline --since='6mo' -- mega-container/ private_dot_claude/ .chezmoiscripts/`
surfaces a long-running theme of **boot crash-loops** across many months,
predating the session window: `d629410` fix(mega-container): reshim before
mise doctor to prevent boot crash-loop; `a120835` fix first-boot bootstrap;
`3e299c0` fix: rename plugin installer to run_onchange_after to fix
first-boot crash; `c4c672d` fix: use on-failure:5 restart policy to prevent
crash-loops; `d2da954` fix(mega): start cron in entrypoint + reap zombies.
These predate the retained session window, so occasion counts can't be
attributed to specific user requests — flagged as a historically recurring
class worth validating with the user directly.

## Bottom line
Only #1 (OrbStack/raf-dev unreachable) and #2 (opencode model
misconfiguration) clear the "3+ occasions" bar with direct session evidence
within the available 6-day window. Both are corroborated independently by
git history (memory notes for #1, four chase-fix commits for #2).
