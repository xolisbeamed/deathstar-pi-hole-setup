#!/bin/bash
#===============================================================================
# File: push_to_pi.sh
# Project: Death Star Pi-hole Setup
# Description: Development deployment script for syncing local development
#              files to Raspberry Pi using rsync over SSH
#
# Development Environment:
#   OS: Fedora Linux 42 (KDE Plasma Desktop Edit4)
#   Shell: bash
#   Dependencies: rsync, ssh, config_loader.sh
#
# Author: galactic-plane
# Repository: https://github.com/galactic-plane/deathstar-pi-hole-setup
# License: See LICENSE file
#===============================================================================

# Load configuration system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/config_loader.sh" || {
    echo "Error: Could not load configuration system" >&2
    exit 1
}

# Initialize with fallback values if config system fails
init_config "" "" "" || {
    echo "Warning: Using fallback configuration values" >&2
    # Fallback color codes
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m'
    PI_IP=""
    SSH_TIMEOUT="5"
}

# Rich helper functions
RICH_HELPER="deathstar-pi-hole-setup/lib/rich_helper.py"

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

# Auto-detect local directory
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/"

# Configuration - will be set dynamically
REMOTE_BASE_PATH=""
PI_USER=""
PI_TARGET=""
REMOTE_DIR=""
SSH_AUTH_METHOD=""

# Function to print colored output
print_status() {
    rich_status "$1" "info"
}

print_success() {
    rich_status "$1" "success"
}

print_error() {
    rich_status "$1" "error"
}

print_warning() {
    rich_status "$1" "warning"
}

# Function to get Pi configuration
get_pi_config() {
    if [[ -z "${PI_USER}" ]]; then
        echo
        print_status "🤖 Death Star Pi Configuration Setup"
        echo
        
        # Get Pi IP address (require configuration)
        if [[ -z "${PI_IP}" ]]; then
            print_error "❌ Pi IP address not configured!"
            print_error "Please update config.json with your Pi's IP address in:"
            print_error "  \"network\" -> \"pi\" -> \"default_ip\""
            print_error "Or provide it as a command line argument: $0 username ip-address"
            exit 1
        fi
        
        print_status "What is your Pi's IP address? (current: ${PI_IP})"
        echo -e "${CYAN}Press Enter to use current, or type new IP:${NC}"
        read -r user_ip
        
        if [[ -n "${user_ip}" ]]; then
            PI_IP="${user_ip}"
        fi
        
        PI_TARGET="${PI_IP}"
        print_success "✅ Pi IP set to: ${PI_IP}"
        
        # Get Pi username
        echo
        print_status "🤖 What is your Pi username? (e.g., pi, r2-d2, etc.)"
        read -r PI_USER
        
        if [[ -z "${PI_USER}" ]]; then
            print_error "❌ Pi username is required!"
            exit 1
        fi
        
        # Load directory configuration with the username
        load_directory_config "${PI_USER}"
        REMOTE_DIR="${REMOTE_BASE_PATH}"
        print_success "✅ Pi configuration set for user: ${PI_USER}"
        print_status "📁 Remote directory: ${REMOTE_DIR}"
    fi
}

# Function to show banner
show_banner() {
    # Load banner configuration with current values
    load_banner_config "$(basename "${LOCAL_DIR}")" "${PI_USER}" "${PI_TARGET}"
    
    rich_header "${PUSH_TITLE:-🚀 Death Star Pi Development Push 🤖}" "${PUSH_SUBTITLE:-Deploying to Death Star Pi}"
    echo -e "${CYAN}📁 Local Directory: ${NC}${LOCAL_DIR}"
    echo -e "${CYAN}🎯 Remote Directory: ${NC}${REMOTE_DIR}"
    echo
}

# Function to check connectivity
check_connectivity() {
    print_status "🔍 Checking connectivity to Death Star Pi at ${PI_IP}..."
    
    if ping -c 1 -W "${SSH_TIMEOUT:-5}" "${PI_IP}" >/dev/null 2>&1; then
        PI_TARGET="${PI_IP}"
        print_success "✅ Connected to ${PI_IP}"
    else
        print_error "❌ Cannot reach Death Star Pi at ${PI_IP}!"
        print_error "   Please check the IP address and Pi connectivity"
        exit 1
    fi
}

