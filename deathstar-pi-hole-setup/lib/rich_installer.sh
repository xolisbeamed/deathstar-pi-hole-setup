#!/bin/bash
#===============================================================================
# File: rich_installer.sh
# Project: Death Star Pi-hole Setup
# Description: Rich library installation utility for enhanced terminal output
#              Ensures Rich is installed and up-to-date on target system
# 
# Target Environment:
#   OS: Raspberry Pi OS aarch64
#   Host: Raspberry Pi 5 Model B Rev 1.1
#   Shell: bash
#   Dependencies: python3, pip3
# 
# Author: galactic-plane
# Repository: https://github.com/galactic-plane/deathstar-pi-hole-setup
# License: See LICENSE file
#===============================================================================

#===============================================================================
# Function: ensure_rich_available
# Description: Ensures Rich library is installed and up-to-date for enhanced output
# Parameters: None
# Returns: 0 on success, continues with fallback on failure
#===============================================================================
ensure_rich_available() {
    echo "🎨 Ensuring Rich library is available for enhanced output..."
    
    # Check if python3 is available
    if ! command -v python3 >/dev/null 2>&1; then
        echo "❌ Python3 not found - installing Python3..."
        if sudo apt update >/dev/null 2>&1 && sudo apt install -y python3 >/dev/null 2>&1; then
            echo "✅ Python3 installed successfully"
        else
            echo "❌ Failed to install Python3"
            return 1
        fi
    fi
    
    # Check if pip3 is available
    if ! command -v pip3 >/dev/null 2>&1; then
        echo "❌ pip3 not found - installing pip3..."
        if sudo apt install -y python3-pip >/dev/null 2>&1; then
            echo "✅ pip3 installed successfully"
        else
            echo "❌ Failed to install pip3"
            return 1
        fi
    fi
    
    # Check if Rich is already installed
    if python3 -c "import rich" >/dev/null 2>&1; then
        echo "✅ Rich library is already installed"
        
        # Try to update Rich to latest version (suppress output for cleaner logs)
        echo "🔄 Updating Rich to latest version..."
        if pip3 install --break-system-packages --upgrade rich >/dev/null 2>&1; then
            echo "✅ Rich library updated successfully"
        else
            echo "⚠️  Rich update failed, but existing installation will work"
        fi
    else
        echo "📦 Installing Rich library for enhanced visual output..."
        
        # Install Rich
        if pip3 install --break-system-packages rich >/dev/null 2>&1; then
            echo "✅ Rich library installed successfully"
        else
            echo "⚠️  Rich installation failed - will use basic text formatting"
            echo "💡 You can manually install with: pip3 install --break-system-packages rich"
            return 1
        fi
    fi
    
    # Verify installation
    if python3 -c "import rich" >/dev/null 2>&1; then
        echo "🌟 Rich library is ready - enhanced output enabled!"
        return 0
    else
        echo "⚠️  Rich library not available - using fallback formatting"
        return 1
    fi
}

#===============================================================================
# Function: install_rich_with_fallback
# Description: Install Rich with multiple fallback methods
# Parameters: None
# Returns: 0 on success, 1 on failure
#===============================================================================
install_rich_with_fallback() {
    echo "🎨 Installing Rich library with fallback methods..."
    
    # Method 1: pip3 with --break-system-packages
    if pip3 install --break-system-packages rich >/dev/null 2>&1; then
        echo "✅ Rich installed via pip3 (--break-system-packages)"
        return 0
    fi
    
    # Method 2: apt system package
    echo "🔄 Trying system package installation..."
    if sudo apt update >/dev/null 2>&1 && sudo apt install -y python3-rich >/dev/null 2>&1; then
        echo "✅ Rich installed via apt (system package)"
        return 0
    fi
    
    # Method 3: pip3 with --user flag
    echo "🔄 Trying user installation..."
    if pip3 install --user rich >/dev/null 2>&1; then
        echo "✅ Rich installed via pip3 (--user)"
        return 0
    fi
    
    echo "❌ All Rich installation methods failed"
    return 1
}

# If script is run directly (not sourced), run the main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ensure_rich_available
fi