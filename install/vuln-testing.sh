#!/bin/bash
# Install vulnerability testing tools (dalfox, sqlmap, crlfuzz)

set -e

export PATH=/root/go/bin:/usr/local/go/bin:$PATH
export GOPATH=/root/go
export GOMODCACHE=/root/go/pkg/mod

echo "[+] Installing vulnerability testing tools..."

# Dalfox (XSS)
echo "  - Installing dalfox..."
go install github.com/hahwul/dalfox/v2@latest

# SQLMap
echo "  - Installing sqlmap..."
apt-get install -y -qq sqlmap

# CRLFuzz (Open Redirect)
echo "  - Installing crlfuzz..."
go install github.com/dwisiswant0/crlfuzz@latest

echo "✓ Vulnerability testing tools installed"

# Verify
echo ""
echo "Verification:"
/root/go/bin/dalfox version 2>&1 | head -1
sqlmap --version 2>&1 | head -1
/root/go/bin/crlfuzz -h 2>&1 | head -1