# Function to check SSH access and ensure key authentication
check_ssh_access() {
    print_status "🔐 Testing SSH access to ${PI_TARGET}..."
    
    local ssh_test_result
    test_ssh_connectivity "${PI_USER}" "${PI_TARGET}" "yes"
    ssh_test_result=$?
    
    if [[ ${ssh_test_result} -eq 0 ]]; then
        print_success "✅ SSH key authentication working - passwordless access confirmed!"
        SSH_AUTH_METHOD="key"
        return 0
    else
        print_error "❌ SSH key authentication failed!"
        echo
        
        # Try to detect and resolve host key issues
        print_status "🔍 Checking for SSH host key issues..."
        test_ssh_connectivity "${PI_USER}" "${PI_TARGET}" "no" "yes"
        ssh_test_result=$?
        
        if [[ ${ssh_test_result} -eq 0 ]]; then
            print_success "✅ SSH key authentication working after host key resolution!"
            SSH_AUTH_METHOD="key"
            return 0
        elif [[ ${ssh_test_result} -eq 2 ]]; then
            print_status "🔍 Host key issue resolved, but SSH key authentication still needed."
        fi
        
        echo
        print_warning "🔒 REQUIRED: SSH key authentication is mandatory for Death Star deployment"
        echo -e "${YELLOW}The Death Star Pi setup includes security hardening that disables SSH password authentication.${NC}"
        echo -e "${YELLOW}SSH keys are required for secure file transfer and automated deployment.${NC}"
        echo
        
        # Check if SSH keys exist
        if [[ ! -f ~/.ssh/id_rsa.pub ]] && [[ ! -f ~/.ssh/id_ed25519.pub ]] && [[ ! -f ~/.ssh/id_ecdsa.pub ]]; then
            print_status "🔑 No SSH key found on this system."
            echo -e "${CYAN}We'll create a new SSH key and configure it for Pi access.${NC}"
        else
            print_status "🔑 SSH key found but not configured for Pi access."
            echo -e "${CYAN}We'll configure your existing SSH key for Pi access.${NC}"
        fi
        
        echo
        print_status "🚀 Setting up SSH key authentication (REQUIRED for Death Star deployment)..."
        read -p "Continue with SSH key setup? (Y/n): " -r setup_keys
        setup_keys=${setup_keys:-Y}
        
        if [[ "${setup_keys^^}" == "Y" ]]; then
            if setup_ssh_keys_mandatory; then
                # SSH key setup succeeded, test the connection
                if test_ssh_connectivity "${PI_USER}" "${PI_TARGET}" "yes"; then
                    SSH_AUTH_METHOD="key"
                    print_success "✅ SSH key setup successful - ready for Death Star deployment!"
                    echo
                    echo -e "${CYAN}🔄 SSH key setup complete! Please run the script again to proceed with deployment:${NC}"
                    echo -e "${YELLOW}    ./push_to_pi.sh${NC}"
                    echo
                    echo -e "${GREEN}Next run will use passwordless SSH and sync your files to the Pi.${NC}"
                    exit 0
                else
                    print_error "❌ SSH key setup verification failed"
                    print_error "Cannot proceed with deployment without SSH key authentication"
                    echo
                    print_status "💡 Troubleshooting steps:"
                    echo -e "  1. Ensure Pi is accessible: ping ${PI_TARGET}"
                    echo -e "  2. Verify Pi allows SSH: ssh ${PI_USER}@${PI_TARGET} (manually)"
                    echo -e "  3. Check SSH service on Pi: sudo systemctl status ssh"
                    echo -e "  4. Ensure ~/.ssh/authorized_keys exists on Pi"
                    exit 1
                fi
            else
                # SSH key setup failed
                print_error "❌ SSH key setup failed"
                print_error "Cannot proceed with deployment without SSH key authentication"
                exit 1
            fi
        else
            print_error "❌ Cannot proceed without SSH key authentication"
            echo -e "${RED}SSH keys are mandatory for Death Star Pi deployment!${NC}"
            echo -e "${YELLOW}The deployment process requires secure file transfer capabilities.${NC}"
            exit 1
        fi
    fi
}

