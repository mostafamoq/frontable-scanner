#!/usr/bin/env bash
# find_frontable_linux.sh — colour-log, parallel ASN scanner (Linux Bash)

set -euo pipefail

# Initialize LOGLEVEL with a default value
LOGLEVEL=info

######################## 2 · colour logger ####################################
if command -v tput >/dev/null; then
  NONE=$(tput sgr0);   RED=$(tput setaf 1);  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3); CYAN=$(tput setaf 6); GRAY=$(tput setaf 7)
else                                   # fallback ANSI if TERM is dumb
  NONE=$'\033[0m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; CYAN=$'\033[36m'; GRAY=$'\033[37m'
fi

level_val() { case $1 in debug)echo 0;; info)echo 1;; warn)echo 2;; error)echo 3;;
               success)echo 1;; *)echo 99;; esac; }

log() {                                # usage: log <level> <message>
  local lvl=$1; shift
  local need=$(level_val "$lvl") cur=$(level_val "$LOGLEVEL")
  (( need<cur )) && return
  local ts=$(date '+%F %T')
  local colour=$NONE
  case $lvl in debug) colour=$GRAY;; info) colour=$CYAN;;
       warn) colour=$YELLOW;; error) colour=$RED;; success) colour=$GREEN;; esac
  printf '%s%s %-7s%s : %s\n' "$colour" "$ts" "${lvl^^}" "$NONE" "$*"
}


######################## 3 · Ctrl-C handling ##################################
cleanup() {
  log info "🛑  Interrupt — stopping masscan…"
  sudo pkill -2 -f /masscan 2>/dev/null || true
  # Only remove WORKDIR, not the entire output directory
  rm -rf "$WORKDIR"
  exit 1
}
trap cleanup INT TERM

######################## 0 · option parsing ###################################
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
CORES=$(nproc 2>/dev/null || echo 2) # Use nproc for Linux
# For network I/O operations, we can use more parallel processes than CPU cores
# This is especially helpful on low-core VPS machines
if (( CORES <= 2 )); then
  PARALLEL_JOBS=20  # Use 20 parallel jobs on low-core machines
elif (( CORES <= 4 )); then
  PARALLEL_JOBS=30  # Use 30 parallel jobs on quad-core machines
else
  PARALLEL_JOBS=$((CORES * 8))  # Use 8x CPU cores on higher-end machines
fi

WORKDIR="$(mktemp -d)"
CIDRS="$WORKDIR/scan.cidrs" # Generic name since it might be multiple ASNs
SCAN="$WORKDIR/scan.scan"
OUTFILE="$WORKDIR/frontable.txt"  # Initialize with temporary paths
LOGFILE="$WORKDIR/frontable.log" # Initialize with temporary paths

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

# Interactive ASN Selection
log info "🔍 Loading ASN database..."
readarray -t ALL_ASNS < <(python3 ~/frontable-scanner/py/checker.py)

