#!/usr/bin/env bash
# find_frontable.sh — colour-log, parallel ASN scanner (macOS Bash 3.2+)

set -euo pipefail

######################## 0 · option parsing ###################################
LOGLEVEL=info
POSITIONAL=()
while (( $# )); do
  case "$1" in
    --log=*) LOGLEVEL="${1#*=}" ; shift ;;
    --log)   LOGLEVEL="$2"      ; shift 2 ;;
    --)      shift; break ;;
    --*)     echo "Unknown option: $1" ; exit 1 ;;
    *)       POSITIONAL+=("$1") ; shift ;;
  esac
done
set -- "${POSITIONAL[@]}"

######################## 1 · globals ##########################################
RATE="${RATE:-50000}"
CORES=$(sysctl -n hw.ncpu 2>/dev/null || echo 2)
WORKDIR="$(mktemp -d)"
CIDRS="$WORKDIR/scan.cidrs" # Generic name since it might be multiple ASNs
SCAN="$WORKDIR/scan.scan"

# Interactive input for DECOY_FULL_URL
DECOY_FULL_URL=""
while true; do
  read -p "Enter the full decoy URL (e.g., https://test.something.something/ws?xxx): " USER_INPUT_URL
  if [[ -n "$USER_INPUT_URL" ]]; then
    DECOY_FULL_URL="$USER_INPUT_URL"
    break
  else
    log warn "Decoy URL cannot be empty. Please try again."
  fi
done

# Extract hostname and path from the full URL
DECOY_HOST=$(echo "$DECOY_FULL_URL" | sed -E 's|^https?://([^/]+).*|\1|')
DECOY_PATH=$(echo "$DECOY_FULL_URL" | sed -E 's|^https?://[^/]+(/.*)|\1|')
DECOY_PATH=${DECOY_PATH:-/} # Default to / if path is empty

# Interactive input for Internet Provider Name
INTERNET_PROVIDER=""
while true; do
  read -p "Enter a name for the Internet Provider (e.g., MyISP or Cloudflare): " USER_INPUT_PROVIDER
  if [[ -n "$USER_INPUT_PROVIDER" ]]; then
    # Sanitize the provider name for use in file paths
    INTERNET_PROVIDER=$(echo "$USER_INPUT_PROVIDER" | tr -cd '[:alnum:]_-')
    if [[ -z "$INTERNET_PROVIDER" ]]; then
      log warn "Sanitized provider name is empty. Please use alphanumeric, underscore, or hyphen characters."
    else
      break
    fi
  else
    log warn "Internet Provider Name cannot be empty. Please try again."
  fi
done

# Create the output directory based on provider name
OUTPUT_DIR="$(pwd)/output/$INTERNET_PROVIDER"
mkdir -p "$OUTPUT_DIR"

######################## 2 · globals ##########################################
WORKDIR="$(mktemp -d)"
CIDRS="$WORKDIR/scan.cidrs" # Generic name since it might be multiple ASNs
SCAN="$WORKDIR/scan.scan"

# Interactive ASN Selection
log info "Fetching available ASNs from ASNs.json…"
readarray -t ALL_ASNS < <(python3 py/checker.py)

if [[ ${#ALL_ASNS[@]} -eq 0 ]]; then
  log error "No ASNs found in py/ASNs.json. Please ensure the file exists and is correctly formatted."
  exit 1
fi

log info "Available ASNs:"
COUNTER=1
for ASN in "${ALL_ASNS[@]}"; do
  log info "  $COUNTER) $ASN"
  COUNTER=$((COUNTER+1))
done
log info "  Type 'all' to scan all ASNs."

ASN_INPUT=""
while true; do
  read -p "Enter a number to select an ASN, or 'all': " SELECTION
  if [[ "$SELECTION" == "all" ]]; then
    ASN_INPUT="all"
    break
  elif [[ "$SELECTION" =~ ^[0-9]+$ ]] && (( SELECTION > 0 && SELECTION <= ${#ALL_ASNS[@]} )); then
    ASN_INPUT="${ALL_ASNS[$((SELECTION-1))]}"
    break
  else
    log warn "Invalid selection. Please enter a valid number or 'all'."
  fi
done

if [[ "$ASN_INPUT" == "all" ]]; then
  OUTFILE="$OUTPUT_DIR/frontable-all_ASNs-$(date +%F).txt"
  LOGFILE="$OUTPUT_DIR/frontable-all_ASNs-$(date +%F).log"
else
  OUTFILE="$OUTPUT_DIR/frontable-$ASN_INPUT-$(date +%F).txt"
  LOGFILE="$OUTPUT_DIR/frontable-$ASN_INPUT-$(date +%F).log"
fi

######################## 2 · colour logger ####################################
if command -v tput >/dev/null; then
  NONE=$(tput sgr0);   RED=$(tput setaf 1);  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3); BLUE=$(tput setaf 4); GRAY=$(tput setaf 7)
else                                   # fallback ANSI if TERM is dumb
  NONE=$'\033[0m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; GRAY=$'\033[37m'
fi

level_val() { case $1 in debug)echo 0;; info)echo 1;; warn)echo 2;; error)echo 3;;
               success)echo 1;; *)echo 99;; esac; }