# Function to warn about multiple login prompts and offer SSH key setup
warn_about_login_prompts() {
    # Check if SSH keys are already working
    if [[ "${SSH_AUTH_METHOD}" == "key" ]]; then
        echo
        print_success "🎉 SSH keys already configured - no password prompts needed!"
        echo -e "${GREEN}✅ Passwordless authentication active${NC}"
        echo -e "${GREEN}✅ Deployment will proceed smoothly without interruptions${NC}"
        echo
        print_status "Press Enter to continue with passwordless deployment..."
        read -r
        return 0
    fi
    
    # If we get here, SSH keys are not working
    echo
    print_warning "⚠️  IMPORTANT LOGIN NOTICE ⚠️"
    echo -e "${YELLOW}"
    echo "══════════════════════════════════════════════════════════════════"
    echo "  You will be prompted for your Pi password MULTIPLE TIMES       "
    echo "  during this deployment process (typically 5+ times).           "
    echo ""
    echo "  This is NORMAL behavior for:                                    "
    echo "  • Creating directories                                          "
    echo "  • Syncing files                                                 "
    echo "  • Setting permissions                                           "
    echo "  • Checking remote status                                        "
    echo "══════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    echo
    
    # Offer to set up SSH keys
    print_status "💡 Would you like to set up SSH keys to avoid repeated password prompts? (Y/n)"
    echo -e "${CYAN}This will copy your SSH public key to the Pi for passwordless authentication.${NC}"
    read -r setup_keys
    
    if [[ ! "${setup_keys}" =~ ^[Nn]$ ]]; then
        setup_ssh_keys
        # Update SSH_AUTH_METHOD if successful
        if test_ssh_connectivity "${PI_USER}" "${PI_TARGET}" "yes"; then
            SSH_AUTH_METHOD="key"
        fi
    else
        echo
        print_status "Press Enter to continue with password-based authentication..."
        read -r
    fi
}

# Function to handle SSH host key verification issues
handle_ssh_host_key_issue() {
    local pi_target="$1"
    local error_output="$2"
    
    # Check if this is a host key verification error
    if echo "${error_output}" | grep -q "WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED"; then
        print_warning "⚠️ SSH Host Key Verification Issue Detected"
        echo
        echo -e "${YELLOW}🔍 The Pi's SSH host key has changed. This commonly happens when:${NC}"
        echo -e "  • Pi OS was reinstalled or updated"
        echo -e "  • Pi hardware was replaced"
        echo -e "  • Different device is now using this IP address"
        echo
        echo -e "${CYAN}💡 This can be safely resolved by updating the stored host key.${NC}"
        echo
        
        # Ask user if they want to automatically fix this
        local response
        echo -e "${YELLOW}🔧 Do you want to automatically update the stored host key? (Y/n):${NC}"
        read -r response
        response=${response:-y}
        
        if [[ ${response,,} =~ ^(y|yes)$ ]]; then
            print_status "🔧 Removing old host key for ${pi_target}..."
            
            if ssh-keygen -R "${pi_target}" >/dev/null 2>&1; then
                print_success "✅ Old host key removed successfully"
                echo -e "${GREEN}🔄 You can now retry the SSH key setup.${NC}"
                echo
                return 0
            else
                print_error "❌ Failed to remove old host key"
                return 1
            fi
        else
            print_status "📋 Manual fix instructions:"
            echo -e "${CYAN}Run this command to remove the old host key:${NC}"
            echo -e "${YELLOW}  ssh-keygen -R ${pi_target}${NC}"
            echo
            return 1
        fi
    fi
    
    return 1
}

# Function to test SSH connectivity with host key issue handling
test_ssh_connectivity() {
    local pi_user="$1"
    local pi_target="$2"
    local batch_mode="${3:-yes}"
    local check_host_key_only="${4:-no}"
    
    # First try with BatchMode for silent test (this only works with key auth)
    if ssh -o ConnectTimeout="${SSH_TIMEOUT:-5}" -o BatchMode=yes "${pi_user}@${pi_target}" exit 2>/dev/null; then
        return 0
    fi
    
    # If batch mode failed and we're checking for host key issues
    if [[ "${batch_mode}" != "yes" ]] || [[ "${check_host_key_only}" == "yes" ]]; then
        local ssh_output
        ssh_output=$(ssh -o ConnectTimeout="${SSH_TIMEOUT:-5}" -o StrictHostKeyChecking=ask "${pi_user}@${pi_target}" exit 2>&1)
        local ssh_exit_code=$?
        
        # Check if this is a host key verification issue
        if handle_ssh_host_key_issue "${pi_target}" "${ssh_output}"; then
            echo -e "${CYAN}🔄 Host key issue resolved. Testing key authentication again...${NC}"
            # Retry the connection after host key fix with BatchMode (key auth only)
            if ssh -o ConnectTimeout="${SSH_TIMEOUT:-5}" -o BatchMode=yes "${pi_user}@${pi_target}" exit 2>/dev/null; then
                return 0
            else
                echo -e "${YELLOW}Host key resolved, but SSH key authentication still not working.${NC}"
                return 2  # Special return code: host key fixed but key auth still needed
            fi
        fi
        
        # If interactive connection succeeded but we need to verify it was key-based
        if [[ ${ssh_exit_code} -eq 0 ]] && [[ "${check_host_key_only}" == "yes" ]]; then
            # This was just a host key check, now test if key auth actually works
            if ssh -o ConnectTimeout="${SSH_TIMEOUT:-5}" -o BatchMode=yes "${pi_user}@${pi_target}" exit 2>/dev/null; then
                return 0
            else
                return 2  # Host accessible but key auth not set up
            fi
        fi
    fi
    
    return 1
}

