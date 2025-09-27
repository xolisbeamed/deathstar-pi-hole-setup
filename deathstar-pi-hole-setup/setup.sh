#!/bin/bash
#===============================================================================
# File: setup.sh
# Project: Death Star Pi-hole Setup
# Description: Single resumable installation script for Death Star Pi-hole setup
#              Installs all dependencies first, then configures services.
#              Tracks progress and can resume from where it left off after reboots.
# 
# Target Environment:
#   OS: Raspberry Pi OS aarch64
#   Host: Raspberry Pi 5 Model B Rev 1.1
#   Shell: bash
#   Dependencies: Multiple (see individual installation functions)
# 
# Author: galactic-plane
# Repository: https://github.com/galactic-plane/deathstar-pi-hole-setup
# License: See LICENSE file
#===============================================================================

set -e  # Exit on error
set -o pipefail  # Pipe failures cause script to exit

# Get script directory reliably
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the Rich installer utility first to ensure enhanced terminal output
if [[ -f "${SCRIPT_DIR}/lib/rich_installer.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/rich_installer.sh"
    ensure_rich_available
fi

# Source the advanced logging library
if [[ -f "${SCRIPT_DIR}/lib/log_handler.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/log_handler.sh"
else
    # Fallback logging functions if log_handler.sh is missing
    log_init() { echo "[INIT] $*"; }
    log_info() { echo "[INFO] $*"; }
    log_warning() { echo "[WARN] $*"; }
    log_error() { echo "[ERROR] $*"; }
    log_critical() { echo "[CRITICAL] $*"; }
    log_debug() { [[ "${DEBUG:-}" == "true" ]] && echo "[DEBUG] $*"; }
    log_success() { echo "[SUCCESS] $*"; }
fi

#===============================================================================
# Function: init_logging
# Description: Initialize logging and session details
# Parameters: None
# Returns: None
#===============================================================================
init_logging() {
    # Initialize the advanced logging system
    log_init "deathstar-pi-setup"
    
    # Log session details
    log_info "Death Star Pi Setup Session Started"
    log_info "User: ${USER}"
    local _hostname
    _hostname=$(hostname)
    log_info "Hostname: ${_hostname}"
    local _pwd
    _pwd=$(pwd)
    log_info "Working Directory: ${_pwd}"
    log_info "Script Version: Death Star Pi-hole Setup v2.0.0"
    
    # Enable debug logging if environment variable is set
    if [[ "${DEBUG:-}" == "true" ]] || [[ "${VERBOSE:-}" == "true" ]]; then
        log_debug "Debug logging enabled"
    fi
}

# Error trap function
#===============================================================================
# Function: error_trap
# Description: Error trap function to handle script failures
# Parameters:
#   $1 - Line number where error occurred
# Returns: Exits with error code
#===============================================================================
error_trap() {
    local exit_code=$?
    local line_number=$1
    log_critical "Script failed at line ${line_number} with exit code ${exit_code}" "Last command: ${BASH_COMMAND}"
    echo -e "${RED}[CRITICAL]${NC} Setup failed! Check logs for details."
    exit "${exit_code}"
}

# Set up error trapping
trap 'error_trap ${LINENO}' ERR

# Load shared configuration if it exists
if [[ -f "${SCRIPT_DIR}/lib/config_loader.sh" ]]; then
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/lib/config_loader.sh"
fi

# Set default values if config_loader.sh didn't set them
: "${DS_STATE_FILE:=${HOME}/.deathstar_setup_state}"
: "${DS_CONFIG_FILE:=${HOME}/.deathstar_config}"
: "${DS_NEW_HOSTNAME:=deathstar}"
: "${DS_DOMAIN_NAME:=local}"
: "${DS_INTERNET_PI_DIR:=${HOME}/Repo/internet-pi}"
: "${DS_REPO_BASE:=${HOME}/Repo}"
: "${DS_INTERNET_PI_URL:=https://github.com/geerlingguy/internet-pi.git}"
: "${DS_GRAFANA_PORT:=3030}"
: "${DS_PROMETHEUS_PORT:=9090}"
: "${LOG_FILE:=${HOME}/.deathstar_setup.log}"
: "${LOG_ERROR_FILE:=${HOME}/.deathstar_setup_error.log}"
: "${LOG_DEBUG_FILE:=${HOME}/.deathstar_setup_debug.log}"
: "${DRY_RUN:=0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Rich helper functions
RICH_HELPER="${SCRIPT_DIR}/lib/rich_helper.py"

# Check if Rich is available and use it, otherwise fallback to basic colors
use_rich_if_available() {
    if [[ -f "${RICH_HELPER}" ]] && command -v python3 >/dev/null 2>&1; then
        if python3 -c "import rich" >/dev/null 2>&1; then
            return 0  # Rich is available
        fi
    fi
    return 1  # Rich not available, use fallback
}

rich_header() {
    if use_rich_if_available; then
        python3 "${RICH_HELPER}" header --title "$1" --subtitle "${2:-}"
    else
        echo -e "\n${PURPLE}══════════════════════════════════════════════════════════════${NC}"
        echo -e "                    ${CYAN}$1${NC}                    "
        [[ -n "${2:-}" ]] && echo -e "                    ${2}                    "
        echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}\n"
    fi
}

rich_section() {
    if use_rich_if_available; then
        python3 "${RICH_HELPER}" section --title "$1"
    else
        echo -e "\n${CYAN}▶ $1${NC}"
    fi
}

rich_status() {
    local message="$1"
    local style="${2:-info}"
    
    if use_rich_if_available; then
        python3 "${RICH_HELPER}" status --message "${message}" --style "${style}"
    else
        case "${style}" in
            "success") echo -e "${GREEN}[SUCCESS]${NC} ${message}" ;;
            "warning") echo -e "${YELLOW}[WARNING]${NC} ${message}" ;;
            "error") echo -e "${RED}[ERROR]${NC} ${message}" ;;
            *) echo -e "${BLUE}[INFO]${NC} ${message}" ;;
        esac
    fi
}

rich_check() {
    local name="$1"
    local status="$2"
    local details="${3:-}"
    
    if use_rich_if_available; then
        python3 "${RICH_HELPER}" check --name "${name}" --status "${status}" --details "${details}"
    else
        case "${status}" in
            "PASS") echo -e "  ${GREEN}✅ PASS${NC} - ${name}" ;;
            "FAIL") echo -e "  ${RED}❌ FAIL${NC} - ${name}" ;;
            "WARN") echo -e "  ${YELLOW}⚠️  WARN${NC} - ${name}" ;;
            *) echo -e "  ${BLUE}ℹ️  INFO${NC} - ${name}" ;;
        esac
        [[ -n "${details}" ]] && echo -e "       ${details}"
    fi
}

# Configuration
STATE_FILE="${DS_STATE_FILE}"
CONFIG_FILE="${DS_CONFIG_FILE}"

# State tracking
STATES=(
    "SYSTEM_UPDATE"
    "CORE_PACKAGES"
    "FASTFETCH_INSTALL"
    "DOCKER_INSTALL"
    "DOCKER_VERIFY"
    "ANSIBLE_INSTALL"
    "ANSIBLE_VERIFY"
    "PI5_OPTIMIZATIONS"
    "RPI_CONNECT_CONSOLE"
    "HOSTNAME_CHANGE"
    "REBOOT_REQUIRED"
    "INTERNET_PI_CLONE"
    "ANSIBLE_COLLECTIONS"
    "CONFIG_GENERATION"
    "ANSIBLE_PLAYBOOK"
    "CONTAINER_DEPLOYMENT"
    "PADD_INSTALL"
    "VERIFICATION"
    "HARDENING"
    "CLEANUP"
    "COMPLETE"
)

# Print functions (using log_handler.sh for actual logging)
print_header() {
    rich_header "Death Star Pi-hole Setup" "Single Resumable Installation Script"
}

print_status() {
    rich_status "$1" "info"
    log_info "$1"
}

print_success() {
    rich_status "$1" "success"
    log_success "$1"
}

print_warning() {
    rich_status "$1" "warning"
    log_warning "$1"
}

print_error() {
    rich_status "$1" "error"
    log_error "$1"
}

print_critical() {
    rich_status "$1" "error"
    log_critical "$1"
}

print_debug() {
    if [[ "${DEBUG:-}" == "true" ]] || [[ "${VERBOSE:-}" == "true" ]]; then
        rich_status "$1" "info"
    fi
    log_debug "$1"
}

print_step() {
    rich_section "$1"
    log_info "Step: $1"
}

# State management functions
get_current_state() {
    if [[ -f "${STATE_FILE}" ]]; then
        head -n1 "${STATE_FILE}"
    else
        echo "START"
    fi
}

set_state() {
    echo "$1" > "${STATE_FILE}"
    log_info "State changed to: $1"
}

is_state_complete() {
    local target_state="$1"
    local current_state
    current_state=$(get_current_state)
    
    # Find position of current state and target state
    local current_pos=-1
    local target_pos=-1
    
    for i in "${!STATES[@]}"; do
        if [[ "${STATES[${i}]}" == "${current_state}" ]]; then
            current_pos=${i}
        fi
        if [[ "${STATES[${i}]}" == "${target_state}" ]]; then
            target_pos=${i}
        fi
    done
    
    # If current state is at or past target state, it's complete
    [[ ${current_pos} -ge ${target_pos} ]]
}

# Utility functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    dpkg -l 2>/dev/null | grep -q "^ii  $1 "
}

wait_for_internet() {
    print_status "Checking internet connectivity..."
    local max_attempts=30
    local attempt=1
    
    while ! ping -c 1 -W 2 google.com >/dev/null 2>&1; do
        if [[ ${attempt} -ge ${max_attempts} ]]; then
            print_error "No internet connection after ${max_attempts} attempts"
            exit 1
        fi
        print_status "Waiting for internet... (attempt ${attempt}/${max_attempts})"
        sleep 2
        ((attempt++))
    done
    print_success "Internet connectivity confirmed"
}

