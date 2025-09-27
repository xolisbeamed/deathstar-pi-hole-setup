#!/bin/bash
#===============================================================================
# File: log_handler.sh
# Project: Death Star Pi-hole Setup
# Description: Advanced logging system - Comprehensive logging library for all 
#              Death Star Pi scripts with multiple log levels, colored terminal
#              output, structured log files, and performance monitoring.
# 
# Target Environment:
#   OS: Raspberry Pi OS aarch64
#   Host: Raspberry Pi 5 Model B Rev 1.1
#   Shell: bash
#   Dependencies: config_loader.sh
# 
# Author: galactic-plane
# Repository: https://github.com/galactic-plane/deathstar-pi-hole-setup
# License: See LICENSE file
#
# Features:
# - Multiple log levels (DEBUG, INFO, SUCCESS, WARNING, ERROR, CRITICAL)
# - Colored terminal output with timestamps
# - Structured log file output with metadata
# - Automatic log rotation and size management
# - Performance timing and metrics
# - Error context and stack traces
# - Session and script tracking
# - Log aggregation and searching capabilities
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/log_handler.sh"
#   log_init "script_name"
#   log_info "Your message here"
#   log_error "Error message" "additional_context"
#   log_performance_start "operation_name"
#   log_performance_end "operation_name"
#===============================================================================

# ═══════════════════════════════════════════════════════════════
# CONFIGURATION AND INITIALIZATION
# ═══════════════════════════════════════════════════════════════

# Load shared configuration
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/config_loader.sh"

# Version and metadata
readonly LOG_HANDLER_VERSION="${DS_LOG_VERSION:-2.0.0}"

# Get script directory for log file location
LOG_SCRIPT_DIR=""
LOG_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_SCRIPT_DIR
readonly LOG_FILE="${LOG_SCRIPT_DIR}/${DS_LOG_MAIN_FILE:-deathstar-pi.log}"
readonly LOG_DEBUG_FILE="${LOG_SCRIPT_DIR}/${DS_LOG_DEBUG_FILE:-deathstar-pi-debug.log}"
readonly LOG_ERROR_FILE="${LOG_SCRIPT_DIR}/${DS_LOG_ERROR_FILE:-deathstar-pi-errors.log}"
readonly LOG_PERFORMANCE_FILE="${LOG_SCRIPT_DIR}/${DS_LOG_PERFORMANCE_FILE:-deathstar-pi-performance.log}"

# Configuration
readonly LOG_MAX_SIZE="${DS_LOG_MAX_SIZE:-50M}"  # Maximum log file size before rotation
readonly LOG_MAX_FILES="${DS_LOG_MAX_FILES:-5}"     # Number of rotated log files to keep
readonly LOG_ENABLE_DEBUG="${DS_LOG_ENABLE_DEBUG:-false}"
readonly LOG_ENABLE_PERFORMANCE="${DS_LOG_ENABLE_PERFORMANCE:-true}"
readonly LOG_ENABLE_ERROR_TRACE="${DS_LOG_ENABLE_ERROR_TRACE:-true}"

# Colors for terminal output
readonly LOG_COLOR_RED='\033[0;31m'
readonly LOG_COLOR_GREEN='\033[0;32m'
readonly LOG_COLOR_YELLOW='\033[1;33m'
readonly LOG_COLOR_BLUE='\033[0;34m'
readonly LOG_COLOR_CYAN='\033[0;36m'
readonly LOG_COLOR_PURPLE='\033[0;35m'
readonly LOG_COLOR_GRAY='\033[0;90m'
readonly LOG_COLOR_NC='\033[0m'

# Global variables
LOG_SCRIPT_NAME=""
LOG_SESSION_ID=""
LOG_SCRIPT_PID=$$
LOG_SCRIPT_START_TIME=""
declare -A LOG_PERFORMANCE_TIMERS

