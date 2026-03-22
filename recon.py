#!/usr/bin/env python3
"""
Automated Bug Bounty Reconnaissance Pipeline
"""

import os
import sys
import json
import subprocess
import logging
from pathlib import Path
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict
import requests

# Configuration
BASE_DIR = Path.home() / "recon"
TARGETS_DIR = BASE_DIR / "targets"
OUTPUT_DIR = BASE_DIR / "results"
LOGS_DIR = BASE_DIR / "logs"
STATE_FILE = BASE_DIR / ".recon_state.json"

PLATFORMS = {
    "bugcrowd": "https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/bugcrowd_data.json",
    "hackerone": "https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/hackerone_data.json",
    "federacy": "https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/federacy_data.json",
    "intigriti": "https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/intigriti_data.json",
    "yeswehack": "https://raw.githubusercontent.com/arkadiyt/bounty-targets-data/main/data/yeswehack_data.json",
}

# Setup logging
LOGS_DIR.mkdir(parents=True, exist_ok=True)
log_file = LOGS_DIR / f"recon_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"

logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)


def run_command(cmd: List[str], timeout: int = 300) -> tuple:
    """Run shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        logger.error(f"Command timeout: {' '.join(cmd)}")
        return -1, "", "Timeout"
    except Exception as e:
        logger.error(f"Command failed: {' '.join(cmd)} - {e}")
        return -1, "", str(e)


def fetch_targets() -> List[str]:
    """Fetch and extract domains from bug bounty platforms"""
    logger.info("Fetching targets from bug bounty platforms...")
    TARGETS_DIR.mkdir(parents=True, exist_ok=True)

    all_domains = set()

    for platform, url in PLATFORMS.items():
        logger.info(f"  - Downloading {platform}_data.json")
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            data = response.json()

            # Extract domains
            for program in data:
                if not program.get("targets", {}).get("in_scope"):
                    continue

                for target in program["targets"]["in_scope"]:
                    if target.get("type") not in ["website", "api"]:
                        continue

                    target_url = target.get("target", "")

                    # Skip placeholders
                    if any(x in target_url for x in ["###", "***", "{", "}", "[", "]"]):
                        continue

                    # Extract domain
                    domain = extract_domain(target_url)
                    if domain and is_valid_domain(domain):
                        all_domains.add(domain)

            logger.info(f"    Extracted {len(all_domains)} unique domains so far")

        except Exception as e:
            logger.error(f"  Failed to fetch {platform}: {e}")

    domains_list = sorted(all_domains)

    # Save to file
    domains_file = TARGETS_DIR / "all_domains.txt"
    with open(domains_file, "w") as f:
        f.write("\n".join(domains_list))

    logger.info(f"Total unique domains: {len(domains_list)}")
    return domains_list


def extract_domain(url: str) -> str:
    """Extract domain from URL"""
    import re

    # Remove protocol
    url = re.sub(r'^https?://', '', url)
    url = re.sub(r'^www\.', '', url)

    # Extract domain (everything before first /)
    domain = url.split('/')[0].split(':')[0]

    return domain.lower()


def is_valid_domain(domain: str) -> bool:
    """Validate domain format"""
    import re

    if not domain or len(domain) < 4:
        return False

    # Must start and end with alphanumeric
    if domain[0] == '-' or domain[-1] == '-':
        return False

    # Must have at least one dot
    if '.' not in domain:
        return False

    # Basic domain pattern
    pattern = r'^[a-zA-Z0-9][a-zA-Z0-9.-]*\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, domain))


def load_state() -> Dict:
    """Load processing state"""
    if STATE_FILE.exists():
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"processed": [], "failed": []}


def save_state(state: Dict):
    """Save processing state"""
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def process_domain(domain: str, counter: int, total: int) -> bool:
    """Process a single domain"""
    logger.info(f"[{counter}/{total}] Processing: {domain}")

    domain_dir = OUTPUT_DIR / domain
    domain_dir.mkdir(parents=True, exist_ok=True)

    try:
        # 1. Subdomain enumeration
        logger.info(f"  [+] Subfinder...")
        subdomains_file = domain_dir / "subdomains.txt"
        run_command([
            "subfinder", "-d", domain, "-silent",
            "-o", str(subdomains_file)
        ], timeout=180)

        # Ensure domain itself is included
        if not subdomains_file.exists() or subdomains_file.stat().st_size == 0:
            with open(subdomains_file, "w") as f:
                f.write(domain)

        # 2. Live hosts
        logger.info(f"  [+] Checking live hosts...")
        live_hosts_file = domain_dir / "live_hosts.txt"
        run_command([
            "httpx", "-silent", "-threads", "50",
            "-l", str(subdomains_file),
            "-o", str(live_hosts_file)
        ], timeout=300)

        if not live_hosts_file.exists() or live_hosts_file.stat().st_size == 0:
            logger.info(f"  [-] No live hosts found, skipping...")
            return True

        live_count = len(live_hosts_file.read_text().strip().split('\n'))
        logger.info(f"  [+] Found {live_count} live hosts")

        # 3. Nuclei scan
        logger.info(f"  [+] Running nuclei...")
        nuclei_file = domain_dir / "nuclei_findings.txt"
        run_command([
            "nuclei", "-silent",
            "-severity", "critical,high,medium",
            "-l", str(live_hosts_file),
            "-o", str(nuclei_file)
        ], timeout=600)

        # 4. URL crawling (limit to 10 hosts)
        logger.info(f"  [+] Crawling URLs...")
        urls_file = domain_dir / "urls.txt"

        # Get first 10 live hosts
        with open(live_hosts_file) as f:
            hosts = [line.strip() for line in f.readlines()[:10]]

        for host in hosts:
            run_command([
                "katana", "-silent", "-d", "2", "-jc",
                "-kf", "all", "-c", "20", "-u", host,
                "-o", str(urls_file)
            ], timeout=120)

        # 5. Wayback URLs
        logger.info(f"  [+] Wayback URLs...")
        code, stdout, _ = run_command(["waybackurls", domain], timeout=120)
        if code == 0 and stdout:
            urls = stdout.strip().split('\n')[:1000]
            with open(urls_file, "a") as f:
                f.write('\n'.join(urls) + '\n')

        # 6. XSS Testing
        if urls_file.exists() and urls_file.stat().st_size > 0:
            logger.info(f"  [+] XSS testing...")
            xss_file = domain_dir / "xss_findings.txt"

            # Get URLs with parameters
            with open(urls_file) as f:
                param_urls = [line.strip() for line in f if '=' in line][:50]

            if param_urls:
                urls_input = '\n'.join(param_urls)
                proc = subprocess.Popen(
                    ["dalfox", "pipe", "--silence", "--skip-bav", "-o", str(xss_file)],
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True
                )
                proc.communicate(input=urls_input, timeout=180)

        # 7. Subdomain takeover
        logger.info(f"  [+] Subdomain takeover check...")
        takeover_file = domain_dir / "takeover.txt"
        run_command([
            "subjack", "-w", str(subdomains_file),
            "-t", "20", "-timeout", "10", "-ssl",
            "-o", str(takeover_file)
        ], timeout=180)

        # Summary
        if nuclei_file.exists() and nuclei_file.stat().st_size > 0:
            findings = len(nuclei_file.read_text().strip().split('\n'))
            logger.info(f"  [!] Found {findings} potential findings!")

        return True

    except Exception as e:
        logger.error(f"  [ERROR] Failed to process {domain}: {e}")
        return False


def main():
    """Main execution"""
    logger.info("Starting automated recon pipeline...")

    # Create directories
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Fetch targets
    domains = fetch_targets()

    if not domains:
        logger.error("No domains found!")
        return

    # Load state
    state = load_state()
    processed = set(state.get("processed", []))

    # Filter unprocessed domains
    remaining = [d for d in domains if d not in processed]

    if not remaining:
        logger.info("All domains already processed!")
        return

    logger.info(f"Processing {len(remaining)} domains (skipping {len(processed)} already done)")

    # Process domains
    total = len(domains)
    for idx, domain in enumerate(remaining, start=len(processed) + 1):
        success = process_domain(domain, idx, total)

        if success:
            state["processed"].append(domain)
        else:
            state["failed"].append(domain)

        # Save state after each domain
        save_state(state)

    logger.info(f"Recon complete! Results in: {OUTPUT_DIR}")
    logger.info(f"Processed: {len(state['processed'])}, Failed: {len(state.get('failed', []))}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("\nInterrupted by user. Progress saved.")
        sys.exit(0)
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        sys.exit(1)
