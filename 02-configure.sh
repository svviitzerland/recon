#!/bin/bash
# Configuration script - optional API keys and settings

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Tool Configuration (Optional)                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Create config directories
mkdir -p ~/.config/subfinder
mkdir -p ~/.config/nuclei
mkdir -p ~/.config/httpx
mkdir -p ~/.config/katana

echo "[+] Configuration directories created"
echo ""
echo "Optional: Add API keys for better results"
echo ""
echo "Subfinder API keys (~/.config/subfinder/provider-config.yaml):"
echo "  - Chaos: https://chaos.projectdiscovery.io"
echo "  - Shodan: https://shodan.io"
echo "  - Censys: https://censys.io"
echo ""
echo "See docs/ folder for each tool's configuration options"
echo ""