#===============================================================================
# Function: detect_pi_model
# Description: Detect Raspberry Pi model by examining /proc/cpuinfo
# Parameters: None
# Returns: "pi5", "pi4", or "unknown"
#===============================================================================
detect_pi_model() {
    if grep -q "Raspberry Pi 5" /proc/cpuinfo 2>/dev/null; then
        echo "pi5"
    elif grep -q "Raspberry Pi 4" /proc/cpuinfo 2>/dev/null; then
        echo "pi4"
    else
        echo "unknown"
    fi
}

#===============================================================================
# Function: get_timezone
# Description: Detect system timezone
# Parameters: None
# Returns: Timezone string
#===============================================================================
get_timezone() {
    if [[ -L /etc/localtime ]]; then
        readlink /etc/localtime | sed 's|/usr/share/zoneinfo/||'
    elif command -v timedatectl >/dev/null 2>&1; then
        timedatectl show --property=Timezone --value
    else
        echo "UTC"
    fi
}

#===============================================================================
# Function: confirm_user_choices
# Description: Display user's configuration choices with visual indicators
#              and confirm before proceeding with setup
# Parameters: None
# Returns: None (exits if user doesn't confirm)
#===============================================================================
confirm_user_choices() {
    echo
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${CYAN}     Configuration Summary${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo
    
    # Pi-hole configuration
    if [[ "${ENABLE_PIHOLE^^}" == "Y" ]]; then
        echo -e "${GREEN}✓${NC} Pi-hole ad blocking: ${GREEN}ENABLED${NC}"
        if [[ -n "${PIHOLE_PASSWORD}" ]]; then
            echo -e "  └─ Admin password: ${GREEN}SET${NC}"
        fi
    else
        echo -e "${RED}✗${NC} Pi-hole ad blocking: ${RED}DISABLED${NC}"
    fi
    
    # Internet speed monitoring
    if [[ "${ENABLE_MONITORING^^}" == "Y" ]]; then
        echo -e "${GREEN}✓${NC} Internet speed monitoring: ${GREEN}ENABLED${NC}"
    else
        echo -e "${RED}✗${NC} Internet speed monitoring: ${RED}DISABLED${NC}"
    fi
    
    # Shelly plug monitoring
    if [[ "${ENABLE_SHELLY^^}" == "Y" ]]; then
        echo -e "${GREEN}✓${NC} Shelly plug monitoring: ${GREEN}ENABLED${NC}"
    else
        echo -e "${RED}✗${NC} Shelly plug monitoring: ${RED}DISABLED${NC}"
    fi
    
    # AirGradient monitoring
    if [[ "${ENABLE_AIRGRADIENT^^}" == "Y" ]]; then
        echo -e "${GREEN}✓${NC} AirGradient monitoring: ${GREEN}ENABLED${NC}"
    else
        echo -e "${RED}✗${NC} AirGradient monitoring: ${RED}DISABLED${NC}"
    fi
    
    # Starlink monitoring
    if [[ "${ENABLE_STARLINK^^}" == "Y" ]]; then
        echo -e "${GREEN}✓${NC} Starlink monitoring: ${GREEN}ENABLED${NC}"
    else
        echo -e "${RED}✗${NC} Starlink monitoring: ${RED}DISABLED${NC}"
    fi
    
    echo
    echo -e "${CYAN}=======================================${NC}"
    echo
    
    # Confirmation prompt
    echo -e "${YELLOW}Please review your configuration above.${NC}"
    read -r -p "Is this configuration correct? (Y/n): " CONFIRM_CONFIG
    CONFIRM_CONFIG=${CONFIRM_CONFIG:-Y}
    
    if [[ "${CONFIRM_CONFIG^^}" != "Y" ]]; then
        echo -e "${RED}Configuration not confirmed.${NC}"
        echo -e "${YELLOW}Please run the setup script again to reconfigure.${NC}"
        echo
        log_info "User did not confirm configuration, exiting setup"
        exit 0
    fi
    
    echo -e "${GREEN}Configuration confirmed! Proceeding with setup...${NC}"
    echo
    log_info "User confirmed configuration, proceeding with setup"
}

# Installation functions
#===============================================================================
# Function: install_system_updates
# Description: Install system updates and prepare the system
# Parameters: None
# Returns: 0 on success, exits on failure
#===============================================================================
install_system_updates() {
    if is_state_complete "SYSTEM_UPDATE"; then
        print_status "System updates already completed, skipping..."
        return 0
    fi
    
    print_step "Updating system packages"
    wait_for_internet
    
    sudo apt update
    sudo apt upgrade -y
    
    set_state "SYSTEM_UPDATE"
    print_success "System updates completed"
}

#===============================================================================
# Function: install_core_packages
# Description: Install essential packages needed for the setup
# Parameters: None
# Returns: 0 on success, exits on failure
#===============================================================================
install_core_packages() {
    if is_state_complete "CORE_PACKAGES"; then
        print_status "Core packages already installed, skipping..."
        return 0
    fi
    
    print_step "Installing core packages"
    
    local packages=(
        "git"
        "curl"
        "wget"
        "dnsutils"
        "python3-pip"
        "net-tools"
        "vim"
        "unzip"
    )
    
    # Detect Pi model for specific tools
    local pi_model
    pi_model=$(detect_pi_model)
    
    # Add monitoring tools - more explicit for Pi5
    if [[ "${pi_model}" == "pi5" ]]; then
        print_status "Detected Raspberry Pi 5 - adding enhanced monitoring tools"
        packages+=("htop" "iotop")
    elif [[ "${pi_model}" == "pi4" ]]; then
        print_status "Detected Raspberry Pi 4 - adding standard monitoring tools"
        packages+=("htop")
    else
        print_status "Detected unknown Pi model - adding basic monitoring tools"
        packages+=("htop")
    fi
    
    for package in "${packages[@]}"; do
        if package_installed "${package}"; then
            print_status "${package} already installed"
        else
            print_status "Installing ${package}..."
            sudo apt install -y "${package}"
        fi
    done
    
    # Install Rich for enhanced terminal output
    print_status "Installing Rich library for enhanced output..."
    if ! python3 -c "import rich" >/dev/null 2>&1; then
        if pip3 install rich >/dev/null 2>&1; then
            print_success "Rich library installed successfully"
        elif pip3 install --break-system-packages rich >/dev/null 2>&1; then
            print_success "Rich library installed successfully (--break-system-packages)"
        else
            print_warning "Rich library installation failed - using fallback formatting"
        fi
    else
        print_status "Rich library already installed"
    fi
    
    set_state "CORE_PACKAGES"
    print_success "Core packages installation completed"
}

#===============================================================================
# Function: install_fastfetch
# Description: Install or update Fastfetch system information tool
# Parameters: None
# Returns: 0 on success, continues on failure
#===============================================================================
install_fastfetch() {
    if is_state_complete "FASTFETCH_INSTALL"; then
        print_status "Fastfetch already installed, skipping..."
        return 0
    fi
    
    print_step "Installing/Updating Fastfetch"
    
    # Detect architecture (e.g., arm64, armhf, amd64)
    ARCH=$(dpkg --print-architecture)
    
    # Handle architecture mapping for GitHub releases
    case "${ARCH}" in
        "arm64") GITHUB_ARCH="aarch64" ;;
        "armhf") GITHUB_ARCH="armv7l" ;;
        *) GITHUB_ARCH="${ARCH}" ;;
    esac
    
    # Get latest version tag from GitHub API with timeout and error handling
    print_debug "Fetching latest Fastfetch version from GitHub..."
    if ! LATEST_VER=$(timeout 30 curl -s --fail --connect-timeout 10 \
        https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
        | grep -m1 '"tag_name":' | cut -d '"' -f4 | sed 's/^v//'); then
        print_warning "Failed to get latest Fastfetch version from GitHub API, skipping installation"
        log_warning "Fastfetch installation skipped due to API timeout or failure"
        set_state "FASTFETCH_INSTALL"
        return 0
    fi
    
    if [[ -z "${LATEST_VER}" ]]; then
        print_warning "Could not determine Fastfetch version, skipping installation"
        log_warning "Fastfetch installation skipped - empty version string"
        set_state "FASTFETCH_INSTALL"
        return 0
    fi
    
    # Get currently installed version (if any)
    if command -v fastfetch >/dev/null 2>&1; then
        CURRENT_VER=$(fastfetch --version 2>/dev/null | awk '{print $2}')
    else
        CURRENT_VER=""
    fi
    
    # Compare versions
    if [[ "${LATEST_VER}" == "${CURRENT_VER}" ]]; then
        print_success "✅ Fastfetch is already up to date (version ${CURRENT_VER})"
        set_state "FASTFETCH_INSTALL"
        return 0
    fi
    
    print_status "⬇️ Installing Fastfetch ${LATEST_VER} (current: ${CURRENT_VER:-none})..."
    
    # Get download URL for correct architecture with timeout and error handling
    print_debug "Fetching download URL for architecture: ${ARCH} (GitHub: ${GITHUB_ARCH})"
    if ! URL=$(timeout 30 curl -s --fail --connect-timeout 10 \
        https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
        | grep "browser_download_url.*linux-${GITHUB_ARCH}.deb" \
        | cut -d '"' -f 4); then
        print_warning "Failed to get Fastfetch download URL, trying fallback with original arch..."
        if ! URL=$(timeout 30 curl -s --fail --connect-timeout 10 \
            https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
            | grep "browser_download_url.*linux-${ARCH}.deb" \
            | cut -d '"' -f 4); then
            print_warning "Failed to get Fastfetch download URL, skipping installation"
            log_warning "Fastfetch installation skipped - could not find download URL"
            set_state "FASTFETCH_INSTALL"
            return 0
        fi
    fi
    
    if [[ -z "${URL}" ]]; then
        print_warning "No suitable Fastfetch package found for architecture ${ARCH}, skipping installation"
        log_warning "Fastfetch installation skipped - no package for architecture ${ARCH}"
        set_state "FASTFETCH_INSTALL"
        return 0
    fi
    
    print_debug "Download URL: ${URL}"
    
    # Download to a temp file with timeout and error handling
    TMP_DEB=$(mktemp)
    if ! timeout 300 wget --connect-timeout=10 --read-timeout=30 -qO "${TMP_DEB}" "${URL}"; then
        print_warning "Failed to download Fastfetch package, skipping installation"
        log_warning "Fastfetch installation skipped - download failed"
        rm -f "${TMP_DEB}"
        set_state "FASTFETCH_INSTALL"
        return 0
    fi
    
    # Verify the downloaded file is not empty
    if [[ ! -s "${TMP_DEB}" ]]; then
        print_warning "Downloaded Fastfetch package is empty, skipping installation"
        log_warning "Fastfetch installation skipped - empty download file"
        rm -f "${TMP_DEB}"
        set_state "FASTFETCH_INSTALL"
        return 0
    fi
    
    # Install and clean up
    if sudo apt install -y "${TMP_DEB}"; then
        print_success "✅ Fastfetch ${LATEST_VER} installed successfully"
        log_info "Fastfetch ${LATEST_VER} installed successfully"
    else
        print_warning "Failed to install Fastfetch package, continuing anyway"
        log_warning "Fastfetch installation failed during apt install"
    fi
    
    rm -f "${TMP_DEB}"
    set_state "FASTFETCH_INSTALL"
    return 0
}

