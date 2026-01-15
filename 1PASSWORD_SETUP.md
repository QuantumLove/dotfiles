# 1Password CLI Automated Authentication Setup

## Option 1: Service Account Token (Recommended)

Service accounts provide programmatic access without interactive login.

### Step 1: Create a Service Account

1. Go to your 1Password account: https://my.1password.com/
2. Navigate to **Integrations** → **Directory** → **Service Accounts**
3. Click **Create Service Account**
4. Name it (e.g., "Claude Code Dev Environment")
5. Grant access to the vaults containing your credentials:
   - Development vault (where Linear/GitHub tokens are stored)
6. Copy the service account token (starts with `ops_`)

### Step 2: Configure Your Environment

Add to your shell configuration (`~/.zshrc` or `~/.bashrc`):

```bash
# 1Password Service Account Token
export OP_SERVICE_ACCOUNT_TOKEN="ops_eyJhbGciOiJFZERTQSIsImtpZCI6I..."
```

### Step 3: Test It

```bash
# No sign-in required!
op read "op://Development/Linear MCP API Key/credential"
```

## Option 2: Biometric Unlock (macOS Touch ID)

For interactive use with Touch ID instead of password:

### Enable Biometric Unlock

```bash
# First, sign in normally
op signin

# Enable biometric unlock
op account add --address my.1password.com --email your-email@example.com

# Enable Touch ID
# In 1Password app: Preferences → Security → Touch ID
```

### Usage

```bash
# Will prompt for Touch ID instead of password
eval $(op signin)
```

## Option 3: Connect Server (Team Setup)

For team environments, 1Password Connect provides a REST API:

### Setup Connect Server

1. Get Connect credentials from 1Password admin
2. Deploy Connect server (Docker):

```yaml
# docker-compose.yml
version: "3.8"
services:
  op-connect-api:
    image: 1password/connect-api:latest
    ports:
      - "8080:8080"
    volumes:
      - ./1password-credentials.json:/home/opuser/.op/1password-credentials.json
      - data:/home/opuser/.op/data
```

3. Configure CLI to use Connect:

```bash
export OP_CONNECT_HOST="http://localhost:8080"
export OP_CONNECT_TOKEN="your-connect-token"
```

## Updating Your Chezmoi Setup

Once you have a service account token, update your `.zshrc.tmpl`:

```bash
{{- if .is_macos }}
# 1Password Service Account (no interactive login required)
export OP_SERVICE_ACCOUNT_TOKEN="${OP_SERVICE_ACCOUNT_TOKEN:-}"

# Load credentials if token is set
if [ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    # Linear API Key
    if [ -z "$LINEAR_API_KEY" ]; then
        export LINEAR_API_KEY=$(op read "op://Development/Linear MCP API Key/credential" 2>/dev/null || echo "")
    fi

    # GitHub Token
    if [ -z "$GITHUB_TOKEN" ]; then
        export GITHUB_TOKEN=$(op read "op://Development/GitHub Personal Access Token/credential" 2>/dev/null || echo "")
    fi
else
    echo "⚠️  OP_SERVICE_ACCOUNT_TOKEN not set. Set it for automatic credential loading."
fi
{{- end }}
```

## Security Best Practices

### For Service Account Tokens

1. **Store securely**: Never commit the token to git
2. **Limit scope**: Only grant access to necessary vaults
3. **Rotate regularly**: Regenerate tokens periodically
4. **Use environment-specific tokens**: Different tokens for dev/prod

### Secure Token Storage Options

#### Option A: macOS Keychain
```bash
# Store in keychain
security add-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w "ops_your_token_here"

# Load in .zshrc
export OP_SERVICE_ACCOUNT_TOKEN=$(security find-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w 2>/dev/null)
```

#### Option B: Secure File
```bash
# Create secure file
echo "ops_your_token_here" > ~/.config/op/service-account-token
chmod 600 ~/.config/op/service-account-token

# Load in .zshrc
if [ -f ~/.config/op/service-account-token ]; then
    export OP_SERVICE_ACCOUNT_TOKEN=$(cat ~/.config/op/service-account-token)
fi
```

#### Option C: direnv (Project-specific)
```bash
# In project .envrc (git-ignored)
export OP_SERVICE_ACCOUNT_TOKEN="ops_your_token_here"

# Enable direnv
direnv allow
```

## Testing Your Setup

Create this test script:

```bash
#!/bin/bash
# test-op-auth.sh

echo "🔐 Testing 1Password Authentication..."

if [ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]; then
    echo "✅ Service account token found"

    # Test read
    if op read "op://Development/Linear MCP API Key/credential" > /dev/null 2>&1; then
        echo "✅ Successfully read from vault"
    else
        echo "❌ Failed to read from vault"
    fi
else
    echo "❌ No service account token found"
fi

# Test environment
echo ""
echo "📊 Environment Status:"
echo "LINEAR_API_KEY: ${LINEAR_API_KEY:+✅ Set}"
echo "GITHUB_TOKEN: ${GITHUB_TOKEN:+✅ Set}"
```

## Troubleshooting

### "No service account token found"
- Ensure `OP_SERVICE_ACCOUNT_TOKEN` is exported
- Check token hasn't expired
- Verify token has correct vault permissions

### "Failed to read from vault"
- Check vault names match exactly
- Verify item paths are correct
- Ensure service account has vault access

### Performance Issues
- Cache credentials in environment variables
- Use `op inject` for templates
- Consider Connect server for high-volume usage

## Migration Path

1. Create service account token
2. Test with a single credential
3. Update .zshrc.tmpl
4. Remove interactive `op signin` commands
5. Deploy with chezmoi

This eliminates all interactive authentication while maintaining security!