# ═══════════════════════════════════════════════════════════════
# UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Generate unique session ID
_log_generate_session_id() {
    echo "$(date +%Y%m%d_%H%M%S)_$${_}$(openssl rand -hex 4 2>/dev/null || echo date +%N | cut -c1-8)"
}

# Get current timestamp in ISO format
_log_timestamp() {
    date '+%Y-%m-%d %H:%M:%S.%3N'
}

# Get current timestamp for filenames
_log_timestamp_file() {
    date '+%Y%m%d_%H%M%S'
}

# Get caller information (script name, function, line number)
_log_get_caller() {
    local frame=${1:-2}
    local caller_info
    read -r caller_info <<< "$(caller "${frame}")"
    local line_num=${caller_info[0]}
    local function_name=${caller_info[1]}
    local script_path=${caller_info[2]}
    local script_name
    script_name=$(basename "${script_path}")
    
    if [[ "${function_name}" == "main" ]] || [[ "${function_name}" == "source" ]]; then
        echo "${script_name}:${line_num}"
    else
        echo "${script_name}:${function_name}():${line_num}"
    fi
}

# Check if log rotation is needed
_log_check_rotation() {
    local log_file="$1"
    
    if [[ -f "${log_file}" ]]; then
        local file_size
        file_size=$(stat -f%z "${log_file}" 2>/dev/null || stat -c%s "${log_file}" 2>/dev/null || echo "0")
        local max_bytes
        
        # Convert LOG_MAX_SIZE to bytes
        case "${LOG_MAX_SIZE}" in
            *K|*k) max_bytes=$((${LOG_MAX_SIZE%[Kk]} * 1024)) ;;
            *M|*m) max_bytes=$((${LOG_MAX_SIZE%[Mm]} * 1024 * 1024)) ;;
            *G|*g) max_bytes=$((${LOG_MAX_SIZE%[Gg]} * 1024 * 1024 * 1024)) ;;
            *) max_bytes=${LOG_MAX_SIZE} ;;
        esac
        
        if [[ ${file_size} -gt ${max_bytes} ]]; then
            _log_rotate_file "${log_file}"
        fi
    fi
}

# Rotate log file
_log_rotate_file() {
    local log_file="$1"
    local base_name="${log_file%.*}"
    local extension="${log_file##*.}"
    local timestamp
    timestamp=$(_log_timestamp_file)
    
    # Move current log to timestamped backup
    if [[ -f "${log_file}" ]]; then
        mv "$log_file" "${base_name}_${timestamp}.${extension}"
        
        # Clean up old rotated files
        find "$(dirname "$log_file")" -name "$(basename "$base_name")_*.${extension}" -type f | \
        sort -r | tail -n +$((LOG_MAX_FILES + 1)) | xargs rm -f 2>/dev/null || true
    fi
}

# Write to log file with proper formatting
_log_write_file() {
    local level="$1"
    local message="$2"
    local context="$3"
    local caller="$4"
    local timestamp="$5"
    
    # Check rotation before writing
    _log_check_rotation "${LOG_FILE}"
    
    # Format: [timestamp] [SESSION] [SCRIPT] [PID] [LEVEL] [CALLER] message [CONTEXT]
    local log_entry="[${timestamp}] [${LOG_SESSION_ID}] [${LOG_SCRIPT_NAME}] [${LOG_SCRIPT_PID}] [${level}] [${caller}] ${message}"
    
    if [[ -n "${context}" ]]; then
        log_entry="${log_entry} [CONTEXT: ${context}]"
    fi
    
    # Write to main log
    echo "${log_entry}" >> "${LOG_FILE}"
    
    # Write to specialized logs
    case "${level}" in
        "DEBUG")
            if [[ "${LOG_ENABLE_DEBUG}" == "true" ]]; then
                echo "${log_entry}" >> "${LOG_DEBUG_FILE}"
            fi
            ;;
        "ERROR"|"CRITICAL")
            echo "${log_entry}" >> "${LOG_ERROR_FILE}"
            if [[ "${LOG_ENABLE_ERROR_TRACE}" == "true" ]]; then
                _log_write_stack_trace "${LOG_ERROR_FILE}"
            fi
            ;;
    esac
}