install_docker() {
    if is_state_complete "DOCKER_INSTALL"; then
        print_status "Docker already installed, skipping..."
        return 0
    fi
    
    print_step "Installing Docker"
    print_debug "Checking if Docker is already installed..."
    
    if ! command_exists docker; then
        print_status "Downloading and installing Docker..."
        print_debug "Downloading Docker installation script from get.docker.com"
        curl -fsSL https://get.docker.com -o get-docker.sh
        print_debug "Running Docker installation script"
        sudo sh get-docker.sh
        rm get-docker.sh
        
        print_status "Adding user to docker group..."
        print_debug "Adding user ${USER} to docker group"
        sudo usermod -aG docker "${USER}"
        
        print_status "Starting Docker service..."
        print_debug "Enabling and starting Docker systemd service"
        sudo systemctl enable docker
        sudo systemctl start docker
    else
        print_status "Docker already installed"
        local docker_path
        docker_path=$(command -v docker || true)
        print_debug "Docker command found at: ${docker_path}"
        
        # Ensure user is in docker group even if Docker was already installed
        local user_in_docker_group=false
        if groups "${USER}" | grep -q docker; then
            user_in_docker_group=true
        fi
        
        if [[ "${user_in_docker_group}" == false ]]; then
            print_status "Adding user to docker group..."
            sudo usermod -aG docker "${USER}"
        fi
    fi
    
    # Install Docker Compose plugin
    if ! docker compose version >/dev/null 2>&1; then
        print_status "Installing Docker Compose plugin..."
        print_debug "Installing docker-compose-plugin via apt"
        sudo apt install -y docker-compose-plugin
    else
        print_debug "Docker Compose already available"
    fi
    
    set_state "DOCKER_INSTALL"
    print_success "Docker installation completed"
}

verify_docker() {
    if is_state_complete "DOCKER_VERIFY"; then
        print_status "Docker verification already completed, skipping..."
        return 0
    fi
    
    print_step "Verifying Docker installation"
    print_debug "Checking Docker daemon status..."
    
    # Check if Docker daemon is running
    if ! sudo systemctl is-active --quiet docker; then
        print_error "Docker daemon is not running"
        print_debug "Attempting to start Docker service..."
        sudo systemctl start docker
        sleep 2
        if ! sudo systemctl is-active --quiet docker; then
            return 1
        fi
    fi
    
    print_debug "Docker daemon is running"
    
    # Test Docker access - use sudo for verification as group may not be active yet
    print_debug "Testing Docker access..."
    if ! sudo docker ps >/dev/null 2>&1; then
        print_error "Cannot access Docker even with sudo"
        return 1
    fi
    
    # Check if user needs to re-login for group membership
    if ! docker ps >/dev/null 2>&1; then
        print_warning "Docker group membership not active - will be available after reboot"
        print_debug "User will need to logout/login or reboot for docker group to take effect"
    else
        print_debug "Docker access working without sudo"
    fi

    # Test Docker Compose
    print_debug "Testing Docker Compose functionality..."
    if ! docker compose version >/dev/null 2>&1 && ! sudo docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose not working"
        print_debug "Docker Compose version check failed"
        return 1
    fi
    
    print_debug "Docker Compose is working"
    set_state "DOCKER_VERIFY"
    print_success "Docker verification completed"
    return 0
}

install_ansible() {
    if is_state_complete "ANSIBLE_INSTALL"; then
        print_status "Ansible already installed, skipping..."
        return 0
    fi
    
    print_step "Installing Ansible"
    
    # Always use virtual environment to avoid dependency conflicts
    print_status "Installing Ansible via virtual environment to avoid dependency conflicts..."
    
    # Remove any existing system Ansible packages that might conflict
    if dpkg -l | grep -q "^ii.*ansible"; then
        print_status "Removing conflicting system Ansible packages..."
        sudo apt remove -y ansible ansible-core 2>/dev/null || true
    fi
    
    # Remove any existing symlinks that might point to non-existent paths
    print_status "Cleaning up any existing Ansible symlinks..."
    sudo rm -f /usr/local/bin/ansible /usr/local/bin/ansible-playbook /usr/local/bin/ansible-galaxy
    
    # Install python3-venv if not present
    local python3_venv_installed=false
    if package_installed python3-venv; then
        python3_venv_installed=true
    fi
    
    if [[ "${python3_venv_installed}" == false ]]; then
        sudo apt-get update
        sudo apt-get install -y python3-venv python3-full python3-pip
    fi
    
    # Create a virtual environment for Ansible
    local venv_dir="${HOME}/.local/venv-ansible"
    if [[ -d "${venv_dir}" ]]; then
        print_status "Removing existing virtual environment..."
        rm -rf "${venv_dir}"
    fi
    
    print_status "Creating virtual environment for Ansible..."
    python3 -m venv "${venv_dir}"
    
    # Upgrade pip and install Ansible with specific resolvelib version
    print_status "Installing Ansible with compatible dependencies..."
    "${venv_dir}/bin/pip" install --upgrade pip
    "${venv_dir}/bin/pip" install "resolvelib>=0.5.3,<1.1.0"
    "${venv_dir}/bin/pip" install ansible
    
    # Create symlinks to make ansible commands available
    print_status "Creating symlinks for Ansible commands..."
    sudo ln -sf "${venv_dir}/bin/ansible" /usr/local/bin/ansible
    sudo ln -sf "${venv_dir}/bin/ansible-playbook" /usr/local/bin/ansible-playbook
    sudo ln -sf "${venv_dir}/bin/ansible-galaxy" /usr/local/bin/ansible-galaxy
    
    print_status "Ansible installed in virtual environment with compatible dependencies"
    
    # Verify the installation works
    if ! "${venv_dir}/bin/ansible" --version >/dev/null 2>&1; then
        print_error "Ansible installation verification failed"
        return 1
    fi
    
    if ! "${venv_dir}/bin/ansible-galaxy" --version >/dev/null 2>&1; then
        print_error "Ansible Galaxy installation verification failed"
        return 1
    fi
    
    # Test resolvelib version is correct
    local resolvelib_version
    resolvelib_version=$("${venv_dir}/bin/python" -c "import resolvelib; print(resolvelib.__version__)" 2>/dev/null || echo "unknown")
    print_status "Virtual environment resolvelib version: ${resolvelib_version}"
    
    print_status "Ansible installation verified successfully"
    
    set_state "ANSIBLE_INSTALL"
    print_success "Ansible installation completed"
}

verify_ansible() {
    if is_state_complete "ANSIBLE_VERIFY"; then
        print_status "Ansible verification already completed, skipping..."
        return 0
    fi
    
    print_step "Verifying Ansible installation"
    
    # Check virtual environment installation
    local venv_dir="${HOME}/.local/venv-ansible"
    if [[ ! -d "${venv_dir}" ]]; then
        print_error "Ansible virtual environment not found"
        return 1
    fi
    
    # Test virtual environment Ansible commands directly
    if ! "${venv_dir}/bin/ansible" --version >/dev/null 2>&1; then
        print_error "Virtual environment Ansible not working"
        return 1
    fi
    
    if ! "${venv_dir}/bin/ansible-playbook" --version >/dev/null 2>&1; then
        print_error "Virtual environment ansible-playbook not working"
        return 1
    fi
    
    if ! "${venv_dir}/bin/ansible-galaxy" --version >/dev/null 2>&1; then
        print_error "Virtual environment ansible-galaxy not working"
        return 1
    fi
    
    # Verify resolvelib version in virtual environment
    local resolvelib_version
    resolvelib_version=$("${venv_dir}/bin/python" -c "import resolvelib; print(resolvelib.__version__)" 2>/dev/null || echo "unknown")
    print_status "Virtual environment resolvelib version: ${resolvelib_version}"
    
    # Check that resolvelib version is compatible
    if [[ "${resolvelib_version}" == "unknown" ]]; then
        print_error "Could not determine resolvelib version in virtual environment"
        return 1
    fi
    
    # Test symlinks work
    if ! /usr/local/bin/ansible --version >/dev/null 2>&1; then
        print_error "Ansible symlink not working"
        return 1
    fi
    
    if ! /usr/local/bin/ansible-galaxy --version >/dev/null 2>&1; then
        print_error "Ansible Galaxy symlink not working"
        return 1
    fi
    
    print_success "Virtual environment Ansible installation verified"
    
    set_state "ANSIBLE_VERIFY"
    print_success "Ansible verification completed"
    return 0
}

