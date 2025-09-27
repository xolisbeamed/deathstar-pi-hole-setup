#!/bin/bash
#===============================================================================
# File: status.sh
# Project: Death Star Pi-hole Setup
# Description: Status and diagnostic script that checks all Death Star Pi
#              components and provides troubleshooting information. Works even
#              if setup was never run - shows current status of all components.
#
# Target Environment:
#   OS: Raspberry Pi OS aarch64
#   Host: Raspberry Pi 5 Model B Rev 1.1
#   Shell: bash
#   Dependencies: log_handler.sh, config_loader.sh
#
# Author: galactic-plane
# Repository: https://github.com/galactic-plane/deathstar-pi-hole-setup
# License: See LICENSE file
#===============================================================================

# Remove the exit on error for more resilient operation
# set -e  # Exit on any error

# Global ShellCheck disables for this diagnostic script
# shellcheck disable=SC2312  # Command substitution in conditions/assignments is acceptable for status checks

# Source the Rich installer utility first to ensure enhanced terminal output
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/rich_installer.sh"

# Ensure Rich library is available for enhanced terminal output
ensure_rich_available

# Load advanced logging system
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/log_handler.sh"

# Load shared configuration
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/lib/config_loader.sh"

# Initialize logging for this script
log_init "status"

# Colors for output (for backward compatibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Rich helper functions
RICH_HELPER="$(dirname "${BASH_SOURCE[0]}")/lib/rich_helper.py"

# Check if Rich is available and use it, otherwise fallback to basic colors
use_rich_if_available() {
# shellcheck disable=SC2312
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

# Configuration variables (from config)
# shellcheck disable=SC2154  # DS_ variables are defined in config_loader.sh
DOMAIN_NAME="${DS_DOMAIN_NAME}"
# shellcheck disable=SC2154  # DS_ variables are defined in config_loader.sh
NEW_HOSTNAME="${DS_NEW_HOSTNAME}"
# shellcheck disable=SC2154  # DS_ variables are defined in config_loader.sh
INTERNET_PI_DIR="${DS_INTERNET_PI_DIR}"
# shellcheck disable=SC2154  # DS_ variables are defined in config_loader.sh
DEATHSTAR_SCRIPTS_DIR="${DS_DEATHSTAR_SCRIPTS_DIR}"

# Hardware detection (with better error handling)
if [[ -f /proc/device-tree/model ]]; then
    PI_MODEL=$(tr -d '\0' </proc/device-tree/model 2>/dev/null || echo "Unknown Hardware")
else
    PI_MODEL="Unknown Hardware"
fi
PI_MEMORY=$(free -m | awk 'NR==2{printf "%.0f", $2/1024}' 2>/dev/null || echo "Unknown")

# Detect if running on Raspberry Pi 5
if [[ "${PI_MODEL}" =~ "Raspberry Pi 5" ]]; then
    PI5_DETECTED=true
else
    PI5_DETECTED=false
fi

# Default ports (from config)
# shellcheck disable=SC2154  # DS_ variables are defined in config_loader.sh
PIHOLE_PORT="${DS_PIHOLE_PORT}"
# shellcheck disable=SC2154  # DS_ variables are defined in config_loader.sh
GRAFANA_PORT="${DS_GRAFANA_PORT}"
# shellcheck disable=SC2154  # DS_ variables are defined in config_loader.sh
PROMETHEUS_PORT="${DS_PROMETHEUS_PORT}"

# Status tracking
ISSUES_FOUND=0
CRITICAL_ISSUES=0
FIXES_APPLIED=0

# Print functions for output formatting (using new logging system)
# Print functions for output formatting (using rich helpers only)
print_status() {
    rich_status "$1" "info"
}

print_success() {
    rich_check "$1" "PASS" "${2:-}"
}

print_warning() {
    rich_check "$1" "WARN" "${2:-}"
    ((ISSUES_FOUND++))
}

print_error() {
    rich_check "$1" "FAIL" "${2:-}"
    ((ISSUES_FOUND++))
    ((CRITICAL_ISSUES++))
}

print_fix() {
    rich_status "💡 FIX: $1" "info"
}

print_fixing() {
    rich_status "🔧 FIXING: $1" "warning"
    log_info "FIXING: $1"
}

print_fixed() {
    rich_check "$1" "PASS" "Fixed successfully"
    log_success "FIXED: $1"
    ((FIXES_APPLIED++))
}

print_separator() {
    if use_rich_if_available; then
        echo  # Just add spacing when using Rich
    else
        echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check service status
check_service_status() {
    local service_name="$1"
    if systemctl is-active --quiet "${service_name}"; then
        return 0
    else
        return 1
    fi
}

# Function to check if port is listening
check_port() {
    local port="$1"
    if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        return 0
    elif ss -tuln 2>/dev/null | grep -q ":${port} "; then
        return 0
    else
        return 1
    fi
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local url="$1"
    local timeout="${2:-5}"
    if curl -s --connect-timeout "${timeout}" --max-time "${timeout}" "${url}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to show banner
show_banner() {
    rich_header "🔍 Death Star Pi Status Check 🤖" "Comprehensive system status and health monitoring"
}

# Function to print table header
print_table_header() {
    local title="$1"
    rich_section "📊 ${title}"
    if ! use_rich_if_available; then
        printf "%-25s %-12s %-15s %-25s\n" "COMPONENT" "STATUS" "HEALTH" "UPDATE/NOTES"
        echo "────────────────────────────────────────────────────────────────────"
    fi
}

# Function to print table row
print_table_row() {
    local component="$1"
    local status="$2"
    local health="$3"
    local notes="$4"
    
    # Color coding for status
    case "${status}" in
        "✅ INSTALLED") status_colored="${GREEN}${status}${NC}" ;;
        "❌ MISSING") status_colored="${RED}${status}${NC}"; ((CRITICAL_ISSUES++)) ;;
        "⚠️ PARTIAL") status_colored="${YELLOW}${status}${NC}"; ((ISSUES_FOUND++)) ;;
        *) status_colored="${status}" ;;
    esac
    
    # Color coding for health
    case "${health}" in
        "🟢 HEALTHY") health_colored="${GREEN}${health}${NC}" ;;
        "🔴 UNHEALTHY") health_colored="${RED}${health}${NC}"; ((CRITICAL_ISSUES++)) ;;
        "🟡 WARNING") health_colored="${YELLOW}${health}${NC}"; ((ISSUES_FOUND++)) ;;
        "⚫ N/A") health_colored="${NC}${health}${NC}" ;;
        *) health_colored="${health}" ;;
    esac
    
    printf "%-25s %-12s %-15s %-25s\n" "${component}" "${status_colored}" "${health_colored}" "${notes}"
}