# Write stack trace to file
_log_write_stack_trace() {
    local log_file="$1"
    local timestamp
    timestamp=$(_log_timestamp)
    
    echo "[${timestamp}] [${LOG_SESSION_ID}] [${LOG_SCRIPT_NAME}] [STACK_TRACE] BEGIN" >> "${log_file}"
    
    local frame=1
    while true; do
        local caller_raw
        caller_raw="$(caller ${frame} 2>/dev/null)" || break
        local caller_info=()
        read -r caller_info <<< "${caller_raw}"
        local line_num=${caller_info[0]}
        local function_name=${caller_info[1]}
        local script_path=${caller_info[2]}
        local script_name
        script_name=$(basename "${script_path}")
        
        echo "[$timestamp] [$LOG_SESSION_ID] [$LOG_SCRIPT_NAME] [STACK_TRACE] Frame $frame: ${script_name}:${function_name}():${line_num}" >> "$log_file"
        ((frame++))
    done
    
    echo "[${timestamp}] [${LOG_SESSION_ID}] [${LOG_SCRIPT_NAME}] [STACK_TRACE] END" >> "${log_file}"
}

# ═══════════════════════════════════════════════════════════════
# CORE LOGGING FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Initialize logging for a script
log_init() {
    local script_name="${1:-$(basename "${BASH_SOURCE[1]}")}"
    
    LOG_SCRIPT_NAME="${script_name}"
    LOG_SESSION_ID=$(_log_generate_session_id)
    LOG_SCRIPT_START_TIME=$(_log_timestamp)
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "${LOG_FILE}")"
    
    # Write session start marker
    local timestamp
    timestamp=$(_log_timestamp)
    local caller
    caller=$(_log_get_caller 1)
    
    _log_write_file "INIT" "=== Death Star Pi Logging Session Started ===" \
        "Version: ${LOG_HANDLER_VERSION}, Script: ${script_name}, PID: ${LOG_SCRIPT_PID}" \
        "${caller}" "${timestamp}"
    
    # Set up exit trap for session end
    trap 'log_cleanup' EXIT
    
    # Display initialization message using Rich helper if available
    local init_message="Logging initialized for $script_name (Session: ${LOG_SESSION_ID})"
    local rich_helper_path
    rich_helper_path="$(dirname "${BASH_SOURCE[0]}")/rich_helper.py"
    
    if [[ -f "${rich_helper_path}" ]] && command -v python3 >/dev/null 2>&1; then
        # Try to use Rich helper for enhanced output
        if ! python3 "${rich_helper_path}" "status" --message "${init_message}" --style "info" 2>/dev/null; then
            # Fallback to basic output if Rich helper fails
            echo -e "${LOG_COLOR_CYAN}[LOG]${LOG_COLOR_NC} $init_message"
        fi
    else
        # Fallback to basic output if Rich helper is not available
        echo -e "${LOG_COLOR_CYAN}[LOG]${LOG_COLOR_NC} $init_message"
    fi
}

# Cleanup function called on script exit
log_cleanup() {
    if [[ -n "${LOG_SCRIPT_START_TIME}" ]]; then
        local end_time
        end_time=$(_log_timestamp)
        local caller
        caller=$(_log_get_caller 1)
        
        _log_write_file "CLEANUP" "=== Death Star Pi Logging Session Ended ===" \
            "Duration: $(log_get_duration "${LOG_SCRIPT_START_TIME}" "${end_time}")" \
            "${caller}" "${end_time}"
    fi
}

