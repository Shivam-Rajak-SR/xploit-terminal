#!/usr/bin/env bash
# xploit_terminal.sh
# Xploit Terminal — Interactive multi-terminal recon helper (professional + colorful)
#
# Save as xploit_terminal.sh, make executable:
#   chmod +x xploit_terminal.sh
# Run with:
#   bash ./xploit_terminal.sh
#
# WARNING: Only run intrusive scans on systems you have permission to test.
set -euo pipefail
IFS=$'\n\t'

### CONFIG ###
TERMINAL_POST_SLEEP=3                       # seconds each terminal remains after finishing
OUTDIR_BASE="$HOME/xploit_recon_$(date +%Y%m%d_%H%M%S)"
PKG=""                                       # detected package manager name
PKG_CMD=""                                   # install command prefix
TERMINAL_EMU=""                              # chosen terminal emulator
TARGET_DOMAIN=""                             # domain entered once
SELECTED_IDX=()                              # zero-based indices of chosen tools

# Colors
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m"

timestamp(){ date +"%Y%m%d_%H%M%S"; }
has_cmd(){ command -v "$1" >/dev/null 2>&1; }

### TOOL LIST (user-visible; add/remove as desired) ###
TOOLS=(
"whois"
"dig"
"curl"
"openssl"
"ping"
"whatweb"
"nmap"                  # intrusive
"masscan"               # intrusive
"netcat (nc)"
"ss (iproute2)"
"tcpdump"
"tshark (wireshark)"
"theHarvester"
"amass"
"subfinder"
"waybackurls"
"httprobe"
"shodan-cli"
"recon-ng"
"spiderfoot"
"metagoofil"
"nikto"                # intrusive (web)
"wpscan"
"sqlmap"               # intrusive (web)
"gobuster"             # intrusive (dir)
"ffuf"                 # intrusive (dir)
"dirb"
"zaproxy"
"mitmproxy"
"lynis"
"metasploit-framework"  # intrusive/potentially dangerous
"john"
"hashcat"
"hydra"                # intrusive
"aircrack-ng"
"kismet"
"ettercap"
"bettercap"
"ngrep"
"radare2"
"volatility"
"sleuthkit (autopsy)"
"yara"
"trivy"
"kube-bench"
"kube-hunter"
"suricata"
"snort"
"zeek"
"responder"
"impacket"
"crackmapexec"
"bloodhound"
"gophish"
"set (Social-Engineer Toolkit)"
"seclists (wordlists)"
"git"
"python3"
"go (golang)"
"docker"
"docker-compose"
)

# Intrusive tools list (string match)
INTRUSIVE_KEYS=( "nmap" "masscan" "nikto" "sqlmap" "gobuster" "ffuf" "hydra" "metasploit-framework" "crackmapexec" )

### HELPERS ###
ask_yes_no(){
  local prompt="$1"
  local default_no="${2:-1}"
  local ans
  while true; do
    if [ "$default_no" -eq 1 ]; then
      read -r -p "$(echo -e "${YELLOW}${prompt} [y/N]: ${NC}")" ans
    else
      read -r -p "$(echo -e "${YELLOW}${prompt} [Y/n]: ${NC}")" ans
    fi
    case "$ans" in
      [Yy]|[Yy][Ee][Ss]) return 0 ;;
      [Nn]|[Nn][Oo]) return 1 ;;
      "") if [ "$default_no" -eq 1 ]; then return 1; else return 0; fi ;;
    esac
  done
}

# Expand selection string like "1,3,5-8" into zero-based array SELECTED_IDX
expand_selection(){
  local sel="$1"
  SELECTED_IDX=()
  if [[ "${sel,,}" == "all" ]]; then
    for i in "${!TOOLS[@]}"; do SELECTED_IDX+=("$i"); done
    return
  fi
  IFS=',' read -ra parts <<< "$sel"
  for p in "${parts[@]}"; do
    if [[ "$p" =~ ^[0-9]+-[0-9]+$ ]]; then
      IFS='-' read -r a b <<< "$p"
      for ((i=a;i<=b;i++)); do SELECTED_IDX+=("$((i-1))"); done
    elif [[ "$p" =~ ^[0-9]+$ ]]; then
      SELECTED_IDX+=("$((p-1))")
    fi
  done
  # dedupe preserving order
  declare -A seen
  uniq=()
  for v in "${SELECTED_IDX[@]}"; do
    if [ -n "$v" ] && [ "$v" -ge 0 ] 2>/dev/null && [ "$v" -lt "${#TOOLS[@]}" ]; then
      if [ -z "${seen[$v]:-}" ]; then uniq+=("$v"); seen[$v]=1; fi
    fi
  done
  SELECTED_IDX=("${uniq[@]}")
}

