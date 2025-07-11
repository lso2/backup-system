#!/bin/bash
# Universal Backup System - One-Command Installer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Universal Backup System Installer ===${NC}"
echo

# Detect platform
PLATFORM="unknown"
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macos"
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
    PLATFORM="windows"
elif grep -q "Microsoft" /proc/version 2>/dev/null; then
    PLATFORM="wsl"
fi

echo -e "${BLUE}Detected platform: $PLATFORM${NC}"

# Set installation directory
INSTALL_DIR="$HOME/.backup-system"
CONFIG_DIR="$INSTALL_DIR/config"

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"

# Copy files
echo -e "${YELLOW}Installing backup system...${NC}"

# If running from git clone, copy files
if [ -f "backup-system.sh" ]; then
    cp backup-system.sh "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/backup-system.sh"
    
    # Copy config examples
    if [ -d "config" ]; then
        cp config/*.conf "$CONFIG_DIR/" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✅ Files installed to $INSTALL_DIR${NC}"
else
    echo -e "${RED}❌ backup-system.sh not found. Run from project directory or download first.${NC}"
    exit 1
fi

# Add to PATH
echo -e "${YELLOW}Setting up PATH...${NC}"

# Determine shell config file
SHELL_CONFIG=""
if [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.profile" ]; then
    SHELL_CONFIG="$HOME/.profile"
fi

if [ -n "$SHELL_CONFIG" ]; then
    # Check if already in PATH
    if ! grep -q "backup-system" "$SHELL_CONFIG"; then
        echo "" >> "$SHELL_CONFIG"
        echo "# Universal Backup System" >> "$SHELL_CONFIG"
        echo "export PATH=\"\$HOME/.backup-system:\$PATH\"" >> "$SHELL_CONFIG"
        echo "alias backup='backup-system.sh'" >> "$SHELL_CONFIG"
        
        echo -e "${GREEN}✅ Added to PATH in $SHELL_CONFIG${NC}"
        echo -e "${BLUE}💡 Run: source $SHELL_CONFIG or restart terminal${NC}"
    else
        echo -e "${GREEN}✅ Already in PATH${NC}"
    fi
fi

# Create symlink for system-wide access (optional)
if [ -w "/usr/local/bin" ]; then
    ln -sf "$INSTALL_DIR/backup-system.sh" "/usr/local/bin/backup-system" 2>/dev/null || true
    echo -e "${GREEN}✅ System-wide symlink created${NC}"
fi

# Check dependencies
echo -e "${YELLOW}Checking dependencies...${NC}"

# Check git
if command -v git >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Git found: $(git --version | head -1)${NC}"
else
    echo -e "${RED}❌ Git not found. Please install git.${NC}"
fi

# Check GitHub CLI
if command -v gh >/dev/null 2>&1; then
    echo -e "${GREEN}✅ GitHub CLI found: $(gh --version | head -1)${NC}"
else
    echo -e "${YELLOW}⚠️  GitHub CLI not found. Install for full functionality:${NC}"
    case $PLATFORM in
        "linux")
            echo -e "${BLUE}  sudo apt install gh  # or yum install gh${NC}"
            ;;
        "macos")
            echo -e "${BLUE}  brew install gh${NC}"
            ;;
        "windows"|"wsl")
            echo -e "${BLUE}  winget install GitHub.cli${NC}"
            ;;
    esac
fi

# Check SSH
if [ -f "$HOME/.ssh/id_rsa" ] || [ -f "$HOME/.ssh/id_ed25519" ]; then
    echo -e "${GREEN}✅ SSH keys found${NC}"
else
    echo -e "${YELLOW}⚠️  No SSH keys found. Generate with:${NC}"
    echo -e "${BLUE}  ssh-keygen -t ed25519 -C \"your_email@example.com\"${NC}"
fi

echo
echo -e "${GREEN}🎉 Installation complete!${NC}"
echo
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Run setup: ${YELLOW}$INSTALL_DIR/backup-system.sh --setup${NC}"
echo -e "2. Configure projects in: ${YELLOW}$CONFIG_DIR/${NC}"
echo -e "3. Test with: ${YELLOW}backup-system.sh list${NC}"
echo
echo -e "${BLUE}For help: ${YELLOW}$INSTALL_DIR/backup-system.sh${NC} (no arguments)"
echo

# Offer to run setup immediately
read -p "Run setup wizard now? (y/n) [y]: " run_setup
run_setup=${run_setup:-y}

if [ "$run_setup" = "y" ]; then
    echo
    "$INSTALL_DIR/backup-system.sh" --setup
fi