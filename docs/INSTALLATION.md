# pgctl Installation & Setup Guide

Complete guide for installing and setting up pgctl on your system.

## Table of Contents

- [Quick Start](#quick-start)
- [Installation](#installation)
  - [Remote Installation](#remote-installation-recommended)
  - [Local Installation](#local-installation)
  - [Manual Methods](#manual-installation-methods)
- [Setup](#setup)
  - [Automated Setup](#automated-setup)
  - [Manual Setup](#manual-setup)
- [Configuration](#configuration)
- [Verification](#verification)
- [Updating](#updating)
- [Uninstallation](#uninstallation)
- [Troubleshooting](#troubleshooting)

---

## Quick Start

Install pgctl with a single command:

```bash
# Automatically installs to ~/.local/bin (no sudo required)
curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash

# Or specify global installation (requires sudo)
curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash -s -- --global
```

Then run the setup:

```bash
cd ~/.pgctl && ./setup.sh
```

That's it! You can now use `pgctl` from anywhere:

```bash
pgctl --version
pgctl help
pgctl  # Interactive menu
```

---

## Installation

### Remote Installation (Recommended)

Install pgctl directly from GitHub using curl:

```bash
# Simple installation (automatically chooses user installation)
curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash

# Global installation (requires sudo, available to all users)
curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash -s -- --global

# User installation (explicit, no sudo required)
curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash -s -- --user
```

This will:
- Clone the repository to `~/.pgctl`
- Install to `~/.local/bin` (user) or `/usr/local/bin` (global)
- Create a symlink to make `pgctl` available from anywhere
- When piped from curl, defaults to user installation (safer, no sudo)

#### Custom Remote Installation

Customize the installation with environment variables:

```bash
# Custom installation directory
PGCTL_DIR=~/tools/pgctl curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash

# Fork or different repository
PGCTL_REPO_URL=https://github.com/YOUR_FORK/pgctl.git curl -o- https://raw.githubusercontent.com/YOUR_FORK/pgctl/main/install.sh | bash

# Specific branch
PGCTL_REPO_BRANCH=develop curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash
```

**Environment Variables:**
- `PGCTL_DIR` - Installation directory (default: `~/.pgctl`)
- `PGCTL_REPO_URL` - Repository URL (default: `https://github.com/gushwork/pgctl.git`)
- `PGCTL_REPO_BRANCH` - Branch to clone (default: `master`)

### Local Installation

If you've already cloned the repository:

```bash
# Clone the repository
git clone https://github.com/gushwork/pgctl.git
cd pgctl

# Run installer
./install.sh --global    # Global (requires sudo)
# or
./install.sh --user      # User-only (no sudo)
# or
./install.sh             # Interactive menu
```

### Manual Installation Methods

#### Method 1: Add to PATH

Add pgctl to your PATH via shell configuration:

```bash
# For Zsh (macOS default)
echo 'export PATH="$HOME/.pgctl:$PATH"' >> ~/.zshrc
source ~/.zshrc

# For Bash
echo 'export PATH="$HOME/.pgctl:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### Method 2: Create Symlink Manually

```bash
# Global (requires sudo)
sudo ln -s "$HOME/.pgctl/pgctl" /usr/local/bin/pgctl

# User-only
mkdir -p ~/.local/bin
ln -s "$HOME/.pgctl/pgctl" ~/.local/bin/pgctl
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### Method 3: Shell Alias

```bash
echo 'alias pgctl="$HOME/.pgctl/pgctl"' >> ~/.zshrc
source ~/.zshrc
```

---

## Setup

After installation, you need to install dependencies (PostgreSQL client and gum).

### Automated Setup

Run the setup script to install all dependencies:

```bash
# For remote installation
cd ~/.pgctl && ./setup.sh

# For local installation
./setup.sh
```

#### Setup Options

```bash
# Install everything (recommended)
./setup.sh

# Install only PostgreSQL client
./setup.sh --skip-gum

# Install only gum
./setup.sh --skip-psql

# Non-interactive mode (for CI/CD)
./setup.sh -y
```

The setup script will:
1. Detect your operating system
2. Install PostgreSQL client (psql)
3. Install gum (optional but recommended for enhanced UI)
4. Create `config.env` from example
5. Verify the installation

### Manual Setup

If you prefer manual installation:

#### PostgreSQL Client

**macOS:**
```bash
brew install postgresql@16
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install postgresql-client
```

**Fedora/RHEL/CentOS:**
```bash
sudo dnf install postgresql
```

**Arch/Manjaro:**
```bash
sudo pacman -S postgresql
```

#### Gum (Optional)

**macOS:**
```bash
brew install gum
```

**Ubuntu/Debian:**
```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
sudo apt update && sudo apt install gum
```

**Fedora/RHEL:**
```bash
echo '[charm]
name=Charm
baseurl=https://repo.charm.sh/yum/
enabled=1
gpgcheck=1
gpgkey=https://repo.charm.sh/yum/gpg.key' | sudo tee /etc/yum.repos.d/charm.repo
sudo yum install gum
```

**Arch/Manjaro:**
```bash
sudo pacman -S gum
```

**Go:**
```bash
go install github.com/charmbracelet/gum@latest
```

**Note:** pgctl works without gum, but provides a better interactive experience with it installed.

---

## Configuration

### Create Configuration File

```bash
# For remote installation
cd ~/.pgctl
cp config.env.example config.env

# For local installation
cp config.env.example config.env
```

### Edit Configuration

```bash
nano config.env  # or use your preferred editor
```

**Required settings:**

```bash
# PostgreSQL connection details
export PGHOST="localhost"
export PGPORT="5432"
export PGADMIN="postgres"

# Optional: Set password (or enter interactively)
# export PGPASSWORD="your_admin_password"
```

### Set Admin Password

You can either:

1. **Set in config.env** (less secure):
   ```bash
   export PGPASSWORD="your_admin_password"
   ```

2. **Set in shell** (recommended):
   ```bash
   export PGPASSWORD=your_admin_password
   ```

3. **Enter interactively** when pgctl prompts

---

## Verification

Verify the installation:

```bash
# Check pgctl is in PATH
which pgctl

# Check version
pgctl --version

# Check PostgreSQL client
psql --version

# Check gum (optional)
gum --version

# Test pgctl
pgctl help
pgctl  # Interactive menu
```

---

## Updating

### Remote Installation (installed via curl)

```bash
cd ~/.pgctl
git pull
```

### Local Installation

```bash
cd /path/to/your/pgctl
git pull
```

The symlink automatically uses the updated version - no need to reinstall!

---

## Uninstallation

### Using the Installer

```bash
# If you have the repository
./install.sh --uninstall

# Or run directly from remote
curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash -s -- --uninstall
```

### Manual Uninstallation

```bash
# Remove global installation
sudo rm /usr/local/bin/pgctl

# Remove user installation
rm ~/.local/bin/pgctl

# Remove installation directory (remote installations)
rm -rf ~/.pgctl

# Remove from PATH (if using manual PATH method)
# Edit ~/.zshrc or ~/.bashrc and remove the line that adds pgctl to PATH
```

---

## Troubleshooting

### Installation Issues

#### "pgctl: command not found"

**Solution 1:** Check if symlink exists
```bash
ls -la /usr/local/bin/pgctl
# or
ls -la ~/.local/bin/pgctl
```

**Solution 2:** Check if directory is in PATH
```bash
echo $PATH | grep -o "/usr/local/bin"
```

**Solution 3:** Restart terminal or reload shell config
```bash
source ~/.zshrc  # or ~/.bashrc
```

#### Permission Denied

```bash
chmod +x ~/.pgctl/pgctl
```

#### Symlink Points to Wrong Location

```bash
# Remove and recreate
sudo rm /usr/local/bin/pgctl
./install.sh --global
```

### Setup Issues

#### Homebrew Not Found (macOS)

Install Homebrew first:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### Permission Errors (Linux)

The setup script uses `sudo` for system package installations. Make sure your user has sudo privileges.

#### Package Manager Not Found

For unsupported systems:
- **PostgreSQL:** https://www.postgresql.org/download/
- **Gum:** https://github.com/charmbracelet/gum/releases

### Connection Issues

#### Cannot Connect to PostgreSQL

```bash
# Test connection
psql -h localhost -U postgres -l

# Check PostgreSQL is running
# macOS:
brew services list | grep postgresql

# Linux:
sudo systemctl status postgresql
```

#### Authentication Failed

1. Verify password is correct
2. Check `pg_hba.conf` authentication method
3. Try connecting as superuser first

---

## Platform-Specific Notes

### macOS

- `/usr/local/bin` is in PATH by default
- Default shell is zsh (since macOS Catalina)
- Uses Homebrew for package management
- May need to allow terminal access in System Preferences

### Linux

- `/usr/local/bin` is typically in PATH
- Shell config file depends on shell (bash: `~/.bashrc`, zsh: `~/.zshrc`)
- Package manager varies by distribution
- May need sudo privileges for system installations

### Windows (WSL)

- Works in WSL (Windows Subsystem for Linux)
- Use Linux installation instructions
- Make sure you're in a bash/zsh environment

---

## Supported Platforms

| Platform | PostgreSQL | Gum | Status |
|----------|-----------|-----|--------|
| macOS (Homebrew) | ✅ | ✅ | Fully Supported |
| Ubuntu/Debian | ✅ | ✅ | Fully Supported |
| Fedora/RHEL/CentOS | ✅ | ✅ | Fully Supported |
| Arch/Manjaro | ✅ | ✅ | Fully Supported |
| Alpine Linux | ✅ | ✅ | Fully Supported |
| Windows WSL | ✅ | ✅ | Supported |
| Other Linux | Manual | Manual | Manual Install |

---

## CI/CD Integration

For automated environments:

```bash
# Non-interactive installation
curl -o- https://raw.githubusercontent.com/gushwork/pgctl/refs/heads/latest/install.sh | bash -s -- --user
cd ~/.pgctl && ./setup.sh --skip-gum -y

# Set configuration
export PGHOST=localhost
export PGPORT=5432
export PGADMIN=postgres
export PGPASSWORD=test_password

# Run tests
pgctl test
```

---

## Next Steps

After installation and setup:

1. **Configure PostgreSQL Connection**
   ```bash
   nano ~/.pgctl/config.env  # or your install location
   ```

2. **Test Connection**
   ```bash
   pgctl list-databases
   ```

3. **Explore Commands**
   ```bash
   pgctl help              # Show all commands
   pgctl                   # Interactive menu
   pgctl create-db         # Create a database
   pgctl create-user       # Create a user
   ```

4. **Read Documentation**
   - [README.md](../README.md) - Full feature reference
   - [CONTRIBUTING.md](CONTRIBUTING.md) - Contribute to the project

---

## Getting Help

If you encounter issues:

1. Check this guide
2. Run `pgctl help` for usage information
3. Check [README.md](../README.md) for general information
4. Report issues: https://github.com/gushwork/pgctl/issues

---

**Happy PostgreSQL managing!** 🐘