apply_pi5_optimizations() {
    if is_state_complete "PI5_OPTIMIZATIONS"; then
        print_status "Pi 5 optimizations already applied, skipping..."
        return 0
    fi

    local pi_model
    pi_model=$(detect_pi_model)

    # Allow dry-run mode
    local SUDO="sudo"
    if [[ "${DRY_RUN}" == "1" ]]; then
        SUDO="echo [DRY-RUN] sudo"
        print_status "Running in DRY-RUN mode — no changes will be made"
    fi

    if [[ "${pi_model}" == "pi5" ]]; then
        print_step "Applying Raspberry Pi 5 optimizations"

        # Create timestamped backups
        local backup_timestamp
        backup_timestamp=$(date +%Y%m%d_%H%M%S)

        print_status "Creating backup of boot configuration files..."
        if [[ -f /boot/firmware/cmdline.txt ]]; then
            ${SUDO} cp /boot/firmware/cmdline.txt "/boot/firmware/cmdline.txt.backup.${backup_timestamp}"
            print_status "Backed up cmdline.txt to cmdline.txt.backup.${backup_timestamp}"
        elif [[ -f /boot/cmdline.txt ]]; then
            # Fallback for older Raspberry Pi OS versions
            ${SUDO} cp /boot/cmdline.txt "/boot/cmdline.txt.backup.${backup_timestamp}"
            print_status "Backed up cmdline.txt to cmdline.txt.backup.${backup_timestamp}"
        fi
        
        if [[ -f /boot/firmware/config.txt ]]; then
            ${SUDO} cp /boot/firmware/config.txt "/boot/firmware/config.txt.backup.${backup_timestamp}"
            print_status "Backed up config.txt to config.txt.backup.${backup_timestamp}"
        elif [[ -f /boot/config.txt ]]; then
            # Fallback for older Raspberry Pi OS versions
            ${SUDO} cp /boot/config.txt "/boot/config.txt.backup.${backup_timestamp}"
            print_status "Backed up config.txt to config.txt.backup.${backup_timestamp}"
        fi

        # Determine boot config location
        local BOOT_DIR="/boot/firmware"
        [[ ! -d "${BOOT_DIR}" ]] && BOOT_DIR="/boot"

        # Enable memory cgroups
        print_status "Configuring memory cgroups..."
        if [[ -f "${BOOT_DIR}/cmdline.txt" ]]; then
            if ! grep -q "cgroup_memory=1 cgroup_enable=memory" "${BOOT_DIR}/cmdline.txt"; then
                ${SUDO} sed -i 's/[[:space:]]*$//; s/$/ cgroup_memory=1 cgroup_enable=memory/' "${BOOT_DIR}/cmdline.txt"
                print_status "Memory cgroups enabled in cmdline.txt"
            else
                print_status "Memory cgroups already enabled in cmdline.txt"
            fi
        fi

        # Set GPU memory split with enhanced logic
        print_status "Setting GPU memory split for headless operation..."
        if [[ -f "${BOOT_DIR}/config.txt" ]]; then
            if ! grep -q "^gpu_mem=" "${BOOT_DIR}/config.txt"; then
                echo "gpu_mem=16" | ${SUDO} tee -a "${BOOT_DIR}/config.txt" >/dev/null
                print_status "GPU memory optimized for headless operation"
            elif ! grep -q "^gpu_mem=16$" "${BOOT_DIR}/config.txt"; then
                ${SUDO} sed -i 's/^gpu_mem=.*/gpu_mem=16/' "${BOOT_DIR}/config.txt"
                print_status "GPU memory setting updated to 16MB"
            else
                print_status "GPU memory already optimized in config.txt"
            fi
        fi

        # Set boot target to CLI mode if systemctl is available
        if command -v systemctl >/dev/null 2>&1; then
            print_status "Setting boot target to CLI (headless mode)..."
            local current_target
            current_target=$(systemctl get-default)
            
            # Store previous target for removal script
            if [[ "${current_target}" != "multi-user.target" ]]; then
                echo "PI5_PREV_TARGET=${current_target}" >> "${STATE_FILE}"
                ${SUDO} systemctl set-default multi-user.target
                print_status "Boot target set to CLI mode (multi-user.target)"
                print_status "Previous target (${current_target}) stored for restoration"
            else
                print_status "Boot target already set to CLI mode"
            fi
        fi

        set_state "PI5_OPTIMIZATIONS"
        print_success "Pi 5 optimizations applied (backups created with timestamp: ${backup_timestamp})"
        print_status "Reboot required for changes to take effect"
        return 0
    else
        print_status "Not a Pi 5, skipping optimizations"
        set_state "PI5_OPTIMIZATIONS"
        return 0
    fi
}

#===============================================================================
# Function: configure_rpi_connect_for_console
# Description: Configure rpi-connect for console-only operation
#              Uninstalls rpi-connect and installs rpi-connect-lite instead
# Parameters: None
# Returns: 0 on success, exits on failure
#===============================================================================
configure_rpi_connect_for_console() {
    if is_state_complete "RPI_CONNECT_CONSOLE"; then
        print_status "RPI Connect console configuration already completed, skipping..."
        return 0
    fi

    print_step "Configuring RPI Connect for console-only operation"

    # Allow dry-run mode
    local SUDO="sudo"
    if [[ "${DRY_RUN}" == "1" ]]; then
        SUDO="echo [DRY-RUN] sudo"
        print_status "Running in DRY-RUN mode — no changes will be made"
    fi

    # Store original rpi-connect status for restoration
    if dpkg -l | grep -q "^ii.*rpi-connect[[:space:]]"; then
        echo "RPI_CONNECT_ORIGINALLY_INSTALLED=true" >> "${STATE_FILE}"
        print_status "Detected original rpi-connect installation - status stored for restoration"
    else
        echo "RPI_CONNECT_ORIGINALLY_INSTALLED=false" >> "${STATE_FILE}"
    fi

    # Check if rpi-connect is installed
    if dpkg -l | grep -q "^ii.*rpi-connect[[:space:]]"; then
        print_status "Found rpi-connect package installed, removing..."
        if ${SUDO} apt remove -y rpi-connect; then
            print_success "Successfully removed rpi-connect package"
        else
            print_warning "Failed to remove rpi-connect package, continuing..."
        fi
    else
        print_status "rpi-connect package not found, no removal needed"
    fi

    # Check if rpi-connect-lite is available and install it
    if apt list --installed 2>/dev/null | grep -q "rpi-connect-lite"; then
        print_status "rpi-connect-lite already installed"
    else
        print_status "Installing rpi-connect-lite for console-only remote access..."
        if ${SUDO} apt update >/dev/null 2>&1; then
            if ${SUDO} apt install -y rpi-connect-lite; then
                print_success "Successfully installed rpi-connect-lite"
                print_status "rpi-connect-lite provides remote access optimized for console environments"
            else
                # Check if package exists in repositories
                if apt search rpi-connect-lite 2>/dev/null | grep -q "rpi-connect-lite"; then
                    print_warning "rpi-connect-lite package found but installation failed"
                else
                    print_warning "rpi-connect-lite package not available in current repositories"
                    print_status "This may be normal if using an older Raspberry Pi OS version"
                fi
            fi
        else
            print_warning "Failed to update package lists"
        fi
    fi

    # Ensure rpi-connect service is stopped and disabled if it still exists
    if systemctl list-unit-files | grep -q "rpi-connect\.service"; then
        print_status "Ensuring rpi-connect service is disabled..."
        ${SUDO} systemctl stop rpi-connect.service 2>/dev/null || true
        ${SUDO} systemctl disable rpi-connect.service 2>/dev/null || true
        print_status "rpi-connect service stopped and disabled"
    fi

    # Enable rpi-connect-lite service if it exists
    if systemctl list-unit-files | grep -q "rpi-connect-lite\.service"; then
        print_status "Enabling rpi-connect-lite service..."
        if ${SUDO} systemctl enable rpi-connect-lite.service; then
            print_success "rpi-connect-lite service enabled"
            # Don't start it immediately as it may require reboot or specific configuration
            print_status "Service will start automatically on next boot"
        else
            print_warning "Failed to enable rpi-connect-lite service"
        fi
    elif command -v rpi-connect >/dev/null 2>&1; then
        # If rpi-connect-lite binary exists but no systemd service, provide guidance
        print_status "rpi-connect-lite binary found but no systemd service detected"
        print_status "You may need to configure it manually or it may start automatically"
    fi

    set_state "RPI_CONNECT_CONSOLE"
    print_success "RPI Connect console configuration completed"
    
    return 0
}

change_hostname() {
    if is_state_complete "HOSTNAME_CHANGE"; then
        print_status "Hostname already changed, skipping..."
        return 0
    fi
    
    print_step "Changing hostname to ${DS_NEW_HOSTNAME}"
    
    local current_hostname
    current_hostname=$(hostname)
    if [[ "${current_hostname}" != "${DS_NEW_HOSTNAME}" ]]; then
        print_status "Changing hostname from ${current_hostname} to ${DS_NEW_HOSTNAME}..."
        
        if command -v hostnamectl >/dev/null 2>&1; then
            sudo hostnamectl set-hostname "${DS_NEW_HOSTNAME}"
        else
            # Fallback for systems without hostnamectl
            echo "${DS_NEW_HOSTNAME}" | sudo tee /etc/hostname >/dev/null
            sudo hostname "${DS_NEW_HOSTNAME}"
        fi
        
        print_status "Updating /etc/hosts file..."
        sudo sed -i "s/${current_hostname}/${DS_NEW_HOSTNAME}/g" /etc/hosts
        
        # Ensure localhost entries exist
        if ! grep -q "127.0.1.1.*${DS_NEW_HOSTNAME}" /etc/hosts; then
            echo "127.0.1.1    ${DS_NEW_HOSTNAME}" | sudo tee -a /etc/hosts >/dev/null
        fi
        
        set_state "HOSTNAME_CHANGE"
        print_success "Hostname changed to ${DS_NEW_HOSTNAME}"
        return 0
    else
        print_status "Hostname already set to ${DS_NEW_HOSTNAME}"
        set_state "HOSTNAME_CHANGE"
        return 0
    fi
}

