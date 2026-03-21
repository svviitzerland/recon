#!/bin/bash
# Configuration script - Setup API keys

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         API Keys Configuration                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Create config directories
mkdir -p ~/.config/subfinder

# Check if API keys are provided as environment variables
if [ -n "$CHAOS_KEY" ] || [ -n "$SHODAN_KEY" ] || [ -n "$CENSYS_TOKEN" ] || [ -n "$SECURITYTRAILS_KEY" ]; then
    echo "[+] Configuring API keys from environment variables..."

    cat > ~/.config/subfinder/provider-config.yaml << EOF
# ProjectDiscovery Chaos
chaos:
  - ${CHAOS_KEY}

# Shodan
shodan:
  - ${SHODAN_KEY}

# Censys (Personal Access Token)
censys:
  - ${CENSYS_TOKEN}

# SecurityTrails
securitytrails:
  - ${SECURITYTRAILS_KEY}
EOF

    echo "✓ API keys configured!"
    echo ""
    echo "Configured services:"
    [ -n "$CHAOS_KEY" ] && echo "  - Chaos (ProjectDiscovery)"
    [ -n "$SHODAN_KEY" ] && echo "  - Shodan"
    [ -n "$CENSYS_TOKEN" ] && echo "  - Censys"
    [ -n "$SECURITYTRAILS_KEY" ] && echo "  - SecurityTrails"

else
    echo "[!] No API keys found in environment variables"
    echo ""
    echo "To configure API keys, set these environment variables:"
    echo ""
    echo "  export CHAOS_KEY='your-chaos-key'"
    echo "  export SHODAN_KEY='your-shodan-key'"
    echo "  export CENSYS_TOKEN='your-censys-pat-token'"
    echo "  export SECURITYTRAILS_KEY='your-securitytrails-key'"
    echo ""
    echo "Then run this script again."
    echo ""
    echo "Or manually edit: ~/.config/subfinder/provider-config.yaml"
fi

echo ""