# Function to check comprehensive installation status
check_installation_status() {
    print_table_header "DEATH STAR PI INSTALLATION STATUS"
    
    # System Packages
    local git_status="❌ MISSING"
    local git_health="⚫ N/A"
    local git_notes="Required for setup"
    if command_exists git; then
        git_status="✅ INSTALLED"
        git_health="🟢 HEALTHY"
        git_notes="$(git --version | awk '{print $3}')"
    fi
    print_table_row "Git" "${git_status}" "${git_health}" "${git_notes}"
    
    local curl_status="❌ MISSING"
    local curl_health="⚫ N/A"
    local curl_notes="Required for downloads"
    if command_exists curl; then
        curl_status="✅ INSTALLED"
        curl_health="🟢 HEALTHY"
        curl_notes="$(curl --version | head -1 | awk '{print $2}')"
    fi
    print_table_row "Curl" "${curl_status}" "${curl_health}" "${curl_notes}"
    
    local wget_status="❌ MISSING"
    local wget_health="⚫ N/A"
    local wget_notes="Required for downloads"
    if command_exists wget; then
        wget_status="✅ INSTALLED"
        wget_health="🟢 HEALTHY"
        wget_notes="$(wget --version | head -1 | awk '{print $3}')"
    fi
    print_table_row "Wget" "${wget_status}" "${wget_health}" "${wget_notes}"
    
    local dnsutils_status="❌ MISSING"
    local dnsutils_health="⚫ N/A"
    local dnsutils_notes="DNS troubleshooting tools"
    if command_exists nslookup && command_exists dig; then
        dnsutils_status="✅ INSTALLED"
        dnsutils_health="🟢 HEALTHY"
        dnsutils_notes="nslookup, dig available"
    fi
    print_table_row "DNS Utils" "${dnsutils_status}" "${dnsutils_health}" "${dnsutils_notes}"
    
    local python_status="❌ MISSING"
    local python_health="⚫ N/A"
    local python_notes="Required for Ansible"
    if command_exists python3; then
        python_status="✅ INSTALLED"
        python_health="🟢 HEALTHY"
        python_notes="$(python3 --version | awk '{print $2}')"
    fi
    print_table_row "Python3" "${python_status}" "${python_health}" "${python_notes}"
    
    local pip_status="❌ MISSING"
    local pip_health="⚫ N/A"
    local pip_notes="Required for Ansible"
    if command_exists pip3; then
        pip_status="✅ INSTALLED"
        pip_health="🟢 HEALTHY"
        pip_notes="$(pip3 --version | awk '{print $2}')"
    fi
    print_table_row "Pip3" "${pip_status}" "${pip_health}" "${pip_notes}"
    
    # Pi 5 Specific Tools
    if [[ "${PI5_DETECTED}" == "true" ]]; then
        local htop_status="❌ MISSING"
        local htop_health="⚫ N/A"
        local htop_notes="Pi 5 monitoring tool"
        if command_exists htop; then
            htop_status="✅ INSTALLED"
            htop_health="🟢 HEALTHY"
            htop_notes="Process monitor"
        fi
        print_table_row "Htop (Pi5)" "${htop_status}" "${htop_health}" "${htop_notes}"
        
        local iotop_status="❌ MISSING"
        local iotop_health="⚫ N/A"
        local iotop_notes="Pi 5 I/O monitoring"
        # Check if iotop is installed using dpkg instead of requiring sudo
        if dpkg -l | grep -q "^ii.*iotop"; then
            iotop_status="✅ INSTALLED"
            # Check if we can access the binary (without sudo)
            if command_exists iotop; then
                iotop_health="🟢 HEALTHY"
                iotop_notes="I/O monitor (use with sudo for full functionality)"
            else
                iotop_health="🟡 WARNING"
                iotop_notes="Package installed but binary not in PATH"
            fi
        fi
        print_table_row "Iotop (Pi5)" "${iotop_status}" "${iotop_health}" "${iotop_notes}"
    fi
}

