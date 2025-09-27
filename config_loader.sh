#!/bin/bash
#===============================================================================
# File: config_loader.sh
# Project: Death Star Pi-hole Setup
# Description: Configuration loader for Death Star Pi-hole setup system
#              Provides functions to load configuration from config.json
# 
# Development Environment:
#   OS: Fedora Linux 42 (KDE Plasma Desktop Edit4)
#   Shell: bash
#   Dependencies: jq
# 
# Author: galactic-plane
# Repository: https://github.com/galactic-plane/deathstar-pi-hole-setup
# License: See LICENSE file
#===============================================================================

# Global configuration file path
CONFIG_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.json"

#===============================================================================
# Function: check_jq_available
# Description: Checks if jq is available for JSON parsing
# Parameters: None
# Returns: 0 if jq is available, 1 if not
#===============================================================================
check_jq_available() {
    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: jq is required for configuration parsing but not installed." >&2
        echo "Please install jq: sudo apt-get install jq (Ubuntu/Debian) or sudo dnf install jq (Fedora)" >&2
        return 1
    fi
    return 0
}

#===============================================================================
# Function: check_config_file
# Description: Checks if the configuration file exists
# Parameters: None
# Returns: 0 if config file exists, 1 if not
#===============================================================================
check_config_file() {
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        echo "Error: Configuration file not found at ${CONFIG_FILE}" >&2
        return 1
    fi
    return 0
}

#===============================================================================
# Function: load_config
# Description: Load configuration value by JSON path
# Parameters:
#   $1 - JSON path to the configuration value
#   $2 - Default value if path not found (optional)
# Returns: 0 on success, 1 on error
#===============================================================================
load_config() {
    local json_path="$1"
    local default_value="$2"
    
    if ! check_config_file || ! check_jq_available; then
        echo "${default_value}"
        return 1
    fi
    
    local value
    value=$(jq -r "${json_path} // \"${default_value}\"" "${CONFIG_FILE}" 2>/dev/null)
    
    if [[ "${value}" == "null" || -z "${value}" ]]; then
        echo "${default_value}"
    else
        echo "${value}"
    fi
}

# Load configuration array
#===============================================================================
# Function: load_config_array
# Description: Load configuration array by JSON path
# Parameters:
#   $1 - JSON path to the configuration array
# Returns: Array elements separated by newlines
#===============================================================================
load_config_array() {
    local json_path="$1"
    
    if ! check_config_file || ! check_jq_available; then
        return 1
    fi
    
    jq -r "${json_path}[]?" "${CONFIG_FILE}" 2>/dev/null
}

# Load all network configuration
#===============================================================================
# Function: load_network_config
# Description: Load all network configuration values and export as environment variables
# Parameters: None
# Returns: 0 on success, 1 if config unavailable (fallback values used)
# Exports: PI_IP, SSH_TIMEOUT, RETRY_ATTEMPTS, RETRY_DELAY, MAX_WAIT_TIME
#===============================================================================
load_network_config() {
    if ! check_config_file || ! check_jq_available; then
        # Fallback defaults
        export PI_IP="192.168.122.164"
        export SSH_TIMEOUT="5"
        export RETRY_ATTEMPTS="3"
        return 1
    fi
    
    # Load network configuration values
    local pi_ip
    pi_ip=$(load_config '.network.pi.default_ip' '192.168.122.164')
    export PI_IP="${pi_ip}"
    local ssh_timeout
    ssh_timeout=$(load_config '.network.pi.ssh.connect_timeout' '5')
    export SSH_TIMEOUT="${ssh_timeout}"
    local retry_attempts
    retry_attempts=$(load_config '.network.connection.retry_attempts' '3')
    export RETRY_ATTEMPTS="${retry_attempts}"
    local retry_delay
    retry_delay=$(load_config '.network.connection.retry_delay' '2')
    export RETRY_DELAY="${retry_delay}"
    local max_wait_time
    max_wait_time=$(load_config '.network.connection.max_wait_time' '30')
    export MAX_WAIT_TIME="${max_wait_time}"
}

# Load directory configuration with user substitution
#===============================================================================
# Function: load_directory_config
# Description: Load directory configuration with username substitution
# Parameters:
#   $1 - Username to substitute in remote paths
# Returns: 0 on success, 1 if config unavailable (fallback values used)
# Exports: LOCAL_ROOT, PI_SCRIPTS_DIR, REMOTE_BASE_PATH
#===============================================================================
load_directory_config() {
    local username="$1"
    
    if ! check_config_file || ! check_jq_available; then
        # Fallback defaults
        export LOCAL_ROOT="."
        export PI_SCRIPTS_DIR="deathstar-pi-hole-setup"
        export REMOTE_BASE_PATH="/home/${username}/Repo/deathstar-pi-hole-setup/"
        return 1
    fi
    
    # Load directory configuration values
    local local_root
    local_root=$(load_config '.directories.local.root' '.')
    export LOCAL_ROOT="${local_root}"
    local pi_scripts_dir
    pi_scripts_dir=$(load_config '.directories.local.pi_scripts' 'deathstar-pi-hole-setup')
    export PI_SCRIPTS_DIR="${pi_scripts_dir}"
    
    # Substitute username in remote paths
    local remote_base
    remote_base=$(load_config '.directories.remote.base_path' '/home/{user}/Repo/deathstar-pi-hole-setup/')
    export REMOTE_BASE_PATH="${remote_base/\{user\}/${username}}"
}

