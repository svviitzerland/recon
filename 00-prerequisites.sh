#!/bin/bash
# Prerequisites check and installation

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║           Prerequisites Check & Installation              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

# Update system
echo "[1/5] Updating system..."
apt-get update -qq
apt-get upgrade -y -qq

# Install basic tools
echo "[2/5] Installing basic tools..."
apt-get install -y -qq \
    curl \
    wget \
    git \
    jq \
    tmux \
    unzip \
    build-essential \
    python3 \
    python3-pip

# Install Go
echo "[3/5] Installing Go 1.26.1..."
if [ -d /usr/local/go ]; then
    echo "  Go already installed, removing old version..."
    rm -rf /usr/local/go
fi

wget -q https://go.dev/dl/go1.26.1.linux-amd64.tar.gz
tar -C /usr/local -xzf go1.26.1.linux-amd64.tar.gz
rm go1.26.1.linux-amd64.tar.gz

# Setup Go environment
echo 'export PATH=/root/go/bin:/usr/local/go/bin:$PATH' >> /root/.bashrc
echo 'export GOPATH=/root/go' >> /root/.bashrc
echo 'export GOMODCACHE=/root/go/pkg/mod' >> /root/.bashrc

export PATH=/root/go/bin:/usr/local/go/bin:$PATH
export GOPATH=/root/go
export GOMODCACHE=/root/go/pkg/mod

# Verify Go
echo "[4/5] Verifying Go installation..."
/usr/local/go/bin/go version

# Create working directories
echo "[5/5] Creating working directories..."
mkdir -p /root/recon/{targets,results,logs}
mkdir -p /root/go/bin

echo ""
echo "✓ Prerequisites installed successfully!"
echo ""
echo "Go version: $(/usr/local/go/bin/go version)"
echo "Python version: $(python3 --version)"
echo ""