# Function to check system configuration status
check_system_configuration() {
    print_table_header "SYSTEM CONFIGURATION STATUS"
    
    # Hostname
    local hostname_status="❌ MISSING"
    local hostname_health="⚫ N/A"
    local hostname_notes="Default hostname"
    CURRENT_HOSTNAME=$(hostname)
    if [[ "${CURRENT_HOSTNAME}" == "${NEW_HOSTNAME}" ]]; then
        hostname_status="✅ INSTALLED"
        hostname_health="🟢 HEALTHY"
        hostname_notes="${NEW_HOSTNAME}"
    else
        hostname_notes="Current: ${CURRENT_HOSTNAME}"
    fi
    print_table_row "Hostname" "${hostname_status}" "${hostname_health}" "${hostname_notes}"
    
    # Pi 5 Optimizations
    if [[ "${PI5_DETECTED}" == "true" ]]; then
        # Memory cgroups
        local cgroups_status="❌ MISSING"
        local cgroups_health="⚫ N/A"
        local cgroups_notes="Docker performance"
        if grep -q "cgroup_memory=1 cgroup_enable=memory" /boot/firmware/cmdline.txt 2>/dev/null; then
            cgroups_status="✅ INSTALLED"
            cgroups_health="🟢 HEALTHY"
            cgroups_notes="Enabled in cmdline.txt"
        else
            cgroups_notes="Reboot required after setup"
        fi
        print_table_row "Memory Cgroups (Pi5)" "${cgroups_status}" "${cgroups_health}" "${cgroups_notes}"
        
        # GPU memory optimization
        local gpu_status="❌ MISSING"
        local gpu_health="⚫ N/A"
        local gpu_notes="Headless optimization"
        if grep -q "gpu_mem=16" /boot/firmware/config.txt 2>/dev/null; then
            gpu_status="✅ INSTALLED"
            gpu_health="🟢 HEALTHY"
            gpu_notes="16MB allocated"
        else
            gpu_notes="Default allocation"
        fi
        print_table_row "GPU Memory (Pi5)" "${gpu_status}" "${gpu_health}" "${gpu_notes}"
    fi
    
    # Docker group membership
    local docker_group_status="❌ MISSING"
    local docker_group_health="⚫ N/A"
    local docker_group_notes="User permissions"
    if groups "${USER}" 2>/dev/null | grep -q docker; then
        docker_group_status="✅ INSTALLED"
        if docker ps >/dev/null 2>&1; then
            docker_group_health="🟢 HEALTHY"
            docker_group_notes="Active permissions"
        else
            docker_group_health="🟡 WARNING"
            docker_group_notes="Reboot required"
        fi
    else
        docker_group_notes="Not in docker group"
    fi
    print_table_row "Docker Group" "${docker_group_status}" "${docker_group_health}" "${docker_group_notes}"
    
    # PADD alias
    local padd_status="❌ MISSING"
    local padd_health="⚫ N/A"
    local padd_notes="Pi-hole dashboard"
    if grep -q "alias padd=" "${HOME}/.bashrc" 2>/dev/null; then
        padd_status="✅ INSTALLED"
        padd_health="🟢 HEALTHY"
        padd_notes="Bashrc alias configured"
    else
        padd_notes="Alias not configured"
    fi
    print_table_row "PADD Alias" "${padd_status}" "${padd_health}" "${padd_notes}"
    
    # Configuration files
    local config_status="❌ MISSING"
    local config_health="⚫ N/A"
    local config_notes="Ansible configs"
    if [[ -f "${INTERNET_PI_DIR}/config.yml" && -f "${INTERNET_PI_DIR}/inventory.ini" ]]; then
        config_status="✅ INSTALLED"
        config_health="🟢 HEALTHY"
        config_notes="Both files present"
        elif [[ -f "${INTERNET_PI_DIR}/config.yml" || -f "${INTERNET_PI_DIR}/inventory.ini" ]]; then
        config_status="⚠️ PARTIAL"
        config_health="🟡 WARNING"
        config_notes="Missing files"
    else
        config_notes="No config files found"
    fi
    print_table_row "Ansible Configs" "${config_status}" "${config_health}" "${config_notes}"
    
    echo
}

