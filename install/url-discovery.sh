#!/bin/bash
# Install URL discovery tools (waybackurls, gau)

set -e

export HOME=/root
export PATH=/root/go/bin:/usr/local/go/bin:$PATH
export GOPATH=/root/go
export GOMODCACHE=/root/go/pkg/mod
export GOCACHE=/root/.cache/go-build

echo "[+] Installing URL discovery tools..."

# Waybackurls
echo "  - Installing waybackurls..."
go install github.com/tomnomnom/waybackurls@latest

# GAU
echo "  - Installing gau..."
go install github.com/lc/gau/v2/cmd/gau@latest

echo "✓ URL discovery tools installed"

# Verify
echo ""
echo "Verification:"
/root/go/bin/waybackurls -h 2>&1 | head -1
/root/go/bin/gau --version 2>&1 | head -1
