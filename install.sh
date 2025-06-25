#!/usr/bin/env bash
# install.sh - Comprehensive installer for the Domain Fronting IP Scanner

set -euo pipefail

# --- Configuration Variables ---
INSTALL_DIR="$HOME/frontable-scanner"
# !!! IMPORTANT: Replace with your actual GitHub raw content URL !!!
GITHUB_RAW_BASE_URL="YOUR_GITHUB_REPO_RAW_URL"

# --- Logging Function ---
log() {
  echo "$(date '+%F %T') INFO : $*"
}

# --- Dependency Installation Function ---
need_dependency() {
  local cmd=$1
  local pkg_macos=$2 # Homebrew package name
  local pkg_apt=$3   # apt package name
  local pkg_dnf=$4   # dnf/yum package name

  if command -v "$cmd" >/dev/null 2>&1; then
    log "✔︎ $cmd is already installed."
    return 0
  fi

  log "🔧 Installing $cmd …"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    if command -v brew >/dev/null 2>&1; then
      sudo -u "${SUDO_USER:-$USER}" brew install "$pkg_macos" >/dev/null
    else
      log "ERROR: Homebrew not found. Please install Homebrew (brew.sh) and try again, or install $cmd manually."
      exit 1
    fi
  elif [[ "$(uname -s)" == "Linux" ]]; then
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get update >/dev/null && sudo apt-get install -y "$pkg_apt" >/dev/null
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y "$pkg_dnf" >/dev/null
    elif command -v yum >/dev/null 2>&1; then
      sudo yum install -y "$pkg_dnf" >/dev/null # dnf and yum often use same package names
    else
      log "ERROR: No supported package manager (apt, dnf, yum) found. Please install $cmd manually."
      exit 1
    fi
  else
    log "ERROR: Unsupported OS for automatic dependency installation. Please install $cmd manually."
    exit 1
  fi

  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: Failed to install $cmd. Please install it manually."
    exit 1
  fi
  log "✔︎ $cmd installed successfully."
}

# --- Main Installation Logic ---
log "Starting Domain Fronting IP Scanner installation…"

# Check if running as root initially (masscan will need sudo later)
if [[ "$EUID" -eq 0 ]]; then
  log "WARNING: Running install.sh as root. This is generally not recommended unless you understand the implications."
  log "Consider running with a regular user and using sudo when prompted."
fi

# 1. Install Dependencies
log "Checking and installing required dependencies…"
need_dependency "whois" "whois" "whois" "whois"
need_dependency "jq" "jq" "jq" "jq"
need_dependency "masscan" "masscan" "masscan" "masscan" # Note: masscan typically needs manual compilation or specific repo on Linux
need_dependency "openssl" "openssl" "openssl" "openssl"
need_dependency "curl" "curl" "curl" "curl"

# Timeout utility differs
if [[ "$(uname -s)" == "Darwin" ]]; then
  need_dependency "gtimeout" "coreutils" "timeout" "timeout" # gtimeout from coreutils on macOS
else
  need_dependency "timeout" "coreutils" "coreutils" "coreutils" # timeout is part of coreutils on Linux
fi

# Python 3 is assumed for py/checker.py
if ! command -v python3 >/dev/null 2>&1; then
  log "ERROR: Python 3 not found. Please install Python 3 manually (e.g., sudo apt install python3)."
  exit 1
fi
log "✔︎ Python 3 found."

# 2. Create Installation Directory
log "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR/py"
log "✔︎ Directory created."

# 3. Download Scripts and Data
log "Downloading scripts and data from GitHub…"

# Check if GITHUB_RAW_BASE_URL is a placeholder
if [[ "$GITHUB_RAW_BASE_URL" == "YOUR_GITHUB_REPO_RAW_URL" ]]; then
  log "ERROR: GITHUB_RAW_BASE_URL is a placeholder. Please edit install.sh and set it to your actual GitHub raw content URL."
  exit 1
fi

curl -Ls "$GITHUB_RAW_BASE_URL/find_frontable.sh" -o "$INSTALL_DIR/find_frontable.sh"
curl -Ls "$GITHUB_RAW_BASE_URL/find_frontable_linux.sh" -o "$INSTALL_DIR/find_frontable_linux.sh"
curl -Ls "$GITHUB_RAW_BASE_URL/py/checker.py" -o "$INSTALL_DIR/py/checker.py"
curl -Ls "$GITHUB_RAW_BASE_URL/py/ASNs.json" -o "$INSTALL_DIR/py/ASNs.json"
log "✔︎ Files downloaded."

# 4. Make Scripts Executable
log "Making scripts executable…"
chmod +x "$INSTALL_DIR/find_frontable.sh"
chmod +x "$INSTALL_DIR/find_frontable_linux.sh"
chmod +x "$INSTALL_DIR/py/checker.py"
log "✔︎ Scripts are executable."

# 5. Offer to create a persistent command
log "
Optional: Create a 'frontable' command for easy access.
This will allow you to run the scanner by simply typing 'frontable' in your terminal."
read -p "Do you want to set up the 'frontable' command? (y/N): " CREATE_COMMAND
if [[ "$CREATE_COMMAND" =~ ^[Yy]$ ]]; then
  log "Setting up 'frontable' command…"
  if [[ "$(uname -s)" == "Darwin" || "$(uname -s)" == "Linux" ]]; then
    # Try creating a symlink in /usr/local/bin first (requires sudo)
    if sudo ln -sf "$INSTALL_DIR/$( [[ "$(uname -s)" == "Darwin" ]] && echo "find_frontable.sh" || echo "find_frontable_linux.sh" )" /usr/local/bin/frontable 2>/dev/null; then
      log "✔︎ 'frontable' command created as a symlink in /usr/local/bin. You may need to open a new terminal or run 'hash -r'."
    else
      # Fallback to shell alias if symlink fails or not preferred
      log "Could not create symlink in /usr/local/bin (might require sudo or path not in $PATH). Attempting to set up shell alias…"
      SHELL_CONFIG=""
      if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_CONFIG="$HOME/.bashrc"
      elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_CONFIG="$HOME/.zshrc"
      fi

      if [[ -n "$SHELL_CONFIG" ]]; then
        echo "alias frontable='$INSTALL_DIR/$( [[ "$(uname -s)" == "Darwin" ]] && echo "find_frontable.sh" || echo "find_frontable_linux.sh" )'" >> "$SHELL_CONFIG"
        log "✔︎ 'frontable' alias added to $SHELL_CONFIG. Please run 'source $SHELL_CONFIG' or open a new terminal."
      else
        log "WARNING: No .bashrc or .zshrc found. Please add 'alias frontable=\"$INSTALL_DIR/$( [[ \"$(uname -s)\" == \"Darwin\" ]] && echo \"find_frontable.sh\" || echo \"find_frontable_linux.sh\" )\"' to your shell profile manually."
      fi
    fi
  fi
else
  log "Skipping 'frontable' command setup."
fi

log "
Installation complete! To run the Domain Fronting IP Scanner:
"

if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "  cd $INSTALL_DIR && ./find_frontable.sh [--log=debug|info|quiet]"
elif [[ "$(uname -s)" == "Linux" ]]; then
  echo "  cd $INSTALL_DIR && ./find_frontable_linux.sh [--log=debug|info|quiet]"
fi

echo "
If you set up the 'frontable' command, you can simply type:

  frontable [--log=debug|info|quiet]

" 