# Function to check Docker services status
check_docker_services() {
    print_table_header "DOCKER SERVICES STATUS"
    
    # Check if Docker is available first
    if ! command_exists docker || ! docker ps >/dev/null 2>&1; then
        print_table_row "Docker Services" "❌ MISSING" "🔴 UNHEALTHY" "Docker not accessible"
        echo
        return
    fi
    
    # Pi-hole
    local pihole_status="❌ MISSING"
    local pihole_health="⚫ N/A"
    local pihole_notes="DNS filtering service"
    if docker ps --format "table {{.Names}}" | grep -q "pihole"; then
        pihole_status="✅ INSTALLED"
        if docker ps --filter "name=pihole" --filter "status=running" --format "table {{.Names}}" | grep -q "pihole"; then
            pihole_health="🟢 HEALTHY"
            # Check if Pi-hole web interface is accessible
            PI_IP=$(hostname -I | awk '{print $1}')
            if [[ -n "${PI_IP}" ]] && test_http_endpoint "http://${PI_IP}:${PIHOLE_PORT}/admin/" 3; then
                pihole_notes="Running & accessible"
            else
                pihole_health="🟡 WARNING"
                pihole_notes="Running but not accessible"
            fi
            # Check for updates (simplified check)
            local current_image
            current_image=$(docker inspect pihole --format='{{.Config.Image}}' 2>/dev/null)
            if [[ -n "${current_image}" ]]; then
                pihole_notes="${pihole_notes} (${current_image})"
            fi
        else
            pihole_health="🔴 UNHEALTHY"
            pihole_notes="Container stopped"
        fi
    else
        pihole_notes="Not deployed"
    fi
    print_table_row "Pi-hole" "${pihole_status}" "${pihole_health}" "${pihole_notes}"
    
    # Grafana
    local grafana_status="❌ MISSING"
    local grafana_health="⚫ N/A"
    local grafana_notes="Monitoring dashboard"
    if docker ps --format "table {{.Names}}" | grep -q "grafana"; then
        grafana_status="✅ INSTALLED"
        if docker ps --filter "name=grafana" --filter "status=running" --format "table {{.Names}}" | grep -q "grafana"; then
            grafana_health="🟢 HEALTHY"
            # Check if Grafana web interface is accessible
            if [[ -n "${PI_IP}" ]] && test_http_endpoint "http://${PI_IP}:${GRAFANA_PORT}" 3; then
                grafana_notes="Running & accessible"
            else
                grafana_health="🟡 WARNING"
                grafana_notes="Running but not accessible"
            fi
        else
            grafana_health="🔴 UNHEALTHY"
            grafana_notes="Container stopped"
        fi
    else
        grafana_notes="Not deployed"
    fi
    print_table_row "Grafana" "${grafana_status}" "${grafana_health}" "${grafana_notes}"
    
    # Prometheus
    local prometheus_status="❌ MISSING"
    local prometheus_health="⚫ N/A"
    local prometheus_notes="Metrics collection"
    if docker ps --format "table {{.Names}}" | grep -q "prometheus"; then
        prometheus_status="✅ INSTALLED"
        if docker ps --filter "name=prometheus" --filter "status=running" --format "table {{.Names}}" | grep -q "prometheus"; then
            prometheus_health="🟢 HEALTHY"
            # Check if Prometheus web interface is accessible
            if [[ -n "${PI_IP}" ]] && test_http_endpoint "http://${PI_IP}:${PROMETHEUS_PORT}" 3; then
                prometheus_notes="Running & accessible"
            else
                prometheus_health="🟡 WARNING"
                prometheus_notes="Running but not accessible"
            fi
        else
            prometheus_health="🔴 UNHEALTHY"
            prometheus_notes="Container stopped"
        fi
    else
        prometheus_notes="Not deployed"
    fi
    print_table_row "Prometheus" "${prometheus_status}" "${prometheus_health}" "${prometheus_notes}"
    
    # Additional monitoring services
    for service in "speedtest" "nodeexp" "ping"; do
        local service_status="❌ MISSING"
        local service_health="⚫ N/A"
        local service_notes="Monitoring exporter"
        if docker ps --format "table {{.Names}}" | grep -q "${service}"; then
            service_status="✅ INSTALLED"
            if docker ps --filter "name=${service}" --filter "status=running" --format "table {{.Names}}" | grep -q "${service}"; then
                service_health="🟢 HEALTHY"
                service_notes="Running normally"
            else
                service_health="🔴 UNHEALTHY"
                service_notes="Container stopped"
            fi
        else
            service_notes="Not deployed"
        fi
        print_table_row "${service^} Exporter" "${service_status}" "${service_health}" "${service_notes}"
    done
    
    # Optional services (Shelly, Starlink, AirGradient)
    for service in "shelly" "starlink" "airgradient"; do
        if docker ps --format "table {{.Names}}" | grep -q "${service}"; then
            local service_status="✅ INSTALLED"
            local service_health="⚫ N/A"
            local service_notes="Optional service"
            if docker ps --filter "name=${service}" --filter "status=running" --format "table {{.Names}}" | grep -q "${service}"; then
                service_health="🟢 HEALTHY"
                service_notes="Running normally"
            else
                service_health="🔴 UNHEALTHY"
                service_notes="Container stopped"
            fi
            print_table_row "${service^} Monitor" "${service_status}" "${service_health}" "${service_notes}"
        fi
    done
    
    echo
}

# Function to check system health and performance
check_system_health() {
    print_table_header "SYSTEM HEALTH & PERFORMANCE"
    
    # Hardware info
    print_table_row "Hardware" "✅ DETECTED" "🟢 HEALTHY" "${PI_MODEL}"
    print_table_row "RAM Total" "✅ DETECTED" "🟢 HEALTHY" "${PI_MEMORY}GB available"
    
    # System load
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | sed 's/,//')
    local load_status="✅ NORMAL"
    local load_health="🟢 HEALTHY"
    local load_notes="Load: ${load_avg}"
    if (( $(echo "${load_avg} > 2.0" | bc -l 2>/dev/null || echo 0) )); then
        load_health="🟡 WARNING"
        load_notes="High load: ${load_avg}"
    fi
    if (( $(echo "${load_avg} > 4.0" | bc -l 2>/dev/null || echo 0) )); then
        load_health="🔴 UNHEALTHY"
        load_notes="Critical load: ${load_avg}"
    fi
    print_table_row "System Load" "${load_status}" "${load_health}" "${load_notes}"
    
    # Memory usage
    local mem_usage
    mem_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local mem_status="✅ NORMAL"
    local mem_health="🟢 HEALTHY"
    local mem_notes="Usage: ${mem_usage}%"
    if (( $(echo "${mem_usage} > 80" | bc -l 2>/dev/null || echo 0) )); then
        mem_health="🟡 WARNING"
        mem_notes="High usage: ${mem_usage}%"
    fi
    if (( $(echo "${mem_usage} > 95" | bc -l 2>/dev/null || echo 0) )); then
        mem_health="🔴 UNHEALTHY"
        mem_notes="Critical usage: ${mem_usage}%"
    fi
    print_table_row "Memory Usage" "${mem_status}" "${mem_health}" "${mem_notes}"
    
    # Disk space
    local disk_usage
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    local disk_status="✅ NORMAL"
    local disk_health="🟢 HEALTHY"
    local disk_notes="Usage: ${disk_usage}%"
    if [[ ${disk_usage} -gt 80 ]]; then
        disk_health="🟡 WARNING"
        disk_notes="High usage: ${disk_usage}%"
    fi
    if [[ ${disk_usage} -gt 95 ]]; then
        disk_health="🔴 UNHEALTHY"
        disk_notes="Critical usage: ${disk_usage}%"
    fi
    print_table_row "Disk Space" "${disk_status}" "${disk_health}" "${disk_notes}"
    
    # Temperature (if available)
    if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
        local temp_raw
        temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp)
        local temp_c=$((temp_raw / 1000))
        local temp_status="✅ NORMAL"
        local temp_health="🟢 HEALTHY"
        local temp_notes="CPU: ${temp_c}°C"
        if [[ ${temp_c} -gt 70 ]]; then
            temp_health="🟡 WARNING"
            temp_notes="Warm: ${temp_c}°C"
        fi
        if [[ ${temp_c} -gt 80 ]]; then
            temp_health="🔴 UNHEALTHY"
            temp_notes="Hot: ${temp_c}°C"
        fi
        print_table_row "CPU Temperature" "${temp_status}" "${temp_health}" "${temp_notes}"
    fi
    
    # Network connectivity
    local network_status="❌ MISSING"
    local network_health="🔴 UNHEALTHY"
    local network_notes="No connectivity"
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        network_status="✅ CONNECTED"
        network_health="🟢 HEALTHY"
        PI_IP=$(hostname -I | awk '{print $1}')
        network_notes="IP: ${PI_IP}"
    fi
    print_table_row "Internet" "${network_status}" "${network_health}" "${network_notes}"
    
    # DNS resolution
    local dns_status="❌ MISSING"
    local dns_health="🔴 UNHEALTHY"
    local dns_notes="DNS not working"
    if nslookup google.com >/dev/null 2>&1; then
        dns_status="✅ WORKING"
        dns_health="🟢 HEALTHY"
        dns_notes="Resolution working"
    fi
    print_table_row "DNS Resolution" "${dns_status}" "${dns_health}" "${dns_notes}"
    
    echo
}