check_reboot_required() {
    local current_state
    current_state=$(get_current_state)
    
    # Check if we need to reboot for various reasons
    local reboot_needed=false
    local reboot_reasons=()
    
    # Check if Docker group membership requires reboot
    if [[ "${current_state}" == "DOCKER_VERIFY" ]] && ! timeout 5 docker ps >/dev/null 2>&1; then
        reboot_needed=true
        reboot_reasons+=("Docker group membership activation")
    fi
    
    # Check if Pi 5 optimizations require reboot
    if [[ "${current_state}" == "PI5_OPTIMIZATIONS" ]]; then
        local pi_model
        pi_model=$(detect_pi_model)
        if [[ "${pi_model}" == "pi5" ]]; then
            if grep -q "cgroup_memory=1" /boot/firmware/cmdline.txt 2>/dev/null || grep -q "cgroup_memory=1" /boot/cmdline.txt 2>/dev/null; then
                if ! grep -q "cgroup" /proc/cmdline; then
                    reboot_needed=true
                    reboot_reasons+=("Pi 5 memory cgroups activation")
                fi
            fi
        fi
    fi
    
    # Check if hostname change requires reboot
    if [[ "${current_state}" == "HOSTNAME_CHANGE" ]]; then
        if command -v hostnamectl >/dev/null 2>&1; then
            local current_hostname
            local static_hostname
            current_hostname=$(hostname)
            static_hostname=$(hostnamectl --static 2>/dev/null || echo "")
            if [[ "${current_hostname}" != "${static_hostname}" ]]; then
                reboot_needed=true
                reboot_reasons+=("Hostname change activation")
            fi
        fi
    fi
    
    if [[ "${reboot_needed}" == true ]]; then
        print_warning "Reboot required for: ${reboot_reasons[*]}"
        set_state "REBOOT_REQUIRED"
        return 0
    else
        # Skip reboot state if not needed
        if [[ "${current_state}" == "REBOOT_REQUIRED" ]]; then
            print_status "Reboot was not actually required, continuing..."
        fi
        return 1
    fi
}

perform_reboot() {
    print_step "Performing mandatory reboot"
    show_prominent_reboot_message
    
    sleep 10
    sudo reboot
}

# Function to display a prominent reboot instruction message
show_prominent_reboot_message() {
    if use_rich_if_available; then
        # Create a custom reboot panel with Rich
        python3 -c "
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.align import Align
from rich import box

console = Console()

reboot_text = Text()
reboot_text.append('🚨  REBOOT REQUIRED  🚨\n\n', style='bold red')
reboot_text.append('The system needs to reboot to activate changes. This is NORMAL behavior.\n\n', style='white')
reboot_text.append('📋 WHAT TO DO AFTER REBOOT:\n\n', style='bold cyan')
reboot_text.append('Option 1 - If running from HOST machine:\n', style='bold yellow')
reboot_text.append('  1. Wait for Pi to reboot completely (~30-60 seconds)\n', style='white')
reboot_text.append('  2. Run: ./connect_to_pi.sh\n', style='green')
reboot_text.append('  3. Run: ./setup.sh\n\n', style='green')
reboot_text.append('Option 2 - If already on the Pi:\n', style='bold yellow')
reboot_text.append('  1. After reboot, simply run: ./setup.sh\n\n', style='green')
reboot_text.append('✅ Setup will automatically resume where it left off!', style='bold green')

panel = Panel(
    Align.center(reboot_text),
    box=box.DOUBLE,
    border_style='red',
    padding=(1, 2),
    width=82
)
console.print(panel)
"
    else
        # Fallback to basic colored output
        echo
        echo -e "${RED}══════════════════════════════════════════════════════════════════════════════"
        echo -e "                            🚨  REBOOT REQUIRED  🚨                           "
        echo -e ""
        echo -e "  The system needs to reboot to activate changes. This is NORMAL behavior.   "
        echo -e ""
        echo -e "  📋 WHAT TO DO AFTER REBOOT:                                                "
        echo -e ""
        echo -e "  Option 1 - If running from HOST machine:                                   "
        echo -e "    1. Wait for Pi to reboot completely (~30-60 seconds)                     "
        echo -e "    2. Run: ./connect_to_pi.sh                                               "
        echo -e "    3. Run: ./setup.sh                                                       "
        echo -e ""
        echo -e "  Option 2 - If already on the Pi:                                           "
        echo -e "    1. After reboot, simply run: ./setup.sh                                  "
        echo -e ""
        echo -e "  ✅ Setup will automatically resume where it left off!                      "
        echo -e ""
        echo -e "══════════════════════════════════════════════════════════════════════════════${NC}"
    fi
    echo
    print_warning "System will reboot in 10 seconds..."
}

clone_internet_pi() {
    if is_state_complete "INTERNET_PI_CLONE"; then
        print_status "Internet-pi repository already cloned, skipping..."
        return 0
    fi
    
    print_step "Cloning internet-pi repository"
    
    local repo_dir="${DS_INTERNET_PI_DIR}"
    
    if [[ ! -d "${repo_dir}" ]]; then
        print_status "Creating Repo directory..."
        mkdir -p "${DS_REPO_BASE}"
        
        print_status "Cloning geerlingguy/internet-pi..."
        git clone "${DS_INTERNET_PI_URL}" "${repo_dir}"
    else
        print_status "Repository already exists, updating..."
        cd "${repo_dir}" || exit 1
        git pull
    fi
    
    set_state "INTERNET_PI_CLONE"
    print_success "Internet-pi repository ready"
}

install_ansible_collections() {
    if is_state_complete "ANSIBLE_COLLECTIONS"; then
        print_status "Ansible collections already installed, skipping..."
        return 0
    fi
    
    print_step "Installing Ansible collections"
    
    local repo_dir="${DS_INTERNET_PI_DIR}"
    
    if [[ -f "${repo_dir}/requirements.yml" ]]; then
        print_status "Installing Ansible collections from requirements.yml..."
        cd "${repo_dir}" || exit 1
        
        # Use virtual environment ansible-galaxy if it exists
        local venv_dir="${HOME}/.local/venv-ansible"
        if [[ -f "${venv_dir}/bin/ansible-galaxy" ]]; then
            print_status "Using virtual environment ansible-galaxy..."
            "${venv_dir}/bin/ansible-galaxy" install -r requirements.yml
        else
            # Fallback to system ansible-galaxy
            export PATH="${HOME}/.local/bin:${PATH}"
            ansible-galaxy install -r requirements.yml
        fi
    else
        print_warning "requirements.yml not found, skipping collection installation"
    fi
    
    set_state "ANSIBLE_COLLECTIONS"
    print_success "Ansible collections installation completed"
}

# Function to securely handle passwords
#===============================================================================
# Function: secure_password_input
# Description: Securely read password with confirmation
# Parameters:
#   $1 - Prompt message
# Returns: Sets SECURE_PASSWORD variable
#===============================================================================
secure_password_input() {
    local prompt="${1}"
    local password=""
    local password_confirm=""
    
    while true; do
        read -r -s -p "${prompt}: " password
        echo
        
        if [[ -z "${password}" ]]; then
            SECURE_PASSWORD=""
            return 0
        fi
        
        read -r -s -p "Confirm password: " password_confirm
        echo
        
        if [[ "${password}" == "${password_confirm}" ]]; then
            SECURE_PASSWORD="${password}"
            return 0
        else
            echo -e "${RED}Passwords do not match. Please try again.${NC}"
        fi
    done
}

# User interaction functions
collect_user_preferences() {
    if [[ -f "${CONFIG_FILE}" ]]; then
        print_status "Loading existing configuration..."
        # shellcheck disable=SC1090
        source "${CONFIG_FILE}"
        
        # Generate password hash if not already present and password exists
        if [[ -n "${PIHOLE_PASSWORD}" && -z "${PIHOLE_PASSWORD_HASH}" ]]; then
            PIHOLE_PASSWORD_HASH=$(echo -n "${PIHOLE_PASSWORD}" | sha256sum | awk '{print $1}' | sha256sum | awk '{print $1}')
            echo "Password hash generated from existing password"
        fi
        
        return 0
    fi
    
    print_step "Collecting user preferences"
    
    echo -e "${CYAN}Please configure your Death Star Pi-hole setup:${NC}\n"
    
    # Pi-hole configuration
    read -r -p "Enable Pi-hole ad blocking? (Y/n): " ENABLE_PIHOLE
    ENABLE_PIHOLE=${ENABLE_PIHOLE:-Y}
    
    if [[ "${ENABLE_PIHOLE^^}" == "Y" ]]; then
        echo "Enter Pi-hole admin password (leave blank for random)"
        secure_password_input "Password"
        
        if [[ -z "${SECURE_PASSWORD}" ]]; then
            PIHOLE_PASSWORD=$(openssl rand -base64 12)
            echo "Generated random password: ${PIHOLE_PASSWORD}"
        else
            PIHOLE_PASSWORD="${SECURE_PASSWORD}"
            echo "Password confirmed successfully"
        fi
        
        # Generate password hash for Pi-hole (double SHA256)
        PIHOLE_PASSWORD_HASH=$(echo -n "${PIHOLE_PASSWORD}" | sha256sum | awk '{print $1}' | sha256sum | awk '{print $1}')
        echo "Password hash generated for Pi-hole configuration"
    fi
    
    # Monitoring services
    read -r -p "Enable internet speed monitoring? (Y/n): " ENABLE_MONITORING
    ENABLE_MONITORING=${ENABLE_MONITORING:-Y}
    
    read -r -p "Enable Shelly plug monitoring? (y/N): " ENABLE_SHELLY
    ENABLE_SHELLY=${ENABLE_SHELLY:-N}
    
    read -r -p "Enable AirGradient monitoring? (y/N): " ENABLE_AIRGRADIENT
    ENABLE_AIRGRADIENT=${ENABLE_AIRGRADIENT:-N}
    
    read -r -p "Enable Starlink monitoring? (y/N): " ENABLE_STARLINK
    ENABLE_STARLINK=${ENABLE_STARLINK:-N}
    
    # Confirm user choices
    confirm_user_choices
    
    # Save configuration (store hash only, not plain password for security)
    cat > "${CONFIG_FILE}" << EOF
# Death Star Pi-hole Configuration
ENABLE_PIHOLE="${ENABLE_PIHOLE^^}"
PIHOLE_PASSWORD_HASH="${PIHOLE_PASSWORD_HASH}"
ENABLE_MONITORING="${ENABLE_MONITORING^^}"
ENABLE_SHELLY="${ENABLE_SHELLY^^}"
ENABLE_AIRGRADIENT="${ENABLE_AIRGRADIENT^^}"
ENABLE_STARLINK="${ENABLE_STARLINK^^}"
GENERATED_DATE="$(date || true)"
GENERATED_DATE="${GENERATED_DATE:-Unknown}"
# Note: Plain password not stored for security reasons
# Password can be regenerated if needed using the hash
EOF
    
    # Set restrictive permissions on config file
    chmod 600 "${CONFIG_FILE}"
    
    print_success "Configuration saved to ${CONFIG_FILE}"
}

