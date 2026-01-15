#!/bin/bash
# Setup script for 1Password Service Account Token

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔐 1Password Service Account Setup${NC}"
echo ""
echo "This script will help you set up automated 1Password authentication."
echo ""

# Check if op is installed
if ! command -v op &> /dev/null; then
    echo -e "${RED}❌ 1Password CLI not found${NC}"
    echo "Please install it first: brew install 1password-cli"
    exit 1
fi

# Show instructions
echo "📋 Setup Instructions:"
echo ""
echo "1. Go to: https://my.1password.com/"
echo "2. Navigate to: Integrations → Directory → Service Accounts"
echo "3. Click: Create Service Account"
echo "4. Name it: 'Claude Code Dev Environment'"
echo "5. Grant access to your Development vault"
echo "6. Copy the service account token (starts with 'ops_')"
echo ""
read -p "Press Enter when you have your token ready..."

# Get token
echo ""
read -sp "Paste your service account token: " TOKEN
echo ""

if [[ ! "$TOKEN" =~ ^ops_ ]]; then
    echo -e "${RED}❌ Invalid token format. Service account tokens start with 'ops_'${NC}"
    exit 1
fi

# Test token
echo ""
echo "Testing token..."
export OP_SERVICE_ACCOUNT_TOKEN="$TOKEN"

if op vault list &> /dev/null; then
    echo -e "${GREEN}✅ Token is valid!${NC}"
else
    echo -e "${RED}❌ Token test failed${NC}"
    exit 1
fi

# Choose storage method
echo ""
echo "How would you like to store the token?"
echo ""
echo "1. macOS Keychain (most secure - recommended)"
echo "2. Secure file (~/.config/op/service-account-token)"
echo "3. Show manual instructions only"
echo ""
read -p "Choice (1-3): " CHOICE

case "$CHOICE" in
    1)
        echo ""
        echo "Storing in macOS Keychain..."

        # Delete existing if present
        security delete-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" &>/dev/null || true

        # Add to keychain
        if security add-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w "$TOKEN"; then
            echo -e "${GREEN}✅ Token stored in Keychain${NC}"

            # Test retrieval
            TEST_TOKEN=$(security find-generic-password -a "$USER" -s "OP_SERVICE_ACCOUNT_TOKEN" -w 2>/dev/null)
            if [ "$TEST_TOKEN" = "$TOKEN" ]; then
                echo -e "${GREEN}✅ Verified: Token can be retrieved${NC}"
            fi
        else
            echo -e "${RED}❌ Failed to store in Keychain${NC}"
            exit 1
        fi
        ;;

    2)
        echo ""
        echo "Storing in secure file..."

        # Create directory
        mkdir -p ~/.config/op
        chmod 700 ~/.config/op

        # Write token
        echo "$TOKEN" > ~/.config/op/service-account-token
        chmod 600 ~/.config/op/service-account-token

        echo -e "${GREEN}✅ Token stored in ~/.config/op/service-account-token${NC}"
        ;;

    3)
        echo ""
        echo "Manual setup instructions:"
        echo ""
        echo "Add to your ~/.zshrc or ~/.bashrc:"
        echo ""
        echo "export OP_SERVICE_ACCOUNT_TOKEN=\"$TOKEN\""
        echo ""
        echo "⚠️  Note: This is less secure than the other methods"
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Test final setup
echo ""
echo "Testing credential access..."

# Clear current token to test loading
unset OP_SERVICE_ACCOUNT_TOKEN

# Source the updated zshrc to test
if [ -f ~/.zshrc ]; then
    source ~/.zshrc
fi

if [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
    echo -e "${GREEN}✅ Token loads automatically${NC}"

    # Test reading credentials
    echo ""
    echo "Testing vault access:"

    if op read "op://Development/Linear MCP API Key/credential" &>/dev/null; then
        echo -e "${GREEN}✅ Can read Linear API Key${NC}"
    else
        echo -e "${YELLOW}⚠️  Cannot read Linear API Key (might not exist)${NC}"
    fi

    if op read "op://Development/GitHub Personal Access Token/credential" &>/dev/null; then
        echo -e "${GREEN}✅ Can read GitHub Token${NC}"
    else
        echo -e "${YELLOW}⚠️  Cannot read GitHub Token (might not exist)${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Token not loading automatically. Reload your shell.${NC}"
fi

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Reload your shell: exec \$SHELL"
echo "2. Test with: /mcp-check"
echo "3. Your credentials will load automatically - no more op signin!"

# Apply chezmoi changes
echo ""
read -p "Apply chezmoi changes now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd ~/.local/share/chezmoi
    chezmoi apply
    echo -e "${GREEN}✅ Changes applied${NC}"
fi