# Function to check system basics
check_system_basics() {
    print_separator
    echo -e "${BLUE}🖥️  SYSTEM BASICS${NC}"
    print_separator
    
    # Hardware information
    print_success "Hardware: ${PI_MODEL}"
    print_success "Available RAM: ${PI_MEMORY}GB"
    if [[ "${PI5_DETECTED}" == "true" ]]; then
        print_success "Raspberry Pi 5 optimizations available"
        
        # Check Pi 5 specific optimizations
        if grep -q "cgroup_memory=1 cgroup_enable=memory" /boot/firmware/cmdline.txt 2>/dev/null; then
            print_success "Memory cgroups enabled (Pi 5 optimization)"
        else
            print_warning "Memory cgroups not enabled"
            print_fix "Run ./setup.sh to enable Pi 5 optimizations"
        fi
        
        if grep -q "gpu_mem=16" /boot/firmware/config.txt 2>/dev/null; then
            print_success "GPU memory optimized for headless operation"
        else
            print_warning "GPU memory not optimized"
            print_fix "Run ./setup.sh to optimize GPU memory allocation"
        fi
    fi
    
    # Hostname check
    CURRENT_HOSTNAME=$(hostname)
    if [[ "${CURRENT_HOSTNAME}" == "${NEW_HOSTNAME}" ]]; then
        print_success "Hostname is correctly set to '${NEW_HOSTNAME}'"
    else
        print_warning "Hostname is '${CURRENT_HOSTNAME}', expected '${NEW_HOSTNAME}'"
        print_fix "Run ./setup.sh to fix hostname configuration"
    fi
    
    # IP address
    PI_IP=$(hostname -I | awk '{print $1}')
    if [[ -n "${PI_IP}" ]]; then
        print_success "Pi IP address: ${PI_IP}"
    else
        print_error "Could not determine Pi IP address"
        print_fix "Check network connection: ip addr show"
    fi
    
    # DNS resolution
    if nslookup google.com >/dev/null 2>&1; then
        print_success "DNS resolution working"
    else
        print_error "DNS resolution not working"
        print_fix "Check /etc/resolv.conf and network settings"
    fi
    
    # Internet connectivity
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        print_success "Internet connectivity working"
    else
        print_error "No internet connectivity"
        print_fix "Check network configuration and gateway"
    fi
    
    # System load
    LOAD_AVG=$(uptime | awk -F'load average:' '{ print $2 }' | awk '{ print $1 }' | sed 's/,//')
    if (( $(echo "${LOAD_AVG} < 2.0" | bc -l) )); then
        print_success "System load is healthy: ${LOAD_AVG}"
    else
        print_warning "System load is high: ${LOAD_AVG}"
        print_fix "Check running processes: htop or top"
    fi
    
    # Memory usage
    MEM_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    if (( $(echo "${MEM_USAGE} < 80" | bc -l) )); then
        print_success "Memory usage is healthy: ${MEM_USAGE}%"
    else
        print_warning "Memory usage is high: ${MEM_USAGE}%"
        print_fix "Check memory-hungry processes: free -h && ps aux --sort=-%mem"
    fi
    
    # Disk space
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ ${DISK_USAGE} -lt 80 ]]; then
        print_success "Disk usage is healthy: ${DISK_USAGE}%"
    else
        print_warning "Disk usage is high: ${DISK_USAGE}%"
        print_fix "Clean up disk space: sudo apt autoremove && docker system prune"
    fi
    
    echo
}

# Function to check required software
check_required_software() {
    print_separator
    echo -e "${BLUE}📦 REQUIRED SOFTWARE${NC}"
    print_separator
    
    # Docker
    if command_exists docker; then
        print_success "Docker is installed"
        
        # Docker service
        if check_service_status docker; then
            print_success "Docker service is running"
        else
            print_error "Docker service is not running"
            print_fix "Run ./setup.sh to install and configure Docker"
        fi
        
        # Docker permissions
        if docker ps >/dev/null 2>&1; then
            print_success "Docker permissions are correct"
        else
            print_warning "Docker permission issues detected"
            print_fix "Run ./setup.sh to fix Docker permissions (may require reboot)"
        fi
    else
        print_error "Docker is not installed"
        print_fix "Run the Death Star setup script to install Docker"
    fi
    
    # Ansible
    if command_exists ansible; then
        ANSIBLE_VERSION=$(ansible --version | head -1 | awk '{print $2}')
        print_success "Ansible is installed (version ${ANSIBLE_VERSION})"
    else
        print_error "Ansible is not installed"
        print_fix "pip3 install ansible"
    fi
    
    # Git
    if command_exists git; then
        print_success "Git is installed"
    else
        print_error "Git is not installed"
        print_fix "sudo apt install -y git"
    fi
    
    # Python3 and pip3
    if command_exists python3; then
        print_success "Python3 is installed"
    else
        print_error "Python3 is not installed"
        print_fix "sudo apt install -y python3"
    fi
    
    if command_exists pip3; then
        print_success "pip3 is installed"
    else
        print_error "pip3 is not installed"
        print_fix "sudo apt install -y python3-pip"
    fi
    
    echo
}