generate_ansible_config() {
    if is_state_complete "CONFIG_GENERATION"; then
        print_status "Ansible configuration already generated, skipping..."
        return 0
    fi
    
    print_step "Generating Ansible configuration"
    
    # Load user preferences
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
    
    # Ensure password hash is available
    if [[ -n "${PIHOLE_PASSWORD}" && -z "${PIHOLE_PASSWORD_HASH}" ]]; then
        PIHOLE_PASSWORD_HASH=$(echo -n "${PIHOLE_PASSWORD}" | sha256sum | awk '{print $1}' | sha256sum | awk '{print $1}')
    fi
    
    local repo_dir="${DS_INTERNET_PI_DIR}"
    local config_file="${repo_dir}/config.yml"
    
    # Detect Pi IP address
    local pi_ip
    pi_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -z "${pi_ip}" ]]; then
        print_error "Could not automatically detect Pi IP address"
        print_error "Please ensure your Pi has a valid network connection and IP address"
        print_error "You can check your IP with: hostname -I"
        print_error "Or configure a static IP in your router/network settings"
        exit 1
    else
        print_status "Detected Pi IP address: ${pi_ip}"
    fi
    
    # Get system timezone
    local system_timezone
    system_timezone=$(get_timezone)
    print_status "Detected system timezone: ${system_timezone}"
    
    # Generate config.yml based on user preferences
    cat > "${config_file}" << EOF
---
# Death Star Pi Configuration - Generated by Death Star Setup

# Network Configuration
internet_pi_ip: "${pi_ip}"
internet_pi_ipv6: ""
internet_pi_hostname: "${DS_NEW_HOSTNAME}"
internet_pi_domain: "${DS_DOMAIN_NAME}"

# Security Configuration  
internet_pi_password_hash: "${PIHOLE_PASSWORD_HASH}"
EOF

    # Pi-hole Configuration
    local _pihole_enable
    if [[ "${ENABLE_PIHOLE}" == "Y" ]]; then
        _pihole_enable="true"
    else
        _pihole_enable="false"
    fi
    echo "internet_pi_pihole_enable: ${_pihole_enable}" >> "${config_file}"

    # Add Pi-hole password if Pi-hole is enabled
    if [[ "${ENABLE_PIHOLE}" == "Y" ]]; then
        cat >> "${config_file}" << EOF
# Pi-hole uses plain text password (not hash) for FTLCONF_webserver_api_password
pihole_password: "${PIHOLE_PASSWORD}"
EOF
    fi

    # Continue with the rest of the config
    # Docker Configuration
    cat >> "${config_file}" << EOF

internet_pi_enable_docker_health_monitor: true
EOF

    # Internet Monitoring Configuration
    local _monitoring_enable
    if [[ "${ENABLE_MONITORING}" == "Y" ]]; then
        _monitoring_enable="true"
    else
        _monitoring_enable="false"
    fi
    cat >> "${config_file}" << EOF
internet_pi_enable_internet_monitoring: ${_monitoring_enable}
EOF

    # Add Grafana password if monitoring is enabled
    if [[ "${ENABLE_MONITORING}" == "Y" ]]; then
        cat >> "${config_file}" << EOF
# Grafana uses plain text password (not hash) for GF_SECURITY_ADMIN_PASSWORD
monitoring_grafana_admin_password: "${PIHOLE_PASSWORD}"
EOF
    fi

    # Shelly Plug Configuration
    local _shelly_enable
    if [[ "${ENABLE_SHELLY}" == "Y" ]]; then
        _shelly_enable="true"
    else
        _shelly_enable="false"
    fi
    
    # AirGradient Configuration
    local _airgradient_enable
    if [[ "${ENABLE_AIRGRADIENT}" == "Y" ]]; then
        _airgradient_enable="true"
    else
        _airgradient_enable="false"
    fi

    # Starlink Configuration
    local _starlink_enable
    if [[ "${ENABLE_STARLINK}" == "Y" ]]; then
        _starlink_enable="true"
    else
        _starlink_enable="false"
    fi

    cat >> "${config_file}" << EOF
internet_pi_shelly_plug_enable: ${_shelly_enable}
internet_pi_shelly_plug_hostname: ""
internet_pi_shelly_plug_username: ""
internet_pi_shelly_plug_password: ""

# AirGradient Configuration
internet_pi_airgradient_enable: ${_airgradient_enable}
internet_pi_airgradient_address: ""

# Starlink Configuration
internet_pi_starlink_enable: ${_starlink_enable}

# External monitoring (disabled by default)
internet_pi_external_host_enable: false
internet_pi_external_host_address: ""

# Speed test configuration (conservative for metered connections)
internet_pi_speedtest_interval: 60  # minutes between tests
internet_pi_speedtest_server: ""    # auto-select best server

# Timezone
internet_pi_timezone: "${system_timezone}"

# Service Configuration
internet_pi_enable_wifi: false

# Docker Configuration
docker_enable: true
docker_users:
  - ${USER}
EOF
    
    print_status "Generated Ansible config with proper variable expansion"
    print_debug "Config file location: ${config_file}"
    
    # Create inventory file
    cat > "${repo_dir}/inventory" << EOF
[internet_pi]
localhost ansible_connection=local ansible_user=${USER}
EOF
    
    set_state "CONFIG_GENERATION"
    print_success "Ansible configuration generated"
}

run_ansible_playbook() {
    if is_state_complete "ANSIBLE_PLAYBOOK"; then
        print_status "Ansible playbook already executed, skipping..."
        return 0
    fi
    
    print_step "Running Ansible playbook"
    
    local repo_dir="${DS_INTERNET_PI_DIR}"
    
    cd "${repo_dir}" || exit 1
    
    print_status "Executing main.yml playbook..."
    
    # Use virtual environment ansible-playbook if it exists
    local venv_dir="${HOME}/.local/venv-ansible"
    if [[ -f "${venv_dir}/bin/ansible-playbook" ]]; then
        print_status "Using virtual environment ansible-playbook..."
        if "${venv_dir}/bin/ansible-playbook" -i inventory main.yml; then
            set_state "ANSIBLE_PLAYBOOK"
            print_success "Ansible playbook execution completed"
        else
            print_warning "Ansible playbook execution encountered errors"
            print_status "This is normal during initial setup - some services may need a reboot to initialize properly"
            show_prominent_reboot_message
            sleep 5
            sudo reboot
        fi
    else
        # Fallback to system ansible-playbook
        export PATH="${HOME}/.local/bin:${PATH}"
        if ansible-playbook -i inventory main.yml; then
            set_state "ANSIBLE_PLAYBOOK"
            print_success "Ansible playbook execution completed"
        else
            print_warning "Ansible playbook execution encountered errors"
            print_status "This is normal during initial setup - some services may need a reboot to initialize properly"
            show_prominent_reboot_message
            sleep 5
            sudo reboot
        fi
    fi
}

deploy_containers() {
    if is_state_complete "CONTAINER_DEPLOYMENT"; then
        print_status "Containers already deployed, skipping..."
        return 0
    fi
    
    print_step "Deploying Docker containers"
    
    local repo_dir="${DS_INTERNET_PI_DIR}"
    cd "${repo_dir}" || exit 1
    
    if [[ -f "docker-compose.yml" ]]; then
        print_status "Starting containers with docker-compose..."
        
        # Use sudo if docker group is not active yet
        local DOCKER_CMD="docker"
        if ! docker ps >/dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
            print_status "Using sudo for docker commands (group not active yet)..."
        fi
        
        # Stop any existing containers first (clean start)
        print_status "Stopping any existing containers..."
        ${DOCKER_CMD} compose down 2>/dev/null || true
        
        # Pull latest images
        print_status "Pulling latest Docker images..."
        if ! ${DOCKER_CMD} compose pull; then
            print_warning "Some images may not have been updated, continuing..."
        fi
        
        # Start containers in detached mode
        print_status "Starting containers..."
        if ${DOCKER_CMD} compose up -d; then
            print_success "Containers started successfully"
            
            # Wait for containers to initialize
            print_status "Waiting for containers to initialize (30 seconds)..."
            sleep 30
            
            # Check container status
            print_status "Container status:"
            ${DOCKER_CMD} compose ps
        else
            print_error "Failed to start containers"
            print_status "Docker compose logs:"
            ${DOCKER_CMD} compose logs --tail=20
            return 1
        fi
    else
        print_warning "docker-compose.yml not found, containers may have been started by Ansible"
    fi
    
    cd - >/dev/null
    set_state "CONTAINER_DEPLOYMENT"
    print_success "Container deployment completed"
}

install_padd() {
    if is_state_complete "PADD_INSTALL"; then
        print_status "PADD already installed, skipping..."
        return 0
    fi
    
    print_step "Installing PADD (Pi-hole Admin Dashboard Display)"
    
    # Load configuration to check if Pi-hole is enabled
    if [[ -f "${CONFIG_FILE}" ]]; then
        # shellcheck disable=SC1090
        source "${CONFIG_FILE}"
    fi
    
    if [[ "${ENABLE_PIHOLE^^}" != "Y" ]]; then
        print_status "Pi-hole not enabled, skipping PADD installation"
        set_state "PADD_INSTALL"
        return 0
    fi
    
    # Use sudo if docker group is not active yet
    local DOCKER_CMD="docker"
    if ! docker ps >/dev/null 2>&1; then
        DOCKER_CMD="sudo docker"
    fi
    
    # Check if Pi-hole container is running
    if ! ${DOCKER_CMD} ps | grep -q pihole; then
        print_warning "Pi-hole container not running, skipping PADD installation"
        print_status "You can install PADD later when Pi-hole is running"
        set_state "PADD_INSTALL"
        return 0
    fi
    
    print_status "Installing PADD in Pi-hole container..."
    
    # Download and install PADD script directly in container
    if ${DOCKER_CMD} exec pihole bash -c \
        'timeout 60 curl -sSL --connect-timeout 10 --max-time 30 \
        https://raw.githubusercontent.com/pi-hole/PADD/master/padd.sh \
        -o /usr/local/bin/padd.sh && chmod +x /usr/local/bin/padd.sh' \
        >/dev/null 2>&1; then
        print_success "PADD installed successfully in Pi-hole container"
        
        # Create improved PADD aliases
        local padd_alias="alias padd=\"${DOCKER_CMD} exec -it pihole /usr/local/bin/padd.sh\""
        local padd_alias_fallback="alias padd-simple=\"${DOCKER_CMD} exec pihole pihole -c -e\""
        
        if ! grep -q "alias padd=" "${HOME}/.bashrc" 2>/dev/null; then
            {
                echo ""
                echo "# Pi-hole PADD aliases"
                echo "${padd_alias}"
                echo "${padd_alias_fallback}"
                echo "# Use 'padd' for full dashboard or 'padd-simple' for basic stats"
            } >> "${HOME}/.bashrc"
            print_success "PADD aliases added to ~/.bashrc"
            print_status "You can now run 'padd' command to view Pi-hole dashboard"
            print_status "Note: You may need to restart your terminal or run 'source ~/.bashrc'"
        else
            print_status "PADD aliases already exist in ~/.bashrc"
        fi
        
    else
        print_warning "PADD installation failed - Pi-hole container may not be ready yet"
        print_status "You can install PADD later with the update script: ./update.sh"
    fi
    
    set_state "PADD_INSTALL"
    print_success "PADD installation completed"
}

