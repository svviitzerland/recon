#!/bin/bash
# Main recon automation script

set -e

export PATH=/root/go/bin:/usr/local/go/bin:$PATH

BASE_DIR="/root/recon"
TARGETS_DIR="$BASE_DIR/targets"
OUTPUT_DIR="$BASE_DIR/results"
LOG_FILE="$BASE_DIR/logs/recon.log"

mkdir -p "$TARGETS_DIR" "$OUTPUT_DIR" "$BASE_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting automated recon pipeline..."

# Fetch targets from all platforms
log "Fetching targets from bug bounty platforms..."

PLATFORMS=(
    "bugcrowd_data.json"
    "hackerone_data.json"
    "federacy_data.json"
    "intigriti_data.json"
    "yeswehack_data.json"
)

for platform in "${PLATFORMS[@]}"; do
    log "  - Downloading $platform"
    curl -s "https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/$platform" \
        -o "$TARGETS_DIR/$platform" || log "    Failed to download $platform"
done

# Extract all domains
log "Extracting domains..."
for platform_file in "$TARGETS_DIR"/*.json; do
    platform_name=$(basename "$platform_file" .json)

    jq -r '
        try (
            .[] |
            select(.targets.in_scope != null) |
            .targets.in_scope[] |
            select(.type == "website" or .type == "api") |
            .target
        ) // empty
    ' "$platform_file" 2>/dev/null | \
    grep -oP '(?:https?://)?(?:www\.)?([a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+)' | \
    sed 's|https\?://||' | sed 's|www\.||' | \
    sort -u >> "$TARGETS_DIR/${platform_name}_domains.txt" || true
done

# Combine all domains
cat "$TARGETS_DIR"/*_domains.txt | sort -u > "$TARGETS_DIR/all_domains.txt"

TOTAL_DOMAINS=$(wc -l < "$TARGETS_DIR/all_domains.txt")
log "Total unique domains: $TOTAL_DOMAINS"

# Process each domain
COUNTER=0
while IFS= read -r domain; do
    COUNTER=$((COUNTER + 1))
    log "[$COUNTER/$TOTAL_DOMAINS] Processing: $domain"

    DOMAIN_DIR="$OUTPUT_DIR/$domain"
    mkdir -p "$DOMAIN_DIR"

    # Subdomain enumeration
    log "  [+] Subfinder..."
    subfinder -d "$domain" -silent -o "$DOMAIN_DIR/subdomains.txt" 2>/dev/null || true

    if [ ! -s "$DOMAIN_DIR/subdomains.txt" ]; then
        echo "$domain" > "$DOMAIN_DIR/subdomains.txt"
    fi

    # Live hosts
    log "  [+] Checking live hosts..."
    cat "$DOMAIN_DIR/subdomains.txt" | \
        httpx -silent -threads 50 -o "$DOMAIN_DIR/live_hosts.txt" 2>/dev/null || true

    if [ ! -s "$DOMAIN_DIR/live_hosts.txt" ]; then
        log "  [-] No live hosts found, skipping..."
        continue
    fi

    LIVE_COUNT=$(wc -l < "$DOMAIN_DIR/live_hosts.txt")
    log "  [+] Found $LIVE_COUNT live hosts"

    # Nuclei scan
    log "  [+] Running nuclei..."
    cat "$DOMAIN_DIR/live_hosts.txt" | \
        nuclei -silent -severity critical,high,medium \
        -o "$DOMAIN_DIR/nuclei_findings.txt" 2>/dev/null || true

    # URL crawling
    log "  [+] Crawling URLs..."
    cat "$DOMAIN_DIR/live_hosts.txt" | head -10 | \
        katana -silent -d 2 -jc -kf all -c 20 \
        -o "$DOMAIN_DIR/urls.txt" 2>/dev/null || true

    # Wayback URLs
    log "  [+] Wayback URLs..."
    echo "$domain" | waybackurls 2>/dev/null | head -1000 >> "$DOMAIN_DIR/urls.txt" || true

    # XSS Testing
    if [ -s "$DOMAIN_DIR/urls.txt" ]; then
        log "  [+] XSS testing..."
        cat "$DOMAIN_DIR/urls.txt" | grep "=" | head -50 | \
            dalfox pipe --silence --skip-bav \
            -o "$DOMAIN_DIR/xss_findings.txt" 2>/dev/null || true
    fi

    # Subdomain Takeover
    log "  [+] Subdomain takeover check..."
    subjack -w "$DOMAIN_DIR/subdomains.txt" -t 20 -timeout 10 -ssl \
        -o "$DOMAIN_DIR/takeover.txt" 2>/dev/null || true

    # Summary
    if [ -s "$DOMAIN_DIR/nuclei_findings.txt" ]; then
        FINDINGS=$(wc -l < "$DOMAIN_DIR/nuclei_findings.txt")
        log "  [!] Found $FINDINGS potential findings!"
    fi

done < "$TARGETS_DIR/all_domains.txt"

log "Recon complete! Results in: $OUTPUT_DIR"