# Function to check Death Star scripts
check_deathstar_scripts() {
    print_separator
    echo -e "${BLUE}📜 DEATH STAR SCRIPTS${NC}"
    print_separator
    
    # Check if deathstar scripts directory exists
    if [[ -d "${DEATHSTAR_SCRIPTS_DIR}" ]]; then
        print_success "Death Star scripts directory exists"
        
        # Check individual scripts
        for script in "setup.sh" "update.sh" "remove.sh" "status.sh"; do
            if [[ -f "${DEATHSTAR_SCRIPTS_DIR}/${script}" ]]; then
                if [[ -x "${DEATHSTAR_SCRIPTS_DIR}/${script}" ]]; then
                    print_success "${script} is present and executable"
                else
                    print_warning "${script} is present but not executable"
                    print_fix "Run ./setup.sh to fix script permissions"
                fi
            else
                print_error "${script} is missing"
                print_fix "Re-run the deployment script from your Fedora machine"
            fi
        done
    else
        print_error "Death Star scripts directory not found"
        print_fix "Create directory: mkdir -p ${DEATHSTAR_SCRIPTS_DIR}"
    fi
    
    echo
}

# Function to check internet-pi repository
check_internet_pi_repo() {
    print_separator
    echo -e "${BLUE}📁 INTERNET-PI REPOSITORY${NC}"
    print_separator
    
    if [[ -d "${INTERNET_PI_DIR}" ]]; then
        print_success "Internet-pi repository directory exists"
        
        # Check key files
        if [[ -f "${INTERNET_PI_DIR}/main.yml" ]]; then
            print_success "main.yml playbook found"
        else
            print_error "main.yml playbook missing"
            print_fix "Re-clone repository or run setup script"
        fi
        
        if [[ -f "${INTERNET_PI_DIR}/config.yml" ]]; then
            print_success "config.yml configuration found"
        else
            print_warning "config.yml configuration missing"
            print_fix "Run the Death Star setup script to generate config.yml"
        fi
        
        if [[ -f "${INTERNET_PI_DIR}/inventory.ini" ]]; then
            print_success "inventory.ini found"
        else
            print_warning "inventory.ini missing"
            print_fix "Run the Death Star setup script to generate inventory.ini"
        fi
        
    else
        print_error "Internet-pi repository not found"
        print_fix "Run the Death Star setup script to clone the repository"
    fi
    
    echo
}

# Function to check Docker containers
check_docker_containers() {
    print_separator
    echo -e "${BLUE}🐳 DOCKER CONTAINERS${NC}"
    print_separator
    
    if ! command_exists docker; then
        print_error "Docker not available for container checks"
        return
    fi
    
    if ! docker ps >/dev/null 2>&1; then
        print_error "Cannot access Docker (permission or service issue)"
        return
    fi
    
    # Get running containers
    RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}\t{{.Status}}" | tail -n +2)
    
    if [[ -z "${RUNNING_CONTAINERS}" ]]; then
        print_warning "No Docker containers are running"
        print_fix "Run ./setup.sh to deploy and start all services"
        
        # Check if internet-pi directory exists and config is present
        if [[ -f "${INTERNET_PI_DIR}/config.yml" ]] && [[ -f "${INTERNET_PI_DIR}/main.yml" ]]; then
            print_status "Found internet-pi configuration - run ./setup.sh to restart services"
        else
            print_warning "No internet-pi configuration found. Run ./setup.sh first"
        fi
    else
        print_status "Running containers:"
        echo "${RUNNING_CONTAINERS}" | while read -r line; do
            echo -e "  ${GREEN}→${NC} ${line}"
        done
    fi
    
    # Check specific containers
    containers=("pihole" "grafana" "prometheus" "node-exporter" "speedtest")
    
    for container in "${containers[@]}"; do
        if docker ps | grep -q "${container}"; then
            print_success "${container} container is running"
        else
            if docker ps -a | grep -q "${container}"; then
                print_warning "${container} container exists but is not running"
                print_fix "Run ./setup.sh to restart all services"
            else
                print_status "${container} container not found (may not be installed)"
            fi
        fi
    done
    
    echo
}

