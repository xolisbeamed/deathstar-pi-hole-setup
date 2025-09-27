#!/bin/bash
#===============================================================================
# File: connect_to_pi.sh
# Project: Death Star Pi-hole Setup
# Description: SSH connection script for quick access to R2-D2's Death Star Core System
#              Provides interactive SSH access with connection testing and failover
#
# Development Environment:
#   OS: Fedora Linux 42 (KDE Plasma Desktop Edit4)
#   Shell: bash
#   Dependencies: ssh, config_loader.sh
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

# Configuration - will be set dynamically
REMOTE_BASE_PATH=""
PI_USER=""
PI_TARGET=""
REMOTE_DIR=""
SSH_METHOD=""

# Rich helper configuration
RICH_HELPER="deathstar-pi-hole-setup/lib/rich_helper.py"

# Rich helper functions
use_rich_if_available() {
    command -v python3 >/dev/null 2>&1 && python3 -c "import rich" >/dev/null 2>&1
}

rich_header() {
    if use_rich_if_available; then
        python3 "${RICH_HELPER}" header --title "$1" --subtitle "${2:-}"
    else
        echo -e "${PURPLE}=============================================="
        echo "   $1"
        if [[ -n "${2:-}" ]]; then
            echo "   $2"
        fi
        echo -e "===============================================${NC}"
    fi
}

rich_status() {
    if use_rich_if_available; then
        python3 "${RICH_HELPER}" status --message "$1" --style "${2:-info}"
    else
        case "${2:-info}" in
            "success") echo -e "${GREEN}[SUCCESS]${NC} $1" ;;
            "error")   echo -e "${RED}[ERROR]${NC} $1" ;;
            "warning") echo -e "${YELLOW}[WARNING]${NC} $1" ;;
            *)         echo -e "${BLUE}[INFO]${NC} $1" ;;
        esac
    fi
}

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
        print_status "🤖 Death Star Pi Connection Setup"
        echo
        
        # Get Pi IP address (require configuration)
        if [[ -z "${PI_IP}" ]]; then
            print_error "❌ Pi IP address not configured!"
            print_error "Please update config.json with your Pi's IP address in:"
            print_error "  \"network\" -> \"pi\" -> \"default_ip\""
            print_error "Or provide it as a command line argument: $0 username ip-address"
            return 1
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
            return 1
        fi
        
        # Load directory configuration with the username
        load_directory_config "${PI_USER}"
        REMOTE_DIR="${REMOTE_BASE_PATH}"
        print_success "✅ Pi configuration set for user: ${PI_USER}"
        print_status "📁 Remote directory: ${REMOTE_DIR}"
    fi
}

# Function to check if push_to_pi has been run
check_push_to_pi_prerequisite() {
    echo
    print_warning "📋 IMPORTANT: Push to Pi Prerequisite Check"
    echo -e "${YELLOW}"
    echo "══════════════════════════════════════════════════════════════════"
    echo "  The 'connect_to_pi.sh' script connects to an EXISTING project   "
    echo "  directory that should have been created by 'push_to_pi.sh'      "
    echo ""
    echo "  If you haven't run 'push_to_pi.sh' first, the remote directory "
    echo "  may not exist and this connection will fail.                   "
    echo ""
    echo "  Expected remote directory:                                      "
    echo "  ${REMOTE_DIR}"
    echo ""
    echo "══════════════════════════════════════════════════════════════════"
    echo -e "${NC}"
    
    print_status "Have you already run './push_to_pi.sh' to deploy the project? (y/N)"
    read -r has_run_push
    
    if [[ ! "${has_run_push}" =~ ^[Yy]$ ]]; then
        print_error "❌ You need to run './push_to_pi.sh' first!"
        print_status "💡 The push script will:"
        echo "   • Create the remote directory structure"
        echo "   • Deploy all project files to the Pi"
        echo "   • Set up proper permissions"
        echo "   • Prepare the environment for connection"
        echo
        print_status "Please run './push_to_pi.sh' first, then try connecting again."
        return 1
    fi
    
    print_success "✅ Proceeding with connection to existing project directory"
    echo
}