# Generic logging function
_log_message() {
    local level="$1"
    local color="$2"
    local icon="$3"
    local message="$4"
    local context="${5:-}"
    
    local timestamp
    timestamp=$(_log_timestamp)
    local caller
    caller=$(_log_get_caller 3)
    
    # Write to file
    _log_write_file "${level}" "${message}" "${context}" "${caller}" "${timestamp}"
    
    # Display to terminal
    local display_message="${message}"
    if [[ -n "${context}" ]]; then
        display_message="${message} (Context: ${context})"
    fi
    
    # Check if Rich helper is available and use it, otherwise fallback to basic colors
    local rich_helper_path
    rich_helper_path="$(dirname "${BASH_SOURCE[0]}")/rich_helper.py"
    
    if [[ -f "${rich_helper_path}" ]] && command -v python3 >/dev/null 2>&1; then
        # Map log levels to Rich styles
        local rich_style
        case "${level}" in
            "SUCCESS") rich_style="success" ;;
            "WARNING") rich_style="warning" ;;
            "ERROR"|"CRITICAL") rich_style="error" ;;
            *) rich_style="info" ;;
        esac
        
        # Try to use Rich helper for enhanced output
        if python3 "${rich_helper_path}" "status" --message "${display_message}" --style "${rich_style}" 2>/dev/null; then
            return 0  # Rich helper worked, we're done
        fi
    fi
    
    # Fallback to basic color output if Rich helper is not available or fails
    echo -e "${color}[$icon]${LOG_COLOR_NC} $display_message"
}

# Debug logging (only shown if enabled)
log_debug() {
    if [[ "${LOG_ENABLE_DEBUG}" == "true" ]]; then
        _log_message "DEBUG" "${LOG_COLOR_GRAY}" "DEBUG" "$1" "$2"
    fi
}

# Info logging
log_info() {
    _log_message "INFO" "${LOG_COLOR_BLUE}" "INFO" "$1" "$2"
}

# Success logging
log_success() {
    _log_message "SUCCESS" "${LOG_COLOR_GREEN}" "SUCCESS" "$1" "$2"
}

# Warning logging
log_warning() {
    _log_message "WARNING" "${LOG_COLOR_YELLOW}" "WARNING" "$1" "$2"
}

# Error logging
log_error() {
    _log_message "ERROR" "${LOG_COLOR_RED}" "ERROR" "$1" "$2"
}

# Critical error logging
log_critical() {
    _log_message "CRITICAL" "${LOG_COLOR_PURPLE}" "CRITICAL" "$1" "$2"
}

# ═══════════════════════════════════════════════════════════════
# SPECIALIZED LOGGING FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Log command execution with output capture
log_command() {
    local cmd="$1"
    local description="${2:-Executing command}"
    local show_output="${3:-true}"
    
    log_info "${description}: ${cmd}"
    
    local start_time
    start_time=$(_log_timestamp)
    local output_file
    output_file=$(mktemp)
    local exit_code
    
    if [[ "${show_output}" == "true" ]]; then
        eval "${cmd}" 2>&1 | tee "${output_file}"
        exit_code=${PIPESTATUS[0]}
    else
        eval "${cmd}" > "${output_file}" 2>&1
        exit_code=$?
    fi
    
    local end_time
    end_time=$(_log_timestamp)
    local duration
    duration=$(log_get_duration "${start_time}" "${end_time}")
    local output
    output=$(cat "${output_file}")
    
    rm -f "${output_file}"
    
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "Command completed successfully in ${duration}"
        if [[ "${LOG_ENABLE_DEBUG}" == "true" && -n "${output}" ]]; then
            log_debug "Command output" "${output}"
        fi
    else
        log_error "Command failed with exit code ${exit_code} in ${duration}" "${output}"
    fi
    
    return "${exit_code}"
}

# Log file operations
log_file_operation() {
    local operation="$1"
    local file_path="$2"
    local description="${3:-File operation}"
    
    case "${operation}" in
        "create"|"write")
            if [[ -f "${file_path}" ]]; then
                log_info "${description}: Created/Updated file ${file_path}"
            else
                log_error "${description}: Failed to create file ${file_path}"
            fi
            ;;
        "delete"|"remove")
            if [[ ! -f "${file_path}" ]]; then
                log_info "${description}: Removed file ${file_path}"
            else
                log_error "${description}: Failed to remove file ${file_path}"
            fi
            ;;
        "backup")
            local backup_path
            backup_path="${file_path}.backup.$(date +%Y%m%d_%H%M%S)"
            if cp "${file_path}" "${backup_path}" 2>/dev/null; then
                log_info "${description}: Backed up ${file_path} to ${backup_path}"
            else
                log_error "${description}: Failed to backup ${file_path}"
            fi
            ;;
    esac
}