detect_pkg_manager(){
  if has_cmd apt-get; then PKG="apt"; PKG_CMD="sudo apt-get update -y && sudo apt-get install -y"; return; fi
  if has_cmd dnf; then PKG="dnf"; PKG_CMD="sudo dnf install -y"; return; fi
  if has_cmd yum; then PKG="yum"; PKG_CMD="sudo yum install -y"; return; fi
  if has_cmd pacman; then PKG="pacman"; PKG_CMD="sudo pacman -Syu --noconfirm"; return; fi
  if has_cmd zypper; then PKG="zypper"; PKG_CMD="sudo zypper install -y"; return; fi
  if has_cmd apk; then PKG="apk"; PKG_CMD="sudo apk add"; return; fi
  PKG=""; PKG_CMD=""
}

# best-effort package mapping; empty means manual/pip/go suggested
pkg_for_tool(){
  local t="$1"
  case "$t" in
    whois) echo "whois" ;;
    dig) echo "dnsutils" ;;
    curl) echo "curl" ;;
    openssl) echo "openssl" ;;
    ping) echo "iputils-ping" ;;
    whatweb) echo "whatweb" ;;
    nmap) echo "nmap" ;;
    masscan) echo "masscan" ;;
    "netcat (nc)") echo "netcat" ;;
    "ss (iproute2)") echo "iproute2" ;;
    tcpdump) echo "tcpdump" ;;
    "tshark (wireshark)") echo "wireshark" ;;
    theHarvester) echo "theharvester" ;;
    amass) echo "amass" ;;
    subfinder) echo "" ;;
    waybackurls) echo "" ;;
    httprobe) echo "" ;;
    "shodan-cli") echo "" ;;
    "recon-ng") echo "recon-ng" ;;
    "spiderfoot") echo "spiderfoot" ;;
    "metagoofil") echo "metagoofil" ;;
    nikto) echo "nikto" ;;
    wpscan) echo "wpscan" ;;
    sqlmap) echo "sqlmap" ;;
    gobuster) echo "gobuster" ;;
    ffuf) echo "ffuf" ;;
    dirb*) echo "dirb" ;;
    zaproxy) echo "owasp-zap" ;;
    mitmproxy) echo "mitmproxy" ;;
    lynis) echo "lynis" ;;
    metasploit-framework) echo "metasploit-framework" ;;
    john) echo "john" ;;
    hashcat) echo "hashcat" ;;
    hydra) echo "hydra" ;;
    "aircrack-ng") echo "aircrack-ng" ;;
    kismet) echo "kismet" ;;
    ettercap*) echo "ettercap-common" ;;
    bettercap) echo "bettercap" ;;
    ngrep) echo "ngrep" ;;
    radare2) echo "radare2" ;;
    volatility) echo "volatility" ;;
    "sleuthkit (autopsy)") echo "sleuthkit autopsy" ;;
    yara) echo "yara" ;;
    trivy) echo "trivy" ;;
    kube-bench) echo "kube-bench" ;;
    kube-hunter) echo "kube-hunter" ;;
    suricata) echo "suricata" ;;
    snort) echo "snort" ;;
    zeek) echo "zeek" ;;
    responder) echo "responder" ;;
    impacket) echo "python3-impacket" ;;
    crackmapexec) echo "crackmapexec" ;;
    bloodhound) echo "" ;;
    gophish) echo "gophish" ;;
    "set (Social-Engineer Toolkit)") echo "set" ;;
    seclists) echo "seclists" ;;
    git) echo "git" ;;
    python3) echo "python3" ;;
    "go (golang)") echo "golang" ;;
    docker) echo "docker.io" ;;
    "docker-compose") echo "docker-compose" ;;
    *) echo "" ;;
  esac
}

try_install(){
  local pkg="$1"
  if [ -z "$PKG_CMD" ]; then
    echo -e "${RED}No supported package manager detected; cannot auto-install ${pkg}.${NC}"
    return 2
  fi
  echo -e "${CYAN}>>> Installing package(s): ${pkg} (via ${PKG})${NC}"
  if bash -c "$PKG_CMD $pkg"; then
    echo -e "${GREEN}[+] Installed: $pkg${NC}"
    return 0
  else
    echo -e "${RED}[-] Failed to install: $pkg${NC}"
    return 1
  fi
}

