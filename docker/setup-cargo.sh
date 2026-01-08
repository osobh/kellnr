#!/bin/bash
#
# Kellnr Developer Setup Script
# Installs Rust (if needed) and configures cargo to use crates.rustystack.io
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/osobh/kellnr/main/docker/setup-cargo.sh | bash -s -- -t YOUR_TOKEN
#   ./setup-cargo.sh -t YOUR_TOKEN
#
# Options:
#   -t TOKEN    Kellnr API token (required)
#   -h          Show help
#

set -e

# Configuration
KELLNR_HOST="crates.rustystack.io"
KELLNR_PROTOCOL="http"
RUST_VERSION="1.92.0"
CARGO_CONFIG="$HOME/.cargo/config.toml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo ""
    echo "========================================================"
    echo "  Kellnr Developer Setup"
    echo "  Registry: ${KELLNR_PROTOCOL}://${KELLNR_HOST}"
    echo "========================================================"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}!${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

show_help() {
    echo "Kellnr Developer Setup Script"
    echo ""
    echo "Usage:"
    echo "  curl -sSL https://raw.githubusercontent.com/osobh/kellnr/main/docker/setup-cargo.sh | bash -s -- -t TOKEN"
    echo "  ./setup-cargo.sh -t TOKEN"
    echo ""
    echo "Options:"
    echo "  -t TOKEN    Kellnr API token (required)"
    echo "  -h          Show this help message"
    echo ""
    echo "Get your API token from: ${KELLNR_PROTOCOL}://${KELLNR_HOST} (Settings > Tokens)"
    exit 0
}

install_rust() {
    echo ""
    echo "Installing Rust ${RUST_VERSION}..."
    echo ""

    # Download and run rustup installer in non-interactive mode
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain ${RUST_VERSION}

    # Source cargo environment
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi

    # Verify installation
    if command -v rustc &> /dev/null; then
        print_success "Rust $(rustc --version | cut -d' ' -f2) installed successfully"
    else
        print_error "Rust installation failed"
        exit 1
    fi
}

configure_cargo() {
    echo ""
    echo "Configuring cargo for Kellnr..."

    # Create .cargo directory if it doesn't exist
    mkdir -p "$HOME/.cargo"

    # Backup existing config if present
    if [ -f "$CARGO_CONFIG" ]; then
        BACKUP="${CARGO_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
        print_warning "Backing up existing config to: $BACKUP"
        cp "$CARGO_CONFIG" "$BACKUP"

        # Remove existing kellnr config sections if present
        if grep -q "kellnr" "$CARGO_CONFIG" 2>/dev/null; then
            print_warning "Removing existing Kellnr configuration"
            # Use temp file for compatibility
            grep -v -E '^\[registries\.kellnr\]|^\[source\.crates-io\]|^\[source\.kellnr-proxy\]' "$CARGO_CONFIG" > "${CARGO_CONFIG}.tmp" 2>/dev/null || true
            # Remove config blocks (lines until next section or empty line)
            awk '/^\[registries\.kellnr\]/,/^$/{next} /^\[source\.crates-io\]/,/^$/{next} /^\[source\.kellnr-proxy\]/,/^$/{next} {print}' "$BACKUP" > "${CARGO_CONFIG}.tmp" 2>/dev/null || cp "$BACKUP" "${CARGO_CONFIG}.tmp"
            mv "${CARGO_CONFIG}.tmp" "$CARGO_CONFIG"
        fi
    fi

    # Append Kellnr configuration
    cat >> "$CARGO_CONFIG" << EOF

# ============================================
# Kellnr Private Registry Configuration
# Generated: $(date)
# Registry: ${KELLNR_PROTOCOL}://${KELLNR_HOST}
# ============================================

# Private crate registry
[registries.kellnr]
index = "sparse+${KELLNR_PROTOCOL}://${KELLNR_HOST}/api/v1/crates/"
credential-provider = ["cargo:token"]
token = "${KELLNR_TOKEN}"

# Replace crates.io with Kellnr proxy
# All crates.io downloads are cached through Kellnr
[source.crates-io]
replace-with = "kellnr-proxy"

[source.kellnr-proxy]
registry = "sparse+${KELLNR_PROTOCOL}://${KELLNR_HOST}/api/v1/cratesio/"
EOF

    print_success "Cargo configured for Kellnr"
}

# Parse command line arguments
KELLNR_TOKEN=""

while getopts "t:h" opt; do
    case $opt in
        t)
            KELLNR_TOKEN="$OPTARG"
            ;;
        h)
            show_help
            ;;
        \?)
            print_error "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

# Validate token
if [ -z "$KELLNR_TOKEN" ]; then
    print_error "API token is required"
    echo ""
    echo "Usage: $0 -t YOUR_TOKEN"
    echo ""
    echo "Get your token from: ${KELLNR_PROTOCOL}://${KELLNR_HOST} (Settings > Tokens)"
    exit 1
fi

# Main execution
print_header

# Step 1: Check/Install Rust
echo "Step 1: Checking Rust installation..."
if command -v rustc &> /dev/null; then
    CURRENT_VERSION=$(rustc --version | cut -d' ' -f2)
    print_success "Rust ${CURRENT_VERSION} is already installed"
else
    print_warning "Rust not found - installing Rust ${RUST_VERSION}"
    install_rust
    RUST_JUST_INSTALLED=1
fi

# Step 2: Verify cargo is available
echo ""
echo "Step 2: Verifying cargo..."
if command -v cargo &> /dev/null; then
    print_success "Cargo $(cargo --version | cut -d' ' -f2) is available"
else
    # Try sourcing cargo env
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    if command -v cargo &> /dev/null; then
        print_success "Cargo $(cargo --version | cut -d' ' -f2) is available"
    else
        print_error "Cargo not found. Please restart your shell or run: source ~/.cargo/env"
        exit 1
    fi
fi

# Step 3: Configure cargo for Kellnr
echo ""
echo "Step 3: Configuring cargo for Kellnr..."
configure_cargo

# Done!
echo ""
echo "========================================================"
echo "  Setup Complete!"
echo "========================================================"
echo ""
echo "Config written to: $CARGO_CONFIG"
echo ""
echo "Quick Start:"
echo ""
echo "  # All crates.io packages are now proxied through Kellnr"
echo "  cargo build"
echo ""
echo "  # Use a private crate in Cargo.toml:"
echo "  [dependencies]"
echo "  my_crate = { version = \"1.0\", registry = \"kellnr\" }"
echo ""
echo "  # Publish a private crate:"
echo "  cargo publish --registry kellnr"
echo ""
echo "Test your setup:"
echo "  cargo search serde"
echo ""

# Remind about shell restart if Rust was just installed
if [ ! -z "$RUST_JUST_INSTALLED" ]; then
    echo ""
    print_warning "NOTE: You may need to restart your shell or run:"
    echo "       source ~/.cargo/env"
    echo ""
fi
