---
date: 2026-06-23
topic: tt-native-time-tracking
---

# tt-native time tracking — requirements

## Summary

Make `tt` the single, native source of truth for a clean daily work log built only from container-local signals. Each day is segmented into LLM-labeled work-blocks (bounded by gaps between prompts and by cwd changes); each block becomes a `tt` stream tagged `project:` + `cat:`, with time split into **direct** (you present) vs **delegated** (agents working while you're away), reported as two numbers that are never summed. Toggl is dropped; `tt today` / `tt week` become the deliverable and feed `/async-standup`.

## Problem Frame

The current `/fill-toggl` is a drifted fork of the upstream design. It infers presence loosely (agent tool-calls count toward "working") and forces every task into pre-existing Toggl projects the user never created. On a headless devbox there is no desktop/AFK signal, so idle stretches and parallel-agent spans get counted — producing impossible totals (a "day" that exceeded wall-clock). Long reused sessions — one session spanning run-kills, debugging, and a security audit — collapse into a single mislabeled blob, and many parallel agent sessions can't be told apart. The output is a daily log that is neither accurate nor trusted, behind a Toggl round-trip that adds friction without value.

## Key Decisions

- **Upstream the model into `tt` (Rust), not a wrapper.** Since tt's native report is the time log, `tt today` / `tt week` must reflect the new model directly; segmentation and allocation live in `tt-core` as one source of truth, shipped via a fork or upstream PR to `sjawhar/time-tracker`.
- **Focus is the spine of presence.** Direct time = tmux pane focused or a `user_message`; `agent_tool_use` alone never implies you are present. On overlap (focused while an agent works), the time is direct — focus wins.
- **Hybrid segmentation.** Work-blocks are bounded deterministically by prompt-gaps and cwd changes; a cheap LLM pass then names each block's topic and suggests a `cat:` tag.
- **Each labeled block is its own stream**, dual-tagged `project:` (repo) and `cat:` (category). Per-project totals come from grouping the `project:` tag, not from one stream per repo.
- **Direct and delegated are two numbers, never summed.** Direct <= wall-clock (honest hours); delegated may exceed wall-clock (parallel-agent leverage). No blended "effort" figure.
- **Idle is excluded.** A span with no focus, no `user_message`, and no `agent_tool_use` within the idle threshold accrues to neither bucket.
- **Sub-agent work rolls up as delegated.** A sub-agent's tool-calls (`parent_session_id`) accrue to the parent block's delegated time.
- **Drop Toggl.** Retire `/fill-toggl` and the forced-project round-trip; `/async-standup` sources "what I did" from tt.

## Requirements

**Allocation model**

R1. tt classifies each tracked instant as direct, delegated, or idle: direct when the pane is focused or a `user_message` falls in the active window; delegated when `agent_tool_use` occurs while unfocused; idle otherwise.
R2. On overlap (focus and agent activity at the same instant) the instant is counted as direct only — never double-counted.
R3. Idle is excluded: a gap with no focus, `user_message`, or `agent_tool_use` exceeding the idle threshold (default 5 min) accrues to no bucket.
R4. Direct time is bounded by wall-clock (one focused pane at a time); delegated is allowed to exceed wall-clock across parallel agents.
R5. Sub-agent `agent_tool_use` (linked via `parent_session_id`) rolls up into the parent work-block's delegated time.

**Segmentation & labeling**

R6. tt segments a day into work-blocks bounded by (a) a gap between the user's prompts exceeding the block-gap threshold and (b) a change of cwd / `git_project`.
R7. Each block receives an LLM-generated topic label and a suggested `cat:` tag derived from the block's prompts/summary; labels are best-effort and user-correctable.
R8. Block boundaries are deterministic (gap + cwd), so re-runs produce stable blocks even though labels are LLM-generated.

**Streams & tags**

R9. Each labeled block becomes a `tt` stream tagged `project:<repo>` and `cat:<category>`.
R10. Per-project and per-category rollups are derivable by grouping tags; no dedicated per-project stream is required.
R11. A user can correct a block's `cat:` tag or topic after the fact (retag) without re-segmenting.

**Reporting**

R12. `tt today` / `tt week` present the period as a chronological list of labeled blocks (time, project, topic) plus a rollup, with direct and delegated shown as two separate figures, never summed.
R13. The report surfaces a delegated/leverage indicator distinct from direct hours.

**Consumer workflows**

R14. `/async-standup` sources its "what I worked on" section from tt's labeled blocks (project + topic + direct/delegated); git PRs/commits and Linear tickets enrich rather than define it.
R15. `/fill-toggl` and the Toggl round-trip (forced projects) are removed; no Toggl dependency remains in the daily workflow.

**Capture (signals)**

R16. The model relies only on container-local signals already in `tt.db`: `tmux_pane_focus`, `agent_session`, `agent_tool_use`, `user_message`, and `agent_sessions` metadata (summary, prompts, `parent_session_id`); optionally git activity. No desktop/ActivityWatch signal.

## Key Flows

F1. **Daily pass.** **Trigger:** `tt today` (or end-of-day). Read events, segment into gap+cwd blocks, LLM-label each block, compute direct/delegated/idle per block, write blocks as streams+tags, render history + rollup.
F2. **Review/correct.** User skims blocks and retags any mislabel; re-running the report reflects corrections without re-segmenting.

## Acceptance Examples

AE1. **Covers R2.** Focused on pane A while an agent in A makes tool-calls for 10 min -> 10 min direct, 0 delegated.
AE2. **Covers R4.** Focused on pane A for 30 min while two unfocused agents in B and C each make tool-calls over the same 30 min -> 30 min direct + 60 min delegated; never reported as 90 min "worked."
AE3. **Covers R3.** No focus, no prompt, no tool-calls for 75 min -> 0 min counted.
AE4. **Covers R5.** A sub-agent grinds 20 min while you're unfocused -> +20 min delegated on the parent block.
AE5. **Covers R6.** One session sits in `/repo` for 9 h with prompts clustering around three topics separated by gaps over the block-gap threshold -> three labeled blocks, even though cwd never changed.

## Scope Boundaries

- Desktop activity / ActivityWatch / AFK signals — out (headless devbox has none).
- Toggl and any forced-project mapping — out; dropped entirely.
- Multi-machine sync redesign — out; tt's existing sync is unchanged.
- A replacement external time-tracker (Clockify/Harvest/etc.) — out; tt is the log.

## Dependencies / Assumptions

- The Rust changes land in a fork of `sjawhar/time-tracker` (or an accepted upstream PR), owned/maintained by the user.
- A cheap LLM is available to the labeling pass (model chosen in planning).
- Container signals are reliably ingested (tmux hooks + OpenCode/Claude ingestion already running).
- Assumption: focused-pane time is a faithful best-effort proxy for human attention on a headless box.

## Outstanding Questions

**Resolve before planning**

- Block-gap threshold for segmentation (distinct from the 5-min idle cap) — what pause starts a new topic-block (e.g., 15-30 min)?
- Fork vs upstream PR to `sjawhar/time-tracker` — maintain a fork or aim to merge upstream? This bounds how invasive the `allocate_time` change can be.

**Deferred to planning**

- LLM model + prompt for labeling, and the cost/runtime budget for the daily pass.
- Retag UX (`tt tag` vs a small interactive review step).
- Exact `tt today` / `tt week` rendering of the two-number + leverage display.
- Whether git activity is folded in as a signal in v1 or later.