detect_terminal(){
  if has_cmd gnome-terminal; then TERMINAL_EMU="gnome-terminal"; return; fi
  if has_cmd xfce4-terminal; then TERMINAL_EMU="xfce4-terminal"; return; fi
  if has_cmd konsole; then TERMINAL_EMU="konsole"; return; fi
  if has_cmd xterm; then TERMINAL_EMU="xterm"; return; fi
  TERMINAL_EMU=""
}

term_launcher(){
  local inner="$1"
  case "$TERMINAL_EMU" in
    gnome-terminal) printf "gnome-terminal -- bash -c %q" "$inner; sleep $TERMINAL_POST_SLEEP" ;;
    xfce4-terminal) local q; q=$(printf "%q" "$inner; sleep $TERMINAL_POST_SLEEP"); printf "xfce4-terminal --command=\"bash -c %s\"" "$q" ;;
    konsole) printf "konsole -e bash -c %q" "$inner; sleep $TERMINAL_POST_SLEEP" ;;
    xterm) printf "xterm -e bash -c %q" "$inner; sleep $TERMINAL_POST_SLEEP" ;;
    *) return 1 ;;
  esac
}

banner_cmd(){
  if has_cmd figlet; then
    printf "clear; echo -e '%s'; figlet -w 200 'Xploit Terminal'; echo -e '%s';" "$MAGENTA" "$NC"
  elif has_cmd toilet; then
    printf "clear; echo -e '%s'; toilet -f mono12 -F metal 'Xploit Terminal' || true; echo -e '%s';" "$MAGENTA" "$NC"
  else
    printf "clear; echo -e '%s'; printf \"====================================================\\n\"; printf \"                X P L O I T   T E R M I N A L \\n\"; printf \"====================================================\\n\"; echo -e '%s';" "$MAGENTA" "$NC"
  fi
}

show_menu(){
  echo -e "${BOLD}${CYAN}Available tools (select by number). Example: 1,3,5-8 or 'all'${NC}"
  for i in "${!TOOLS[@]}"; do
    printf "%3d) %s\n" $((i+1)) "${TOOLS[i]}"
  done
  echo
}

### MAIN FLOW ###
clear
echo -e "${MAGENTA}"
if has_cmd figlet; then figlet -w 200 "Xploit Terminal"; else echo "======== Xploit Terminal ========"; fi
echo -e "${NC}"
echo -e "${BOLD}${CYAN}Interactive Xploit Terminal — select tools to run in separate terminals${NC}"
echo

# show menu and read selection
show_menu
read -r -p "$(echo -e "${YELLOW}Enter selection (numbers/ranges or 'all'): ${NC}")" USER_SEL
expand_selection "$USER_SEL"
if [ ${#SELECTED_IDX[@]} -eq 0 ]; then
  echo -e "${RED}No selection or invalid selection. Exiting.${NC}"
  exit 1
fi

# ask domain once
read -r -p "$(echo -e "${YELLOW}Enter target domain to use (e.g. example.com): ${NC}")" TARGET_DOMAIN
TARGET_DOMAIN=${TARGET_DOMAIN:-example.com}

detect_pkg_manager
detect_terminal

echo
echo -e "${CYAN}Selected ${#SELECTED_IDX[@]} tools. Target domain: ${BOLD}${TARGET_DOMAIN}${NC}"
echo -e "${CYAN}Output directory: ${BOLD}${OUTDIR_BASE}${NC}"
echo

# Pre-install missing tools (interactive)
echo -e "${BOLD}${BLUE}== Pre-check & install selected tools ==${NC}"
if [ -n "$PKG" ]; then
  echo -e "${GREEN}Detected package manager: $PKG${NC}"
else
  echo -e "${YELLOW}No supported package manager detected; manual installs may be necessary.${NC}"
fi
echo

for idx in "${SELECTED_IDX[@]}"; do
  tool="${TOOLS[idx]}"
  echo -e "${MAGENTA}Tool: ${BOLD}${tool}${NC}"
  pkgname="$(pkg_for_tool "$tool")"
  # approximate binary name for check
  prob_cmd="$(echo "$tool" | sed -E 's/[[:space:]]*\(.*\)//; s/ .*$//')"
  if has_cmd "$prob_cmd"; then
    echo -e "  ${GREEN}[+] ${prob_cmd} already available, skipping install.${NC}"
    continue
  fi
  if [ -n "$pkgname" ]; then
    if ask_yes_no "Install package '${pkgname}' (best-effort mapping) for '$tool' now?"; then
      try_install "$pkgname" || echo -e "${YELLOW}Manual install may be required for $tool.${NC}"
    else
      echo -e "${YELLOW}Skipping install for ${tool}.${NC}"
    fi
  else
    echo -e "  ${YELLOW}No automatic package mapping for ${tool}.${NC}"
    case "$tool" in
      *burpsuite*) echo "      Manual: download Burp Suite from https://portswigger.net/burp" ;;
      *ghidra*) echo "      Manual: download Ghidra from https://ghidra-sre.org/" ;;
      *subfinder*) echo "      Suggest: go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest" ;;
      *ffuf*) echo "      Suggest: go install github.com/ffuf/ffuf@latest" ;;
      *waybackurls*) echo "      Suggest: go install github.com/tomnomnom/waybackurls@latest" ;;
      *shodan*) echo "      Suggest: pip3 install shodan" ;;
      *) echo "      Please install $tool manually (project site / github)." ;;
    esac
    if ask_yes_no "After manual install, press y to re-check availability now?"; then
      echo "  Re-checking..."
      sleep 1
    else
      echo "  Continuing without installing $tool."
    fi
  fi
  echo
