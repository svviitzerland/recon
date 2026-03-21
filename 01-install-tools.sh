#!/bin/bash
# Master installation script - installs all tools

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Bug Bounty Tools Installation                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Run prerequisites
if [ -f "$SCRIPT_DIR/00-prerequisites.sh" ]; then
    bash "$SCRIPT_DIR/00-prerequisites.sh"
else
    echo "Error: 00-prerequisites.sh not found"
    exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Installing Tools                                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Install tool categories
bash "$SCRIPT_DIR/install/projectdiscovery.sh"
echo ""

bash "$SCRIPT_DIR/install/url-discovery.sh"
echo ""

bash "$SCRIPT_DIR/install/vuln-testing.sh"
echo ""

bash "$SCRIPT_DIR/install/fuzzing.sh"
echo ""

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║         Installation Complete!                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "All tools installed successfully!"
echo ""
echo "Installed tools:"
echo "  - subfinder, httpx, nuclei, katana, dnsx"
echo "  - waybackurls, gau"
echo "  - dalfox, sqlmap, crlfuzz"
echo "  - ffuf, subjack, s3scanner"
echo ""
echo "Next steps:"
echo "  1. Configure tools (optional): ./02-configure.sh"
echo "  2. Run recon: ./03-run-recon.sh"
echo ""
