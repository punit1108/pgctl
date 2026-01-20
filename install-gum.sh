#!/bin/bash

# =============================================================================
# Gum Installation Helper for pgctl
# =============================================================================
# This script detects your OS and helps install Charm's gum CLI tool
# https://github.com/charmbracelet/gum
# =============================================================================

set -e

# Colors for output (basic, works without gum)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gum is already installed
check_gum_installed() {
    if command -v gum &> /dev/null; then
        GUM_VERSION=$(gum --version 2>/dev/null || echo "unknown")
        log_success "gum is already installed (version: $GUM_VERSION)"
        return 0
    fi
    return 1
}

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macos"
            ;;
        Linux*)
            OS="linux"
            # Detect Linux distribution
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                DISTRO=$ID
            elif [ -f /etc/debian_version ]; then
                DISTRO="debian"
            elif [ -f /etc/redhat-release ]; then
                DISTRO="rhel"
            else
                DISTRO="unknown"
            fi
            ;;
        *)
            OS="unknown"
            ;;
    esac
    log_info "Detected OS: $OS"
    if [ "$OS" = "linux" ]; then
        log_info "Detected distribution: $DISTRO"
    fi
}

# Install gum on macOS
install_macos() {
    log_info "Installing gum via Homebrew..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew is not installed."
        echo ""
        echo "To install Homebrew, run:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        echo "Then run this script again."
        exit 1
    fi
    
    brew install gum
}

# Install gum on Linux
install_linux() {
    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint)
            log_info "Installing gum via apt (Debian/Ubuntu)..."
            echo ""
            echo "Run the following commands:"
            echo ""
            echo "  sudo mkdir -p /etc/apt/keyrings"
            echo "  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg"
            echo '  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list'
            echo "  sudo apt update && sudo apt install gum"
            echo ""
            
            read -p "Would you like to run these commands now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo mkdir -p /etc/apt/keyrings
                curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
                echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
                sudo apt update && sudo apt install gum
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            log_info "Installing gum via yum/dnf (Fedora/RHEL)..."
            echo ""
            echo "Run the following commands:"
            echo ""
            echo '  echo "[charm]'
            echo '  name=Charm'
            echo '  baseurl=https://repo.charm.sh/yum/'
            echo '  enabled=1'
            echo '  gpgcheck=1'
            echo '  gpgkey=https://repo.charm.sh/yum/gpg.key" | sudo tee /etc/yum.repos.d/charm.repo'
            echo "  sudo yum install gum"
            echo ""
            
            read -p "Would you like to run these commands now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
                sudo yum install gum -y
            fi
            ;;
        arch|manjaro)
            log_info "Installing gum via pacman (Arch Linux)..."
            echo ""
            echo "Run the following command:"
            echo "  sudo pacman -S gum"
            echo ""
            
            read -p "Would you like to run this command now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo pacman -S gum
            fi
            ;;
        alpine)
            log_info "Installing gum via apk (Alpine Linux)..."
            echo ""
            echo "Run the following command:"
            echo "  sudo apk add gum"
            echo ""
            
            read -p "Would you like to run this command now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo apk add gum
            fi
            ;;
        *)
            log_warning "Unknown Linux distribution: $DISTRO"
            install_from_binary
            ;;
    esac
}

# Install from binary (fallback)
install_from_binary() {
    log_info "Installing gum from binary..."
    echo ""
    echo "You can download gum binaries from:"
    echo "  https://github.com/charmbracelet/gum/releases"
    echo ""
    echo "Or install via Go:"
    echo "  go install github.com/charmbracelet/gum@latest"
    echo ""
    echo "Or use Nix:"
    echo "  nix-env -iA nixpkgs.gum"
    echo ""
}

# Verify installation
verify_installation() {
    if command -v gum &> /dev/null; then
        GUM_VERSION=$(gum --version 2>/dev/null || echo "unknown")
        log_success "gum installed successfully (version: $GUM_VERSION)"
        echo ""
        echo "You can now use pgctl with full interactive features!"
        echo "Try running: ./postgres/pgctl"
        return 0
    else
        log_error "gum installation could not be verified"
        log_info "Please try installing manually or check your PATH"
        return 1
    fi
}

# Main function
main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║  Gum Installation Helper for pgctl     ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    # Check if already installed
    if check_gum_installed; then
        echo ""
        echo "No installation needed. gum is ready to use!"
        exit 0
    fi
    
    log_info "gum is not installed. Starting installation..."
    echo ""
    
    # Detect OS
    detect_os
    
    # Install based on OS
    case "$OS" in
        macos)
            read -p "Would you like to install gum via Homebrew? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_macos
            else
                log_info "Skipping installation."
                install_from_binary
            fi
            ;;
        linux)
            install_linux
            ;;
        *)
            log_warning "Unknown operating system"
            install_from_binary
            ;;
    esac
    
    echo ""
    
    # Verify installation
    verify_installation
}

# Run main function
main "$@"