# Function to set up SSH keys (mandatory version)
setup_ssh_keys_mandatory() {
    print_status "🔑 Setting up SSH keys for secure Death Star deployment..."
    echo
    
    # Check if SSH key exists, create if needed
    local key_file=""
    if [[ -f ~/.ssh/id_ed25519.pub ]]; then
        key_file="${HOME}/.ssh/id_ed25519.pub"
        print_status "📋 Using existing Ed25519 key: ${key_file}"
        elif [[ -f ~/.ssh/id_rsa.pub ]]; then
        key_file="${HOME}/.ssh/id_rsa.pub"
        print_status "📋 Using existing RSA key: ${key_file}"
        elif [[ -f ~/.ssh/id_ecdsa.pub ]]; then
        key_file="${HOME}/.ssh/id_ecdsa.pub"
        print_status "� Using existing ECDSA key: ${key_file}"
    else
        print_status "�🔧 No SSH key found, generating a new Ed25519 key..."
        echo -e "${CYAN}Creating secure SSH key for Death Star deployment...${NC}"
        
        # Create .ssh directory if it doesn't exist
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        
        # Generate new Ed25519 key (more secure and faster than RSA)
        if ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "deathstar-pi-$(whoami || true)@$(hostname || true)-$(date +%Y%m%d || true)"; then
            key_file="${HOME}/.ssh/id_ed25519.pub"
            print_success "✅ SSH key generated successfully"
            echo -e "${GREEN}New Ed25519 key created: ~/.ssh/id_ed25519${NC}"
        else
            print_error "❌ Failed to generate SSH key"
            exit 1
        fi
    fi
    
    echo
    print_status "� Copying SSH key to Death Star Pi..."
    echo -e "${CYAN}You will need to enter the Pi password ONE FINAL TIME.${NC}"
    echo -e "${CYAN}After this, all deployments will use secure key authentication.${NC}"
    echo
    
    # Attempt to copy SSH key to Pi
    local max_attempts=3
    local attempt=1
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        print_status "🔐 Attempt ${attempt}/${max_attempts}: Copying SSH key to Pi..."
        
        # Capture both success and error output
        local ssh_output
        ssh_output=$(ssh-copy-id -o ConnectTimeout="${SSH_TIMEOUT:-10}" "${PI_USER}@${PI_TARGET}" 2>&1)
        local ssh_exit_code=$?
        
        if [[ ${ssh_exit_code} -eq 0 ]]; then
            print_success "✅ SSH key copied successfully to Death Star Pi!"
            echo -e "${GREEN}🚀 Secure key-based deployment is now active!${NC}"
            echo -e "${GREEN}🔒 Future deployments will be passwordless and secure.${NC}"
            return 0
        else
            print_warning "⚠️ Attempt ${attempt} failed"
            
            # Check if this is a host key verification issue
            if handle_ssh_host_key_issue "${PI_TARGET}" "${ssh_output}"; then
                echo -e "${CYAN}🔄 Host key issue resolved. Retrying ssh-copy-id...${NC}"
                continue
            fi
            
            if [[ ${attempt} -lt ${max_attempts} ]]; then
                echo -e "${YELLOW}💡 Common issues:${NC}"
                echo -e "  • Check Pi password is correct"
                echo -e "  • Ensure Pi SSH service is running"
                echo -e "  • Verify network connectivity"
                echo -e "  • SSH host key mismatch (script will auto-fix)"
                echo
                echo -e "${YELLOW}Error details:${NC}"
                echo "${ssh_output}" | head -5
                echo
                read -r -p "Press Enter to try again, or Ctrl+C to abort..."
            fi
        fi
        
        ((attempt++))
    done
    
    print_error "❌ Failed to copy SSH key after ${max_attempts} attempts"
    echo
    print_status "�️ Manual SSH key setup instructions:"
    echo -e "${CYAN}1. Connect to Pi manually:${NC} ssh ${PI_USER}@${PI_TARGET}"
    echo -e "${CYAN}2. Create .ssh directory:${NC} mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    echo -e "${CYAN}3. Copy this key content to Pi ~/.ssh/authorized_keys:${NC}"
    echo
    echo -e "${YELLOW}$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "No public key found" || true)${NC}"
    echo
    echo -e "${CYAN}4. Set permissions:${NC} chmod 600 ~/.ssh/authorized_keys"
    echo -e "${CYAN}5. Test deployment:${NC} ./push_to_pi.sh"
    echo
    return 1
}