# Log system information
log_system_info() {
    local info_type="$1"
    
    case "${info_type}" in
        "os")
            local os_info
            os_info=$(uname -a)
            log_info "Operating System Information" "${os_info}"
            ;;
        "memory")
            local mem_info
            mem_info=$(free -h | head -2 | tail -1)
            log_info "Memory Information" "${mem_info}"
            ;;
        "disk")
            local disk_info
            disk_info=$(df -h / | tail -1)
            log_info "Disk Space Information" "${disk_info}"
            ;;
        "network")
            local ip_info
            ip_info=$(hostname -I | awk '{print $1}')
            log_info "Network Information" "Primary IP: ${ip_info}"
            ;;
        "all")
            log_system_info "os"
            log_system_info "memory"
            log_system_info "disk"
            log_system_info "network"
            ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# PERFORMANCE MONITORING
# ═══════════════════════════════════════════════════════════════

# Start performance timer
log_performance_start() {
    local operation_name="$1"
    
    if [[ "${LOG_ENABLE_PERFORMANCE}" == "true" ]]; then
    local start_time
    start_time=$(_log_timestamp)
        LOG_PERFORMANCE_TIMERS["${operation_name}"]="${start_time}"
        
        log_debug "Performance timer started for: ${operation_name}"
        
        # Write to performance log
        echo "[${start_time}] [${LOG_SESSION_ID}] [${LOG_SCRIPT_NAME}] [PERF_START] ${operation_name}" >> "${LOG_PERFORMANCE_FILE}"
    fi
}