log() {                                # usage: log <level> <message>
  local lvl=$1; shift
  local need=$(level_val "$lvl") cur=$(level_val "$LOGLEVEL")
  (( need<cur )) && return
  local ts=$(date '+%F %T')
  local colour=$NONE
  case $lvl in debug) colour=$GRAY;; info) colour=$BLUE;;
       warn) colour=$YELLOW;; error) colour=$RED;; success) colour=$GREEN;; esac
  printf '%s%s %-7s%s : %s\n' "$colour" "$ts" "${lvl^^}" "$NONE" "$*"
}

exec > >(tee -a "$LOGFILE") 2>&1       # everything shown and logged
[[ $LOGLEVEL == debug ]] && set -x

######################## 3 · Ctrl-C handling ##################################
cleanup() {
  log info "🛑  Interrupt — stopping masscan…"
  sudo pkill -2 -f /masscan 2>/dev/null || true
  # Only remove WORKDIR, not the entire output directory
  rm -rf "$WORKDIR"
  exit 1
}
trap cleanup INT TERM

######################## 4 · Homebrew helper ##################################
# Dependency checks moved to install.sh
# [[ "$(uname -s)" == Darwin ]] || { echo "macOS only"; exit 1; }
# command -v brew >/dev/null 2>&1 || { echo "Install Homebrew → brew.sh"; exit 1; }
# need whois whois; need jq jq; need masscan masscan; need gtimeout coreutils; need openssl openssl@3

######################## 5 · dependency check #################################
# Removed: All dependency checks will be handled by install.sh

######################## 6 · fetch routed prefixes ############################
if [[ "$ASN_INPUT" == "all" ]]; then
  log info "📡  Fetching prefixes for all ASNs from ASNs.json …"
  ./py/checker.py > "$CIDRS"
else
  log info "📡  Fetching prefixes for $ASN_INPUT from ASNs.json …"
  ./py/checker.py "$ASN_INPUT" > "$CIDRS"
fi

log info "    → $(wc -l <"$CIDRS") CIDRs"

######################## 7 · masscan port 443 #################################
log info "🚀  masscan @${RATE}pps (sudo prompt follows)"
sudo -p "masscan needs root → " \
     masscan -iL "$CIDRS" -p443 --rate "$RATE" --banners -oL "$SCAN"

grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$SCAN" | sort -u > "$SCAN.ips"
log info "    → $(wc -l <"$SCAN.ips") hosts responded on 443"

######################## 8 · parallel TLS probe ###############################
log info "🔍  TLS handshakes in parallel ($CORES cores)…"
: > "$OUTFILE"

probe_one() {                           # $1 = IP address
  local ip=$1
  if gtimeout 4 openssl s_client -connect "$ip:443" -servername "$DECOY_HOST" \
         < /dev/null 2>/dev/null | grep -q "Server certificate"; then
    if gtimeout 4 curl --resolve "$DECOY_HOST:443:$ip" "$DECOY_FULL_URL" 2>/dev/null | grep -q "Bad Request"; then
      echo "$ip" >> "$OUTFILE"
      log success "✔︎ $ip"
    else
      log debug   "✘ $ip (TLS OK, but curl test failed)"
    fi
  else
    log debug   "✘ $ip (TLS handshake failed)"
  fi
}

export -f probe_one log level_val                      # functions only
export LOGLEVEL DECOY_FULL_URL DECOY_HOST DECOY_PATH OUTFILE NONE RED GREEN YELLOW BLUE GRAY  # Export new variables

# BSD xargs has -P but not -a → feed file via stdin
xargs -n1 -P "$CORES" -I{} bash -c 'probe_one "$@"' _ {} < "$SCAN.ips"

GOOD=$(wc -l <"$OUTFILE")
log success "✅  $GOOD frontable IPs saved → $OUTFILE"
log info    "📜  Full plain log: $LOGFILE"
rm -rf "$WORKDIR"
exit 0