# Function to show what will be synced
show_sync_preview() {
    print_status "📋 Files to be synchronized:"
    echo
    # Get files from configuration and display them
    while IFS= read -r file; do
        if [[ -n "${file}" ]] && [[ -f "${LOCAL_DIR}/${file}" ]]; then
            local filename
            filename=$(basename "${file}" || true)
            echo -e "  ${CYAN}📄${NC} ${filename}"
        fi
    done < <(get_files_to_sync || true)
    echo
}

# Function to create remote directories
create_remote_directories() {
    print_status "📁 Creating Repo directory structure on Pi..."
    
    # Create Repo directory if it doesn't exist, then create project directory and lib subdirectory
    # shellcheck disable=SC2029
    if ssh "${PI_USER}@${PI_TARGET}" "mkdir -p /home/${PI_USER}/Repo && mkdir -p ${REMOTE_DIR} && mkdir -p ${REMOTE_DIR}lib" 2>/dev/null; then
        print_success "✅ Remote directories created/verified"
    else
        print_error "❌ Failed to create remote directories"
        exit 1
    fi
}

# Function to perform the sync
sync_files() {
    print_status "🚀 Deploying Death Star Pi scripts to ${PI_USER}'s system..."
    
    # Create remote directories first
    create_remote_directories
    
    # Clean project directory for fresh deployment (but keep Repo directory)
    print_status "🧹 Cleaning project directory for fresh deployment..."
    # shellcheck disable=SC2029
    ssh "${PI_USER}@${PI_TARGET}" "rm -rf ${REMOTE_DIR}* && mkdir -p ${REMOTE_DIR}" 2>/dev/null
    
    # Build rsync command with files from configuration
    print_status "📦 Preparing file list from configuration..."
    
    # Sync the entire deathstar-pi-hole-setup directory structure to preserve subdirectories
    local rsync_opts="${RSYNC_OPTIONS:--avz --progress}"
    # shellcheck disable=SC2086
    if rsync ${rsync_opts} "${LOCAL_DIR}/deathstar-pi-hole-setup/" "${PI_USER}@${PI_TARGET}:${REMOTE_DIR}" && \
       rsync ${rsync_opts} "${LOCAL_DIR}/LICENSE" "${PI_USER}@${PI_TARGET}:${REMOTE_DIR}"; then
        print_success "✅ Files synchronized successfully!"
    else
        print_error "❌ Sync failed!"
        exit 1
    fi
}

# Function to set permissions
set_permissions() {
    print_status "🔧 Setting executable permissions on scripts..."
    
    local perms="${SCRIPT_PERMISSIONS:-755}"
    # shellcheck disable=SC2029
    if ssh "${PI_USER}@${PI_TARGET}" "chmod ${perms} ${REMOTE_DIR}*.sh" 2>/dev/null; then
        print_success "✅ Script permissions set to ${perms}"
    else
        print_warning "⚠️ Could not set permissions (scripts may not be executable)"
    fi
}

# Function to show remote status
show_remote_status() {
    print_status "📊 Remote Death Star Pi status:"
    echo
    
    # Show files on remote
    print_status "📁 Files on Death Star Core:"
    local ssh_output
    # shellcheck disable=SC2029
    ssh_output=$(ssh "${PI_USER}@${PI_TARGET}" "ls -la ${REMOTE_DIR}*.sh 2>/dev/null || true" || true) || true
    echo "${ssh_output}" | while read -r line; do
        [[ -n "${line}" ]] && echo "  ${line}"
    done
    
    echo
    print_status "🎯 Ready to execute on Death Star Pi:"
    echo -e "  🎯 Ready to execute on Death Star Pi:"
    echo -e "  ssh ${PI_USER}@${PI_TARGET}"
    echo -e "  cd ${REMOTE_DIR}"
    echo -e "  ${GREEN}./setup.sh${NC}"
}