# End performance timer
log_performance_end() {
    local operation_name="$1"
    
    if [[ "${LOG_ENABLE_PERFORMANCE}" == "true" ]]; then
    local end_time
    end_time=$(_log_timestamp)
        local start_time="${LOG_PERFORMANCE_TIMERS[${operation_name}]}"
        
        if [[ -n "${start_time}" ]]; then
            local duration
            duration=$(log_get_duration "${start_time}" "${end_time}")
            log_info "Performance: ${operation_name} completed in ${duration}"
            
            # Write to performance log
            echo "[${end_time}] [${LOG_SESSION_ID}] [${LOG_SCRIPT_NAME}] [PERF_END] ${operation_name} [${duration}]" >> "${LOG_PERFORMANCE_FILE}"
            
            # Clean up timer
            unset 'LOG_PERFORMANCE_TIMERS["${operation_name}"]'
        else
            log_warning "Performance timer not found for: ${operation_name}"
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════
# UTILITY AND HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════

# Calculate duration between two timestamps
log_get_duration() {
    local start_time="$1"
    local end_time="$2"
    
    local start_epoch
    start_epoch=$(date -d "${start_time}" +%s.%N 2>/dev/null || echo "0")
    local end_epoch
    end_epoch=$(date -d "${end_time}" +%s.%N 2>/dev/null || echo "0")
    
    if [[ "${start_epoch}" != "0" && "${end_epoch}" != "0" ]]; then
    local duration
    duration=$(echo "${end_epoch} - ${start_epoch}" | bc -l 2>/dev/null || echo "0")
        printf "%.3fs" "${duration}"
    else
        echo "unknown"
    fi
}

# Search logs
log_search() {
    local search_term="$1"
    local log_file="${2:-${LOG_FILE}}"
    local context_lines="${3:-3}"
    
    if [[ -f "${log_file}" ]]; then
        echo -e "${LOG_COLOR_CYAN}Searching for '$search_term' in $(basename "$log_file"):${LOG_COLOR_NC}"
        grep -n -C "${context_lines}" "${search_term}" "${log_file}" | head -50
    else
        log_error "Log file not found: ${log_file}"
    fi
}

# Show recent logs
log_tail() {
    local lines="${1:-50}"
    local log_file="${2:-${LOG_FILE}}"
    
    if [[ -f "${log_file}" ]]; then
        echo -e "${LOG_COLOR_CYAN}Recent $lines lines from $(basename "$log_file"):${LOG_COLOR_NC}"
        tail -n "${lines}" "${log_file}"
    else
        log_error "Log file not found: ${log_file}"
    fi
}

# Get log file info
log_info_files() {
    echo -e "${LOG_COLOR_CYAN}Death Star Pi Log Files:${LOG_COLOR_NC}"
    echo -e "  📄 Main Log: ${LOG_FILE}"
    echo -e "  🐛 Debug Log: ${LOG_DEBUG_FILE}"
    echo -e "  ❌ Error Log: ${LOG_ERROR_FILE}"
    echo -e "  ⚡ Performance Log: ${LOG_PERFORMANCE_FILE}"
    echo
    
    for log_file in "${LOG_FILE}" "${LOG_DEBUG_FILE}" "${LOG_ERROR_FILE}" "${LOG_PERFORMANCE_FILE}"; do
        if [[ -f "${log_file}" ]]; then
            local size
            size=$(du -h "${log_file}" | cut -f1)
            local lines
            lines=$(wc -l < "${log_file}")
            echo -e "  $(basename "$log_file"): ${LOG_COLOR_GREEN}$size${LOG_COLOR_NC} ($lines lines)"
        else
            echo -e "  $(basename "$log_file"): ${LOG_COLOR_GRAY}Not created yet${LOG_COLOR_NC}"
        fi
    done
}

# ═══════════════════════════════════════════════════════════════
# COMPATIBILITY FUNCTIONS (for existing scripts)
# ═══════════════════════════════════════════════════════════════

# Maintain compatibility with existing log_message function
log_message() {
    local level="$1"
    local message="$2"
    local context="$3"
    
    case "${level^^}" in
        "DEBUG") log_debug "${message}" "${context}" ;;
        "INFO") log_info "${message}" "${context}" ;;
        "SUCCESS") log_success "${message}" "${context}" ;;
        "WARNING") log_warning "${message}" "${context}" ;;
        "ERROR") log_error "${message}" "${context}" ;;
        "CRITICAL") log_critical "${message}" "${context}" ;;
        "STARTUP") log_info "=== ${message} ===" "${context}" ;;
        "SHUTDOWN") log_info "=== ${message} ===" "${context}" ;;
        *) log_info "${message}" "${context}" ;;
    esac
}

# ═══════════════════════════════════════════════════════════════
# INITIALIZATION CHECK
# ═══════════════════════════════════════════════════════════════

# Verify logging system is ready
if ! command -v date >/dev/null 2>&1; then
    echo "ERROR: date command not available - logging system cannot function"
    exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "$(dirname "${LOG_FILE}")"

# Export functions for use in other scripts
export -f log_init log_cleanup log_debug log_info log_success log_warning log_error log_critical
export -f log_command log_file_operation log_system_info
export -f log_performance_start log_performance_end log_get_duration
export -f log_search log_tail log_info_files log_message

# Set readonly for configuration
readonly LOG_HANDLER_VERSION LOG_SCRIPT_DIR LOG_FILE LOG_DEBUG_FILE LOG_ERROR_FILE LOG_PERFORMANCE_FILE
readonly LOG_MAX_SIZE LOG_MAX_FILES LOG_ENABLE_DEBUG LOG_ENABLE_PERFORMANCE LOG_ENABLE_ERROR_TRACE
readonly LOG_COLOR_RED LOG_COLOR_GREEN LOG_COLOR_YELLOW LOG_COLOR_BLUE LOG_COLOR_CYAN LOG_COLOR_PURPLE LOG_COLOR_GRAY LOG_COLOR_NC