# Function to show banner
show_banner() {
    # Load banner configuration with current values
    load_banner_config "$(basename "${PWD}")" "${PI_USER}" "${PI_TARGET}"
    
    rich_header "${CONNECT_TITLE:-🚀 Death Star Pi SSH Connect 🤖}" "${CONNECT_SUBTITLE:-Establishing connection to Death Star Pi}"
    echo -e "${CYAN}🎯 Remote Directory: ${NC}${REMOTE_DIR}"
    echo
}

# Function to show usage
show_usage() {
    echo "Death Star Pi SSH Connection Script"
    echo
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo
    echo "IMPORTANT: Run './push_to_pi.sh' first to deploy the project!"
    echo
    echo "Features:"
    echo "  • Auto-detects existing SSH keys for passwordless access"
    echo "  • Offers to set up SSH keys if not already configured"
    echo "  • Connects to deployed project directory automatically"
    echo "  • Verifies remote directory exists before connecting"
    echo
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -i, --info      Show connection information only"
    echo
    echo "Arguments:"
    echo "  COMMAND         Optional command to run on the Pi (in quotes)"
    echo
    echo "Examples:"
    echo "  $0                           Connect to Pi interactively"
    echo "  $0 \"./status.sh\"         Run status check on Pi"
    echo "  $0 \"docker ps\"               Check running containers"
    echo "  $0 --info                   Show connection details"
    echo
    echo "Prerequisites:"
    echo "  1. Run './push_to_pi.sh' to deploy project files"
    echo "  2. Ensure Pi is accessible and project directory exists"
    echo
    echo "SSH Key Setup:"
    echo "  • Script automatically detects if SSH keys are working"
    echo "  • Offers to set up SSH keys for passwordless connections"
    echo "  • Future connections will be seamless after key setup"
    echo
}

# Function to test connectivity
test_connectivity() {
    print_status "🔍 Testing connection to Death Star Pi at ${PI_IP}..."
    
    if ping -c 1 -W "${SSH_TIMEOUT:-5}" "${PI_IP}" >/dev/null 2>&1; then
        PI_TARGET="${PI_IP}"
        print_success "✅ Connected to ${PI_IP}"
        return 0
    else
        print_error "❌ Cannot reach Death Star Pi at ${PI_IP}"
        print_error "    Check network connection and Pi status"
        return 1
    fi
}

