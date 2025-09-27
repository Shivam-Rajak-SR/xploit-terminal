# Xploit Terminal — Multi-Terminal Recon (Educational & Interactive)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)

© 2025 Shivam Rajak — Licensed under the MIT License.

**Xploit Terminal** is an interactive, colorful multi-terminal reconnaissance script intended for educational and authorized security testing.

> ⚠️ **Disclaimer:** Only run intrusive scans and pentest tools on systems you own or where you have explicit written permission. Misuse is illegal.

---

## Features

- Big ASCII banner and polished colored UI
- Interactive tool selection (supports ranges and `all`)
- Installs missing tools interactively (best-effort)
- Launches selected tools in separate terminals concurrently
- Auto-closes terminals a few seconds after each task completes
- Saves outputs in a timestamped directory: `~/xploit_recon_<timestamp>/raw/`
- Single domain input used for all tools
- Clear safety prompts before intrusive tools

---

## Quick Start

```bash
# Clone this repo (if from GitHub)
git clone https://github.com/Shivam-Rajak-SR/xploit-terminal.git
cd xploit-terminal

# Make the main script executable
chmod +x xploit_terminal.sh

# Run with bash (do not use sh)
bash ./xploit_terminal.sh

# steps 

Follow the on-screen prompts:

Select tools by number (e.g. 1,3,5-8) or type all.

Enter the target domain (asked once).

Accept installation prompts for missing packages (interactive).

Confirm intrusive scans if prompted.

Each selected tool will open in its own terminal and save output in ~/xploit_recon_<timestamp>/raw/.

# this is all tools  
Tool List (Partial)

Some of the tools supported (educational purposes only):

whois, dig, curl, openssl, ping

whatweb, nmap, masscan

netcat, tcpdump, tshark

theHarvester, amass, subfinder

nikto, wpscan, sqlmap

gobuster, ffuf, dirb

metasploit-framework, hydra, john, hashcat

docker, docker-compose, git, python3, go

And many more (see xploit_terminal.sh for full list)