done

# Confirm intrusive tools
selected_intrusive=false
for idx in "${SELECTED_IDX[@]}"; do
  t="${TOOLS[idx]}"
  for ik in "${INTRUSIVE_KEYS[@]}"; do
    if [[ "$t" == "$ik" ]]; then selected_intrusive=true; fi
  done
done
if $selected_intrusive; then
  echo -e "${YELLOW}You selected at least one intrusive tool (nmap/masscan/nikto/sqlmap/gobuster/ffuf/hydra/msf/crackmapexec).${NC}"
  if ! ask_yes_no "Ensure you have WRITTEN permission to test the target. Proceed with intrusive tools?"; then
    newsel=()
    for idx in "${SELECTED_IDX[@]}"; do
      t="${TOOLS[idx]}"
      skip=false
      for ik in "${INTRUSIVE_KEYS[@]}"; do
        if [[ "$t" == "$ik" ]]; then skip=true; fi
      done
      if ! $skip; then newsel+=("$idx"); fi
    done
    SELECTED_IDX=("${newsel[@]}")
    echo -e "${YELLOW}Intrusive tools removed from selection.${NC}"
  fi
fi

# Launch selected tools in terminals
if [ ${#SELECTED_IDX[@]} -eq 0 ]; then
  echo -e "${RED}No tools selected to run. Exiting.${NC}"; exit 1
fi

if [ -z "$TERMINAL_EMU" ]; then
  echo -e "${RED}No supported GUI terminal emulator found (gnome-terminal/xfce4-terminal/konsole/xterm).${NC}"
  echo -e "${YELLOW}Install one or run commands manually. Exiting.${NC}"
  exit 1
fi

mkdir -p "$OUTDIR_BASE" "$OUTDIR_BASE/raw"
COMBINED="$OUTDIR_BASE/combined_report_header.txt"

echo -e "${BOLD}${GREEN}Launching terminals for selected tools...${NC}"
for idx in "${SELECTED_IDX[@]}"; do
  tool="${TOOLS[idx]}"
  safe_name="$(echo "$tool" | tr ' /()' '___' | tr -cd '[:alnum:]_-')"
  outfile="$OUTDIR_BASE/raw/${safe_name}.txt"

  # default safe/demo commands per tool (customize to your needs)
  case "$tool" in
    whois) cmd="whois ${TARGET_DOMAIN} 2>&1 | tee \"$outfile\"" ;;
    dig) cmd="dig +noall +answer ${TARGET_DOMAIN} 2>&1 | tee \"$outfile\"" ;;
    curl) cmd="curl -I --max-time 12 https://${TARGET_DOMAIN} 2>&1 | tee \"$outfile\"" ;;
    openssl) cmd="echo | openssl s_client -connect ${TARGET_DOMAIN}:443 -servername ${TARGET_DOMAIN} 2>/dev/null | openssl x509 -noout -subject -issuer -dates 2>&1 | tee \"$outfile\"" ;;
    ping) cmd="ping -c 4 ${TARGET_DOMAIN} 2>&1 | tee \"$outfile\"" ;;
    "whatweb") cmd="whatweb ${TARGET_DOMAIN} 2>&1 | tee \"$outfile\"" ;;
    nmap) cmd="nmap -Pn -sV -oN \"$outfile\" ${TARGET_DOMAIN} || true" ;;
    masscan) cmd="masscan -p1-65535 ${TARGET_DOMAIN} --rate=1000 --open 2>&1 | tee \"$outfile\" || true" ;;
    "netcat (nc)") cmd="echo 'Netcat (nc) — run manually for interactive sessions' | tee \"$outfile\"" ;;
    "ss (iproute2)") cmd="ss -tunap 2>&1 | tee \"$outfile\"" ;;
    tcpdump) cmd="tcpdump -c 50 -nn -i any 2>/dev/null | tee \"$outfile\"" ;;
    "tshark (wireshark)") cmd="tshark -c 50 -i any 2>/dev/null | tee \"$outfile\"" ;;
    theHarvester) cmd="theHarvester -d ${TARGET_DOMAIN} -b all 2>&1 | tee \"$outfile\"" ;;
    amass) cmd="amass enum -d ${TARGET_DOMAIN} 2>&1 | tee \"$outfile\"" ;;
    subfinder) cmd="subfinder -d ${TARGET_DOMAIN} -silent 2>&1 | tee \"$outfile\"" ;;
    waybackurls) cmd="echo 'Install waybackurls (go) then run: waybackurls ${TARGET_DOMAIN} > $outfile' | tee \"$outfile\"" ;;
    httprobe) cmd="echo 'httprobe requires URL list; run manually' | tee \"$outfile\"" ;;
    "shodan-cli") cmd="echo 'shodan-cli needs API key; run shodan info or shodan host <ip>' | tee \"$outfile\"" ;;
    "recon-ng") cmd="echo 'recon-ng is interactive; run recon-ng and use modules' | tee \"$outfile\"" ;;
    spiderfoot) cmd="echo 'spiderfoot runs a web UI; see docs' | tee \"$outfile\"" ;;
    metagoofil) cmd="metagoofil -d ${TARGET_DOMAIN} -t doc,pdf -l 200 -n 10 -o /tmp/metagoofil 2>&1 | tee \"$outfile\"" ;;
    nikto) cmd="nikto -h ${TARGET_DOMAIN} -output \"$outfile\" 2>&1 || true" ;;
    wpscan) cmd="wpscan --url https://${TARGET_DOMAIN} --no-update 2>&1 | tee \"$outfile\"" ;;
    sqlmap) cmd="echo 'sqlmap requires target URL & options; run manually' | tee \"$outfile\"" ;;
    gobuster) cmd="gobuster dir -u https://${TARGET_DOMAIN} -w /usr/share/wordlists/dirb/common.txt -o \"$outfile\" -t 20 || true" ;;
    ffuf) cmd="echo 'ffuf requires a wordlist; run manually with proper wordlist' | tee \"$outfile\"" ;;
    dirb*) cmd="dirb https://${TARGET_DOMAIN} 2>&1 | tee \"$outfile\"" ;;
    zaproxy) cmd="echo 'OWASP ZAP is GUI; use zap-baseline.py for automated scan' | tee \"$outfile\"" ;;
    mitmproxy) cmd="echo 'mitmproxy is interactive; use mitmdump for scripts' | tee \"$outfile\"" ;;
    lynis) cmd="lynis audit system 2>&1 | tee \"$outfile\"" ;;
    metasploit-framework) cmd="msfconsole -q -x 'version; exit' 2>&1 | tee \"$outfile\"" ;;
    john) cmd="echo 'john needs a hashfile; sample: john --test' | tee \"$outfile\"" ;;
    hashcat) cmd="echo 'hashcat is GPU-based; run with hash and rules' | tee \"$outfile\"" ;;
    hydra) cmd="echo 'hydra requires target/service/creds; run manually' | tee \"$outfile\"" ;;
    "aircrack-ng") cmd="echo 'aircrack-ng requires capture (.cap) file; run manually' | tee \"$outfile\"" ;;
    kismet) cmd="echo 'kismet is interactive; run kismet' | tee \"$outfile\"" ;;
    ettercap*) cmd="echo 'ettercap is interactive; run with proper options' | tee \"$outfile\"" ;;
    bettercap) cmd="echo 'bettercap is interactive; run with modules' | tee \"$outfile\"" ;;
    ngrep) cmd="ngrep -c 20 '' 2>/dev/null | tee \"$outfile\"" ;;
    radare2) cmd="echo 'radare2 is interactive; open files with r2' | tee \"$outfile\"" ;;
    volatility) cmd="echo 'volatility requires memory dump; run with appropriate profile' | tee \"$outfile\"" ;;
    "sleuthkit (autopsy)") cmd="echo 'Autopsy is GUI; use sleuthkit CLI (fls, mmls) for forensics' | tee \"$outfile\"" ;;
    yara) cmd="echo 'yara pattern usage: yara rules.y file' | tee \"$outfile\"" ;;
    trivy) cmd="trivy image --quiet alpine:latest 2>&1 | tee \"$outfile\"" ;;
    kube-bench) cmd="kube-bench run --json 2>&1 | tee \"$outfile\"" ;;
    kube-hunter) cmd="kube-hunter --remote ${TARGET_DOMAIN} 2>&1 | tee \"$outfile\" || true" ;;
    suricata) cmd="echo 'suricata is an IDS; configure and run with -c' | tee \"$outfile\"" ;;
    snort) cmd="echo 'snort is an IDS; run with configuration' | tee \"$outfile\"" ;;
    zeek) cmd="echo 'zeek is network analysis; run zeek -i eth0' | tee \"$outfile\"" ;;
    responder) cmd="echo 'responder requires network interface; use responsibly' | tee \"$outfile\"" ;;
    impacket) cmd="echo 'impacket has many scripts; run specific ones like impacket-smbclient' | tee \"$outfile\"" ;;
    crackmapexec) cmd="echo 'crackmapexec requires credentials/target; run manually' | tee \"$outfile\"" ;;
    bloodhound) cmd="echo 'BloodHound requires collection via SharpHound' | tee \"$outfile\"" ;;
    gophish) cmd="echo 'Gophish is a phishing platform; run gophish binary' | tee \"$outfile\"" ;;
    "set (Social-Engineer Toolkit)") cmd="setoolkit 2>&1 | tee \"$outfile\" || true" ;;
    seclists) cmd="ls -lah /usr/share/wordlists 2>&1 | tee \"$outfile\"" ;;
    git) cmd="git --version 2>&1 | tee \"$outfile\"" ;;
    python3) cmd="python3 --version 2>&1 | tee \"$outfile\"" ;;
    "go (golang)") cmd="go version 2>&1 | tee \"$outfile\"" ;;
    docker) cmd="docker --version 2>&1 | tee \"$outfile\"" ;;
    "docker-compose") cmd="docker-compose version 2>&1 | tee \"$outfile\"" ;;
    *) cmd="echo 'No default demo action for ${tool}; run it manually' | tee \"$outfile\"" ;;
  esac

  inner="$(banner_cmd) echo -e \"${CYAN}=== Running: ${tool} ===${NC}\"; echo; echo -e \"${YELLOW}Output file: ${outfile}${NC}\"; echo; ${cmd}; echo; echo -e \"${GREEN}Finished ${tool}. Output saved: ${outfile}${NC}\""
  launcher="$(term_launcher "$inner")" || { echo -e "${RED}Failed to prepare launcher for ${tool}${NC}"; continue; }

  echo -e "${BLUE}Launching: ${BOLD}${tool}${NC}"
  eval "${launcher} &" >/dev/null 2>&1 || echo -e "${RED}Failed to open terminal for ${tool}${NC}"
  sleep 0.12
done

# combined header report
{
  echo "Xploit Terminal - Combined Report Header"
  echo "Target: ${TARGET_DOMAIN}"
  echo "Timestamp: $(date -Iseconds)"
  echo ""
  echo "Tools launched:"
  for idx in "${SELECTED_IDX[@]}"; do
    echo " - ${TOOLS[idx]}"
  done
  echo ""
  echo "Raw outputs directory: ${OUTDIR_BASE}/raw"
} > "$COMBINED"

echo
echo -e "${GREEN}All requested terminals launched. Raw outputs are under: ${BOLD}${OUTDIR_BASE}/raw${NC}"
echo -e "${YELLOW}Terminals will auto-close ${TERMINAL_POST_SLEEP}s after each task finishes.${NC}"
echo -e "${MAGENTA}Xploit Terminal — stay ethical: only test authorized targets.${NC}"
