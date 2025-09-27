#!/bin/bash
#===============================================================================
# File: config_loader.sh
# Project: Death Star Pi-hole Setup
# Description: Configuration loader for Death Star Pi-hole setup system
#              Helper script to load configuration from JSON file for all 
#              Death Star scripts. Should be sourced by other scripts.
# 
# Target Environment:
#   OS: Raspberry Pi OS aarch64
#   Host: Raspberry Pi 5 Model B Rev 1.1
#   Shell: bash
#   Dependencies: jq (optional)
# 
# Author: galactic-plane
# Repository: https://github.com/galactic-plane/deathstar-pi-hole-setup
# License: See LICENSE file
#===============================================================================

# Get the directory where this script is located
if [[ -z "${CONFIG_SCRIPT_DIR:-}" ]]; then
    CONFIG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    readonly CONFIG_SCRIPT_DIR
fi
if [[ -z "${CONFIG_JSON_FILE:-}" ]]; then
    readonly CONFIG_JSON_FILE="$CONFIG_SCRIPT_DIR/config.json"
fi

#===============================================================================
# Function: get_config_value
# Description: Extract JSON values using jq or fallback method
# Parameters:
#   $1 - JSON path to extract
#   $2 - Default value if extraction fails
# Returns: Configuration value or default
#===============================================================================
get_config_value() {
    local json_path="$1"
    local default_value="$2"
    
    if command -v jq >/dev/null 2>&1; then
        # Use jq if available
        local value
        value=$(jq -r "$json_path" "$CONFIG_JSON_FILE" 2>/dev/null)
        if [[ "$value" != "null" && -n "$value" ]]; then
            echo "$value"
        else
            echo "$default_value"
        fi
    else
        # Fallback method without jq (basic grep/sed parsing)
        local key
        key=$(echo "$json_path" | sed 's/^\.//; s/\./\\\./g')
        local value
        value=$(grep -E "\"$key\":" "$CONFIG_JSON_FILE" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' | head -1)
        if [[ -n "$value" ]]; then
            echo "$value"
        else
            echo "$default_value"
        fi
    fi
}

# Function to expand environment variables in config values
expand_config_value() {
    local value="$1"
    # Use eval to expand environment variables like $HOME
    eval echo "$value"
}

# Load all configuration variables
load_deathstar_config() {
    # Check if config file exists
    if [[ ! -f "$CONFIG_JSON_FILE" ]]; then
        echo "Warning: Configuration file not found at $CONFIG_JSON_FILE" >&2
        echo "Using default values..." >&2
        return 1
    fi
    
    # System configuration
    export DS_NEW_HOSTNAME
    DS_NEW_HOSTNAME=$(get_config_value ".system.hostnames.new_hostname" "deathstar-core")
    
    export DS_ORIGINAL_HOSTNAME
    DS_ORIGINAL_HOSTNAME=$(get_config_value ".system.hostnames.original_hostname" "raspberrypi")
    
    export DS_DOMAIN_NAME
    DS_DOMAIN_NAME=$(get_config_value ".system.hostnames.domain_name" "deathstar.core")
    
    # Paths (with environment variable expansion)
    export DS_HOME_DIR
    DS_HOME_DIR=$(expand_config_value "$(get_config_value ".system.paths.home_dir" "$HOME")")
    
    export DS_REPO_BASE
    DS_REPO_BASE=$(expand_config_value "$(get_config_value ".system.paths.repo_base" "$HOME/Repo")")
    
    export DS_INTERNET_PI_DIR
    DS_INTERNET_PI_DIR=$(expand_config_value "$(get_config_value ".system.paths.internet_pi_dir" "$HOME/Repo/internet-pi")")
    
    export DS_DEATHSTAR_SCRIPTS_DIR
    DS_DEATHSTAR_SCRIPTS_DIR=$(expand_config_value "$(get_config_value ".system.paths.deathstar_scripts_dir" "$HOME/Repo/deathstar-pi-hole-setup")")
    
    export DS_CONFIG_DIR
    DS_CONFIG_DIR=$(expand_config_value "$(get_config_value ".system.paths.config_dir" "$HOME")")
    
    # Repository configuration
    export DS_INTERNET_PI_URL
    DS_INTERNET_PI_URL=$(get_config_value ".repositories.internet_pi.url" "https://github.com/geerlingguy/internet-pi.git")
    
    # Service ports
    export DS_PIHOLE_PORT
    DS_PIHOLE_PORT=$(get_config_value ".services.ports.pihole" "80")
    
    export DS_GRAFANA_PORT
    DS_GRAFANA_PORT=$(get_config_value ".services.ports.grafana" "3030")
    
    export DS_PROMETHEUS_PORT
    DS_PROMETHEUS_PORT=$(get_config_value ".services.ports.prometheus" "9090")
    
    # Logging configuration
    export DS_LOG_VERSION
    DS_LOG_VERSION=$(get_config_value ".logging.version" "2.0.0")
    
    export DS_LOG_MAIN_FILE
    DS_LOG_MAIN_FILE=$(get_config_value ".logging.files.main_log" "deathstar-pi.log")
    
    export DS_LOG_DEBUG_FILE
    DS_LOG_DEBUG_FILE=$(get_config_value ".logging.files.debug_log" "deathstar-pi-debug.log")
    
    export DS_LOG_ERROR_FILE
    DS_LOG_ERROR_FILE=$(get_config_value ".logging.files.error_log" "deathstar-pi-errors.log")
    
    export DS_LOG_PERFORMANCE_FILE
    DS_LOG_PERFORMANCE_FILE=$(get_config_value ".logging.files.performance_log" "deathstar-pi-performance.log")
    
    export DS_LOG_MAX_SIZE
    DS_LOG_MAX_SIZE=$(get_config_value ".logging.rotation.max_size" "50M")
    
    export DS_LOG_MAX_FILES
    DS_LOG_MAX_FILES=$(get_config_value ".logging.rotation.max_files" "5")
    
    export DS_LOG_ENABLE_DEBUG
    DS_LOG_ENABLE_DEBUG=$(get_config_value ".logging.settings.enable_debug" "false")
    
    export DS_LOG_ENABLE_PERFORMANCE
    DS_LOG_ENABLE_PERFORMANCE=$(get_config_value ".logging.settings.enable_performance" "true")
    
    export DS_LOG_ENABLE_ERROR_TRACE
    DS_LOG_ENABLE_ERROR_TRACE=$(get_config_value ".logging.settings.enable_error_trace" "true")
    
    # State management
    export DS_STATE_FILE
    DS_STATE_FILE=$(expand_config_value "$(get_config_value ".state_management.state_file" "$HOME/.deathstar_setup_state")")
    
    export DS_CONFIG_FILE
    DS_CONFIG_FILE=$(expand_config_value "$(get_config_value ".state_management.config_file" "$HOME/.deathstar_config")")
    
    return 0
}

# Function to display loaded configuration (for debugging)
show_deathstar_config() {
    echo "Death Star Pi Configuration:"
    echo "=============================="
    echo "Hostnames:"
    echo "  New Hostname: $DS_NEW_HOSTNAME"
    echo "  Original Hostname: $DS_ORIGINAL_HOSTNAME"
    echo "  Domain Name: $DS_DOMAIN_NAME"
    echo ""
    echo "Paths:"
    echo "  Home Directory: $DS_HOME_DIR"
    echo "  Repo Base: $DS_REPO_BASE"
    echo "  Internet-Pi Directory: $DS_INTERNET_PI_DIR"
    echo "  Scripts Directory: $DS_DEATHSTAR_SCRIPTS_DIR"
    echo "  Config Directory: $DS_CONFIG_DIR"
    echo ""
    echo "Repositories:"
    echo "  Internet-Pi URL: $DS_INTERNET_PI_URL"
    echo ""
    echo "Service Ports:"
    echo "  Pi-hole: $DS_PIHOLE_PORT"
    echo "  Grafana: $DS_GRAFANA_PORT"
    echo "  Prometheus: $DS_PROMETHEUS_PORT"
    echo ""
    echo "Logging:"
    echo "  Max Size: $DS_LOG_MAX_SIZE"
    echo "  Max Files: $DS_LOG_MAX_FILES"
    echo "  Debug Enabled: $DS_LOG_ENABLE_DEBUG"
    echo ""
    echo "State Files:"
    echo "  State File: $DS_STATE_FILE"
    echo "  Config File: $DS_CONFIG_FILE"
}

# Auto-load configuration when this script is sourced (only if not already loaded)
if [[ -z "${DS_NEW_HOSTNAME:-}" ]]; then
    load_deathstar_config
fi