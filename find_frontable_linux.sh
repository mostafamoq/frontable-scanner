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

# Interactive protocol selection
PROTOCOL_TYPE=""
while true; do
  echo ""
  printf "${GREEN}🔌 Select the target protocol:${NONE}\n"
  printf "${CYAN}  1) ${GREEN}WebSocket (WS)${CYAN} - Traditional WebSocket connections${NONE}\n"
  printf "${CYAN}  2) ${GREEN}XHTTP${CYAN} - HTTP/2 multiplexing protocol${NONE}\n"
  echo ""
  
  read -p "Your choice (1-2): " PROTOCOL_CHOICE
  
  case "$PROTOCOL_CHOICE" in
    1)
      PROTOCOL_TYPE="ws"
      log info "${GREEN}Selected: WebSocket (WS) protocol"
      break
      ;;
    2)
      PROTOCOL_TYPE="xhttp"
      log info "${GREEN}Selected: XHTTP protocol"
      break
      ;;
    *)
      log warn "Invalid selection. Please enter 1 or 2."
      ;;
  esac
done

# Extract hostname and path from the full URL
DECOY_HOST=$(echo "$DECOY_FULL_URL" | sed -E 's|^https?://([^/]+).*|\1|')
DECOY_PATH=$(echo "$DECOY_FULL_URL" | sed -E 's|^https?://[^/]+(/.*)|\1|')
DECOY_PATH=${DECOY_PATH:-/} # Default to / if path is empty