# Function to test SSH and ensure key authentication
test_ssh() {
    print_status "🔐 Testing SSH access to ${PI_TARGET}..."
    
    local ssh_test_result
    test_ssh_connectivity "${PI_USER}" "${PI_TARGET}" "yes"
    ssh_test_result=$?
    
    if [[ ${ssh_test_result} -eq 0 ]]; then
        print_success "✅ SSH key authentication working - passwordless access confirmed!"
        SSH_METHOD="key"
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
            SSH_METHOD="key"
            return 0
        elif [[ ${ssh_test_result} -eq 2 ]]; then
            print_status "🔍 Host key issue resolved, but SSH key authentication still needed."
        fi
        
        echo
        print_warning "🔒 REQUIRED: SSH key authentication is mandatory for Death Star setup"
        echo -e "${YELLOW}The Death Star Pi setup includes security hardening that disables SSH password authentication.${NC}"
        echo -e "${YELLOW}SSH keys are required for secure access and automated deployment.${NC}"
        echo
        
        # Check if SSH keys exist
        if [[ ! -f ~/.ssh/id_rsa.pub ]] && [[ ! -f ~/.ssh/id_ed25519.pub ]] && [[ ! -f ~/.ssh/id_ecdsa.pub ]]; then
            print_status "� No SSH key found on this system."
            echo -e "${CYAN}We'll create a new SSH key and configure it for Pi access.${NC}"
        else
            print_status "🔑 SSH key found but not configured for Pi access."
            echo -e "${CYAN}We'll configure your existing SSH key for Pi access.${NC}"
        fi
        
        echo
        print_status "🚀 Setting up SSH key authentication (REQUIRED for Death Star setup)..."
        read -p "Continue with SSH key setup? (Y/n): " -r setup_keys
        setup_keys=${setup_keys:-Y}
        
        if [[ "${setup_keys^^}" == "Y" ]]; then
            setup_ssh_keys_mandatory
            # Test again after setup
            if test_ssh_connectivity "${PI_USER}" "${PI_TARGET}" "yes"; then
                SSH_METHOD="key"
                print_success "✅ SSH key setup successful - ready for Death Star deployment!"
                return 0
            else
                print_error "❌ SSH key setup verification failed"
                print_error "Cannot proceed without SSH key authentication"
                echo
                print_status "💡 Troubleshooting steps:"
                echo -e "  1. Ensure Pi is accessible: ping ${PI_TARGET}"
                echo -e "  2. Verify Pi allows SSH: ssh ${PI_USER}@${PI_TARGET} (manually)"
                echo -e "  3. Check SSH service on Pi: sudo systemctl status ssh"
                echo -e "  4. Ensure ~/.ssh/authorized_keys exists on Pi"
                return 1
            fi
        else
            print_error "❌ Cannot proceed without SSH key authentication"
            echo -e "${RED}SSH keys are mandatory for Death Star Pi setup!${NC}"
            echo -e "${YELLOW}The setup process configures security hardening that requires key-based authentication.${NC}"
            return 1
        fi
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
    print_status "🔑 Setting up SSH keys for secure Death Star access..."
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
        print_status "📋 Using existing ECDSA key: ${key_file}"
    else
        print_status "�🔧 No SSH key found, generating a new Ed25519 key..."
        echo -e "${CYAN}Creating secure SSH key for Death Star authentication...${NC}"
        
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
            return 1
        fi
    fi
    
    echo
    print_status "� Copying SSH key to Death Star Pi..."
    echo -e "${CYAN}You will need to enter the Pi password ONE FINAL TIME.${NC}"
    echo -e "${CYAN}After this, all connections will use secure key authentication.${NC}"
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
            echo -e "${GREEN}🚀 Secure key-based authentication is now active!${NC}"
            echo -e "${GREEN}🔒 Future connections will be passwordless and secure.${NC}"
            echo
            print_status "🔄 SSH key setup complete!"
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
    print_status "🛠️ Manual SSH key setup instructions:"
    echo -e "${CYAN}1. Connect to Pi manually:${NC} ssh ${PI_USER}@${PI_TARGET}"
    echo -e "${CYAN}2. Create .ssh directory:${NC} mkdir -p ~/.ssh && chmod 700 ~/.ssh"
    echo -e "${CYAN}3. Copy this key content to Pi ~/.ssh/authorized_keys:${NC}"
    echo
    echo -e "${YELLOW}$(cat ~/.ssh/id_ed25519.pub 2>/dev/null || cat ~/.ssh/id_rsa.pub 2>/dev/null || echo "No public key found" || true)${NC}"
    echo
    echo -e "${CYAN}4. Set permissions:${NC} chmod 600 ~/.ssh/authorized_keys"
    echo -e "${CYAN}5. Test connection:${NC} ./connect_to_pi.sh"
    echo
    return 1
}

