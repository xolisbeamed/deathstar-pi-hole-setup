# 🍓 Raspberry Pi Environment Scripts Documentation

This directory documents all scripts designed to run on your **Raspberry Pi** for Death Star Pi-hole setup, monitoring, and maintenance.

---

## 📋 Script Overview

| Script | Purpose | Complexity | Duration | Resumable |
|--------|---------|------------|----------|-----------|
| [`setup.sh`](#setup.sh) | Complete system installation | High | 30-60 min | ✅ Yes |
| [`status.sh`](#status.sh) | System diagnostics & health check | Moderate | 30-90 sec | ❌ No |
| [`update.sh`](#update.sh) | Update all installed services | Moderate | 5-15 min | ❌ No |
| [`remove.sh`](#remove.sh) | Complete system removal | High | 10-20 min | ❌ No |

---

## 🚀 setup.sh

### Purpose
Comprehensive, resumable installation script that transforms a fresh Raspberry Pi into a complete Death Star Pi-hole system with monitoring, ad-blocking, and network management capabilities.

### What It Does Exactly

#### 🔧 Phase 1: System Preparation
1. **System Updates**
   - Updates package lists (`apt update`)
   - Upgrades all installed packages (`apt upgrade -y`)
   - Configures unattended upgrades for security
   - Sets up package repository management

2. **Core Package Installation**
   - Essential build tools (`build-essential`, `git`, `curl`, `wget`)
   - Development libraries (`python3-dev`, `python3-pip`)
   - Network tools (`dnsutils`, `net-tools`, `iptables`)
   - System utilities (`htop`, `tree`, `vim`, `screen`)

3. **Fastfetch Installation**
   - Downloads and installs fastfetch system info tool
   - Configures automatic display on SSH login
   - Customizes output for Pi hardware information

#### 🐳 Phase 2: Docker Infrastructure
1. **Docker Installation**
   - Adds official Docker APT repository
   - Installs Docker Engine and Docker Compose
   - Configures Docker daemon for Pi hardware
   - Adds user to docker group for non-root access

2. **Docker Verification**
   - Tests Docker installation with hello-world container
   - Verifies Docker Compose functionality
   - Sets up Docker log rotation
   - Configures Docker security settings

#### 🛡️ Phase 3: Pi-hole & DNS
1. **Pi-hole Installation**
   - Downloads and runs official Pi-hole installer
   - Configures Pi-hole for optimal Pi performance
   - Sets up custom blocklists for enhanced ad-blocking
   - Configures Pi-hole admin interface

2. **Unbound DNS Resolver**
   - Installs Unbound recursive DNS resolver
   - Configures for privacy-focused DNS resolution
   - Integrates with Pi-hole for complete DNS control
   - Sets up DNS-over-TLS for enhanced security

3. **DHCP Configuration** (Optional)
   - Configures Pi-hole DHCP server
   - Sets up network device management
   - Configures static IP reservations
   - Integrates network monitoring

#### 📊 Phase 4: Monitoring Stack
1. **Prometheus Installation**
   - Deploys Prometheus time-series database
   - Configures scraping for Pi-hole metrics
   - Sets up system and network monitoring
   - Configures data retention policies

2. **Grafana Installation**
   - Deploys Grafana analytics platform
   - Imports pre-configured Pi-hole dashboards
   - Sets up system monitoring dashboards
   - Configures user access and security

3. **Node Exporter**
   - Installs Prometheus Node Exporter
   - Configures system metrics collection
   - Sets up hardware monitoring (CPU, memory, disk, temperature)
   - Integrates with Grafana dashboards

#### 🔒 Phase 5: Security & Hardening
1. **SSH Hardening**
   - Disables password authentication (key-only)
   - Configures secure SSH settings
   - Sets up fail2ban for intrusion prevention
   - Configures SSH logging and monitoring

2. **Firewall Configuration**
   - Sets up UFW (Uncomplicated Firewall)
   - Configures required port access
   - Blocks unnecessary services
   - Sets up logging for security monitoring

3. **System Hardening**
   - Configures automatic security updates
   - Sets up log rotation and management
   - Configures system resource limits
   - Implements security best practices

#### 📈 Phase 6: Optimization & Finalization
1. **Performance Tuning**
   - Optimizes memory settings for Pi hardware
   - Configures swap file for stability
   - Tunes network buffer sizes
   - Optimizes disk I/O settings

2. **Service Integration**
   - Configures all services to start on boot
   - Sets up service dependencies
   - Tests service integration
   - Configures health monitoring

3. **Final Validation**
   - Tests all installed services
   - Validates network configuration
   - Verifies monitoring functionality
   - Provides access information and next steps

### System Requirements

#### Hardware Requirements
- **Raspberry Pi**: Model 3B+ or newer (Pi 4/5 recommended)
- **RAM**: Minimum 2GB (4GB+ recommended for full monitoring)
- **Storage**: 32GB+ microSD card (Class 10 or better)
- **Network**: Ethernet connection recommended (WiFi supported)

#### Pre-Installation Requirements
- **OS**: Fresh Raspberry Pi OS (64-bit recommended)
- **SSH**: SSH service enabled
- **User**: Non-root user with sudo privileges
- **Network**: Stable internet connection for downloads
- **Time**: 30-60 minutes for complete installation

#### Network Requirements
- **Internet Access**: Required for package downloads
- **Static IP**: Recommended (can be configured during setup)
- **DNS**: Current working DNS for initial setup
- **Bandwidth**: Broadband connection recommended

### Resumable Installation Process

The script uses a sophisticated state management system:

#### State Tracking
```bash
# Installation states (resumable checkpoints)
STATES=(
    "SYSTEM_UPDATE"      # System packages updated
    "CORE_PACKAGES"      # Essential tools installed
    "FASTFETCH_INSTALL"  # System info tool ready
    "DOCKER_INSTALL"     # Docker infrastructure ready
    "DOCKER_VERIFY"      # Docker tested and working
    "PIHOLE_INSTALL"     # Pi-hole installed and configured
    "UNBOUND_INSTALL"    # DNS resolver configured
    "DHCP_CONFIG"        # Network management ready
    "PROMETHEUS_INSTALL" # Metrics database ready
    "GRAFANA_INSTALL"    # Analytics platform ready
    "NODE_EXPORTER"      # System monitoring ready
    "SSH_HARDENING"      # Security configured
    "FIREWALL_CONFIG"    # Network security ready
    "OPTIMIZATION"       # Performance tuned
    "VALIDATION"         # System tested
    "COMPLETE"           # Installation finished
)
```

#### Resume Capability
- **Automatic Detection**: Script detects previous installation state
- **Skip Completed**: Automatically skips already completed phases
- **Progress Display**: Shows current progress and remaining steps
- **Error Recovery**: Can recover from failed installations
- **Reboot Survival**: Continues after system reboots

### Usage Examples

```bash
# Fresh installation
./setup.sh

# Resume after interruption
./setup.sh

# Check current state without installing
./setup.sh --status

# Reset installation (start over)
./setup.sh --reset

# Verbose installation with debug output
./setup.sh --verbose
```

### Configuration Options

#### Pi-hole Settings
- **Admin Password**: Generated automatically or user-specified
- **Blocklists**: Curated list of ad/malware blocking lists
- **DNS Servers**: Configurable upstream DNS providers
- **Web Interface**: Accessible on port 80

#### Monitoring Settings
- **Grafana**: Port 3000, admin user auto-configured
- **Prometheus**: Port 9090, metrics retention configurable
- **Node Exporter**: Port 9100, system metrics enabled

### Exit Codes
- `0` - Success: Installation completed or resumed successfully
- `1` - Error: System requirements not met
- `2` - Error: Network or dependency issues
- `3` - Error: Permission or security issues
- `4` - Error: Hardware compatibility issues

---

## 🔍 status.sh

### Purpose
Comprehensive system diagnostics and health monitoring script that provides real-time status of all Death Star Pi components, performance metrics, and troubleshooting information.

### What It Does Exactly

#### 🩺 System Health Checks
1. **Hardware Status**
   - CPU temperature and thermal throttling detection
   - Memory usage and swap utilization
   - Disk space and I/O performance
   - Network interface status and statistics
   - USB and GPIO device detection

2. **Service Status Monitoring**
   - Pi-hole service health and performance
   - Docker container status and resource usage
   - Grafana accessibility and dashboard health
   - Prometheus metric collection status
   - Unbound DNS resolver functionality

3. **Network Analysis**
   - DNS resolution testing (internal and external)
   - Network connectivity and latency tests
   - DHCP server status (if enabled)
   - Firewall rule validation
   - Port accessibility testing

#### 📊 Performance Metrics
1. **Real-time Statistics**
   - CPU usage (overall and per-core)
   - Memory consumption by service
   - Network throughput and packet statistics
   - Disk read/write performance
   - System load averages

2. **Pi-hole Analytics**
   - Query statistics (total, blocked, allowed)
   - Top blocked domains and advertisers
   - Client device activity and statistics
   - DNS query type analysis
   - Blocklist effectiveness metrics

3. **Security Monitoring**
   - Failed SSH login attempts
   - Firewall activity and blocked connections
   - System security update status
   - Log file analysis for anomalies
   - Intrusion detection alerts

#### 🔧 Diagnostic Tools
1. **Service Diagnostics**
   - Service startup time analysis
   - Configuration file validation
   - Log file error analysis
   - Dependency relationship mapping
   - Performance bottleneck identification

2. **Network Diagnostics**
   - DNS resolution path tracing
   - Network configuration validation
   - Connectivity troubleshooting
   - Bandwidth testing and optimization
   - Router and gateway accessibility

3. **System Diagnostics**
   - Boot time analysis
   - System resource constraints
   - Hardware compatibility checks
   - Temperature and power monitoring
   - Storage health and performance

### System Requirements

#### Runtime Requirements
- **Installed Services**: Checks adapt to what's actually installed
- **Permissions**: Read access to system files and logs
- **Network**: Access to test connectivity and DNS
- **Memory**: Minimal impact (< 50MB during execution)

#### Optional Tools (Enhanced Features)
- **speedtest-cli**: For bandwidth testing
- **iotop**: For I/O performance analysis
- **nethogs**: For network usage by process
- **lsof**: For detailed process and file analysis

### Output Formats

#### Standard Output
```bash
🍓 Death Star Pi Status Report
════════════════════════════════════

🖥️  System Information
✅ CPU: BCM2835 ARMv8 @ 1.5GHz (4 cores)
✅ Memory: 3.2GB used / 7.8GB total (41%)
✅ Disk: 45GB used / 119GB total (38%)
✅ Temperature: 42.3°C (Normal)

🛡️  Pi-hole Status
✅ Service: Active and running
✅ Queries: 15,247 total (89% blocked)
✅ Blocklists: 127,345 domains blocked
⚠️  Cache: 85% full (consider clearing)

📊 Monitoring Services
✅ Grafana: Running on :3000
✅ Prometheus: Running on :9090
✅ Node Exporter: Collecting metrics
```

#### Rich Terminal Output
- **Colored status indicators** (green/yellow/red)
- **Progress bars** for resource utilization
- **Tables** for organized data presentation
- **Panels** for grouped information
- **Interactive** prompts for detailed analysis

### Usage Examples

```bash
# Standard status check
./status.sh

# Detailed diagnostics with network tests
./status.sh --detailed

# Continuous monitoring (refresh every 30 seconds)
./status.sh --monitor

# Export status to file
./status.sh --export > system-status.txt

# Check specific service only
./status.sh --service pihole

# Performance analysis mode
./status.sh --performance

# Security audit mode
./status.sh --security
```

### Features

#### Auto-Detection
- **Service Discovery**: Automatically detects installed services
- **Configuration Analysis**: Reads actual configuration files
- **Dynamic Adaptation**: Works even with partial installations
- **Error Tolerance**: Continues checks even if some services fail

#### Troubleshooting Integration
- **Problem Identification**: Highlights issues with specific guidance
- **Solution Suggestions**: Provides specific commands to fix problems
- **Log Analysis**: Extracts relevant errors from system logs
- **Performance Optimization**: Suggests improvements based on metrics

### Exit Codes
- `0` - Success: All systems operating normally
- `1` - Warning: Minor issues detected
- `2` - Error: Significant problems found
- `3` - Critical: System requires immediate attention

---

## 🔄 update.sh

### Purpose
Intelligent update management script that safely updates all Death Star Pi components while maintaining system stability and configuration integrity.

### What It Does Exactly

#### 🔄 System Updates
1. **Package Manager Updates**
   - Updates APT package lists
   - Upgrades system packages with dependency resolution
   - Handles package conflicts and removals
   - Manages kernel updates and module dependencies

2. **Security Updates**
   - Prioritizes security patches
   - Applies critical vulnerabilities fixes
   - Updates security tools and databases
   - Validates security configuration after updates

#### 🐳 Service Updates
1. **Docker Container Updates**
   - Pulls latest container images
   - Safely restarts containers with new versions
   - Preserves data volumes and configurations
   - Validates container functionality after updates

2. **Pi-hole Updates**
   - Updates Pi-hole core components
   - Updates blocklists and domain databases
   - Preserves custom configurations and whitelists
   - Validates DNS functionality after updates

3. **Monitoring Stack Updates**
   - Updates Grafana to latest stable version
   - Updates Prometheus and exporters
   - Preserves dashboards and alerting rules
   - Validates monitoring functionality

#### 🔧 Configuration Management
1. **Backup Creation**
   - Creates pre-update configuration backups
   - Saves current service states
   - Documents current versions for rollback
   - Preserves custom modifications

2. **Configuration Validation**
   - Tests configurations before applying
   - Validates service dependencies
   - Checks for breaking changes
   - Provides rollback options if needed

### System Requirements

#### Runtime Requirements
- **Root Access**: Sudo privileges for system updates
- **Disk Space**: 2GB+ free space for update downloads
- **Network**: Stable internet for package downloads
- **Memory**: 1GB+ available for update processes

#### Safety Requirements
- **Backup Space**: Additional storage for configuration backups
- **Service Downtime**: Brief interruptions during service restarts
- **Testing Window**: Time for post-update validation

### Update Process

#### Pre-Update Validation
1. **System Health Check**
   - Verifies system stability before updates
   - Checks available disk space
   - Validates network connectivity
   - Confirms service status

2. **Backup Creation**
   - Backs up critical configurations
   - Documents current versions
   - Creates rollback scripts
   - Validates backup integrity

#### Update Execution
1. **Staged Updates**
   - Updates system packages first
   - Updates services in dependency order
   - Tests each component after update
   - Provides progress feedback

2. **Service Management**
   - Gracefully stops services before updates
   - Preserves running configurations
   - Restarts services in correct order
   - Validates functionality at each stage

#### Post-Update Validation
1. **Functionality Testing**
   - Tests all critical services
   - Validates configuration integrity
   - Performs connectivity tests
   - Checks monitoring functionality

2. **Performance Validation**
   - Monitors resource usage after updates
   - Validates service performance
   - Checks for regression issues
   - Optimizes settings if needed

### Usage Examples

```bash
# Standard update (all components)
./update.sh

# System packages only
./update.sh --packages-only

# Services only (skip system packages)
./update.sh --services-only

# Pi-hole specific update
./update.sh --pihole-only

# Dry run (show what would be updated)
./update.sh --dry-run

# Force update (skip validation)
./update.sh --force

# Update with verbose logging
./update.sh --verbose
```

### Safety Features

#### Rollback Capability
- **Configuration Restoration**: Restore previous configurations
- **Version Downgrade**: Rollback to previous package versions
- **Service Restoration**: Restore previous service states
- **Data Recovery**: Recover from backup if needed

#### Update Validation
- **Compatibility Checking**: Verify component compatibility
- **Dependency Resolution**: Handle complex dependency chains
- **Configuration Migration**: Migrate settings to new versions
- **Functional Testing**: Comprehensive post-update testing

### Exit Codes
- `0` - Success: All updates completed successfully
- `1` - Warning: Some updates completed with warnings
- `2` - Error: Update failed, system may need attention
- `3` - Critical: Update failed, rollback recommended

---

## 🗑️ remove.sh

### Purpose
Complete system removal script that safely uninstalls all Death Star Pi components and restores the system to a clean state while preserving user data and system integrity.

### What It Does Exactly

#### 🔍 Pre-Removal Analysis
1. **System Discovery**
   - Scans for all installed Death Star Pi components
   - Identifies custom configurations and data
   - Maps service dependencies and integrations
   - Catalogs files and directories for removal

2. **Data Preservation Planning**
   - Identifies user data and custom configurations
   - Plans backup strategies for important data
   - Documents restoration procedures
   - Warns about data that will be lost

#### 🛡️ Safe Removal Process
1. **Service Shutdown**
   - Gracefully stops all services in dependency order
   - Disables auto-start services
   - Cleanly disconnects network services
   - Preserves system stability during removal

2. **Component Removal**
   - **Pi-hole**: Removes Pi-hole components while preserving DNS functionality
   - **Docker**: Removes containers, images, and Docker engine
   - **Monitoring**: Removes Grafana, Prometheus, and exporters
   - **Dependencies**: Removes unnecessary packages and libraries

3. **Configuration Cleanup**
   - Removes service configuration files
   - Cleans up user accounts and groups
   - Removes custom scripts and cronjobs
   - Restores original system configurations

#### 🔧 System Restoration
1. **Network Restoration**
   - Restores original DNS settings
   - Removes custom firewall rules
   - Restores original DHCP configuration
   - Re-enables standard network services

2. **Security Restoration**
   - Restores original SSH configuration
   - Removes custom security policies
   - Restores original user permissions
   - Removes security hardening (if requested)

3. **System Cleanup**
   - Removes unnecessary packages
   - Cleans package cache and temporary files
   - Removes log files and monitoring data
   - Optimizes system after removal

### System Requirements

#### Runtime Requirements
- **Root Access**: Sudo privileges for system modifications
- **Disk Space**: Space for temporary backups during removal
- **Time**: 10-20 minutes for complete removal
- **Network**: Optional internet access for package cleanup

#### Safety Requirements
- **Data Backup**: External backup of important data
- **System Access**: Alternative access method in case of issues
- **Recovery Plan**: Plan for restoring system if needed

### Interactive Removal Configuration

#### deathstar_removal_config.json File
The removal script uses an interactive configuration system via a JSON file that provides granular control over what gets removed:

**File Location:**
```bash
~/Repo/deathstar_removal_config.json
```

**Purpose:**
The configuration file provides a hierarchical tree structure where you can selectively choose which components to remove, rather than an all-or-nothing approach.

#### How It Works

1. **First Run**: The script detects installed services and generates the configuration file
2. **User Editing**: You edit the file to set `"enabled": true` for items you want removed
3. **Second Run**: The script reads your configuration and removes only selected items

#### Configuration Structure

The file contains a dependency tree with these main categories:

```json
{
  "removal_tree": {
    "services": {
      "children": {
        "pi_hole": {
          "enabled": false,
          "description": "Pi-hole DNS filtering service",
          "path": "CONFIG_DIR/pi-hole",
          "impact": "DNS filtering will stop - update router DNS settings",
          "children": {
            "containers": { "enabled": false },
            "configuration": { "enabled": false }
          }
        },
        "internet_monitoring": {
          "enabled": false,
          "description": "Internet monitoring (Grafana & Prometheus)",
          "impact": "Network monitoring dashboards will be lost",
          "children": {
            "containers": { "enabled": false },
            "configuration": { "enabled": false },
            "data": { "enabled": false }
          }
        }
      }
    },
    "system_packages": {
      "children": {
        "development_tools": {
          "packages": ["vim", "htop", "iotop", "unzip", "net-tools"]
        }
      }
    },
    "cleanup_files": {
      "children": {
        "state_files": { "files": ["~/.deathstar_setup_state"] },
        "temp_files": { "files": ["get-docker.sh"] }
      }
    }
  }
}
```

#### Key Features

**Hierarchical Dependencies:**
- Parent items control their children
- Enabling a parent automatically removes all children
- Children can be selectively removed while keeping the parent

**Impact Assessment:**
- Each item shows the impact of removal
- Critical warnings for services that affect network functionality
- Path information showing what directories/files will be affected

**Safety Defaults:**
- All items start with `"enabled": false` (safe mode)
- Must explicitly enable items for removal
- Cannot accidentally remove everything

#### Usage Workflow

```bash
# Step 1: Generate configuration file
./remove.sh

# Step 2: Edit the configuration (opens with nano/vim)
nano ~/Repo/deathstar_removal_config.json

# Step 3: Set desired items to "enabled": true
# Example: To remove only Pi-hole:
# "pi_hole": { "enabled": true, ... }

# Step 4: Run removal with your configuration
./remove.sh
```

#### Example Configurations

**Remove Only Monitoring (Keep Pi-hole):**
```json
"internet_monitoring": { "enabled": true }
"pi_hole": { "enabled": false }
```

**Remove Everything Except Configuration Files:**
```json
"services": { "enabled": true },
"containers": { "enabled": true },
"configuration": { "enabled": false }
```

**Complete Removal:**
```json
"services": { "enabled": true },
"system_packages": { "enabled": true },
"cleanup_files": { "enabled": true }
```

### Removal Options

#### Selective Removal
```bash
# Remove specific components only
./remove.sh --pihole-only      # Remove only Pi-hole
./remove.sh --monitoring-only  # Remove only Grafana/Prometheus
./remove.sh --docker-only      # Remove only Docker components
./remove.sh --services-only    # Keep system packages, remove services
```

#### Complete Removal
```bash
# Complete removal with prompts
./remove.sh

# Silent removal (auto-confirm all)
REMOVE_ALL=true ./remove.sh

# Remove with data preservation
./remove.sh --preserve-data

# Remove with system restoration
./remove.sh --restore-system
```

### Safety Features

#### Confirmation System
1. **Legal Disclaimer**: Confirms understanding of data loss risks
2. **Component Selection**: Allows selective removal choices
3. **Final Confirmation**: Last chance to abort removal
4. **Progress Confirmation**: Confirms each major step

#### Data Protection
1. **Backup Creation**: Automatic backup of critical data
2. **Preservation Options**: Keep user data and custom configurations
3. **Recovery Documentation**: Creates removal log for troubleshooting
4. **Rollback Information**: Documents how to restore removed components

#### Error Handling
1. **Graceful Failures**: Continues removal even if some components fail
2. **Error Logging**: Documents all errors for troubleshooting
3. **Partial Recovery**: Can handle incomplete removals
4. **System Stability**: Maintains system stability throughout process

### REMOVE_ALL Flag

#### Automated Removal Mode
```bash
# Set at top of script for complete automation
REMOVE_ALL=true
```

#### What It Does
- **Skips all confirmations**: No user interaction required
- **Enables all removal options**: Removes everything
- **Bypasses safety prompts**: Proceeds without warnings
- **Complete automation**: Suitable for scripted deployments

#### ⚠️ Critical Warning
- **Use with extreme caution**: No confirmation prompts
- **Complete data loss**: All configurations and data removed
- **No rollback**: Cannot undo automated removal
- **System changes**: May significantly alter system state

### Usage Examples

```bash
# Interactive removal (recommended)
./remove.sh

# Automated complete removal (DANGEROUS)
REMOVE_ALL=true ./remove.sh

# Remove Pi-hole only
./remove.sh --component pihole

# Remove with data preservation
./remove.sh --preserve-configs

# Dry run (show what would be removed)
./remove.sh --dry-run

# Force removal (ignore errors)
./remove.sh --force
```

### Post-Removal Actions

#### System Verification
1. **Service Status**: Confirms all services are stopped
2. **File Cleanup**: Verifies all files are removed
3. **Network Functionality**: Tests network connectivity
4. **System Performance**: Checks resource utilization

#### Documentation
1. **Removal Log**: Complete log of removal actions
2. **Restoration Guide**: Instructions for re-installation
3. **Recovery Information**: Data recovery procedures
4. **System State**: Final system configuration documentation

### Exit Codes
- `0` - Success: Removal completed successfully
- `1` - Warning: Removal completed with warnings
- `2` - Error: Removal failed, some components may remain
- `3` - Critical: Removal failed, system may be unstable

---

## 📚 Library Scripts

### lib/rich_helper.py

#### Purpose
Python-based terminal enhancement library providing rich visual output for all Death Star Pi scripts.

#### Functionality
- **Enhanced Tables**: Formatted tables with borders and colors
- **Progress Bars**: Visual progress indicators for long operations
- **Status Panels**: Organized information display panels
- **Color Management**: Consistent color schemes across scripts
- **Fallback Support**: Graceful degradation when Rich library unavailable

#### Requirements
- **Python**: 3.6 or higher
- **Rich Library**: `pip3 install rich`
- **Terminal**: Compatible terminal emulator

### lib/rich_installer.sh

#### Purpose
Automated Rich library installation and management script.

#### Functionality
- **Automatic Detection**: Checks if Rich library is available
- **Automatic Installation**: Installs Rich if not present
- **Fallback Management**: Configures fallback to basic output
- **Error Handling**: Graceful handling of installation failures

#### Requirements
- **Python**: 3.6+ with pip
- **Network**: Internet access for package installation
- **Permissions**: User-level package installation

### lib/log_handler.sh

#### Purpose
Advanced logging system for comprehensive logging across all Death Star Pi scripts.

#### Functionality
- **Multi-level Logging**: DEBUG, INFO, WARNING, ERROR, CRITICAL levels
- **Structured Logging**: JSON-compatible log format
- **Performance Tracking**: Operation timing and metrics
- **Log Rotation**: Automatic log size management
- **Session Tracking**: Per-script session logging

#### Features
- **Colored Output**: Terminal color coding by log level
- **Timestamping**: Precise timestamp for all log entries
- **Context Tracking**: Script and function context in logs
- **Error Context**: Detailed error information and stack traces

#### Requirements
- **Bash**: 4.0+ with associative arrays
- **Disk Space**: Log directory with write access
- **Permissions**: Write access to log files

### lib/config_loader.sh

#### Purpose
Shared configuration management library for all Death Star Pi scripts.

#### Functionality
- **JSON Processing**: Loads and parses configuration files
- **Environment Detection**: Detects Pi vs host environment
- **Variable Management**: Sets global configuration variables
- **Fallback Handling**: Provides defaults when configuration missing

#### Configuration Hierarchy
1. **Script Parameters**: Command-line arguments
2. **Environment Variables**: Shell environment settings  
3. **Configuration Files**: JSON configuration files
4. **Default Values**: Hardcoded fallback values

#### Requirements
- **jq**: JSON parsing utility (optional)
- **Python**: Fallback JSON processor
- **File Access**: Read access to configuration files

---

## 🔧 Common System Requirements

### Base System Requirements (All Scripts)
- **Operating System**: Raspberry Pi OS (32-bit or 64-bit)
- **Hardware**: Raspberry Pi 3B+ or newer
- **Memory**: 1GB+ RAM (2GB+ recommended)
- **Storage**: 16GB+ microSD (32GB+ recommended)
- **Network**: Ethernet or WiFi connectivity

### Required System Tools
```bash
# Core utilities (usually pre-installed)
bash (4.0+)
coreutils (ls, cp, mv, rm, etc.)
grep, sed, awk
find, xargs
curl, wget

# Network tools
ssh, scp, rsync
ping, netstat
iptables, ufw

# System tools
systemctl, journalctl
ps, top, htop
df, du, lsof
```

### Optional Tools (Enhanced Features)
```bash
# JSON processing
jq

# Python environment
python3 (3.6+)
pip3
python3-rich

# Development tools
git
vim or nano

# Monitoring tools
htop, iotop
nethogs, iftop
speedtest-cli

# Security tools
fail2ban
chkrootkit
```

### Network Requirements
- **Internet Access**: Required for installations and updates
- **DNS Resolution**: Working DNS for package downloads
- **SSH Access**: For remote management and deployment
- **Port Access**: Various ports for web interfaces (80, 3000, 9090, etc.)

---

## 🚨 Important Notes

### Script Execution Order
1. **First**: Run host environment scripts (`push_to_pi.sh`, `connect_to_pi.sh`)
2. **Second**: Run `setup.sh` on Pi for initial installation
3. **Ongoing**: Use `status.sh` and `update.sh` for maintenance
4. **Last Resort**: Use `remove.sh` for complete removal

### Data and Configuration Persistence
- **Pi-hole Settings**: Preserved across updates
- **Grafana Dashboards**: Backed up during updates
- **Custom Configurations**: Documented and preserved
- **User Data**: Protected during removal (with options)

### Security Considerations
- **SSH Keys**: Required for all remote operations
- **Firewall**: Configured automatically with safe defaults
- **Updates**: Automatic security updates enabled
- **Logging**: Comprehensive logging for security auditing

### Performance Considerations
- **Resource Usage**: Optimized for Raspberry Pi hardware
- **Memory Management**: Configured for Pi memory constraints
- **Storage Optimization**: Efficient use of SD card storage
- **Network Optimization**: Optimized for typical home networks

---

For host-side script documentation, see [`../host/README.md`](../host/README.md).