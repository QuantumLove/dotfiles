# Global agent rules

## AWS authentication

When an AWS command fails with missing or expired credentials, do NOT ask the user
to log in. Run `aws-sso-login` (staging, default) or `aws-sso-login production`. In
headless/SSH environments it prints a device-authorization URL with the code
pre-filled — give that URL to the user and ask them to open it and approve the
sign-in; that is their only step. After approval the active profile is
`<env>-device`, so retry the failed command with `--profile <env>-device` (e.g.
`staging-device`).

## Branch rules

1. The primary worktree stays on the default branch, and tracked files there are
   not edited. Feature work happens in `.worktrees/`. Untracked and gitignored
   files are unaffected — scratch files never enter a commit.
2. No commit on the default branch.
3. No push to the default branch.
4. `QuantumLove/dotfiles` and `QuantumLove/glove80` are exempt from all of the
   above, along with any fork we maintain.
5. `--no-verify` is the escape hatch when you genuinely mean it.
6. A repo with no remote is unguarded — nothing shared to protect.
7. There is no force-push rule. Force-push is fine anywhere it is allowed to
   push at all.

Rules 2 and 3 are git hooks, so they apply to every actor equally. Rule 1 has no
git hook — git provides no pre-edit or pre-checkout — so it is enforced by a
per-harness adapter reading the same policy file.

## Never merge PRs

Create draft PRs; never merge them. Merging is a human action in the GitHub UI.
