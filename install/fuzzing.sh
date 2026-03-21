#!/bin/bash
# Install fuzzing and discovery tools (ffuf, subjack, s3scanner)

set -e

export PATH=/root/go/bin:/usr/local/go/bin:$PATH
export GOPATH=/root/go
export GOMODCACHE=/root/go/pkg/mod

echo "[+] Installing fuzzing and discovery tools..."

# FFUF
echo "  - Installing ffuf..."
go install github.com/ffuf/ffuf/v2@latest

# Subjack (subdomain takeover)
echo "  - Installing subjack..."
go install github.com/haccer/subjack@latest

# S3Scanner
echo "  - Installing s3scanner..."
go install github.com/sa7mon/s3scanner@latest

echo "✓ Fuzzing and discovery tools installed"

# Verify
echo ""
echo "Verification:"
/root/go/bin/ffuf -V 2>&1 | head -1
/root/go/bin/subjack -h 2>&1 | head -1
/root/go/bin/s3scanner --version 2>&1 | head -1