# Load deployment configuration
#===============================================================================
# Function: load_deployment_config
# Description: Load deployment configuration values
# Parameters: None
# Returns: 0 on success, 1 if config unavailable (fallback values used)
# Exports: RSYNC_OPTIONS, EXCLUDE_PATTERNS
#===============================================================================
load_deployment_config() {
    if ! check_config_file || ! check_jq_available; then
        # Fallback defaults
        export RSYNC_OPTIONS="-avz --progress"
        return 1
    fi
    
    # Load rsync options as a single string
    local options_array
    options_array=$(jq -r '.deployment.rsync.options | join(" ")' "${CONFIG_FILE}" 2>/dev/null)
    export RSYNC_OPTIONS="${options_array:-"-avz --progress"}"
    
    # Load file count for validation
    local expected_file_count
    expected_file_count=$(load_config '.integrity_check.expected_file_count' '6')
    export EXPECTED_FILE_COUNT="${expected_file_count}"
}

# Load color configuration
#===============================================================================
# Function: load_color_config
# Description: Load color configuration for terminal output
# Parameters: None
# Returns: 0 on success, 1 if config unavailable (fallback values used)
# Exports: RED, GREEN, YELLOW, BLUE, PURPLE, CYAN, NC
#===============================================================================
load_color_config() {
    if ! check_config_file || ! check_jq_available; then
        # Fallback defaults
        export RED='\033[0;31m'
        export GREEN='\033[0;32m'
        export YELLOW='\033[1;33m'
        export BLUE='\033[0;34m'
        export PURPLE='\033[0;35m'
        export CYAN='\033[0;36m'
        export NC='\033[0m'
        return 1
    fi
    
    RED=$(load_config '.display.colors.red' '\033[0;31m')
    export RED
    GREEN=$(load_config '.display.colors.green' '\033[0;32m')
    export GREEN
    YELLOW=$(load_config '.display.colors.yellow' '\033[1;33m')
    export YELLOW
    BLUE=$(load_config '.display.colors.blue' '\033[0;34m')
    export BLUE
    PURPLE=$(load_config '.display.colors.purple' '\033[0;35m')
    export PURPLE
    CYAN=$(load_config '.display.colors.cyan' '\033[0;36m')
    export CYAN
    NC=$(load_config '.display.colors.no_color' '\033[0m')
    export NC
}

# Load display configuration
load_display_config() {
    if ! check_config_file || ! check_jq_available; then
        export RICH_ENABLED="true"
        export FALLBACK_TO_BASIC="true"
        return 1
    fi
    
    local rich_enabled
    rich_enabled=$(load_config '.display.rich_formatting.enabled' 'true')
    export RICH_ENABLED="${rich_enabled}"
    local fallback_to_basic
    fallback_to_basic=$(load_config '.display.rich_formatting.fallback_to_basic' 'true')
    export FALLBACK_TO_BASIC="${fallback_to_basic}"
}