# Function to validate local directory
validate_local_directory() {
    print_status "🔍 Validating local directory..."
    print_status "📁 Current directory: ${LOCAL_DIR}"
    
    if [[ ! -f "${LOCAL_DIR}/deathstar-pi-hole-setup/setup.sh" ]] || [[ ! -f "${LOCAL_DIR}/deathstar-pi-hole-setup/remove.sh" ]]; then
        print_error "❌ Not in Death Star Pi setup directory!"
        print_error "   Required files not found in: ${LOCAL_DIR}/deathstar-pi-hole-setup/"
        print_error "   Please run this script from the deathstar-pi-hole-setup directory"
        exit 1
    fi
    
    print_success "✅ Local directory validated"
}

# Function to offer quick SSH
offer_ssh() {
    echo
    print_status "💫 Would you like to SSH to the Death Star Pi now? (y/N)"
    read -r response
    if [[ "${response}" =~ ^[Yy]$ ]]; then
        print_status "🚀 Connecting to Death Star Pi..."
        ssh "${PI_USER}@${PI_TARGET}" -t "cd ${REMOTE_DIR} && bash"
    fi
}

# Main execution
main() {
    validate_local_directory
    get_pi_config
    show_banner
    
    check_connectivity
    check_ssh_access
    show_sync_preview
    
    # Confirm deployment
    print_status "🤖 Deploy to Death Star Pi system? (Y/n)"
    read -r confirm
    if [[ "${confirm}" =~ ^[Nn]$ ]]; then
        print_warning "⚠️ Deployment cancelled"
        exit 0
    fi
    
    sync_files
    set_permissions
    show_remote_status
    offer_ssh
    
    echo
    print_success "🌟 Death Star Pi deployment complete!"
    print_success "   The rebellion's plans have been delivered to ${PI_USER}! 🤖⭐"
}

# Handle command line arguments
case "${1:-}" in
    --quick|-q)
        validate_local_directory
        get_pi_config
        show_banner
        check_connectivity
        sync_files
        set_permissions
        print_success "🚀 Quick deployment complete!"
    ;;
    --ssh|-s)
        get_pi_config
        check_connectivity
        ssh "${PI_USER}@${PI_TARGET}" -t "cd ${REMOTE_DIR} && bash"
    ;;
    --status)
        get_pi_config
        check_connectivity
        show_remote_status
    ;;
    --help|-h)
        echo "Death Star Pi Deployment Script"
        echo
        echo "Usage: $0 [option]"
        echo
        echo "Features:"
        echo "  • Auto-detects local directory"
        echo "  • Prompts for Pi IP address (with default)"
        echo "  • Creates Repo directory structure automatically"
        echo "  • Auto-detects existing SSH keys (no prompts if working)"
        echo "  • Offers to set up SSH keys automatically"
        echo "  • Syncs files and sets permissions"
        echo "  • Warns about multiple SSH login prompts"
        echo
        echo "Options:"
        echo "  (none)     Interactive deployment with preview"
        echo "  --quick    Quick deployment without prompts"
        echo "  --ssh      SSH directly to Death Star Pi"
        echo "  --status   Show remote file status"
        echo "  --help     Show this help"
        echo
        echo "Setup:"
        echo "  1. Run script from deathstar-pi-hole-setup directory"
        echo "  2. Enter Pi IP address (or press Enter for default)"
        echo "  3. Enter your Pi username when prompted"
        echo "  4. Choose to set up SSH keys (recommended for easier access)"
        echo "  5. Script will create /home/[user]/Repo/deathstar-pi-hole-setup/"
        echo "  6. Files are synced and ready for ./setup.sh"
        echo
        echo "SSH Key Setup:"
        echo "  • Automatically detects if SSH keys are already working"
        echo "  • Skips prompts if passwordless authentication is active"
        echo "  • Automatically generates SSH key if none exists"
        echo "  • Copies key to Pi for passwordless authentication"
        echo "  • Eliminates multiple password prompts during deployment"
    ;;
    *)
        main
    ;;
esac