#===============================================================================
# Function: harden_pi_security
# Description: Apply comprehensive security hardening to the Raspberry Pi
# Parameters: None
# Returns: 0 on success, exits on failure
#===============================================================================
harden_pi_security() {
    if is_state_complete "HARDENING"; then
        print_status "Pi security hardening already applied, skipping..."
        return 0
    fi
    
    print_step "Applying comprehensive security hardening"
    print_warning "This will configure firewall, SSH, and system security settings"
    
    # Allow dry-run mode
    local SUDO="sudo"
    if [[ "${DRY_RUN}" == "1" ]]; then
        SUDO="echo [DRY-RUN] sudo"
        print_status "Running in DRY-RUN mode — no changes will be made"
    fi
    
    print_status "[*] Updating package lists..."
    ${SUDO} apt-get update -y && ${SUDO} apt-get upgrade -y
    
    print_status "[*] Installing security essentials..."
    ${SUDO} apt-get install -y unattended-upgrades apt-listchanges fail2ban ufw curl wget vim
    
    print_status "[*] Enabling automatic security updates..."
    if [[ "${DRY_RUN}" != "1" ]]; then
        # Use non-interactive mode for unattended-upgrades
        echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | ${SUDO} debconf-set-selections
        ${SUDO} dpkg-reconfigure -f noninteractive unattended-upgrades
    else
        echo "[DRY-RUN] Would configure unattended-upgrades"
    fi
    
    print_status "[*] Initializing UFW firewall..."
    # Ensure UFW service is available and reset to clean state
    ${SUDO} systemctl enable ufw
    ${SUDO} ufw --force reset
    
    print_status "[*] Configuring UFW firewall..."
    ${SUDO} ufw --force default deny incoming
    ${SUDO} ufw --force default allow outgoing
    ${SUDO} ufw allow 22/tcp
    # Allow Pi-hole web interface
    ${SUDO} ufw allow 80/tcp
    ${SUDO} ufw allow 53
    # Allow Grafana if monitoring is enabled
    if [[ -f "${CONFIG_FILE}" ]]; then
        # shellcheck disable=SC1090
        source "${CONFIG_FILE}"
        if [[ "${ENABLE_MONITORING^^}" == "Y" ]]; then
            ${SUDO} ufw allow 3000/tcp
            print_status "Added firewall rule for Grafana monitoring"
        fi
    fi
    echo "y" | ${SUDO} ufw --force enable
    
    print_status "[*] Hardening SSH configuration..."
    # Backup SSH config before modification
    if [[ "${DRY_RUN}" != "1" ]]; then
        local backup_timestamp
        backup_timestamp=$(date +%Y%m%d_%H%M%S)
        ${SUDO} cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.backup.${backup_timestamp}"
    fi
    
    # Note: Not disabling password authentication by default as it may lock users out
    ${SUDO} sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    ${SUDO} sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    ${SUDO} sed -i 's/^#\?AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config
    ${SUDO} systemctl restart ssh
    
    print_status "[*] Applying sysctl hardening..."
    if [[ "${DRY_RUN}" != "1" ]]; then
        ${SUDO} tee /etc/sysctl.d/99-custom-hardening.conf >/dev/null <<'EOF'
# IP spoofing protection
net.ipv4.conf.all.rp_filter=1
net.ipv4.conf.default.rp_filter=1
# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts=1
# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses=1
# Disable source routing
net.ipv4.conf.all.accept_source_route=0
net.ipv4.conf.default.accept_source_route=0
# Enable SYN cookies
net.ipv4.tcp_syncookies=1
# Disable IPv6 if not needed (uncomment if desired)
# net.ipv6.conf.all.disable_ipv6=1
# net.ipv6.conf.default.disable_ipv6=1
EOF
        ${SUDO} sysctl --system
    else
        echo "[DRY-RUN] Would create /etc/sysctl.d/99-custom-hardening.conf"
    fi
    
    print_status "[*] Disabling unused services..."
    for svc in avahi-daemon triggerhappy bluetooth; do
        if systemctl list-unit-files | grep -q "^${svc}"; then
            ${SUDO} systemctl disable --now "${svc}" 2>/dev/null || true
            print_status "Disabled service: ${svc}"
        fi
    done
    
    print_status "[*] Setting up log cleanup..."
    if [[ "${DRY_RUN}" != "1" ]]; then
        ${SUDO} mkdir -p /etc/systemd/journald.conf.d
        ${SUDO} tee /etc/systemd/journald.conf.d/clean.conf >/dev/null <<'EOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
MaxRetentionSec=7day
EOF
        ${SUDO} systemctl restart systemd-journald
    else
        echo "[DRY-RUN] Would configure journald log cleanup"
    fi
    
    print_status "[*] Configuring fail2ban for SSH protection..."
    if [[ "${DRY_RUN}" != "1" ]]; then
        ${SUDO} tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
        ${SUDO} systemctl enable fail2ban
        ${SUDO} systemctl restart fail2ban
    else
        echo "[DRY-RUN] Would configure fail2ban"
    fi
    
    set_state "HARDENING"
    print_success "🔒 Security hardening completed successfully!"
    print_status "🔥 Firewall (UFW) is now active and protecting your Pi"
    print_status "🛡️  fail2ban is monitoring SSH for brute force attempts"
    print_status "📦 Automatic security updates are enabled"
    
    return 0
}

verify_installation() {
    if is_state_complete "VERIFICATION"; then
        print_status "Installation already verified, skipping..."
        return 0
    fi
    
    print_step "Verifying installation"
    
    # Load configuration
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
    
    local all_good=true
    local container_issues=false
    
    # Use sudo if docker group is not active yet
    local DOCKER_CMD="docker"
    if ! docker ps >/dev/null 2>&1; then
        if sudo docker ps >/dev/null 2>&1; then
            DOCKER_CMD="sudo docker"
            rich_check "Docker Access" "WARN" "Docker requires sudo (group not active yet)"
        else
            rich_check "Docker Access" "FAIL" "Docker is not accessible"
            all_good=false
        fi
    else
        rich_check "Docker Access" "PASS" "Docker is working properly"
    fi
    
    # Wait for containers to start (they may take a moment)
    print_status "Waiting for containers to fully initialize..."
    sleep 10
    
    # Verify containers based on configuration
    if [[ "${ENABLE_PIHOLE}" == "Y" ]]; then
        if ${DOCKER_CMD} ps --format "{{.Names}}" | grep -q "pihole"; then
            rich_check "Pi-hole Container" "PASS" "Container is running"
            
            # Check if Pi-hole web interface is accessible
            if timeout 10 curl -s --connect-timeout 5 http://localhost/admin >/dev/null; then
                rich_check "Pi-hole Web Interface" "PASS" "Accessible at http://localhost/admin"
            else
                rich_check "Pi-hole Web Interface" "WARN" "Not yet accessible (may still be starting)"
            fi
        else
            rich_check "Pi-hole Container" "FAIL" "Container is not running"
            container_issues=true
            all_good=false
        fi
    fi
    
    if [[ "${ENABLE_MONITORING}" == "Y" ]]; then
        if ${DOCKER_CMD} ps --format "{{.Names}}" | grep -q "grafana"; then
            rich_check "Grafana Container" "PASS" "Container is running"
        else
            rich_check "Grafana Container" "WARN" "Container not found"
            container_issues=true
        fi
        
        if ${DOCKER_CMD} ps --format "{{.Names}}" | grep -q "prometheus"; then
            rich_check "Prometheus Container" "PASS" "Container is running"
        else
            rich_check "Prometheus Container" "WARN" "Container not found"
            container_issues=true
        fi
    fi
    
    # Check system resources
    local free_space
    free_space=$(df / | awk 'NR==2 {print $4}')
    if [[ ${free_space} -lt 1000000 ]]; then  # Less than 1GB
        local free_space_human
        free_space_human=$(df -h / | awk 'NR==2 {print $4}')
        rich_check "Disk Space" "WARN" "Low disk space: ${free_space_human} free"
    else
        rich_check "Disk Space" "PASS" "Sufficient disk space available"
    fi
    
    # Check Rich library installation
    if python3 -c "import rich" >/dev/null 2>&1; then
        rich_check "Rich Library" "PASS" "Enhanced formatting available"
    else
        rich_check "Rich Library" "INFO" "Using fallback formatting"
    fi
    
    if [[ "${container_issues}" == "true" ]]; then
        print_warning "Some containers are not running as expected"
        print_status "This is normal during initial startup - containers may still be starting"
        print_status "Run ./status.sh later to verify all services are operational"
    else
        print_success "All expected containers are running"
    fi
    
    if [[ "${all_good}" == true ]]; then
        set_state "VERIFICATION"
        print_success "Installation verification completed successfully"
    else
        print_error "Some verification checks failed"
        return 1
    fi
}