if [[ ${#ALL_ASNS[@]} -eq 0 ]]; then
  log error "No ASNs found in ~/frontable-scanner/py/ASNs.json. Please ensure the file exists and is correctly formatted."
  exit 1
fi

# Define popular ASNs (most commonly used for domain fronting)
POPULAR_ASNS=(
  "AS13335 Cloudflare, Inc."
  "AS16509 Amazon.com, Inc."
  "AS15169 Google LLC"
  "AS8075 Microsoft Corporation"
  "AS32934 Facebook, Inc."
  "AS20940 Akamai International B.V."
  "AS2906 Netflix, Inc."
  "AS16625 Akamai Technologies, Inc."
  "AS54113 Fastly"
  "AS19527 Google LLC"
  "AS14618 Amazon.com, Inc."
  "AS396982 Google LLC"
  "AS8987 Amazon Data Services UK"
  "AS16591 Google Fiber Inc."
  "AS36040 YouTube LLC"
)

# Filter popular ASNs that actually exist in our data
AVAILABLE_POPULAR=()
for popular in "${POPULAR_ASNS[@]}"; do
  for asn in "${ALL_ASNS[@]}"; do
    if [[ "$asn" == "$popular" ]]; then
      AVAILABLE_POPULAR+=("$asn")
      break
    fi
  done
done

ASN_INPUT=""
while true; do
  echo ""
  printf "${GREEN}🔥 Popular ASNs (commonly used for domain fronting):${NONE}\n"
  COUNTER=1
  for ASN in "${AVAILABLE_POPULAR[@]}"; do
    printf "${CYAN}  %d) ${GREEN}%s${NONE}\n" "$COUNTER" "$ASN"
    COUNTER=$((COUNTER+1))
  done
  
  echo ""
  printf "${YELLOW}Options:${NONE}\n"
  printf "${CYAN}  • Enter ${GREEN}1-${#AVAILABLE_POPULAR[@]}${CYAN} to select a popular ASN${NONE}\n"
  printf "${CYAN}  • Type ${GREEN}'search'${CYAN} to search all ${GREEN}${#ALL_ASNS[@]}${CYAN} ASNs by keyword${NONE}\n"
  printf "${CYAN}  • Type ${GREEN}'all'${CYAN} to scan all ASNs${NONE}\n"
  echo ""
  
  read -p "Your choice: " SELECTION
  
  # Check if it's a number for popular ASNs
  if [[ "$SELECTION" =~ ^[0-9]+$ ]] && (( SELECTION > 0 && SELECTION <= ${#AVAILABLE_POPULAR[@]} )); then
    # Extract just the ASN ID (e.g., "AS16509" from "AS16509 Amazon.com, Inc.")
    ASN_INPUT=$(echo "${AVAILABLE_POPULAR[$((SELECTION-1))]}" | awk '{print $1}')
    log info "${GREEN}Selected: ${AVAILABLE_POPULAR[$((SELECTION-1))]}"
    break
  elif [[ "$SELECTION" == "all" ]]; then
    ASN_INPUT="all"
    log info "${GREEN}Selected: All ASNs"
    break
  elif [[ "$SELECTION" == "search" ]]; then
    # Enter search mode
    while true; do
      echo ""
      read -p "🔍 Enter keywords to search ASNs (or 'back' to return): " SEARCH_TERM
      
      if [[ "$SEARCH_TERM" == "back" ]]; then
        break  # Go back to main menu
      elif [[ -z "$SEARCH_TERM" ]]; then
        log warn "Please enter a search term."
        continue
      fi
      
      # Search for matching ASNs (case-insensitive)
      SEARCH_RESULTS=()
      for asn in "${ALL_ASNS[@]}"; do
        if [[ "${asn,,}" == *"${SEARCH_TERM,,}"* ]]; then
          SEARCH_RESULTS+=("$asn")
        fi
      done
      
      if [[ ${#SEARCH_RESULTS[@]} -eq 0 ]]; then
        log warn "No ASNs found matching '$SEARCH_TERM'. Try different keywords."
        continue
      fi
      
      echo ""
      printf "${GREEN}Found ${#SEARCH_RESULTS[@]} ASNs matching '${YELLOW}$SEARCH_TERM${GREEN}':${NONE}\n"
      COUNTER=1
      for result in "${SEARCH_RESULTS[@]}"; do
        printf "${CYAN}  %d) ${GREEN}%s${NONE}\n" "$COUNTER" "$result"
        COUNTER=$((COUNTER+1))
        # Limit display to first 20 results to avoid overwhelming output
        if (( COUNTER > 20 )); then
          printf "${GRAY}  ... and $((${#SEARCH_RESULTS[@]} - 20)) more results${NONE}\n"
          break
        fi
      done
      
      read -p "Enter number to select, 'refine' to search again, or 'back': " SEARCH_SELECTION
      
      if [[ "$SEARCH_SELECTION" == "back" ]]; then
        break  # Go back to main menu
      elif [[ "$SEARCH_SELECTION" == "refine" ]]; then
        continue  # Search again
      elif [[ "$SEARCH_SELECTION" =~ ^[0-9]+$ ]] && (( SEARCH_SELECTION > 0 && SEARCH_SELECTION <= ${#SEARCH_RESULTS[@]} && SEARCH_SELECTION <= 20 )); then
        # Extract just the ASN ID
        ASN_INPUT=$(echo "${SEARCH_RESULTS[$((SEARCH_SELECTION-1))]}" | awk '{print $1}')
        log info "${GREEN}Selected: ${SEARCH_RESULTS[$((SEARCH_SELECTION-1))]}"
        break 2  # Break out of both search loop and main loop
      else
        log warn "Invalid selection. Please enter a valid number, 'refine', or 'back'."
      fi
    done
  else
    log warn "Invalid selection. Please try again."
  fi
done

if [[ "$ASN_INPUT" == "all" ]]; then
  OUTFILE="$OUTPUT_DIR/frontable-all_ASNs-$(date +%F).txt"
  LOGFILE="$OUTPUT_DIR/frontable-all_ASNs-$(date +%F).log"
else
  OUTFILE="$OUTPUT_DIR/frontable-$ASN_INPUT-$(date +%F).txt"
  LOGFILE="$OUTPUT_DIR/frontable-$ASN_INPUT-$(date +%F).log"
fi
# PATH variable removed; install.sh handles it

# Now that LOGFILE is set, redirect all output to log file
exec > >(tee -a "$LOGFILE") 2>&1

# Activate debug mode after logging setup is complete
[[ $LOGLEVEL == debug ]] && set -x

######################## 4 · Dependency helper (Linux) ######################
# Dependency checks moved to install.sh
# need() {
#   local cmd=$1
#   local pkg_apt=$2 # Package name for apt
#   local pkg_dnf=$3 # Package name for dnf (often same as yum)
#   local pkg_yum=$4 # Package name for yum (often same as dnf)
# 
#   if ! command -v "$cmd" >/dev/null 2>&1; then
#     log info "🔧  Installing $cmd …"
#     if command -v apt-get >/dev/null 2>&1; then
#       sudo apt-get update >/dev/null && sudo apt-get install -y "$pkg_apt" >/dev/null
#     elif command -v dnf >/dev/null 2>&1; then
#       sudo dnf install -y "$pkg_dnf" >/dev/null
#     elif command -v yum >/dev/null 2>&1; then
#       sudo yum install -y "$pkg_yum" >/dev/null
#     else
#       log error "❌  Error: $cmd not found. Please install it manually using your distribution's package manager."
#       exit 1
#     fi
# 
#     # Verify installation after attempting
#     if ! command -v "$cmd" >/dev/null 2>&1; then
#       log error "❌  Error: Failed to install $cmd. Please install it manually."
#       exit 1
#     fi
#   fi
# }

######################## 5 · dependency check #################################
# Removed: All dependency checks will be handled by install.sh

######################## 6 · fetch routed prefixes ############################
if [[ "$ASN_INPUT" == "all" ]]; then
  log info "${CYAN}📡 Fetching prefixes for ${GREEN}all ASNs${CYAN}..."
  python3 ~/frontable-scanner/py/checker.py --cidrs > "$CIDRS"
else
  log info "${CYAN}📡 Fetching prefixes for ${GREEN}$ASN_INPUT${CYAN}..."
  python3 ~/frontable-scanner/py/checker.py "$ASN_INPUT" > "$CIDRS"
fi

log info "${GREEN}Found ${YELLOW}$(wc -l <"$CIDRS")${GREEN} CIDR ranges"

######################## 7 · masscan port 443 #################################
log info "${CYAN}🚀 Scanning ports ${GRAY}(rate: ${YELLOW}${RATE}pps${GRAY})${CYAN}..."
sudo -p "masscan needs root → " \
     masscan -iL "$CIDRS" -p443 --rate "$RATE" --banners -oL "$SCAN"

grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$SCAN" | sort -u > "$SCAN.ips"
log info "${GREEN}Found ${YELLOW}$(wc -l <"$SCAN.ips")${GREEN} hosts with port 443 open"

######################## 8 · parallel TLS probe ###############################
log info "${CYAN}🔍 Testing IPs for domain fronting ${GRAY}(${YELLOW}${PARALLEL_JOBS}${GRAY} parallel jobs)${CYAN}..."
: > "$OUTFILE"

probe_one() {                           # $1 = IP address
  local ip=$1
  if timeout 4 openssl s_client -connect "$ip:443" -servername "$DECOY_HOST" \
         < /dev/null 2>/dev/null | grep -q "Server certificate"; then
    if timeout 4 curl --resolve "$DECOY_HOST:443:$ip" "$DECOY_FULL_URL" 2>/dev/null | grep -q "Bad Request"; then
      echo "$ip" >> "$OUTFILE"
      log info "${GREEN}✔︎ $ip"
    else
      log info "${RED}✘ $ip ${GRAY}(TLS OK, but curl test failed)"
    fi
  else
    log info "${RED}✘ $ip ${GRAY}(TLS handshake failed)"
  fi
}

export -f probe_one log level_val                      # functions only
export LOGLEVEL DECOY_FULL_URL DECOY_HOST DECOY_PATH OUTFILE NONE RED GREEN YELLOW CYAN GRAY  # Export new variables

# Use PARALLEL_JOBS instead of CORES for better performance on network I/O
xargs -n1 -P "$PARALLEL_JOBS" -I{} bash -c 'probe_one "$@"' _ {} < "$SCAN.ips"

GOOD=$(wc -l <"$OUTFILE")
log info "${GREEN}✅ Scan complete! Found ${YELLOW}$GOOD${GREEN} working IPs"
log info "${CYAN}📁 Results saved: ${GREEN}$OUTFILE"
log debug "📜 Full log: $LOGFILE"
rm -rf "$WORKDIR"
exit 0 