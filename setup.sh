#!/bin/bash

# =============================================================================
# pgctl Setup Script
# =============================================================================
# Installs required dependencies for pgctl:
# - PostgreSQL client (psql)
# - Charm's gum CLI tool (optional, but recommended)
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# Logging Functions
# =============================================================================

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

log_step() {
    echo -e "\n${CYAN}▶${NC} $1"
}

# =============================================================================
# Command Line Argument Parsing
# =============================================================================

SKIP_GUM=false
SKIP_PSQL=false
NON_INTERACTIVE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-gum)
                SKIP_GUM=true
                shift
                ;;
            --skip-psql)
                SKIP_PSQL=true
                shift
                ;;
            --non-interactive|-y)
                NON_INTERACTIVE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Run 'setup.sh --help' for usage information."
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
pgctl Setup Script

Installs required dependencies for pgctl:
  - PostgreSQL client (psql)
  - Charm's gum CLI tool (optional, but recommended)

Usage:
  ./setup.sh [OPTIONS]

Options:
  --skip-gum           Skip gum installation
  --skip-psql          Skip PostgreSQL client installation
  --non-interactive    Skip all prompts (auto-confirm)
  -y                   Same as --non-interactive
  --help, -h           Show this help message

Examples:
  # Install everything (recommended)
  ./setup.sh

  # Install only PostgreSQL client
  ./setup.sh --skip-gum

  # Install only gum
  ./setup.sh --skip-psql

  # Non-interactive installation
  ./setup.sh -y

EOF
}

# =============================================================================
# OS Detection
# =============================================================================

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

# =============================================================================
# Confirmation Prompts
# =============================================================================

confirm() {
    local prompt="$1"
    
    if [ "$NON_INTERACTIVE" = true ]; then
        return 0
    fi
    
    read -p "$prompt (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    fi
    return 1
}

# =============================================================================
# PostgreSQL Client Installation
# =============================================================================

check_psql_installed() {
    if command -v psql &> /dev/null; then
        PSQL_VERSION=$(psql --version 2>/dev/null || echo "unknown")
        log_success "PostgreSQL client is already installed: $PSQL_VERSION"
        return 0
    fi
    return 1
}

install_psql_macos() {
    log_step "Installing PostgreSQL client via Homebrew..."
    
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew is not installed."
        echo ""
        echo "To install Homebrew, run:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        return 1
    fi
    
    if confirm "Install PostgreSQL client via Homebrew?"; then
        brew install postgresql@16
        log_success "PostgreSQL client installed"
    else
        log_info "Skipping PostgreSQL client installation"
        return 1
    fi
}

install_psql_linux() {
    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint)
            log_step "Installing PostgreSQL client via apt..."
            if confirm "Install PostgreSQL client?"; then
                sudo apt update
                sudo apt install -y postgresql-client
                log_success "PostgreSQL client installed"
            else
                log_info "Skipping PostgreSQL client installation"
                return 1
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            log_step "Installing PostgreSQL client via yum/dnf..."
            if confirm "Install PostgreSQL client?"; then
                sudo yum install -y postgresql
                log_success "PostgreSQL client installed"
            else
                log_info "Skipping PostgreSQL client installation"
                return 1
            fi
            ;;
        arch|manjaro)
            log_step "Installing PostgreSQL client via pacman..."
            if confirm "Install PostgreSQL client?"; then
                sudo pacman -S --noconfirm postgresql-libs
                log_success "PostgreSQL client installed"
            else
                log_info "Skipping PostgreSQL client installation"
                return 1
            fi
            ;;
        alpine)
            log_step "Installing PostgreSQL client via apk..."
            if confirm "Install PostgreSQL client?"; then
                sudo apk add postgresql-client
                log_success "PostgreSQL client installed"
            else
                log_info "Skipping PostgreSQL client installation"
                return 1
            fi
            ;;
        *)
            log_warning "Unknown Linux distribution: $DISTRO"
            echo ""
            echo "Please install PostgreSQL client manually:"
            echo "  https://www.postgresql.org/download/"
            echo ""
            return 1
            ;;
    esac
}

install_psql() {
    log_step "Checking PostgreSQL client..."
    
    if check_psql_installed; then
        return 0
    fi
    
    log_info "PostgreSQL client (psql) is not installed"
    
    case "$OS" in
        macos)
            install_psql_macos
            ;;
        linux)
            install_psql_linux
            ;;
        *)
            log_warning "Unknown operating system"
            echo ""
            echo "Please install PostgreSQL client manually:"
            echo "  https://www.postgresql.org/download/"
            echo ""
            return 1
            ;;
    esac
}

# =============================================================================
# Gum Installation
# =============================================================================

check_gum_installed() {
    if command -v gum &> /dev/null; then
        GUM_VERSION=$(gum --version 2>/dev/null || echo "unknown")
        log_success "gum is already installed: $GUM_VERSION"
        return 0
    fi
    return 1
}

