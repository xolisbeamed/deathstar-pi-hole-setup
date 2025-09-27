#!/bin/bash
#===============================================================================
# File: remove.sh
# Project: Death Star Pi-hole Setup
# Description: Complete removal script that uninstalls all Death Star Pi
#              components and cleans up the system. Works even if setup was
#              never run - will attempt to remove everything.
#
#              REMOVE_ALL Flag: Set REMOVE_ALL=true at the top of this script
#              to automatically enable ALL removal options and skip ALL
#              confirmations. Use with EXTREME CAUTION - this will remove
#              everything without any user interaction!
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

#===============================================================================
# REMOVE ALL FLAG - Set to true to skip all confirmations and remove everything
#===============================================================================
# When set to true, this flag will:
# - Skip the legal disclaimer confirmation
# - Skip the final removal confirmation
# - Enable ALL removal items in the configuration (overrides individual settings)
# - Proceed with complete Death Star Pi removal without user interaction
#
# ⚠️  WARNING: Only set this to true if you are ABSOLUTELY CERTAIN you want to
#              remove ALL Death Star Pi components without any confirmations!
#
# Default: false (safe mode - all confirmations required)
# To enable: Change to REMOVE_ALL=true
REMOVE_ALL=false

# Remove the exit on error for more resilient operation
# set -e  # Exit on any error

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

# Ensure configuration is loaded
load_deathstar_config

# Initialize logging for this script
log_init "remove"

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

rich_disclaimer() {
    local disclaimer_type="${1:-legal}"
    
    if use_rich_if_available; then
        python3 "${RICH_HELPER}" disclaimer --type "${disclaimer_type}"
    else
        # Fallback to manual box drawing
        if [[ "${disclaimer_type}" == "legal" ]]; then
            echo -e "${RED}"
            echo "══════════════════════════════════════════════════════════════════"
            echo "                        ⚠️  LEGAL DISCLAIMER ⚠️                   "
            echo ""
            echo "  This script is provided 'AS IS' without warranty of any kind.  "
            echo "  The author(s) cannot be held responsible for any damage,        "
            echo "  data loss, system instability, or other issues that may         "
            echo "  result from running this script.                                "
            echo ""
            echo "  YOU RUN THIS SCRIPT ENTIRELY AT YOUR OWN RISK.                 "
            echo ""
            echo "  By proceeding, you acknowledge that you:                        "
            echo "  • Understand the risks involved                                 "
            echo "  • Have backups of important data                                "
            echo "  • Accept full responsibility for any consequences               "
            echo "  • Release the author(s) from any liability                      "
            echo ""
            echo "══════════════════════════════════════════════════════════════════"
            echo -e "${NC}"
            elif [[ "${disclaimer_type}" == "removal" ]]; then
            echo -e "${RED}"
            echo "══════════════════════════════════════════════════════════════════"
            echo "               🚨 COMPLETE REMOVAL CONFIRMATION 🚨               "
            echo ""
            echo "  This will COMPLETELY REMOVE all Death Star Pi components:      "
            echo "  • Docker and all containers                                     "
            echo "  • Ansible (if installed by this script)                        "
            echo "  • All configuration files and data                             "
            echo "  • System modifications and optimizations                       "
            echo ""
            echo "  Type 'REMOVE DEATH STAR' to proceed with complete removal,     "
            echo "  or anything else to use interactive mode.                       "
            echo ""
            echo "══════════════════════════════════════════════════════════════════"
            echo -e "${NC}"
            elif [[ "${disclaimer_type}" == "system_removal" ]]; then
            echo -e "${RED}"
            echo "══════════════════════════════════════════════════════════════════"
            echo "                    ⚠️  COMPLETE SYSTEM REMOVAL ⚠️                "
            echo ""
            echo "  This will completely remove all Death Star Pi components:      "
            echo "  • Pi-hole (DNS filtering)                                      "
            echo "  • Grafana & Prometheus (monitoring)                            "
            echo "  • All monitoring services                                      "
            echo "  • Docker containers, images, and volumes                       "
            echo "  • internet-pi repository and configurations                    "
            echo "  • Ansible collections and configurations                       "
            echo "  • System hostname and /etc/hosts changes                       "
            echo "  • Pi 5 boot optimizations (if applicable)                      "
            echo "  • PADD alias and customizations (if applicable)                "
            echo ""
            echo "  ⚠️  THIS ACTION CANNOT BE UNDONE! ⚠️                            "
            echo "══════════════════════════════════════════════════════════════════"
            echo -e "${NC}"
        fi
    fi
}

# JSON configuration file for removal options
REMOVAL_CONFIG_FILE="${DS_CONFIG_DIR:-${HOME}/Repo}/deathstar_removal_config.json"

# Function to show completion message
show_completion_message() {
    echo -e "${GREEN}All Death Star Pi components have been removed:${NC}"
    echo -e "  ✅ All Docker containers stopped and removed"
    echo -e "  ✅ All Docker volumes and data deleted"
    echo -e "  ✅ All configuration directories removed"
    echo -e "  ✅ internet-pi repository removed"
    echo -e "  ✅ Ansible virtual environment and collections removed"
    echo -e "  ✅ Ansible symlinks and conflicting packages removed"
    echo -e "  ✅ PADD installations and aliases removed"
    echo -e "  ✅ Setup state and config files removed"
    echo -e "  ✅ System hostname restored (if changed)"
    echo -e "  ✅ /etc/hosts file cleaned up"
    echo -e "  ✅ Docker group membership removed"
}

# Configuration variables (from config)
CONFIG_DIR="${DS_CONFIG_DIR:-${HOME}}"
INTERNET_PI_DIR="${DS_INTERNET_PI_DIR:-${HOME}/Repo/internet-pi}"
NEW_HOSTNAME="${DS_NEW_HOSTNAME:-deathstar-core}"
ORIGINAL_HOSTNAME="${DS_ORIGINAL_HOSTNAME:-raspberrypi}"  # Default Pi hostname

# Hardware detection (with better error handling)
if [[ -f /proc/device-tree/model ]]; then
    PI_MODEL=$(tr -d '\0' </proc/device-tree/model 2>/dev/null || echo "Unknown Hardware")
else
    PI_MODEL="Unknown Hardware"
fi

# Detect if running on Raspberry Pi 5
if [[ "${PI_MODEL}" =~ "Raspberry Pi 5" ]]; then
    PI5_DETECTED=true
else
    PI5_DETECTED=false
fi

# Print functions for output formatting (using rich helpers only)
print_status() {
    rich_status "$1" "info"
}

print_success() {
    rich_status "$1" "success"
}

print_warning() {
    rich_status "$1" "warning"
}

print_error() {
    rich_status "$1" "error"
}

