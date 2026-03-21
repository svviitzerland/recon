#!/bin/bash
# Install ProjectDiscovery tools (subfinder, httpx, nuclei, katana, dnsx)

set -e

export PATH=/root/go/bin:/usr/local/go/bin:$PATH
export GOPATH=/root/go
export GOMODCACHE=/root/go/pkg/mod

echo "[+] Installing ProjectDiscovery tools..."

# Subfinder
echo "  - Installing subfinder..."
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Httpx
echo "  - Installing httpx..."
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest

# Nuclei
echo "  - Installing nuclei..."
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest

# Katana
echo "  - Installing katana..."
go install github.com/projectdiscovery/katana/cmd/katana@latest

# Dnsx
echo "  - Installing dnsx..."
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest

# Update nuclei templates
echo "  - Updating nuclei templates..."
/root/go/bin/nuclei -update-templates -silent

echo "✓ ProjectDiscovery tools installed"

# Verify
echo ""
echo "Verification:"
/root/go/bin/subfinder -version 2>&1 | head -1
/root/go/bin/httpx -version 2>&1 | head -1
/root/go/bin/nuclei -version 2>&1 | head -1
/root/go/bin/katana -version 2>&1 | head -1
/root/go/bin/dnsx -version 2>&1 | head -1
