# Gmail access for the mega-container (gws CLI)

`morning-triage` reads and triages your Gmail through the [`gws` CLI](https://github.com/googleworkspace/cli)
(`@googleworkspace/cli`). This is a **one-time** setup; the credential then persists in 1Password and the
container auto-loads it on every boot — **no recurring browser login**.

**Why there are extra steps:** `gws` ships **no OAuth client of its own**, and `gmail.readonly` /
`gmail.modify` are Google **restricted scopes**. So you create your **own** Google Cloud OAuth client
once. Use an **Internal** consent screen (a project owned by the metr.org org): Internal apps skip
Google's verification, show no scope warning, and get a **long-lived** refresh token. (An External
"Testing" app instead expires tokens every ~7 days — see the alternative at the end.)

## Recommended: Internal OAuth client (one-time, persistent)

Do this on a machine with a browser:

1. **Create/select a GCP project owned by the metr.org organization** —
   [Cloud Console](https://console.cloud.google.com) → project picker → **New Project**. It must be
   under the metr.org org (not a personal account) for "Internal" to be available.

2. **Enable the Gmail API** —
   [enable it directly](https://console.cloud.google.com/apis/library/gmail.googleapis.com), or
   `gcloud services enable gmail.googleapis.com`.

3. **Set the OAuth consent screen to Internal** — APIs & Services → OAuth consent screen (Google Auth
   Platform) → User type **Internal** → set an app name + support email.
   Ref: <https://developers.google.com/workspace/guides/configure-oauth-consent>

4. **Create a Desktop OAuth client** — APIs & Services → Credentials → Create credentials →
   OAuth client ID → Application type **Desktop app** → Create → **Download JSON** → save as
   `~/.config/gws/client_secret.json`.

5. **Install gws and log in** — request **only** `gmail` (the "recommended" preset pulls 85+ scopes and
   fails for non-production apps):
   ```bash
   npm install -g @googleworkspace/cli
   gws auth login -s gmail        # grant gmail.readonly + gmail.modify in the browser
   ```

6. **Export the credential** (an `authorized_user` JSON — `client_id` + `client_secret` + `refresh_token`):
   ```bash
   gws auth export --unmasked > gws-credentials.json
   ```

7. **Smoke-test:**
   ```bash
   gws gmail messages list --params '{"q":"is:unread","maxResults":3}'
   ```

8. **Store in 1Password** — Vault **Development**, item **GWS Credentials JSON**, type **Secure Note**;
   paste the full JSON into the note body. Then delete the local files:
   ```bash
   rm gws-credentials.json ~/.config/gws/client_secret.json
   ```

9. **Apply to the container** — rebuild or `/hot-patch --chezmoi`. The entrypoint reads
   `op://Development/GWS Credentials JSON/notesPlain`, writes `~/.config/gws/credentials.json`, and
   exports `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE`. `mega-doctor` then shows GWS ready and
   `/morning-triage` works.

**Do you need an admin?** Internal + restricted scopes need **no** Google verification. You only need a
Workspace/GCP admin if (a) you can't create a project in the metr.org GCP org, or (b) metr's Admin
console restricts the Gmail API / unconfigured apps. Quick test: run step 5 — if you hit
**"Access blocked: this app is blocked by your administrator,"** file a request (give them your OAuth
**client ID** + the two scopes, or ask them to grant you a metr-org GCP project / trust internal apps).
Admin app-access ref: <https://support.google.com/a/answer/13152743>

## Alternative: External + Testing (quick trial — NOT persistent)

If you can't get an org-owned project, try a **personal** GCP project to see whether metr lets it
through. Same steps as above, except:

- Step 3: consent screen **User type → External**, publishing status **Testing**, and add your own
  address under **Test users**.
- Step 5: click through the **"unverified app"** warning.

**Caveats:** refresh tokens **expire after ~7 days** (weekly re-auth), and if metr blocks unverified /
unconfigured third-party apps your metr.org Gmail may still be denied. Fine for an experiment; **not**
suitable for the set-once container flow — use Internal for the real setup.

## If a token ever stops working

Re-run steps 5–8 to refresh the credential in 1Password.

## How the container consumes it

`mega-container/entrypoint.sh` reads `op://Development/GWS Credentials JSON/notesPlain`, writes it to
`~/.config/gws/credentials.json` (chmod 600), and exports `GOOGLE_WORKSPACE_CLI_CREDENTIALS_FILE`.
`private_dot_claude/commands/morning-triage.md.tmpl` then drives `gws gmail messages list/get/modify`.
Only the exported `authorized_user` JSON is needed at runtime — **not** `client_secret.json` (that's only
for the initial interactive login on the browser machine).

## Links

- gws CLI: [repo](https://github.com/googleworkspace/cli) ·
  [npm](https://www.npmjs.com/package/@googleworkspace/cli) ·
  [auth docs](https://googleworkspace-cli.mintlify.app/concepts/authentication)
- Google: [Gmail API scopes](https://developers.google.com/workspace/gmail/api/auth/scopes) ·
  [OAuth consent setup](https://developers.google.com/workspace/guides/configure-oauth-consent) ·
  [Admin app access control](https://support.google.com/a/answer/13152743)