# Function to check network services
check_network_services() {
    print_separator
    echo -e "${BLUE}🌐 NETWORK SERVICES${NC}"
    print_separator
    
    # Get Pi IP for testing
    PI_IP=$(hostname -I | awk '{print $1}')
    
    # Pi-hole
    if check_port "${PIHOLE_PORT}"; then
        print_success "Pi-hole port ${PIHOLE_PORT} is listening"
        
        if test_http_endpoint "http://localhost:${PIHOLE_PORT}/admin"; then
            print_success "Pi-hole web interface is accessible"
        else
            print_warning "Pi-hole port open but web interface not responding"
            print_fix "Check Pi-hole logs: docker logs pihole"
        fi
    else
        print_error "Pi-hole port ${PIHOLE_PORT} is not listening"
        print_fix "Check if Pi-hole container is running: docker ps | grep pihole"
    fi
    
    # Grafana
    if check_port "${GRAFANA_PORT}"; then
        print_success "Grafana port ${GRAFANA_PORT} is listening"
        
        if test_http_endpoint "http://localhost:${GRAFANA_PORT}"; then
            print_success "Grafana web interface is accessible"
        else
            print_warning "Grafana port open but web interface not responding"
            print_fix "Check Grafana logs: docker logs grafana"
        fi
    else
        print_warning "Grafana port ${GRAFANA_PORT} is not listening"
        print_fix "Check if Grafana container is running: docker ps | grep grafana"
    fi
    
    # Prometheus
    if check_port "${PROMETHEUS_PORT}"; then
        print_success "Prometheus port ${PROMETHEUS_PORT} is listening"
        
        if test_http_endpoint "http://localhost:${PROMETHEUS_PORT}"; then
            print_success "Prometheus web interface is accessible"
        else
            print_warning "Prometheus port open but web interface not responding"
            print_fix "Check Prometheus logs: docker logs prometheus"
        fi
    else
        print_warning "Prometheus port ${PROMETHEUS_PORT} is not listening"
        print_fix "Check if Prometheus container is running: docker ps | grep prometheus"
    fi
    
    # DNS functionality (Pi-hole)
    if nslookup google.com localhost >/dev/null 2>&1; then
        print_success "DNS resolution through Pi-hole is working"
    else
        print_warning "DNS resolution through Pi-hole may not be working"
        print_fix "Check Pi-hole DNS settings and logs"
    fi
    
    echo
}

# Function to check configuration files
check_configurations() {
    print_separator
    echo -e "${BLUE}⚙️  CONFIGURATION FILES${NC}"
    print_separator
    
    # Check config.yml
    if [[ -f "${INTERNET_PI_DIR}/config.yml" ]]; then
        # Check for Death Star domain configuration
        if grep -q "${DOMAIN_NAME}" "${INTERNET_PI_DIR}/config.yml"; then
            print_success "Death Star domain configuration found in config.yml"
        else
            print_warning "Death Star domain not configured in config.yml"
            print_fix "Re-run the Death Star setup script to update configuration"
        fi
        
        # Check for enabled services
        if grep -q "pihole_enable: true" "${INTERNET_PI_DIR}/config.yml"; then
            print_success "Pi-hole is enabled in configuration"
        else
            print_status "Pi-hole is disabled in configuration"
        fi
        
        if grep -q "monitoring_enable: true" "${INTERNET_PI_DIR}/config.yml"; then
            print_success "Monitoring is enabled in configuration"
        else
            print_status "Monitoring is disabled in configuration"
        fi
    else
        print_error "config.yml not found"
        print_fix "Run the Death Star setup script to generate configuration"
    fi
    
    # Check /etc/hosts for hostname
    if grep -q "${NEW_HOSTNAME}" /etc/hosts; then
        print_success "Death Star hostname configured in /etc/hosts"
    else
        print_warning "Death Star hostname not found in /etc/hosts"
        print_fix "Add hostname: echo '127.0.1.1 ${NEW_HOSTNAME}' | sudo tee -a /etc/hosts"
    fi
    
    # Check PADD alias
    if grep -q "alias padd=" "${HOME}/.bashrc" 2>/dev/null; then
        print_success "PADD alias configured in ~/.bashrc"
        print_status "💡 You can run 'padd' to view Pi-hole dashboard"
    else
        print_warning "PADD alias not found in ~/.bashrc"
        print_fix "Run ./setup.sh to install PADD and create alias"
    fi
    
    echo
}

# Function to check logs for errors
check_logs() {
    print_separator
    echo -e "${BLUE}📋 LOG ANALYSIS${NC}"
    print_separator
    
    # Check system logs for errors
    RECENT_ERRORS=$(journalctl --since="1 hour ago" --priority=err --no-pager -q | wc -l)
    if [[ ${RECENT_ERRORS} -eq 0 ]]; then
        print_success "No system errors in the last hour"
    else
        print_warning "${RECENT_ERRORS} system errors found in the last hour"
        print_fix "Check system logs: journalctl --since='1 hour ago' --priority=err"
    fi
    
    # Check Docker logs for errors (if Docker is available)
    if command_exists docker && docker ps >/dev/null 2>&1; then
        containers=("pihole" "grafana" "prometheus")
        for container in "${containers[@]}"; do
            if docker ps | grep -q "${container}"; then
                ERROR_COUNT=$(docker logs "${container}" --since=1h 2>&1 | grep -c "error\|failed\|exception")
                if [[ ${ERROR_COUNT} -eq 0 ]]; then
                    print_success "${container}: No errors in recent logs"
                else
                    print_warning "${container}: ${ERROR_COUNT} errors found in recent logs"
                    print_fix "Check ${container} logs: docker logs ${container} --tail=50"
                fi
            fi
        done
    fi
    
    echo
}

# Function to show access URLs
show_access_info() {
    print_separator
    echo -e "${BLUE}🔗 ACCESS INFORMATION${NC}"
    print_separator
    
    PI_IP=$(hostname -I | awk '{print $1}')
    
    echo -e "${GREEN}Death Star Pi Services:${NC}"
    
    # Check and show Pi-hole
    if check_port "${PIHOLE_PORT}"; then
        echo -e "  🕳️  Pi-hole Admin:    http://${PI_IP}:${PIHOLE_PORT}/admin"
        echo -e "                      http://${NEW_HOSTNAME}:${PIHOLE_PORT}/admin"
    else
        echo -e "  🕳️  Pi-hole Admin:    ${RED}Not available${NC}"
    fi
    
    # Check and show Grafana
    if check_port "${GRAFANA_PORT}"; then
        echo -e "  📊 Grafana:          http://${PI_IP}:${GRAFANA_PORT}"
        echo -e "                      http://${NEW_HOSTNAME}:${GRAFANA_PORT}"
    else
        echo -e "  📊 Grafana:          ${RED}Not available${NC}"
    fi
    
    # Check and show Prometheus
    if check_port "${PROMETHEUS_PORT}"; then
        echo -e "  📈 Prometheus:       http://${PI_IP}:${PROMETHEUS_PORT}"
        echo -e "                      http://${NEW_HOSTNAME}:${PROMETHEUS_PORT}"
    else
        echo -e "  📈 Prometheus:       ${RED}Not available${NC}"
    fi
    
    echo
}

