# Warp BYOK — bring your own API keys

Warp is removing free agents. Use your own Anthropic/OpenAI keys instead.

**This is a manual, per-device step — it cannot be chezmoi-managed.** Warp stores
BYOK keys in local device storage (not `settings.toml`, not synced), configured
only through the Settings UI. So each machine needs this done once by hand.

## Steps

1. Warp → **Settings** (⌘,) → search **"API keys"** → the BYOK widget.
2. Add **Anthropic** key — from 1Password:
   `op read "op://Development/Anthropic API Key/credential"`
3. Add **OpenAI** key:
   `op read "op://Development/OpenAI API Key/credential"`
4. Pick the model (or "auto" to use the enabled BYOK providers).

Available on the free plan; keys stay local and are billed to your own accounts.

Docs: https://docs.warp.dev/agent-platform/inference/bring-your-own-api-key/