install_gum_macos() {
    log_step "Installing gum via Homebrew..."
    
    if ! command -v brew &> /dev/null; then
        log_warning "Homebrew is not installed."
        echo ""
        echo "To install Homebrew, run:"
        echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        echo ""
        return 1
    fi
    
    if confirm "Install gum via Homebrew?"; then
        brew install gum
        log_success "gum installed"
    else
        log_info "Skipping gum installation"
        return 1
    fi
}

install_gum_linux() {
    case "$DISTRO" in
        ubuntu|debian|pop|linuxmint)
            log_step "Installing gum via apt..."
            if confirm "Install gum via apt?"; then
                sudo mkdir -p /etc/apt/keyrings
                curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
                echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
                sudo apt update && sudo apt install -y gum
                log_success "gum installed"
            else
                log_info "Skipping gum installation"
                return 1
            fi
            ;;
        fedora|rhel|centos|rocky|almalinux)
            log_step "Installing gum via yum/dnf..."
            if confirm "Install gum via yum/dnf?"; then
                echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
                sudo yum install -y gum
                log_success "gum installed"
            else
                log_info "Skipping gum installation"
                return 1
            fi
            ;;
        arch|manjaro)
            log_step "Installing gum via pacman..."
            if confirm "Install gum via pacman?"; then
                sudo pacman -S --noconfirm gum
                log_success "gum installed"
            else
                log_info "Skipping gum installation"
                return 1
            fi
            ;;
        alpine)
            log_step "Installing gum via apk..."
            if confirm "Install gum via apk?"; then
                sudo apk add gum
                log_success "gum installed"
            else
                log_info "Skipping gum installation"
                return 1
            fi
            ;;
        *)
            log_warning "Unknown Linux distribution: $DISTRO"
            show_gum_manual_install
            return 1
            ;;
    esac
}

show_gum_manual_install() {
    echo ""
    echo "You can install gum manually:"
    echo ""
    echo "  Download from: https://github.com/charmbracelet/gum/releases"
    echo ""
    echo "  Or install via Go:"
    echo "    go install github.com/charmbracelet/gum@latest"
    echo ""
    echo "  Or use Nix:"
    echo "    nix-env -iA nixpkgs.gum"
    echo ""
}

install_gum() {
    log_step "Checking gum..."
    
    if check_gum_installed; then
        return 0
    fi
    
    log_info "gum is not installed (optional but recommended)"
    
    case "$OS" in
        macos)
            install_gum_macos
            ;;
        linux)
            install_gum_linux
            ;;
        *)
            log_warning "Unknown operating system"
            show_gum_manual_install
            return 1
            ;;
    esac
}

# =============================================================================
# Configuration Setup
# =============================================================================

setup_config() {
    log_step "Setting up configuration..."
    
    local config_file="config.env"
    local config_example="config.env.example"
    
    if [ -f "$config_file" ]; then
        log_info "Configuration file already exists: $config_file"
        return 0
    fi
    
    if [ -f "$config_example" ]; then
        if confirm "Create config.env from example?"; then
            cp "$config_example" "$config_file"
            log_success "Created config.env"
            echo ""
            log_info "Please edit config.env with your PostgreSQL connection details"
        fi
    else
        log_warning "config.env.example not found"
    fi
}

# =============================================================================
# Verification
# =============================================================================

verify_installation() {
    log_step "Verifying installation..."
    
    local all_ok=true
    
    echo ""
    echo "Installation Status:"
    echo "═══════════════════════════════"
    
    # Check psql
    if command -v psql &> /dev/null; then
        PSQL_VERSION=$(psql --version)
        echo -e "${GREEN}✓${NC} PostgreSQL client: $PSQL_VERSION"
    else
        echo -e "${RED}✗${NC} PostgreSQL client: Not installed"
        all_ok=false
    fi
    
    # Check gum
    if command -v gum &> /dev/null; then
        GUM_VERSION=$(gum --version)
        echo -e "${GREEN}✓${NC} gum: $GUM_VERSION"
    else
        echo -e "${YELLOW}○${NC} gum: Not installed (optional)"
    fi
    
    echo ""
    
    if [ "$all_ok" = true ]; then
        log_success "Setup complete! You can now use pgctl."
        echo ""
        echo "Next steps:"
        echo "  1. Edit config.env with your PostgreSQL connection details"
        echo "  2. Set your admin password: export PGPASSWORD=your_password"
        echo "  3. Run pgctl: ./pgctl"
        echo ""
        return 0
    else
        log_error "Some dependencies are missing. Please install them manually."
        return 1
    fi
}

# =============================================================================
# Main Function
# =============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║      pgctl Setup Script                ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    
    # Parse command line arguments
    parse_args "$@"
    
    # Detect OS
    detect_os
    echo ""
    
    # Install PostgreSQL client
    if [ "$SKIP_PSQL" = false ]; then
        install_psql || true
    else
        log_info "Skipping PostgreSQL client installation (--skip-psql)"
    fi
    
    # Install gum
    if [ "$SKIP_GUM" = false ]; then
        install_gum || true
    else
        log_info "Skipping gum installation (--skip-gum)"
    fi
    
    # Setup configuration
    setup_config
    
    # Verify installation
    echo ""
    verify_installation
}

# =============================================================================
# Entry Point
# =============================================================================

main "$@"