# Function to provide recommendations
show_recommendations() {
    print_separator
    echo -e "${BLUE}💡 RECOMMENDATIONS${NC}"
    print_separator
    
    if [[ ${CRITICAL_ISSUES} -eq 0 ]] && [[ ${ISSUES_FOUND} -eq 0 ]]; then
        echo -e "${GREEN}🎉 Excellent! Your Death Star Pi is fully operational!${NC}"
        echo
        echo -e "${BLUE}Maintenance recommendations:${NC}"
        echo -e "  • Run system updates monthly: ${CYAN}sudo apt update && sudo apt upgrade${NC}"
        echo -e "  • Check disk space regularly: ${CYAN}df -h${NC}"
        echo -e "  • Monitor container logs: ${CYAN}docker logs <container-name>${NC}"
        echo -e "  • Backup your configuration: ${CYAN}cp ${INTERNET_PI_DIR}/config.yml ~/config-backup.yml${NC}"
        elif [[ ${CRITICAL_ISSUES} -eq 0 ]]; then
        echo -e "${YELLOW}✅ Your Death Star Pi is mostly operational with ${ISSUES_FOUND} minor issues.${NC}"
        echo
        echo -e "${BLUE}Priority fixes:${NC}"
        echo -e "  • Review warnings above and apply suggested fixes"
        echo -e "  • Test services after applying fixes"
        echo -e "  • Re-run this status script to verify fixes"
    else
        echo -e "${RED}⚠️ Your Death Star Pi has ${CRITICAL_ISSUES} critical issues that need attention.${NC}"
        echo
        echo -e "${BLUE}Immediate actions needed:${NC}"
        echo -e "  • Fix critical errors marked with ❌"
        echo -e "  • Consider re-running the setup script: ${CYAN}./setup.sh${NC}"
        echo -e "  • Check system logs: ${CYAN}journalctl -xe${NC}"
        echo -e "  • Verify network connectivity and DNS settings"
    fi
    
    echo
    echo -e "${BLUE}Useful commands:${NC}"
    echo -e "  • System status:     ${CYAN}systemctl status docker${NC}"
    echo -e "  • Container status:  ${CYAN}docker ps -a${NC}"
    echo -e "  • Container logs:    ${CYAN}docker logs <container-name>${NC}"
    echo -e "  • System resources:  ${CYAN}htop${NC} or ${CYAN}free -h${NC}"
    echo -e "  • Network ports:     ${CYAN}netstat -tuln${NC} or ${CYAN}ss -tuln${NC}"
    if [[ "${PI5_DETECTED}" == "true" ]]; then
        echo -e "  • Pi 5 performance:  ${CYAN}iotop${NC} for I/O monitoring"
        echo -e "  • Memory cgroups:    ${CYAN}cat /proc/cgroups${NC}"
        echo -e "  • Pi-hole dashboard: ${CYAN}padd${NC} (if alias installed)"
    fi
    
    echo
}

# Function to show usage
show_usage() {
    echo "Death Star Pi Status & Diagnostic Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0              Run status check with fix recommendations"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
        ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
        ;;
    esac
done

# Main execution
main() {
    # Start performance monitoring for entire script
    log_performance_start "status_check_total"
    
    show_banner
    
    # New table-based status reporting
    check_installation_status
    check_system_configuration
    check_docker_services
    check_system_health
    
    # Legacy functions still available but streamlined
    check_network_services
    check_logs
    show_access_info
    show_recommendations
    
    print_separator
    if [[ ${FIXES_APPLIED} -gt 0 ]]; then
        echo -e "${GREEN}🔧 Applied ${FIXES_APPLIED} automatic fixes during this scan!${NC}"
        echo
    fi
    
    if [[ ${ISSUES_FOUND} -eq 0 ]]; then
        echo -e "${GREEN}🌟 Death Star Pi Status: FULLY OPERATIONAL${NC}"
        elif [[ ${CRITICAL_ISSUES} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️ Death Star Pi Status: OPERATIONAL WITH WARNINGS (${ISSUES_FOUND} issues)${NC}"
    else
        echo -e "${RED}❌ Death Star Pi Status: CRITICAL ISSUES DETECTED (${CRITICAL_ISSUES} critical, ${ISSUES_FOUND} total)${NC}"
    fi
    
    # Check if major components are missing and provide helpful guidance
    if ! command -v docker >/dev/null 2>&1 || ! command -v ansible >/dev/null 2>&1; then
        echo
        echo -e "${BLUE}💡 SETUP GUIDANCE:${NC}"
        echo -e "   To install Death Star Pi components, run: ${GREEN}./setup.sh${NC}"
        echo -e "   For updates to existing components, run: ${GREEN}./update.sh${NC}"
        echo -e "   For complete removal, run: ${GREEN}./remove.sh${NC}"
    fi
    
    if [[ ${FIXES_APPLIED} -gt 0 ]]; then
        echo -e "${BLUE}💡 Re-run the status check to verify all fixes: ./status.sh${NC}"
    fi
    print_separator
    
    # End performance monitoring
    log_performance_end "status_check_total"
    
    echo
}

# Check if running as root
if [[ ${EUID} -eq 0 ]]; then
    print_error "This script should not be run as root"
    exit 1
fi

# Run main function
main "$@"