# Extract port from URL or use default
if [[ "$DECOY_FULL_URL" =~ ^https://[^:/]+:([0-9]+) ]]; then
  DECOY_PORT="${BASH_REMATCH[1]}"
elif [[ "$DECOY_FULL_URL" =~ ^http://[^:/]+:([0-9]+) ]]; then
  DECOY_PORT="${BASH_REMATCH[1]}"
elif [[ "$DECOY_FULL_URL" =~ ^https:// ]]; then
  DECOY_PORT="443"  # Default HTTPS port
elif [[ "$DECOY_FULL_URL" =~ ^http:// ]]; then
  DECOY_PORT="80"   # Default HTTP port
else
  DECOY_PORT="443"  # Fallback default
fi

# Remove port from hostname if it was included
DECOY_HOST=$(echo "$DECOY_HOST" | sed -E 's|:[0-9]+$||')

log info "🎯 Target: ${GREEN}$DECOY_HOST:$DECOY_PORT${NONE} → ${YELLOW}$DECOY_PATH${NONE}"

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
# Main ASN list pagination
page_size=20
current_page=1
total_pages=$(( (${#ALL_ASNS[@]} + page_size - 1) / page_size ))

while true; do
  echo ""
  printf "${GREEN}🌐 ASN List (Page ${YELLOW}$current_page${GREEN}/${YELLOW}$total_pages${GREEN}):${NONE}\n"
  
  # Calculate start and end indices for current page
  start_idx=$(( (current_page - 1) * page_size ))
  end_idx=$(( start_idx + page_size - 1 ))
  if (( end_idx >= ${#ALL_ASNS[@]} )); then
    end_idx=$(( ${#ALL_ASNS[@]} - 1 ))
  fi
  
  # Display current page results
  for i in $(seq $start_idx $end_idx); do
    display_num=$(( i + 1 ))
    asn="${ALL_ASNS[$i]}"
    
    # Highlight popular ASNs
    is_popular=false
    for popular in "${AVAILABLE_POPULAR[@]}"; do
      if [[ "$asn" == "$popular" ]]; then
        is_popular=true
        break
      fi
    done
    
    if [[ "$is_popular" == true ]]; then
      printf "${CYAN}  %d) ${GREEN}%s ${YELLOW}🔥${NONE}\n" "$display_num" "$asn"
    else
      printf "${CYAN}  %d) ${GREEN}%s${NONE}\n" "$display_num" "$asn"
    fi
  done
  
  echo ""
  printf "${YELLOW}Navigation:${NONE}\n"
  if (( current_page > 1 )); then
    printf "${CYAN}  • Type ${GREEN}'p'${CYAN} for previous page${NONE}\n"
  fi
  if (( current_page < total_pages )); then
    printf "${CYAN}  • Type ${GREEN}'n'${CYAN} for next page${NONE}\n"
  fi
  if (( total_pages > 1 )); then
    printf "${CYAN}  • Type ${GREEN}'l'${CYAN} for last page${NONE}\n"
    printf "${CYAN}  • Type ${GREEN}'g'${CYAN} followed by page number (e.g., 'g3') to go to specific page${NONE}\n"
  fi
  printf "${CYAN}  • Enter ${GREEN}1-${#ALL_ASNS[@]}${CYAN} to select an ASN${NONE}\n"
  printf "${CYAN}  • Type ${GREEN}'search'${CYAN} to search ASNs by keyword${NONE}\n"
  echo ""
  
  read -p "Your choice: " SELECTION
  
  # Handle navigation
  if [[ "$SELECTION" == "n" ]] && (( current_page < total_pages )); then
    current_page=$((current_page + 1))
  elif [[ "$SELECTION" == "p" ]] && (( current_page > 1 )); then
    current_page=$((current_page - 1))
  elif [[ "$SELECTION" == "l" ]] && (( total_pages > 1 )); then
    current_page=$total_pages
  elif [[ "$SELECTION" =~ ^g([0-9]+)$ ]]; then
    target_page="${BASH_REMATCH[1]}"
    if (( target_page >= 1 && target_page <= total_pages )); then
      current_page=$target_page
    else
      printf "${RED}Invalid page number. Please enter a page between 1 and $total_pages.${NONE}\n"
      read -p "Press Enter to continue..."
    fi
  elif [[ "$SELECTION" =~ ^[0-9]+$ ]] && (( SELECTION > 0 && SELECTION <= ${#ALL_ASNS[@]} )); then
    # Extract just the ASN ID
    ASN_INPUT=$(echo "${ALL_ASNS[$((SELECTION-1))]}" | awk '{print $1}')
    log info "${GREEN}Selected: ${ALL_ASNS[$((SELECTION-1))]}"
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
      
      # Pagination for search results
      search_page_size=20
      search_current_page=1
      search_total_pages=$(( (${#SEARCH_RESULTS[@]} + search_page_size - 1) / search_page_size ))
      
      while true; do
        echo ""
        printf "${GREEN}Found ${#SEARCH_RESULTS[@]} ASNs matching '${YELLOW}$SEARCH_TERM${GREEN}' (Page ${YELLOW}$search_current_page${GREEN}/${YELLOW}$search_total_pages${GREEN}):${NONE}\n"
        
        # Calculate start and end indices for current page
        search_start_idx=$(( (search_current_page - 1) * search_page_size ))
        search_end_idx=$(( search_start_idx + search_page_size - 1 ))
        if (( search_end_idx >= ${#SEARCH_RESULTS[@]} )); then
          search_end_idx=$(( ${#SEARCH_RESULTS[@]} - 1 ))
        fi
        
        # Display current page results
        for i in $(seq $search_start_idx $search_end_idx); do
          search_display_num=$(( i + 1 ))
          printf "${CYAN}  %d) ${GREEN}%s${NONE}\n" "$search_display_num" "${SEARCH_RESULTS[$i]}"
        done
        
        # Show navigation options
        echo ""
        printf "${YELLOW}Navigation:${NONE}\n"
        if (( search_current_page > 1 )); then
          printf "${CYAN}  • Type ${GREEN}'p'${CYAN} for previous page${NONE}\n"
        fi
        if (( search_current_page < search_total_pages )); then
          printf "${CYAN}  • Type ${GREEN}'n'${CYAN} for next page${NONE}\n"
        fi
        if (( search_total_pages > 1 )); then
          printf "${CYAN}  • Type ${GREEN}'l'${CYAN} for last page${NONE}\n"
          printf "${CYAN}  • Type ${GREEN}'g'${CYAN} followed by page number (e.g., 'g3') to go to specific page${NONE}\n"
        fi
        printf "${CYAN}  • Enter ${GREEN}1-${#SEARCH_RESULTS[@]}${CYAN} to select an ASN${NONE}\n"
        printf "${CYAN}  • Type ${GREEN}'refine'${CYAN} to search again${NONE}\n"
        printf "${CYAN}  • Type ${GREEN}'back'${CYAN} to return to main menu${NONE}\n"
        
        read -p "Your choice: " SEARCH_SELECTION
        
        if [[ "$SEARCH_SELECTION" == "back" ]]; then
          break  # Go back to main menu
        elif [[ "$SEARCH_SELECTION" == "refine" ]]; then
          break  # Search again
        elif [[ "$SEARCH_SELECTION" == "n" ]] && (( search_current_page < search_total_pages )); then
          search_current_page=$((search_current_page + 1))
        elif [[ "$SEARCH_SELECTION" == "p" ]] && (( search_current_page > 1 )); then
          search_current_page=$((search_current_page - 1))
        elif [[ "$SEARCH_SELECTION" == "l" ]] && (( search_total_pages > 1 )); then
          search_current_page=$search_total_pages
        elif [[ "$SEARCH_SELECTION" =~ ^g([0-9]+)$ ]]; then
          search_target_page="${BASH_REMATCH[1]}"
          if (( search_target_page >= 1 && search_target_page <= search_total_pages )); then
            search_current_page=$search_target_page
          else
            printf "${RED}Invalid page number. Please enter a page between 1 and $search_total_pages.${NONE}\n"
            read -p "Press Enter to continue..."
          fi
        elif [[ "$SEARCH_SELECTION" =~ ^[0-9]+$ ]] && (( SEARCH_SELECTION > 0 && SEARCH_SELECTION <= ${#SEARCH_RESULTS[@]} )); then
          # Extract just the ASN ID
          ASN_INPUT=$(echo "${SEARCH_RESULTS[$((SEARCH_SELECTION-1))]}" | awk '{print $1}')
          log info "${GREEN}Selected: ${SEARCH_RESULTS[$((SEARCH_SELECTION-1))]}"
          break 2  # Break out of both search loop and main loop
        else
          log warn "Invalid selection. Please try again."
        fi
      done
    done
    # Check if ASN was selected during search
    if [[ -n "$ASN_INPUT" ]]; then
      break  # Exit main loop
    fi
  else
    log warn "Invalid selection. Please try again."
  fi
done

OUTFILE="$OUTPUT_DIR/frontable-$ASN_INPUT-$(date +%F).txt"
LOGFILE="$OUTPUT_DIR/frontable-$ASN_INPUT-$(date +%F).log"
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
log info "${CYAN}📡 Fetching prefixes for ${GREEN}$ASN_INPUT${CYAN}..."
python3 ~/frontable-scanner/py/checker.py "$ASN_INPUT" > "$CIDRS"

log info "${GREEN}Found ${YELLOW}$(wc -l <"$CIDRS")${GREEN} CIDR ranges"

######################## 7 · masscan port scan ###################################
log info "${CYAN}🚀 Scanning port ${GREEN}$DECOY_PORT${CYAN} ${GRAY}(rate: ${YELLOW}${RATE}pps${GRAY})${CYAN}..."
sudo -p "masscan needs root → " \
     masscan -iL "$CIDRS" -p"$DECOY_PORT" --rate "$RATE" --banners -oL "$SCAN"

grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' "$SCAN" | sort -u > "$SCAN.ips"
log info "${GREEN}Found ${YELLOW}$(wc -l <"$SCAN.ips")${GREEN} hosts with port ${YELLOW}$DECOY_PORT${GREEN} open"

######################## 8 · parallel TLS probe ###############################
log info "${CYAN}🔍 Testing IPs for ${GREEN}$PROTOCOL_TYPE${CYAN} domain fronting ${GRAY}(${YELLOW}${PARALLEL_JOBS}${GRAY} parallel jobs)${CYAN}..."
: > "$OUTFILE"

probe_one() {                           # $1 = IP address
  local ip=$1
  
  # First check TLS handshake
  if timeout 4 openssl s_client -connect "$ip:$DECOY_PORT" -servername "$DECOY_HOST" \
         < /dev/null 2>/dev/null | grep -q "Server certificate"; then
    
    # Protocol-specific testing
    if [[ "$PROTOCOL_TYPE" == "ws" ]]; then
      # WebSocket test - expect "Bad Request" for non-WebSocket HTTP requests
      if timeout 4 curl --resolve "$DECOY_HOST:$DECOY_PORT:$ip" "$DECOY_FULL_URL" 2>/dev/null | grep -q "Bad Request"; then
        echo "$ip" >> "$OUTFILE"
        log info "${GREEN}✔︎ $ip ${GRAY}(WebSocket fronting works)"
      else
        log info "${RED}✘ $ip ${GRAY}(TLS OK, but WebSocket test failed)"
      fi
    elif [[ "$PROTOCOL_TYPE" == "xhttp" ]]; then
      # XHTTP test - more comprehensive detection
      local curl_output=$(timeout 6 curl -s -w "HTTPCODE:%{http_code}|TIME:%{time_total}|SIZE:%{size_download}" \
                         --http2 --resolve "$DECOY_HOST:$DECOY_PORT:$ip" \
                         -H "Host: $DECOY_HOST" \
                         -H "User-Agent: Chrome/120.0.0.0" \
                         -H "Accept: */*" \
                         -H "Accept-Encoding: gzip, deflate, br" \
                         "$DECOY_FULL_URL" 2>&1 || echo "ERROR")
      
      # Extract HTTP code from output
      local http_code="000"
      if [[ "$curl_output" =~ HTTPCODE:([0-9]+) ]]; then
        http_code="${BASH_REMATCH[1]}"
      fi
      
      # For XHTTP, any valid HTTP response code indicates working fronting
      # Valid codes: 200, 400, 401, 403, 404, 405, 500, etc.
      # These all prove the server is reachable and responding through the fronting path
      
      if [[ "$http_code" =~ ^[1-5][0-9][0-9]$ ]]; then
        # Got a valid HTTP response code (1xx, 2xx, 3xx, 4xx, 5xx)
        echo "$ip" >> "$OUTFILE"
        log info "${GREEN}✔︎ $ip ${GRAY}(XHTTP fronting works, HTTP $http_code)"
      else
        # Connection failed - no valid HTTP response
        log info "${RED}✘ $ip ${GRAY}(TLS OK, but XHTTP connection failed - code: $http_code)"
      fi
    fi
  else
    log info "${RED}✘ $ip ${GRAY}(TLS handshake failed)"
  fi
}

export -f probe_one log level_val                      # functions only
export LOGLEVEL DECOY_FULL_URL DECOY_HOST DECOY_PATH DECOY_PORT OUTFILE NONE RED GREEN YELLOW CYAN GRAY PROTOCOL_TYPE  # Export new variables

# Use PARALLEL_JOBS instead of CORES for better performance on network I/O
xargs -n1 -P "$PARALLEL_JOBS" -I{} bash -c 'probe_one "$@"' _ {} < "$SCAN.ips"

GOOD=$(wc -l <"$OUTFILE")
log info "${GREEN}✅ Scan complete! Found ${YELLOW}$GOOD${GREEN} working IPs"
log info "${CYAN}📁 Results saved: ${GREEN}$OUTFILE"
log debug "📜 Full log: $LOGFILE"
rm -rf "$WORKDIR"
exit 0 