# Function to show connection info
show_connection_info() {
    echo -e "${BLUE}🌐 Death Star Pi Connection Information:${NC}"
    echo
    echo -e "  ${CYAN}IP Address:${NC}    ${PI_IP}"
    echo -e "  ${CYAN}Username:${NC}      ${PI_USER}"
    echo -e "  ${CYAN}Remote Dir:${NC}    ${REMOTE_DIR}"
    echo
    echo -e "${BLUE}🔑 Connection Methods:${NC}"
    echo -e "  ${CYAN}SSH with IP:${NC}    ssh ${PI_USER}@${PI_IP}"
    echo -e "  ${CYAN}Quick connect:${NC}  ./connect_to_pi.sh"
    echo
    echo -e "${BLUE}💡 Useful Commands on Pi:${NC}"
    echo -e "  ${CYAN}Status check:${NC}   ./status.sh"
    echo -e "  ${CYAN}Auto-fix:${NC}       ./status.sh --fix"
    echo -e "  ${CYAN}Setup services:${NC} ./setup.sh"
    echo -e "  ${CYAN}Update services:${NC} ./update.sh"
    echo -e "  ${CYAN}Remove services:${NC} ./remove.sh"
    echo -e "  ${CYAN}PADD dashboard:${NC} padd"
    echo
    echo -e "${BLUE}📋 Prerequisites:${NC}"
    echo -e "  ${CYAN}Deploy first:${NC}   ./push_to_pi.sh"
    echo
}

# Function to connect to Pi
connect_to_pi() {
    local remote_command="$1"
    
    if ! test_connectivity; then
        return 1
    fi
    
    if ! test_ssh; then
        return 1
    fi
    
    # Check if remote directory exists
    print_status "📁 Verifying remote project directory exists..."
    if ! ssh -o ConnectTimeout="${SSH_TIMEOUT:-5}" "${PI_USER}@${PI_TARGET}" "test -d ${REMOTE_DIR}" 2>/dev/null; then
        print_error "❌ Remote project directory does not exist: ${REMOTE_DIR}"
        print_error "    You need to run './push_to_pi.sh' first to create it!"
        return 1
    fi
    print_success "✅ Remote project directory confirmed"
    
    if [[ -n "${remote_command}" ]]; then
        # Execute single command
        print_status "🚀 Executing command on Death Star Pi: ${remote_command}"
        echo
        
        if [[ "${SSH_METHOD}" == "key" ]]; then
            # shellcheck disable=SC2029
            ssh "${PI_USER}@${PI_TARGET}" "cd ${REMOTE_DIR} && ${remote_command}"
        else
            ssh -t "${PI_USER}@${PI_TARGET}" "cd ${REMOTE_DIR} && ${remote_command}"
        fi
    else
        # Interactive session
        print_status "🚀 Connecting to Death Star Pi..."
        print_status "📁 You'll be in: ${REMOTE_DIR}"
        echo
        
        if [[ "${SSH_METHOD}" == "key" ]]; then
            ssh "${PI_USER}@${PI_TARGET}" -t "cd ${REMOTE_DIR} && exec \${SHELL}"
        else
            ssh -t "${PI_USER}@${PI_TARGET}" "cd ${REMOTE_DIR} && exec \${SHELL}"
        fi
    fi
    
    # shellcheck disable=SC2181
    if [[ $? -eq 0 ]]; then
        print_success "✅ Connection completed successfully"
    else
        print_error "❌ Connection failed or command had errors"
        return 1
    fi
}

# Main execution
main() {
    local show_info_only=false
    local remote_command=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
            ;;
            -i|--info)
                show_info_only=true
                shift
            ;;
            *)
                # Treat as remote command
                remote_command="$1"
                shift
            ;;
        esac
    done
    
    # Get configuration first
    if ! get_pi_config; then
        exit 1
    fi
    
    if [[ "${show_info_only}" == "true" ]]; then
        show_banner
        show_connection_info
        exit 0
    fi
    
    show_banner
    if ! check_push_to_pi_prerequisite; then
        exit 1
    fi
    if ! connect_to_pi "${remote_command}"; then
        exit 1
    fi
}

# Check if running as root
if [[ ${EUID} -eq 0 ]]; then
    print_error "This script should not be run as root"
    exit 1
fi

# Run main function
main "$@"
