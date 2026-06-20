# Manual verification — Warp + tmux durability

`test_tmux_durability.sh` automates AE1, AE3, AE5, AE8 over SSH. The examples
below need a live Warp session / opencode / a real disconnect, so they're
manual. Run them from Warp connected to `raf-dev`.

## AE2 / AE4 — opencode session capture + history
1. `ws main`, then start opencode (`oc`) in a pane and run a couple of prompts.
2. `tmux-snapshot`; confirm `~/.local/share/tmux-snapshots/snapshot-main.json`
   lists the opencode `session_id` for that pane.
3. Kill the server (`tmux -L work kill-server`), `ws main`, `tmux-restore`;
   confirm the opencode pane resumes its session and history is intact.

## AE6 — agent notification reaches Warp through tmux
1. In a `ws` pane, trigger a Claude Code Stop/Notification (finish a task or
   hit a permission prompt).
2. Confirm Warp surfaces a bell/activity for that window (tmux `monitor-bell`
   flags it). No reliance on Warp's native agent toast (broken in tmux+SSH).

## AE7 — reconnect with no lost work / no sprawl
1. In `ws main`, start something long-running. Close the laptop / drop the link.
2. Reconnect via Warp, `ws main`. Confirm you reattach the SAME session
   (no `main`+`1`+`2`… numbered sprawl) and the work is still running.

## Full-restart durability (the real test)
1. `ws main` with a couple of windows; wait for a supercronic save (≤5 min) or
   run `tmux-save`.
2. `cd ~/mega-container && ./rebuild.sh` (or `docker compose restart mega`).
3. Reconnect, `ws`; confirm tmux-resurrect restored the layout + pane contents
   on boot, and opencode sessions resume via `tmux-restore`.