# Load banner configuration with substitutions
load_banner_config() {
    local local_dir="$1"
    local username="$2" 
    local target="$3"
    
    if ! check_config_file || ! check_jq_available; then
        export PUSH_TITLE="🚀 Death Star Pi Development Push 🤖"
        export CONNECT_TITLE="🚀 Death Star Pi SSH Connect 🤖"
        export INTEGRITY_TITLE="🔍 Death Star Pi Integrity Check 🤖"
        return 1
    fi
    
    PUSH_TITLE=$(load_config '.display.banners.push_title' '🚀 Death Star Pi Development Push 🤖')
    export PUSH_TITLE
    CONNECT_TITLE=$(load_config '.display.banners.connect_title' '🚀 Death Star Pi SSH Connect 🤖')
    export CONNECT_TITLE
    INTEGRITY_TITLE=$(load_config '.display.banners.integrity_title' '🔍 Death Star Pi Integrity Check 🤖')
    export INTEGRITY_TITLE
    
    # Load subtitles with substitutions
    local push_subtitle
    push_subtitle=$(load_config '.display.banners.push_subtitle' 'Deploying from {local_dir} development station to {user}'\''s Death Star Pi ({target})')
    local connect_subtitle
    connect_subtitle=$(load_config '.display.banners.connect_subtitle' 'Establishing connection to {user}'\''s Death Star Pi at {target}')
    
    export PUSH_SUBTITLE="${push_subtitle/\{local_dir\}/${local_dir}}"
    export PUSH_SUBTITLE="${PUSH_SUBTITLE/\{user\}/${username}}"
    export PUSH_SUBTITLE="${PUSH_SUBTITLE/\{target\}/${target}}"
    
    export CONNECT_SUBTITLE="${connect_subtitle/\{user\}/${username}}"
    export CONNECT_SUBTITLE="${CONNECT_SUBTITLE/\{target\}/${target}}"
}

# Load security configuration
load_security_config() {
    if ! check_config_file || ! check_jq_available; then
        export BATCH_MODE_FOR_TESTS="true"
        export VALIDATE_TARGET="true"
        export CONFIRM_OVERWRITES="true"
        return 1
    fi
    
    local batch_mode_for_tests
    batch_mode_for_tests=$(load_config '.security.ssh.batch_mode_for_tests' 'true')
    export BATCH_MODE_FOR_TESTS="${batch_mode_for_tests}"

    local validate_target
    validate_target=$(load_config '.security.deployment.validate_target' 'true')
    export VALIDATE_TARGET="${validate_target}"

    local confirm_overwrites
    confirm_overwrites=$(load_config '.security.deployment.confirm_overwrites' 'true')
    export CONFIRM_OVERWRITES="${confirm_overwrites}"

    local script_permissions
    script_permissions=$(load_config '.security.file_permissions.script_permissions' '755')
    export SCRIPT_PERMISSIONS="${script_permissions}"
}

# Get list of files to sync
get_files_to_sync() {
    if ! check_config_file || ! check_jq_available; then
        # Fallback list
        echo "LICENSE"
        echo "deathstar-pi-hole-setup/remove.sh"
        echo "deathstar-pi-hole-setup/setup.sh"
        echo "deathstar-pi-hole-setup/status.sh"
        echo "deathstar-pi-hole-setup/update.sh"
        return 1
    fi
    
    load_config_array '.deployment.rsync.files_to_sync'
}

# Get list of validation files
get_validation_files() {
    local type="$1" # "host_scripts", "pi_scripts", or "required_files"
    
    if ! check_config_file || ! check_jq_available; then
        case "${type}" in
            "host_scripts")
                echo "connect_to_pi.sh"
                echo "push_to_pi.sh"
                echo "integrity-check.sh"
                echo "rich_helper.py"
                ;;
            "pi_scripts")
                echo "deathstar-pi-hole-setup/setup.sh"
                echo "deathstar-pi-hole-setup/status.sh"
                echo "deathstar-pi-hole-setup/update.sh"
                echo "deathstar-pi-hole-setup/remove.sh"
                ;;
            "required_files")
                echo "LICENSE"
                echo "deathstar-pi-hole-setup/remove.sh"
                echo "deathstar-pi-hole-setup/setup.sh"
                echo "deathstar-pi-hole-setup/status.sh"
                echo "deathstar-pi-hole-setup/update.sh"
                ;;
            *)
                echo "Error: Unknown type '${type}'. Expected 'host_scripts', 'pi_scripts', or 'required_files'" >&2
                return 1
                ;;
        esac
        return 1
    fi
    
    load_config_array ".deployment.validation.${type}"
}

# Initialize all configuration - call this at the start of scripts
init_config() {
    local username="$1"
    local target="$2"
    local local_dir="$3"
    
    # Load all configuration sections
    load_color_config
    load_network_config
    load_directory_config "${username}"
    load_deployment_config
    load_display_config
    load_security_config
    
    # Load banners with substitutions if parameters provided
    if [[ -n "${local_dir}" && -n "${username}" && -n "${target}" ]]; then
        load_banner_config "${local_dir}" "${username}" "${target}"
    fi
}

# Function to validate configuration file
validate_config() {
    echo "Validating configuration file..."
    
    if ! check_config_file; then
        echo "❌ Config file check failed"
        return 1
    fi
    
    if ! check_jq_available; then
        echo "❌ jq dependency check failed"
        return 1
    fi
    
    # Test JSON validity
    if ! jq empty "${CONFIG_FILE}" 2>/dev/null; then
        echo "❌ Invalid JSON in config file"
        return 1
    fi
    
    echo "✅ Configuration file is valid"
    return 0
}

# Show current configuration (for debugging)
show_config() {
    echo "Current Configuration:"
    echo "====================="
    echo "Config File: ${CONFIG_FILE}"
    echo "PI_IP: ${PI_IP:-'not set'}"
    echo "SSH_TIMEOUT: ${SSH_TIMEOUT:-'not set'}"
    echo "PI_SCRIPTS_DIR: ${PI_SCRIPTS_DIR:-'not set'}"
    echo "REMOTE_BASE_PATH: ${REMOTE_BASE_PATH:-'not set'}"
    echo "RSYNC_OPTIONS: ${RSYNC_OPTIONS:-'not set'}"
    echo "RICH_ENABLED: ${RICH_ENABLED:-'not set'}"
}