# Function to check if directory exists
check_directory() {
    local dir="$1"
    if [[ -d "${dir}" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to generate removal configuration JSON
generate_removal_config() {
    local config_file="$1"
    
    print_status "📋 Generating removal configuration file: ${config_file}"
    
    # Detect what's actually installed
    detect_installed_services_quiet
    
    # Create the JSON structure with dependency tree
    cat > "${config_file}" << 'EOF'
{
  "version": "1.0",
  "description": "Death Star Pi Removal Configuration",
  "instructions": [
    "Set 'enabled': true for items you want to remove",
    "Set 'enabled': false for items you want to keep",
    "Child items are dependencies of their parent",
    "If you remove a parent, all children will be removed too",
    "You can selectively remove children while keeping the parent"
  ],
  "removal_tree": {
    "services": {
      "enabled": false,
      "description": "Death Star Pi Services",
      "children": {
        "pi_hole": {
          "enabled": false,
          "description": "Pi-hole DNS filtering service",
          "path": "CONFIG_DIR/pi-hole",
          "impact": "DNS filtering will stop - update router DNS settings",
          "children": {
            "containers": {
              "enabled": false,
              "description": "Pi-hole Docker containers and volumes"
            },
            "configuration": {
              "enabled": false,
              "description": "Pi-hole configuration files and data"
            }
          }
        },
        "internet_monitoring": {
          "enabled": false,
          "description": "Internet monitoring (Grafana & Prometheus)",
          "path": "CONFIG_DIR/internet-monitoring",
          "impact": "Network monitoring dashboards will be lost",
          "children": {
            "containers": {
              "enabled": false,
              "description": "Monitoring Docker containers and volumes"
            },
            "configuration": {
              "enabled": false,
              "description": "Grafana and Prometheus configuration files"
            },
            "data": {
              "enabled": false,
              "description": "Historical monitoring data and dashboards"
            }
          }
        },
        "shelly_monitoring": {
          "enabled": false,
          "description": "Shelly Plug monitoring service",
          "path": "CONFIG_DIR/shelly-plug-prometheus",
          "impact": "Shelly device monitoring will stop",
          "children": {
            "containers": {
              "enabled": false,
              "description": "Shelly monitoring containers"
            },
            "configuration": {
              "enabled": false,
              "description": "Shelly monitoring configuration"
            }
          }
        },
        "starlink_monitoring": {
          "enabled": false,
          "description": "Starlink monitoring service",
          "path": "CONFIG_DIR/starlink-exporter",
          "impact": "Starlink monitoring will stop",
          "children": {
            "containers": {
              "enabled": false,
              "description": "Starlink monitoring containers"
            },
            "configuration": {
              "enabled": false,
              "description": "Starlink monitoring configuration"
            }
          }
        },
        "airgradient_monitoring": {
          "enabled": false,
          "description": "AirGradient air quality monitoring",
          "path": "CONFIG_DIR/airgradient-prometheus",
          "impact": "Air quality monitoring will stop",
          "children": {
            "containers": {
              "enabled": false,
              "description": "AirGradient monitoring containers"
            },
            "configuration": {
              "enabled": false,
              "description": "AirGradient monitoring configuration"
            }
          }
        }
      }
    },
    "infrastructure": {
      "enabled": false,
      "description": "Core Infrastructure Components",
      "children": {
        "docker": {
          "enabled": false,
          "description": "Docker container platform",
          "impact": "Will affect ANY other Docker containers on system",
          "children": {
            "cleanup_resources": {
              "enabled": false,
              "description": "Clean up unused Docker images, containers, networks"
            },
            "remove_completely": {
              "enabled": false,
              "description": "Remove Docker entirely from system",
              "impact": "DANGER: Removes Docker completely - affects all containers"
            }
          }
        },
        "ansible": {
          "enabled": false,
          "description": "Ansible automation platform",
          "impact": "Only remove if installed by Death Star Pi setup",
          "children": {
            "virtual_environment": {
              "enabled": false,
              "description": "Ansible virtual environment"
            },
            "collections": {
              "enabled": false,
              "description": "Ansible collections and configurations"
            },
            "system_packages": {
              "enabled": false,
              "description": "System-installed Ansible packages"
            }
          }
        },
        "internet_pi_repo": {
          "enabled": false,
          "description": "Internet-pi repository and files",
          "path": "INTERNET_PI_DIR",
          "impact": "Repository files will be permanently deleted",
          "children": {
            "source_code": {
              "enabled": false,
              "description": "Internet-pi source repository"
            },
            "configuration_files": {
              "enabled": false,
              "description": "Generated configuration files (inventory.ini, config.yml)"
            }
          }
        }
      }
    },
    "system_modifications": {
      "enabled": false,
      "description": "System-level modifications",
      "children": {
        "hostname": {
          "enabled": false,
          "description": "Restore original hostname",
          "details": "Changes hostname back from NEW_HOSTNAME to ORIGINAL_HOSTNAME"
        },
        "rpi_connect": {
          "enabled": false,
          "description": "RPI Connect console configuration",
          "details": "Restores rpi-connect and removes rpi-connect-lite if installed"
        },
        "pi5_optimizations": {
          "enabled": false,
          "description": "Raspberry Pi 5 boot optimizations",
          "condition": "Only available on Raspberry Pi 5",
          "children": {
            "boot_configuration": {
              "enabled": false,
              "description": "Boot cmdline.txt and config.txt optimizations"
            },
            "gpu_memory": {
              "enabled": false,
              "description": "GPU memory allocation optimization"
            },
            "boot_target": {
              "enabled": false,
              "description": "Boot target (desktop vs console)"
            }
          }
        },
        "padd": {
          "enabled": false,
          "description": "PADD (Pi-hole statistics display)",
          "children": {
            "container_installation": {
              "enabled": false,
              "description": "PADD installation in Pi-hole container"
            },
            "bash_aliases": {
              "enabled": false,
              "description": "PADD aliases in ~/.bashrc"
            }
          }
        },
        "docker_group": {
          "enabled": false,
          "description": "Remove user from docker group",
          "impact": "Requires re-login to take effect"
        }
      }
    },
    "system_packages": {
      "enabled": false,
      "description": "System packages installed by setup",
      "impact": "Only removes packages that are less commonly used",
      "children": {
        "development_tools": {
          "enabled": false,
          "description": "Development and utility packages",
          "packages": ["vim", "htop", "iotop", "unzip", "net-tools", "dnsutils"],
          "note": "git, curl, wget, python3-pip are kept as commonly used"
        }
      }
    },
    "cleanup_files": {
      "enabled": false,
      "description": "Cleanup temporary and state files",
      "children": {
        "state_files": {
          "enabled": false,
          "description": "Death Star setup state files",
          "files": ["~/.deathstar_setup_state", "~/.deathstar_config"]
        },
        "temp_files": {
          "enabled": false,
          "description": "Temporary installation files",
          "files": ["get-docker.sh", "~/get-docker.sh"]
        },
        "docker_compose_files": {
          "enabled": false,
          "description": "Leftover Docker Compose files"
        },
        "empty_directories": {
          "enabled": false,
          "description": "Remove empty Repo directory if empty"
        }
      }
    },
    "system_reboot": {
      "enabled": false,
      "description": "Reboot system after removal",
      "impact": "Recommended for hostname and group membership changes"
    }
  }
}
EOF
    
    print_success "✅ Removal configuration file created: ${config_file}"
    
    # If REMOVE_ALL is true, enable ALL items in the configuration
    if [[ "${REMOVE_ALL}" == "true" ]]; then
        print_status "🤖 REMOVE_ALL=true: Enabling ALL removal items in configuration..."
        enable_all_removals "${config_file}"
        print_success "✅ All removal items enabled automatically"
    fi
    
    echo
    print_status "📝 Instructions:"
    echo -e "  ${CYAN}1. Edit the file: nano ${config_file}${NC}"
    echo -e "  ${CYAN}2. Set 'enabled': true for items you want to remove${NC}"
    echo -e "  ${CYAN}3. Set 'enabled': false for items you want to keep${NC}"
    echo -e "  ${CYAN}4. Run this script again to perform the removal${NC}"
    echo
    print_warning "⚠️ Parent items will remove all their children automatically!"
    print_warning "⚠️ Review the 'impact' fields carefully before enabling removal!"
    echo
}

# Function to enable ALL removals in the configuration when REMOVE_ALL=true
enable_all_removals() {
    local config_file="$1"
    
    # Use jq to recursively enable all "enabled": false to "enabled": true
    local temp_file="${config_file}.tmp"
    
    if ! jq '
        def enable_all:
            if type == "object" then
                (if has("enabled") then .enabled = true else . end) |
                with_entries(.value |= enable_all)
            elif type == "array" then
                map(enable_all)
            else
                .
            end;
        enable_all
    ' "${config_file}" > "${temp_file}"; then
        print_error "❌ Failed to enable all removals in configuration"
        rm -f "${temp_file}"
        return 1
    fi
    
    # Replace the original file
    mv "${temp_file}" "${config_file}"
    return 0
}

# Function to read removal configuration from JSON
read_removal_config() {
    local config_file="$1"
    
    if [[ ! -f "${config_file}" ]]; then
        return 1
    fi
    
    # Check if jq is available for JSON parsing
    if ! command -v jq >/dev/null 2>&1; then
        print_error "❌ jq is required for JSON parsing but not installed"
        print_status "Installing jq..."
        sudo apt update && sudo apt install -y jq
    fi
    
    # Validate JSON syntax
    if ! jq . "${config_file}" >/dev/null 2>&1; then
        print_error "❌ Invalid JSON syntax in ${config_file}"
        return 1
    fi
    
    return 0
}

# Function to check if an item is enabled for removal
is_removal_enabled() {
    local config_file="$1"
    local json_path="$2"
    
    local enabled
    enabled=$(jq -r ".removal_tree${json_path}.enabled" "${config_file}" 2>/dev/null)
    
    if [[ "${enabled}" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if parent is enabled (which forces children to be removed)
is_parent_enabled() {
    local config_file="$1"
    local parent_path="$2"
    
    local enabled
    enabled=$(jq -r ".removal_tree${parent_path}.enabled" "${config_file}" 2>/dev/null)
    
    if [[ "${enabled}" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Quiet version of detect_installed_services for JSON generation
detect_installed_services_quiet() {
    SERVICES_FOUND=false
    
    # Check Pi-hole
    if check_directory "${CONFIG_DIR}/pi-hole"; then
        PIHOLE_INSTALLED=true
        SERVICES_FOUND=true
    else
        PIHOLE_INSTALLED=false
    fi
    
    # Check Internet Monitoring
    if check_directory "${CONFIG_DIR}/internet-monitoring"; then
        MONITORING_INSTALLED=true
        SERVICES_FOUND=true
    else
        MONITORING_INSTALLED=false
    fi
    
    # Check Shelly Plug
    if check_directory "${CONFIG_DIR}/shelly-plug-prometheus"; then
        SHELLY_INSTALLED=true
        SERVICES_FOUND=true
    else
        SHELLY_INSTALLED=false
    fi
    
    # Check Starlink
    if check_directory "${CONFIG_DIR}/starlink-exporter"; then
        STARLINK_INSTALLED=true
        SERVICES_FOUND=true
    else
        STARLINK_INSTALLED=false
    fi
    
    # Check AirGradient
    if check_directory "${CONFIG_DIR}/airgradient-prometheus"; then
        AIRGRADIENT_INSTALLED=true
        SERVICES_FOUND=true
    else
        AIRGRADIENT_INSTALLED=false
    fi
    
    # Check internet-pi repository
    if check_directory "${INTERNET_PI_DIR}"; then
        INTERNET_PI_INSTALLED=true
        SERVICES_FOUND=true
    else
        INTERNET_PI_INSTALLED=false
    fi
    
    return 0
}

# Function to show removal plan based on configuration
show_removal_plan() {
    local config_file="$1"
    
    echo -e "${CYAN}📋 Removal Plan Analysis:${NC}"
    echo
    
    # Check each major category
    check_category_status "${config_file}" ".services" "🕳️  Death Star Pi Services"
    check_category_status "${config_file}" ".infrastructure" "🐳 Infrastructure Components"
    check_category_status "${config_file}" ".system_modifications" "⚙️  System Modifications"
    check_category_status "${config_file}" ".system_packages" "📦 System Packages"
    check_category_status "${config_file}" ".cleanup_files" "🧹 Cleanup Files"
    check_category_status "${config_file}" ".system_reboot" "🔄 System Reboot"
    
    echo
}

# Function to check category status
check_category_status() {
    local config_file="$1"
    local category_path="$2"
    local category_name="$3"
    
    if is_removal_enabled "${config_file}" "${category_path}"; then
        echo -e "  ${RED}[REMOVE]${NC} ${category_name}"
    else
        echo -e "  ${GREEN}[KEEP]${NC} ${category_name}"
    fi
}

# Function to check if any removals are enabled
has_any_removals_enabled() {
    local config_file="$1"
    
    # Check if any top-level or specific items are enabled
    local enabled_count
    enabled_count=$(jq -r '[.. | objects | select(has("enabled")) | .enabled] | map(select(. == true)) | length' "${config_file}" 2>/dev/null)
    
    if [[ "${enabled_count}" -gt 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Function to show what will be removed
show_enabled_removals() {
    local config_file="$1"
    
    # Services
    if is_removal_enabled "${config_file}" ".services" ||
    is_removal_enabled "${config_file}" ".services.children.pi_hole" ||
    is_removal_enabled "${config_file}" ".services.children.internet_monitoring" ||
    is_removal_enabled "${config_file}" ".services.children.shelly_monitoring" ||
    is_removal_enabled "${config_file}" ".services.children.starlink_monitoring" ||
    is_removal_enabled "${config_file}" ".services.children.airgradient_monitoring"; then
        
        echo -e "  ${RED}🕳️  SERVICES:${NC}"
        is_removal_enabled "${config_file}" ".services.children.pi_hole" && echo "    • Pi-hole (DNS filtering will stop)"
        is_removal_enabled "${config_file}" ".services.children.internet_monitoring" && echo "    • Internet Monitoring (Grafana & Prometheus)"
        is_removal_enabled "${config_file}" ".services.children.shelly_monitoring" && echo "    • Shelly Plug Monitoring"
        is_removal_enabled "${config_file}" ".services.children.starlink_monitoring" && echo "    • Starlink Monitoring"
        is_removal_enabled "${config_file}" ".services.children.airgradient_monitoring" && echo "    • AirGradient Monitoring"
    fi
    
    # Infrastructure
    if is_removal_enabled "${config_file}" ".infrastructure" ||
    is_removal_enabled "${config_file}" ".infrastructure.children.docker" ||
    is_removal_enabled "${config_file}" ".infrastructure.children.ansible" ||
    is_removal_enabled "${config_file}" ".infrastructure.children.internet_pi_repo"; then
        
        echo -e "  ${RED}🐳 INFRASTRUCTURE:${NC}"
        is_removal_enabled "${config_file}" ".infrastructure.children.docker.children.cleanup_resources" && echo "    • Docker cleanup (unused resources)"
        is_removal_enabled "${config_file}" ".infrastructure.children.docker.children.remove_completely" && echo "    • Docker complete removal (⚠️  DANGER)"
        is_removal_enabled "${config_file}" ".infrastructure.children.ansible" && echo "    • Ansible"
        is_removal_enabled "${config_file}" ".infrastructure.children.internet_pi_repo" && echo "    • Internet-pi repository"
    fi
    
    # System modifications
    if is_removal_enabled "${config_file}" ".system_modifications" ||
    is_removal_enabled "${config_file}" ".system_modifications.children.hostname" ||
    is_removal_enabled "${config_file}" ".system_modifications.children.rpi_connect" ||
    is_removal_enabled "${config_file}" ".system_modifications.children.pi5_optimizations" ||
    is_removal_enabled "${config_file}" ".system_modifications.children.padd" ||
    is_removal_enabled "${config_file}" ".system_modifications.children.docker_group"; then
        
        echo -e "  ${RED}⚙️  SYSTEM MODIFICATIONS:${NC}"
        is_removal_enabled "${config_file}" ".system_modifications.children.hostname" && echo "    • Hostname restoration"
        is_removal_enabled "${config_file}" ".system_modifications.children.rpi_connect" && echo "    • RPI Connect console configuration"
        is_removal_enabled "${config_file}" ".system_modifications.children.pi5_optimizations" && echo "    • Pi 5 optimizations"
        is_removal_enabled "${config_file}" ".system_modifications.children.padd" && echo "    • PADD installations"
        is_removal_enabled "${config_file}" ".system_modifications.children.docker_group" && echo "    • Docker group membership"
    fi
    
    # System packages
    if is_removal_enabled "${config_file}" ".system_packages"; then
        echo -e "  ${RED}📦 SYSTEM PACKAGES:${NC}"
        echo "    • Development tools (vim, htop, iotop, etc.)"
    fi
    
    # Cleanup files
    if is_removal_enabled "${config_file}" ".cleanup_files"; then
        echo -e "  ${RED}🧹 CLEANUP FILES:${NC}"
        echo "    • State files, temp files, empty directories"
    fi
    
    # System reboot
    if is_removal_enabled "${config_file}" ".system_reboot"; then
        echo -e "  ${RED}🔄 SYSTEM REBOOT:${NC}"
        echo "    • Automatic reboot after removal"
    fi
}

# Function to execute the removal plan
execute_removal_plan() {
    local config_file="$1"
    
    echo -e "${CYAN}🚀 Executing removal plan...${NC}"
    echo
    
    # Remove services based on configuration
    if is_removal_enabled "${config_file}" ".services" || has_service_removals "${config_file}"; then
        echo
        print_status "🛑 Processing service removals..."
        
        # Individual service removals or parent removal
        if is_removal_enabled "${config_file}" ".services" || is_removal_enabled "${config_file}" ".services.children.pi_hole"; then
            [[ "${PIHOLE_INSTALLED}" == "true" ]] && remove_service "${CONFIG_DIR}/pi-hole" "Pi-hole"
        fi
        
        if is_removal_enabled "${config_file}" ".services" || is_removal_enabled "${config_file}" ".services.children.internet_monitoring"; then
            [[ "${MONITORING_INSTALLED}" == "true" ]] && remove_service "${CONFIG_DIR}/internet-monitoring" "Internet Monitoring"
        fi
        
        if is_removal_enabled "${config_file}" ".services" || is_removal_enabled "${config_file}" ".services.children.shelly_monitoring"; then
            [[ "${SHELLY_INSTALLED}" == "true" ]] && remove_service "${CONFIG_DIR}/shelly-plug-prometheus" "Shelly Plug Monitoring"
        fi
        
        if is_removal_enabled "${config_file}" ".services" || is_removal_enabled "${config_file}" ".services.children.starlink_monitoring"; then
            [[ "${STARLINK_INSTALLED}" == "true" ]] && remove_service "${CONFIG_DIR}/starlink-exporter" "Starlink Monitoring"
        fi
        
        if is_removal_enabled "${config_file}" ".services" || is_removal_enabled "${config_file}" ".services.children.airgradient_monitoring"; then
            [[ "${AIRGRADIENT_INSTALLED}" == "true" ]] && remove_service "${CONFIG_DIR}/airgradient-prometheus" "AirGradient Monitoring"
        fi
    fi
    
    # Remove infrastructure components
    if is_removal_enabled "${config_file}" ".infrastructure" || has_infrastructure_removals "${config_file}"; then
        echo
        print_status "🐳 Processing infrastructure removals..."
        
        # Internet-pi repository
        if is_removal_enabled "${config_file}" ".infrastructure" || is_removal_enabled "${config_file}" ".infrastructure.children.internet_pi_repo"; then
            if [[ "${INTERNET_PI_INSTALLED}" == "true" ]]; then
                print_status "🗑️ Removing internet-pi repository..."
                rm -rf "${INTERNET_PI_DIR}"
                print_success "✅ Removed internet-pi repository"
            fi
        fi
        
        # Docker cleanup
        if is_removal_enabled "${config_file}" ".infrastructure" || is_removal_enabled "${config_file}" ".infrastructure.children.docker.children.cleanup_resources"; then
# shellcheck disable=SC2312
            if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
                cleanup_docker
            fi
        fi
        
        # Docker complete removal
        if is_removal_enabled "${config_file}" ".infrastructure.children.docker.children.remove_completely"; then
            remove_docker_non_interactive
        fi
        
        # Ansible removal
        if is_removal_enabled "${config_file}" ".infrastructure" || is_removal_enabled "${config_file}" ".infrastructure.children.ansible"; then
            remove_ansible_non_interactive
        fi
    fi
    
    # System modifications
    if is_removal_enabled "${config_file}" ".system_modifications" || has_system_modification_removals "${config_file}"; then
        echo
        print_status "⚙️  Processing system modifications..."
        
        # Hostname restoration
        if is_removal_enabled "${config_file}" ".system_modifications" || is_removal_enabled "${config_file}" ".system_modifications.children.hostname"; then
            restore_hostname
        fi
        
        # RPI Connect configuration restoration
        if is_removal_enabled "${config_file}" ".system_modifications" || is_removal_enabled "${config_file}" ".system_modifications.children.rpi_connect"; then
            restore_rpi_connect
        fi
        
        # Pi 5 optimizations
        if is_removal_enabled "${config_file}" ".system_modifications" || is_removal_enabled "${config_file}" ".system_modifications.children.pi5_optimizations"; then
            remove_pi5_optimizations
        fi
        
        # PADD removal
        if is_removal_enabled "${config_file}" ".system_modifications" || is_removal_enabled "${config_file}" ".system_modifications.children.padd"; then
            remove_padd
        fi
        
        # Docker group removal
        if is_removal_enabled "${config_file}" ".system_modifications" || is_removal_enabled "${config_file}" ".system_modifications.children.docker_group"; then
            remove_docker_group
        fi
    fi
    
    # System packages
    if is_removal_enabled "${config_file}" ".system_packages"; then
        echo
        remove_system_packages_non_interactive
    fi
    
    # Cleanup files
    if is_removal_enabled "${config_file}" ".cleanup_files"; then
        echo
        perform_final_cleanup
    fi
}

# Helper functions to check if categories have any removals
has_service_removals() {
    local config_file="$1"
    is_removal_enabled "${config_file}" ".services.children.pi_hole" ||
    is_removal_enabled "${config_file}" ".services.children.internet_monitoring" ||
    is_removal_enabled "${config_file}" ".services.children.shelly_monitoring" ||
    is_removal_enabled "${config_file}" ".services.children.starlink_monitoring" ||
    is_removal_enabled "${config_file}" ".services.children.airgradient_monitoring"
}

has_infrastructure_removals() {
    local config_file="$1"
    is_removal_enabled "${config_file}" ".infrastructure.children.docker" ||
    is_removal_enabled "${config_file}" ".infrastructure.children.ansible" ||
    is_removal_enabled "${config_file}" ".infrastructure.children.internet_pi_repo"
}

has_system_modification_removals() {
    local config_file="$1"
    is_removal_enabled "${config_file}" ".system_modifications.children.hostname" ||
    is_removal_enabled "${config_file}" ".system_modifications.children.pi5_optimizations" ||
    is_removal_enabled "${config_file}" ".system_modifications.children.padd" ||
    is_removal_enabled "${config_file}" ".system_modifications.children.docker_group"
}

# Non-interactive versions of removal functions
remove_docker_non_interactive() {
    if command -v docker >/dev/null 2>&1; then
        print_status "🗑️ Removing Docker completely..."
        
        # Stop Docker service
        sudo systemctl stop docker
        sudo systemctl disable docker
        
        # Remove Docker packages
        sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        sudo apt-get autoremove -y
        
        # Remove Docker directories
        sudo rm -rf /var/lib/docker
        sudo rm -rf /var/lib/containerd
        sudo rm -rf /etc/docker
        
        print_success "✅ Docker completely removed"
    fi
}

remove_ansible_non_interactive() {
    if command -v ansible >/dev/null 2>&1; then
        print_status "🗑️ Removing Ansible..."
        
        # Remove virtual environment first (new installation method)
        local venv_dir="${HOME}/.local/venv-ansible"
        if [[ -d "${venv_dir}" ]]; then
            print_status "🐍 Removing Ansible virtual environment..."
            rm -rf "${venv_dir}"
            print_success "✅ Ansible virtual environment removed"
        fi
        
        # Remove symlinks
        sudo rm -f /usr/local/bin/ansible /usr/local/bin/ansible-playbook /usr/local/bin/ansible-galaxy 2>/dev/null || true
        
        # Remove Ansible collections
        [[ -d "${HOME}/.ansible" ]] && rm -rf "${HOME}/.ansible"
        
        # Remove pip installations
        pip3 uninstall -y ansible ansible-core 2>/dev/null || pip3 uninstall --break-system-packages -y ansible ansible-core 2>/dev/null || true
        
        # Remove system packages
        sudo apt remove -y ansible ansible-core python3-resolvelib 2>/dev/null || true
        sudo apt autoremove -y 2>/dev/null || true
        
        print_success "✅ Ansible removed"
    fi
}

remove_system_packages_non_interactive() {
    print_status "🗑️ Removing additional packages..."
    
    # Remove packages that are less commonly used
    local packages_to_remove=("vim" "unzip" "net-tools" "dnsutils")
    
    # Add Pi 5 specific packages
    if [[ "${PI5_DETECTED}" == "true" ]]; then
        packages_to_remove+=("htop" "iotop")
    else
        packages_to_remove+=("htop")
    fi
    
    # Remove packages that exist
    for package in "${packages_to_remove[@]}"; do
        local dpkg_check
        dpkg_check=$(dpkg -l) || true
        if echo "${dpkg_check}" | grep -q "^ii.*${package}"; then
            print_status "Removing ${package}..."
            sudo apt remove -y "${package}" 2>/dev/null || true
        fi
    done
    
    sudo apt autoremove -y || true
    print_success "✅ Additional packages removed"
}

perform_final_cleanup() {
    print_status "🧹 Performing final cleanup..."
    
    # Remove Death Star setup state and config files
    [[ -f "${HOME}/.deathstar_setup_state" ]] && rm -f "${HOME}/.deathstar_setup_state" && print_success "✅ Removed setup state file"
    [[ -f "${HOME}/.deathstar_config" ]] && rm -f "${HOME}/.deathstar_config" && print_success "✅ Removed setup config file"
    
    # Remove temporary installation files
    [[ -f "get-docker.sh" ]] && rm -f get-docker.sh && print_success "✅ Removed Docker installation script"
    [[ -f "${HOME}/get-docker.sh" ]] && rm -f "${HOME}/get-docker.sh" && print_success "✅ Removed Docker installation script from home"
    
    # Remove configuration files
    [[ -f "${INTERNET_PI_DIR}/inventory.ini" ]] && rm -f "${INTERNET_PI_DIR}/inventory.ini"
    [[ -f "${INTERNET_PI_DIR}/config.yml" ]] && rm -f "${INTERNET_PI_DIR}/config.yml"
    
    # Remove leftover Docker Compose files
    find "${CONFIG_DIR}" -name "docker-compose.yml" -path "*/{pi-hole,internet-monitoring,shelly-plug-prometheus,starlink-exporter,airgradient-prometheus}" -delete 2>/dev/null || true
    
    # Clean up empty Repo directory
    REPO_BASE="${DS_REPO_BASE:-${HOME}/Repo}"
    if [[ -d "${REPO_BASE}" ]]; then
        local ls_output
        ls_output=$(ls -A "${REPO_BASE}" 2>/dev/null) || true
        if [[ -z "${ls_output}" ]]; then
            rmdir "${REPO_BASE}" 2>/dev/null && print_success "✅ Removed empty Repo directory"
        fi
    fi
    
    print_success "✅ Final cleanup completed"
}

# Function to show removal summary
show_removal_summary() {
    local config_file="$1"
    
    echo -e "${GREEN}📋 Removal Summary:${NC}"
    echo
    
    local removed_items=0
    
    # Check what was actually removed and show appropriate messages
    if is_removal_enabled "${config_file}" ".services" || has_service_removals "${config_file}"; then
        echo -e "  ✅ Services processed according to configuration"
        ((removed_items++))
    fi
    
    if is_removal_enabled "${config_file}" ".infrastructure" || has_infrastructure_removals "${config_file}"; then
        echo -e "  ✅ Infrastructure components processed"
        ((removed_items++))
    fi
    
    if is_removal_enabled "${config_file}" ".system_modifications" || has_system_modification_removals "${config_file}"; then
        echo -e "  ✅ System modifications processed"
        ((removed_items++))
    fi
    
    if is_removal_enabled "${config_file}" ".system_packages"; then
        echo -e "  ✅ System packages removed"
        ((removed_items++))
    fi
    
    if is_removal_enabled "${config_file}" ".cleanup_files"; then
        echo -e "  ✅ Cleanup files removed"
        ((removed_items++))
    fi
    
    if [[ ${removed_items} -eq 0 ]]; then
        echo -e "  ${YELLOW}ℹ️  No items were processed (configuration may have all items disabled)${NC}"
    fi
    
    echo
    echo -e "${CYAN}💡 Next Steps:${NC}"
    echo -e "  • Configuration file will be automatically cleaned up"
    echo -e "  • Run removal script again to create fresh configuration"
    echo -e "  • Each run will detect current system state and create new configuration"
}

# Function to detect installed services
detect_installed_services() {
    print_status "🔍 Detecting installed Death Star Pi services..."
    
    SERVICES_FOUND=false
    
    # Check Pi-hole
    if check_directory "${CONFIG_DIR}/pi-hole"; then
        PIHOLE_INSTALLED=true
        SERVICES_FOUND=true
        print_status "  🕳️  Pi-hole found at ${CONFIG_DIR}/pi-hole"
    else
        PIHOLE_INSTALLED=false
    fi
    
    # Check Internet Monitoring
    if check_directory "${CONFIG_DIR}/internet-monitoring"; then
        MONITORING_INSTALLED=true
        SERVICES_FOUND=true
        print_status "  📊 Internet Monitoring found at ${CONFIG_DIR}/internet-monitoring"
    else
        MONITORING_INSTALLED=false
    fi
    
    # Check Shelly Plug
    if check_directory "${CONFIG_DIR}/shelly-plug-prometheus"; then
        SHELLY_INSTALLED=true
        SERVICES_FOUND=true
        print_status "  🔌 Shelly Plug Monitoring found at ${CONFIG_DIR}/shelly-plug-prometheus"
    else
        SHELLY_INSTALLED=false
    fi
    
    # Check Starlink
    if check_directory "${CONFIG_DIR}/starlink-exporter"; then
        STARLINK_INSTALLED=true
        SERVICES_FOUND=true
        print_status "  🛰️  Starlink Monitoring found at ${CONFIG_DIR}/starlink-exporter"
    else
        STARLINK_INSTALLED=false
    fi
    
    # Check AirGradient
    if check_directory "${CONFIG_DIR}/airgradient-prometheus"; then
        AIRGRADIENT_INSTALLED=true
        SERVICES_FOUND=true
        print_status "  🌡️  AirGradient Monitoring found at ${CONFIG_DIR}/airgradient-prometheus"
    else
        AIRGRADIENT_INSTALLED=false
    fi
    
    # Check internet-pi repository
    if check_directory "${INTERNET_PI_DIR}"; then
        INTERNET_PI_INSTALLED=true
        SERVICES_FOUND=true
        print_status "  📦 Internet-pi repository found at ${INTERNET_PI_DIR}"
    else
        INTERNET_PI_INSTALLED=false
    fi
    
    if [[ "${SERVICES_FOUND}" != "true" ]]; then
        print_warning "⚠️ No Death Star Pi services detected!"
        print_status "💡 Will attempt to clean up any remaining components anyway."
    fi
    
    return 0  # Always return success to continue cleanup
}

# Function to stop and remove a Docker Compose service
remove_service() {
    local service_dir="$1"
    local service_name="$2"
    
    if check_directory "${service_dir}"; then
        print_status "🛑 Stopping and removing ${service_name}..."
        cd "${service_dir}" || {
            print_warning "⚠️ Cannot access ${service_dir}, trying to remove anyway"
            if rm -rf "${service_dir}" 2>/dev/null; then
                print_success "✅ Removed ${service_name} directory"
            else
                print_warning "⚠️ Could not remove ${service_name} directory"
            fi
            return
        }
        
        # Stop containers and remove volumes
        if docker compose down -v 2>/dev/null; then
            print_success "✅ Stopped ${service_name} containers and removed volumes"
        else
            print_warning "⚠️ Some issues stopping ${service_name} (may already be stopped)"
        fi
        
        # Remove the directory
        cd "${HOME}" || cd /
        if rm -rf "${service_dir}" 2>/dev/null; then
            print_success "✅ Removed ${service_name} directory: ${service_dir}"
        else
            print_warning "⚠️ Could not remove ${service_name} directory"
        fi
    else
        print_status "ℹ️  ${service_name} directory not found (may already be removed)"
    fi
}

# Function to clean up Docker resources
cleanup_docker() {
    print_status "🧹 Cleaning up Docker resources..."
    
    # Remove all unused containers, networks, images, and build cache
    if docker system prune -af --volumes 2>/dev/null; then
        print_success "✅ Cleaned up all unused Docker resources"
    else
        print_warning "⚠️ Some Docker cleanup operations may have failed"
    fi
    
    # Show remaining Docker usage
    print_status "💾 Remaining Docker disk usage:"
    docker system df 2>/dev/null || print_warning "⚠️ Could not get Docker disk usage"
}

# Function to restore hostname
restore_hostname() {
    local current_hostname
    current_hostname=$(hostname)
    
    if [[ "${current_hostname}" == "${NEW_HOSTNAME}" ]]; then
        print_status "🏷️ Restoring hostname from ${NEW_HOSTNAME} to ${ORIGINAL_HOSTNAME}..."
        
        # Change hostname back
        sudo hostnamectl set-hostname "${ORIGINAL_HOSTNAME}"
        
        # Update hosts file - remove Death Star entries
        print_status "📝 Cleaning up /etc/hosts file..."
        sudo sed -i "s/${NEW_HOSTNAME}/${ORIGINAL_HOSTNAME}/g" /etc/hosts 2>/dev/null || true
        
        # Remove any Death Star specific entries that may have been added
        local pi_ip
        local hostname_output
        hostname_output=$(hostname -I) || true
        pi_ip=$(echo "${hostname_output}" | awk '{print $1}')
        if [[ -n "${pi_ip}" ]]; then
            sudo sed -i "/${pi_ip}.*${NEW_HOSTNAME}/d" /etc/hosts 2>/dev/null || true
        fi
        
        print_success "✅ Hostname restored to ${ORIGINAL_HOSTNAME}"
        print_success "✅ /etc/hosts file cleaned up"
    else
        print_status "ℹ️  Hostname is already ${current_hostname} (not ${NEW_HOSTNAME})"
    fi
}

# Function to remove Pi 5 optimizations
remove_pi5_optimizations() {
    if [[ "${PI5_DETECTED}" == "true" ]]; then
        print_status "🔧 Removing Pi 5 optimizations..."
        
        # Restore original boot files from backups if they exist
        local backup_found=false
        local cmdline_restored=false
        local config_restored=false
        
        # Find the most recent backup files
        local latest_cmdline_backup
        local latest_config_backup
        
        if compgen -G "/boot/firmware/cmdline.txt.backup.*" > /dev/null; then
            local find_output
            find_output=$(find /boot/firmware -name "cmdline.txt.backup.*" -type f -printf "%T@ %p\n" 2>/dev/null) || true
            local sort_output
            sort_output=$(echo "${find_output}" | sort -nr) || true
            local head_output
            head_output=$(echo "${sort_output}" | head -n 1) || true
            latest_cmdline_backup=$(echo "${head_output}" | cut -d' ' -f2-)
            if [[ -f "${latest_cmdline_backup}" ]]; then
                print_status "📝 Restoring cmdline.txt from backup: $(basename "${latest_cmdline_backup}")"
                sudo cp "${latest_cmdline_backup}" /boot/firmware/cmdline.txt
                print_success "✅ cmdline.txt restored from backup"
                cmdline_restored=true
                backup_found=true
            fi
        fi
        
        if compgen -G "/boot/firmware/config.txt.backup.*" > /dev/null; then
            local find_output2
            find_output2=$(find /boot/firmware -name "config.txt.backup.*" -type f -printf "%T@ %p\n" 2>/dev/null) || true
            local sort_output2
            sort_output2=$(echo "${find_output2}" | sort -nr) || true
            local head_output2
            head_output2=$(echo "${sort_output2}" | head -n 1) || true
            latest_config_backup=$(echo "${head_output2}" | cut -d' ' -f2-)
            if [[ -f "${latest_config_backup}" ]]; then
                print_status "🎮 Restoring config.txt from backup: $(basename "${latest_config_backup}")"
                sudo cp "${latest_config_backup}" /boot/firmware/config.txt
                print_success "✅ config.txt restored from backup"
                config_restored=true
                backup_found=true
            fi
        fi
        
        # Restore original boot target
        print_status "🖥️  Restoring boot target..."
        local prev_target=""
        local state_file="${DS_STATE_FILE:-${HOME}/.deathstar_setup_state}"
        
        # Try to read the previous target from state file
        if [[ -f "${state_file}" ]]; then
            local grep_output
            grep_output=$(grep "^PI5_PREV_TARGET=" "${state_file}" 2>/dev/null) || grep_output=""
            prev_target=$(echo "${grep_output}" | cut -d'=' -f2-)
            [[ -z "${prev_target}" ]] && prev_target=""
        fi
        
        # If we have a stored previous target, restore it
        if [[ -n "${prev_target}" && "${prev_target}" != "multi-user.target" ]]; then
            print_status "🖥️  Restoring original boot target: ${prev_target}"
            sudo systemctl set-default "${prev_target}"
            print_success "✅ Boot target restored to: ${prev_target}"
        else
            # Fallback to graphical target (default desktop environment)
            local current_target
            current_target=$(systemctl get-default 2>/dev/null || echo "unknown")
            if [[ "${current_target}" == "multi-user.target" ]]; then
                print_status "🖥️  Restoring default desktop boot target..."
                sudo systemctl set-default graphical.target
                print_success "✅ Boot target restored to graphical.target (desktop)"
            else
                print_status "ℹ️  Boot target already set to: ${current_target}"
            fi
        fi
        
        # If no backups found, fall back to manual removal
        if [[ "${backup_found}" == "false" ]]; then
            print_status "⚠️  No backup files found, performing manual cleanup..."
            
            # Remove memory cgroups from cmdline.txt
            if grep -q "cgroup_memory=1 cgroup_enable=memory" /boot/firmware/cmdline.txt; then
                print_status "📝 Removing memory cgroups from boot configuration..."
                sudo sed -i 's/ cgroup_memory=1 cgroup_enable=memory//g' /boot/firmware/cmdline.txt
                print_success "✅ Memory cgroups configuration removed"
            fi
            
            # Remove GPU memory optimization (handle both old and new patterns)
            if grep -q "^gpu_mem=16$" /boot/firmware/config.txt; then
                print_status "🎮 Removing GPU memory optimization..."
                sudo sed -i '/^gpu_mem=16$/d' /boot/firmware/config.txt
                print_success "✅ GPU memory configuration restored to default"
                elif grep -q "gpu_mem=16" /boot/firmware/config.txt; then
                print_status "🎮 Removing GPU memory optimization (legacy pattern)..."
                sudo sed -i '/gpu_mem=16/d' /boot/firmware/config.txt
                print_success "✅ GPU memory configuration restored to default"
            fi
        else
            # Clean up backup files after successful restoration
            print_status "🧹 Cleaning up backup files..."
            
            if [[ "${cmdline_restored}" == "true" ]]; then
                sudo rm -f /boot/firmware/cmdline.txt.backup.*
                print_success "✅ cmdline.txt backup files removed"
            fi
            
            if [[ "${config_restored}" == "true" ]]; then
                sudo rm -f /boot/firmware/config.txt.backup.*
                print_success "✅ config.txt backup files removed"
            fi
        fi
        
        # Remove PADD alias
        if grep -q "alias padd=" "${HOME}/.bashrc" 2>/dev/null; then
            print_status "📊 Removing PADD alias..."
            # Remove PADD alias and comment
            sed -i '/# Pi-hole PADD.*alias/d' "${HOME}/.bashrc" 2>/dev/null || true
            sed -i '/alias padd=/d' "${HOME}/.bashrc" 2>/dev/null || true
            print_success "✅ PADD alias removed"
        fi
        
        print_success "✅ Pi 5 optimizations removed"
    else
        print_status "ℹ️  No Pi 5 optimizations to remove"
    fi
}

# Function to restore RPI Connect configuration
restore_rpi_connect() {
    print_status "🔄 Restoring RPI Connect configuration..."
    
    # Get original installation status from state file
    local state_file="${DS_STATE_FILE:-${HOME}/.deathstar_setup_state}"
    local originally_installed="false"
    
    if [[ -f "${state_file}" ]]; then
        local grep_output2
        grep_output2=$(grep "^RPI_CONNECT_ORIGINALLY_INSTALLED=" "${state_file}" 2>/dev/null) || grep_output2=""
        originally_installed=$(echo "${grep_output2}" | cut -d'=' -f2-)
        [[ -z "${originally_installed}" ]] && originally_installed="false"
    fi
    
    # Check if rpi-connect-lite is installed and remove it
    local dpkg_output
    dpkg_output=$(dpkg -l) || true
    if echo "${dpkg_output}" | grep -q "^ii.*rpi-connect-lite[[:space:]]"; then
        print_status "📦 Found rpi-connect-lite package installed, removing..."
        if sudo apt remove -y rpi-connect-lite; then
            print_success "✅ Successfully removed rpi-connect-lite package"
        else
            print_warning "⚠️  Failed to remove rpi-connect-lite package"
        fi
    else
        print_status "ℹ️  rpi-connect-lite package not found"
    fi

    # Stop and disable rpi-connect-lite service if it exists
    local systemctl_output
    systemctl_output=$(systemctl list-unit-files) || true
    if echo "${systemctl_output}" | grep -q "rpi-connect-lite\.service"; then
        print_status "🛑 Stopping and disabling rpi-connect-lite service..."
        sudo systemctl stop rpi-connect-lite.service 2>/dev/null || true
        sudo systemctl disable rpi-connect-lite.service 2>/dev/null || true
        print_success "✅ rpi-connect-lite service stopped and disabled"
    fi

    # Only install standard rpi-connect if it was originally installed
    if [[ "${originally_installed}" == "true" ]]; then
        local dpkg_check2
        dpkg_check2=$(dpkg -l) || true
        if ! echo "${dpkg_check2}" | grep -q "^ii.*rpi-connect[[:space:]]"; then
            print_status "📦 Restoring original rpi-connect package..."
            if sudo apt update >/dev/null 2>&1; then
                if sudo apt install -y rpi-connect; then
                    print_success "✅ Successfully restored rpi-connect package"
                    
                    # Enable and start the service if it exists
                    local systemctl_output2
                    systemctl_output2=$(systemctl list-unit-files) || true
                    if echo "${systemctl_output2}" | grep -q "rpi-connect\.service"; then
                        print_status "🚀 Enabling rpi-connect service..."
                        if sudo systemctl enable rpi-connect.service; then
                            print_success "✅ rpi-connect service enabled"
                            print_status "ℹ️  Service will start automatically on next boot"
                        else
                            print_warning "⚠️  Failed to enable rpi-connect service"
                        fi
                    fi
                else
                    print_warning "⚠️  Failed to restore rpi-connect package"
                fi
            else
                print_warning "⚠️  Failed to update package lists"
            fi
        else
            print_status "ℹ️  rpi-connect package already installed"
            
            # Ensure the service is enabled if it exists
            local systemctl_output3
            systemctl_output3=$(systemctl list-unit-files) || true
            if echo "${systemctl_output3}" | grep -q "rpi-connect\.service"; then
                local is_enabled_result
                is_enabled_result=$(systemctl is-enabled rpi-connect.service 2>/dev/null) || is_enabled_result=""
                if [[ "${is_enabled_result}" != "enabled" ]]; then
                    print_status "🚀 Enabling rpi-connect service..."
                    sudo systemctl enable rpi-connect.service 2>/dev/null || true
                    print_success "✅ rpi-connect service enabled"
                else
                    print_status "ℹ️  rpi-connect service already enabled"
                fi
            fi
        fi
    else
        print_status "ℹ️  rpi-connect was not originally installed, skipping installation"
        print_status "ℹ️  Only removing rpi-connect-lite as requested"
    fi
    
    print_success "✅ RPI Connect configuration restored"
}

# Function to remove PADD from containers
remove_padd() {
    print_status "📊 Checking for PADD installations..."
    
    # Check if Pi-hole container exists and is running
# shellcheck disable=SC2312
    if command -v docker >/dev/null 2>&1 && docker ps -q --filter "name=pihole" | grep -q .; then
        print_status "📊 Removing PADD from Pi-hole container..."
        # PADD is typically just a script, removing it by deleting downloaded files
        docker exec pihole bash -c "rm -f /usr/local/bin/padd.sh /root/padd.sh 2>/dev/null || true" 2>/dev/null || true
        print_success "✅ PADD removed from Pi-hole container"
    fi
    
    # Remove PADD alias from bashrc if it exists (covering all Pi models)
    if grep -q "alias padd=" "${HOME}/.bashrc" 2>/dev/null; then
        print_status "📊 Removing PADD alias from ~/.bashrc..."
        # Remove PADD alias and comment
        sed -i '/# Pi-hole PADD.*alias/d' "${HOME}/.bashrc" 2>/dev/null || true
        sed -i '/alias padd=/d' "${HOME}/.bashrc" 2>/dev/null || true
        print_success "✅ PADD alias removed"
    fi
}

# Function to remove user from docker group
remove_docker_group() {
    local groups_output
    groups_output=$(groups "${USER}") || true
    if echo "${groups_output}" | grep -q docker; then
        print_status "🔧 Removing ${USER} from docker group..."
        sudo gpasswd -d "${USER}" docker
        print_success "✅ Removed ${USER} from docker group"
        print_warning "⚠️ You may need to log out and log back in for this to take effect"
    else
        print_status "ℹ️  User ${USER} is not in docker group"
    fi
}

# Main removal function
main() {
    # Start performance monitoring for entire script
    log_performance_start "remove_total"
    
    # Check if removal configuration file exists
    if [[ ! -f "${REMOVAL_CONFIG_FILE}" ]]; then
        # First run - generate configuration file
        rich_header "💀 Death Star Pi Removal Configuration" "Generating removal configuration file"
        
        # Show REMOVE_ALL warning if enabled
        if [[ "${REMOVE_ALL}" == "true" ]]; then
            echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${RED}                    ⚠️  REMOVE ALL MODE ENABLED ⚠️                   ${NC}"
            echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
            echo -e "${YELLOW}REMOVE_ALL=true detected - This will:${NC}"
            echo -e "${YELLOW}  • Skip all user confirmations${NC}"
            echo -e "${YELLOW}  • Enable EVERY removal option automatically${NC}"
            echo -e "${YELLOW}  • Proceed with COMPLETE Death Star Pi removal${NC}"
            echo -e "${RED}ALL Death Star Pi components will be PERMANENTLY REMOVED!${NC}"
            echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
            echo
        fi
        
        print_status "🔍 This is your first time running the removal script."
        print_status "📋 I'll scan for installed components and create a configuration file."
        echo
        
        # Show legal disclaimer first
        rich_disclaimer "legal"
        echo
        
        # Check REMOVE_ALL flag for automatic acceptance
        if [[ "${REMOVE_ALL}" == "true" ]]; then
            echo -e "${YELLOW}🤖 REMOVE_ALL=true: Automatically accepting terms and proceeding...${NC}"
            echo
        else
            read -p "Do you accept these terms and wish to proceed? (yes/no): " -r
            echo
            if [[ ! ${REPLY} =~ ^[Yy][Ee][Ss]$ ]]; then
                echo -e "${YELLOW}Operation cancelled by user. Exiting safely.${NC}"
                exit 0
            fi
        fi
        echo -e "${GREEN}Terms accepted. Generating configuration file...${NC}"
        echo
        
        # Generate the configuration file
        generate_removal_config "${REMOVAL_CONFIG_FILE}"
        
        echo -e "${GREEN}🎯 Next Steps:${NC}"
        echo -e "  ${CYAN}1. Review and edit: ${REMOVAL_CONFIG_FILE}${NC}"
        echo -e "  ${CYAN}2. Set 'enabled': true for items you want to remove${NC}"
        echo -e "  ${CYAN}3. Run this script again: $0${NC}"
        echo
        echo -e "${YELLOW}💡 Pro Tips:${NC}"
        echo -e "  • Parent items automatically include their children"
        echo -e "  • Read the 'impact' descriptions carefully"
        echo -e "  • Start with just services if unsure"
        echo -e "  • You can always run multiple times with different settings"
        echo
        
        # End performance monitoring
        log_performance_end "remove_total"
        exit 0
    fi
    
    # Second run - read configuration and perform removal
    rich_header "💀 Death Star Pi Removal" "Executing configured removal plan"
    
    # Show REMOVE_ALL warning if enabled
    if [[ "${REMOVE_ALL}" == "true" ]]; then
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}                    ⚠️  REMOVE ALL MODE ENABLED ⚠️                   ${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}REMOVE_ALL=true detected - Overriding all configuration settings${NC}"
        echo -e "${YELLOW}ALL Death Star Pi components will be enabled for removal${NC}"
        echo -e "${RED}Complete removal will proceed without confirmations!${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo
    fi
    
    # Read and validate configuration file
    if ! read_removal_config "${REMOVAL_CONFIG_FILE}"; then
        print_error "❌ Failed to read removal configuration file: ${REMOVAL_CONFIG_FILE}"
        print_status "💡 Delete the file to regenerate it: rm ${REMOVAL_CONFIG_FILE}"
        exit 1
    fi
    
    print_success "✅ Successfully loaded removal configuration"
    
    # If REMOVE_ALL is true, override configuration and enable all items
    if [[ "${REMOVE_ALL}" == "true" ]]; then
        print_status "🤖 REMOVE_ALL=true: Enabling ALL removal items in existing configuration..."
        if enable_all_removals "${REMOVAL_CONFIG_FILE}"; then
            print_success "✅ All removal items enabled automatically"
        else
            print_error "❌ Failed to enable all removal items"
            exit 1
        fi
    fi
    
    # Show what will be removed based on configuration
    print_status "📋 Analyzing removal configuration..."
    show_removal_plan "${REMOVAL_CONFIG_FILE}"
    
    # Check if anything is actually enabled for removal
    if ! has_any_removals_enabled "${REMOVAL_CONFIG_FILE}"; then
        print_warning "⚠️ No items are enabled for removal in your configuration."
        echo -e "${CYAN}Edit the configuration file and set items to 'enabled': true${NC}"
        echo -e "${CYAN}Configuration file: ${REMOVAL_CONFIG_FILE}${NC}"
        exit 0
    fi
    
    echo
    print_warning "⚠️ THE FOLLOWING WILL BE PERMANENTLY REMOVED:"
    show_enabled_removals "${REMOVAL_CONFIG_FILE}"
    echo
    
    # Final confirmation - check REMOVE_ALL flag
    if [[ "${REMOVE_ALL}" == "true" ]]; then
        echo -e "${YELLOW}🤖 REMOVE_ALL=true: Skipping final confirmation and proceeding with removal...${NC}"
        echo -e "${RED}🚀 EXECUTING REMOVAL PLAN AUTOMATICALLY${NC}"
        echo
    else
        echo -e "${RED}Are you absolutely sure you want to proceed with the configured removal plan?${NC}"
        echo -e "${YELLOW}Type 'EXECUTE REMOVAL PLAN' to confirm (case sensitive):${NC}"
        read -r confirmation
        
        if [[ "${confirmation}" != "EXECUTE REMOVAL PLAN" ]]; then
            print_status "❌ Removal cancelled by user"
            echo -e "${GREEN}Your Death Star remains operational! 🌟${NC}"
            echo -e "${CYAN}Edit configuration: ${REMOVAL_CONFIG_FILE}${NC}"
            exit 0
        fi
    fi
    
    echo
    print_status "🚀 Executing Death Star Pi removal plan..."
    
    if [[ "${PI5_DETECTED}" == "true" ]]; then
        print_status "🎯 Raspberry Pi 5 detected"
    fi
    
    # Check if running as root
    if [[ ${EUID} -eq 0 ]]; then
        print_error "This script should not be run as root"
        exit 1
    fi
    
    # Detect installed services for removal logic
    detect_installed_services_quiet
    
    # Check Docker availability
    if ! command -v docker >/dev/null 2>&1; then
        print_warning "⚠️ Docker not found. Will only remove directories."
        elif ! docker ps >/dev/null 2>&1; then
        print_warning "⚠️ Cannot access Docker. Will only remove directories."
    fi
    
    # Execute removal plan based on configuration
    execute_removal_plan "${REMOVAL_CONFIG_FILE}"
    
    # Success message
    echo
    print_success "🎉 Death Star Pi Removal Plan Executed!"
    echo
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                  💀 REMOVAL PLAN COMPLETED 💀                  ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
    echo
    
    # Show what was actually removed
    show_removal_summary "${REMOVAL_CONFIG_FILE}"
    
    # Handle reboot if configured
    if is_removal_enabled "${REMOVAL_CONFIG_FILE}" ".system_reboot"; then
        echo -e "${BLUE}🔄 System Reboot Configured${NC}"
        print_status "🔄 Rebooting system in 5 seconds (as configured)..."
        print_status "Press Ctrl+C to cancel..."
        sleep 5
        sudo reboot
    else
        # Ask about reboot if hostname or docker group was changed
        local reboot_recommended=false
        if is_removal_enabled "${REMOVAL_CONFIG_FILE}" ".system_modifications.hostname" ||
        is_removal_enabled "${REMOVAL_CONFIG_FILE}" ".system_modifications.docker_group"; then
            reboot_recommended=true
        fi
        
        if [[ "${reboot_recommended}" == "true" ]]; then
            echo -e "${BLUE}🔄 Reboot Recommendation${NC}"
            echo -e "${YELLOW}A reboot is recommended for hostname and group membership changes.${NC}"
            echo
            
            while true; do
                read -p "Would you like to reboot now? (Y/n): " -n 1 -r
                echo
                if [[ ${REPLY} =~ ^[Yy]$ ]] || [[ -z ${REPLY} ]]; then
                    print_status "🔄 Rebooting system in 5 seconds..."
                    print_status "Press Ctrl+C to cancel..."
                    sleep 5
                    sudo reboot
                    break
                    elif [[ ${REPLY} =~ ^[Nn]$ ]]; then
                    print_status "ℹ️  Reboot skipped. Remember to reboot later for complete effect."
                    break
                else
                    print_error "Please enter Y or N"
                fi
            done
        fi
    fi
    
    echo
    # End performance monitoring
    log_performance_end "remove_total"
    
    # Clean up the removal configuration file so it's regenerated fresh next time
    echo
    print_status "🧹 Cleaning up removal configuration file..."
    if [[ -f "${REMOVAL_CONFIG_FILE}" ]]; then
        rm -f "${REMOVAL_CONFIG_FILE}"
        print_success "✅ Removal configuration file deleted: ${REMOVAL_CONFIG_FILE}"
        print_status "💡 Configuration will be regenerated fresh on next run"
    else
        print_status "ℹ️  Configuration file not found (already cleaned up)"
    fi
    
    echo -e "${GREEN}Death Star Pi removal plan executed successfully! ⭐${NC}"
    echo -e "${GREEN}Configuration file cleaned up - will be regenerated fresh next time. 🌟${NC}"
}

# Run main function
main "$@"