cleanup_installation() {
    if is_state_complete "CLEANUP"; then
        print_status "Cleanup already completed, skipping..."
        return 0
    fi
    
    print_step "Performing cleanup"
    
    # Remove temporary files
    rm -f get-docker.sh
    
    # Clean up apt cache
    sudo apt autoremove -y
    sudo apt autoclean
    
    # Rotate logs if they get too large (>10MB)
    if [[ -f "${LOG_FILE}" ]]; then
        local log_size
        log_size=$(stat -c%s "${LOG_FILE}" 2>/dev/null || echo 0)
        if [[ ${log_size} -gt 10485760 ]]; then
            log_info "Rotating large log file"
            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            mv "${LOG_FILE}" "${LOG_FILE}.${timestamp}"
            touch "${LOG_FILE}"
            
            # Keep only last 3 rotated logs
            find "$(dirname "${LOG_FILE}")" -name "$(basename "${LOG_FILE}").*" -type f | sort | head -n -3 | xargs -r rm
        fi
    fi
    
    set_state "CLEANUP"
    print_success "Cleanup completed"
}

show_completion_summary() {
    print_step "Installation Complete!"
    
    # shellcheck disable=SC1090
    source "${CONFIG_FILE}"
    
    # Show completion header with Rich if available
    if use_rich_if_available; then
        python3 -c "
from rich.console import Console
from rich.panel import Panel
from rich.text import Text
from rich.align import Align
from rich import box

console = Console()

header_text = Text()
header_text.append('🌟 DEATH STAR OPERATIONAL 🌟', style='bold green')

panel = Panel(
    Align.center(header_text),
    box=box.DOUBLE,
    border_style='green',
    padding=(1, 2)
)
console.print(panel)
"
    else
        echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "                 ${CYAN}🌟 DEATH STAR OPERATIONAL 🌟${NC}                   "
        echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"
    fi
    
    # Get Pi's IP address for service URLs
    local pi_ip
    pi_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    if [[ -z "${pi_ip}" ]]; then
        pi_ip="<YOUR_PI_IP>"
    fi
    
    echo -e "${CYAN}Services Installed:${NC}"
    
    if [[ "${ENABLE_PIHOLE}" == "Y" ]]; then
        echo -e "  ${GREEN}✓${NC} Pi-hole ad blocking"
        echo -e "    └ Web interface: ${BLUE}http://${DS_NEW_HOSTNAME}/admin${NC}"
        echo -e "    └ Alternative: ${BLUE}http://${pi_ip}/admin${NC}"
        echo -e "    └ Password: ${YELLOW}${PIHOLE_PASSWORD}${NC}"
    fi
    
    if [[ "${ENABLE_MONITORING}" == "Y" ]]; then
        echo -e "  ${GREEN}✓${NC} Internet monitoring"
        echo -e "    └ Grafana: ${BLUE}http://${DS_NEW_HOSTNAME}:${DS_GRAFANA_PORT}${NC}"
        echo -e "    └ Alternative: ${BLUE}http://${pi_ip}:${DS_GRAFANA_PORT}${NC}"
        echo -e "    └ Prometheus: ${BLUE}http://${DS_NEW_HOSTNAME}:${DS_PROMETHEUS_PORT}${NC}"
        echo -e "    └ Alternative: ${BLUE}http://${pi_ip}:${DS_PROMETHEUS_PORT}${NC}"
    fi
    
    [[ "${ENABLE_SHELLY}" == "Y" ]] && echo -e "  ${GREEN}✓${NC} Shelly plug monitoring"
    [[ "${ENABLE_AIRGRADIENT}" == "Y" ]] && echo -e "  ${GREEN}✓${NC} AirGradient air quality monitoring"
    [[ "${ENABLE_STARLINK}" == "Y" ]] && echo -e "  ${GREEN}✓${NC} Starlink satellite monitoring"
    
    echo -e "\n${CYAN}Useful Commands:${NC}"
    echo -e "  ${YELLOW}docker ps${NC}                    - View running containers"
    echo -e "  ${YELLOW}docker compose logs${NC}          - View container logs"
    echo -e "  ${YELLOW}sudo systemctl status docker${NC} - Check Docker service status"
    if [[ "${ENABLE_PIHOLE}" == "Y" ]] && grep -q "alias padd=" "${HOME}/.bashrc" 2>/dev/null; then
        echo -e "  ${YELLOW}padd${NC}                         - View Pi-hole dashboard"
    fi
    echo -e "  ${YELLOW}./status.sh${NC}                  - Check system status anytime"
    
    echo -e "\n${GREEN}Your Death Star Pi is now operational!${NC}"
    
    # Log session completion
    log_success "Death Star Pi Setup Session Completed Successfully"
    
    set_state "COMPLETE"
    
    # Final reboot recommendation
    is_state_complete "HARDENING"
    if [[ $? -eq 0 && "${DRY_RUN}" != "1" ]]; then
        echo -e "\n${YELLOW}🔄 Final reboot recommended to activate all security hardening...${NC}"
        read -r -p "Reboot now to complete setup? (Y/n): " FINAL_REBOOT
        FINAL_REBOOT=${FINAL_REBOOT:-Y}
        
        if [[ "${FINAL_REBOOT^^}" == "Y" ]]; then
            print_success "🚀 Rebooting system to activate all security settings..."
            sleep 5
            sudo reboot
        else
            print_warning "⚠️  Manual reboot recommended to ensure all security settings are active"
            echo -e "${YELLOW}Run 'sudo reboot' when ready${NC}"
        fi
    fi
}

# Main execution flow
main() {
    # Initialize logging system
    init_logging
    
    print_header
    
    local current_state
    current_state=$(get_current_state)
    print_status "Current state: ${current_state}"
    
    # Phase 1: System preparation and dependency installation
    if ! is_state_complete "SYSTEM_UPDATE"; then
        install_system_updates
    fi
    
    if ! is_state_complete "CORE_PACKAGES"; then
        install_core_packages
    fi
    
    # Install Fastfetch system information tool with state management
    if ! is_state_complete "FASTFETCH_INSTALL"; then
        install_fastfetch
    fi
    
    if ! is_state_complete "DOCKER_INSTALL"; then
        install_docker
    fi
    
    if ! is_state_complete "DOCKER_VERIFY"; then
        if ! verify_docker; then
            print_warning "Docker verification failed - continuing to see if reboot resolves it"
        fi
    fi
    
    if ! is_state_complete "ANSIBLE_INSTALL"; then
        install_ansible
    fi
    
    if ! is_state_complete "ANSIBLE_VERIFY"; then
        if ! verify_ansible; then
            print_error "Ansible verification failed"
            exit 1
        fi
    fi
    
    if ! is_state_complete "PI5_OPTIMIZATIONS"; then
        apply_pi5_optimizations
    fi
    
    if ! is_state_complete "RPI_CONNECT_CONSOLE"; then
        configure_rpi_connect_for_console
    fi
    
    if ! is_state_complete "HOSTNAME_CHANGE"; then
        change_hostname
    fi
    
    # Check if reboot is required
    if ! is_state_complete "REBOOT_REQUIRED"; then
        if check_reboot_required; then
            perform_reboot
            # Script will exit here and resume after reboot
        fi
    fi
    
    # Phase 2: Repository and configuration
    if ! is_state_complete "INTERNET_PI_CLONE"; then
        clone_internet_pi
    fi
    
    if ! is_state_complete "ANSIBLE_COLLECTIONS"; then
        install_ansible_collections
    fi
    
    if ! is_state_complete "CONFIG_GENERATION"; then
        collect_user_preferences
        generate_ansible_config
    fi
    
    # Phase 3: Service deployment
    if ! is_state_complete "ANSIBLE_PLAYBOOK"; then
        run_ansible_playbook
    fi
    
    if ! is_state_complete "CONTAINER_DEPLOYMENT"; then
        deploy_containers
    fi
    
    if ! is_state_complete "PADD_INSTALL"; then
        install_padd
    fi
    
    # Phase 4: Verification and cleanup
    if ! is_state_complete "VERIFICATION"; then
        verify_installation
    fi
    
    if ! is_state_complete "HARDENING"; then
        harden_pi_security
    fi
    
    if ! is_state_complete "CLEANUP"; then
        cleanup_installation
    fi
    
    if ! is_state_complete "COMPLETE"; then
        show_completion_summary
    fi
    
    print_success "Death Star Pi setup completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --reset)
        print_warning "Resetting setup state..."
        rm -f "${STATE_FILE}" "${CONFIG_FILE}"
        print_status "State reset. Run script again to start fresh."
        exit 0
    ;;
    --status)
        current_state=$(get_current_state)
        echo "Current state: ${current_state}"
        if [[ -f "${CONFIG_FILE}" ]]; then
            echo "Configuration file exists: ${CONFIG_FILE}"
        else
            echo "No configuration file found"
        fi
        echo "Log files:"
        echo "  Main log: ${LOG_FILE}"
        echo "  Error log: ${LOG_ERROR_FILE}"
        echo "  Debug log: ${LOG_DEBUG_FILE}"
        exit 0
    ;;
    --debug)
        export DEBUG=true
        echo "Debug mode enabled"
        shift
        # Continue execution with debug enabled
    ;;
    --help)
        echo "Death Star Pi-hole Setup Script"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  (no args)  - Run setup (resumes from last state)"
        echo "  --reset    - Reset setup state and start over"
        echo "  --status   - Show current setup state and log files"
        echo "  --debug    - Enable debug logging and verbose output"
        echo "  --help     - Show this help message"
        echo ""
        echo "Environment Variables:"
        echo "  DEBUG=true     - Enable debug logging"
        echo "  VERBOSE=true   - Enable verbose output"
        echo "  DRY_RUN=1      - Run in dry-run mode (no changes)"
        exit 0
    ;;
    *)
        # Default case - no arguments or unknown argument, continue with normal execution
        if [[ -n "${1:-}" ]]; then
            print_warning "Unknown argument: $1"
            print_status "Use --help for usage information"
        fi
    ;;
esac

# Check if running as root
if [[ ${EUID} -eq 0 ]]; then
    print_error "This script should not be run as root"
    print_status "Run as a regular user - it will prompt for sudo when needed"
    exit 1
fi

# Start main execution
main "$@"