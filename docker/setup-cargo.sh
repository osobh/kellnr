#!/bin/bash
#
# Kellnr Cargo Configuration Script
# Configures cargo to use crates.rustystack.io for all crate operations
#
# Usage: curl -sSL https://raw.githubusercontent.com/osobh/kellnr/main/docker/setup-cargo.sh | bash
#    or: ./setup-cargo.sh
#

set -e

KELLNR_HOST="crates.rustystack.io"
KELLNR_PROTOCOL="http"
CARGO_CONFIG="$HOME/.cargo/config.toml"

echo "================================================"
echo "  Kellnr Cargo Configuration Setup"
echo "  Registry: ${KELLNR_PROTOCOL}://${KELLNR_HOST}"
echo "================================================"
echo ""

# Check if cargo is installed
if ! command -v cargo &> /dev/null; then
    echo "ERROR: cargo is not installed. Please install Rust first."
    echo "       Visit: https://rustup.rs"
    exit 1
fi

# Prompt for API token
echo "Enter your Kellnr API token (get it from the web UI):"
read -r KELLNR_TOKEN

if [ -z "$KELLNR_TOKEN" ]; then
    echo "ERROR: API token is required."
    exit 1
fi

# Create .cargo directory if it doesn't exist
mkdir -p "$HOME/.cargo"

# Backup existing config if present
if [ -f "$CARGO_CONFIG" ]; then
    BACKUP="${CARGO_CONFIG}.backup.$(date +%Y%m%d%H%M%S)"
    echo "Backing up existing config to: $BACKUP"
    cp "$CARGO_CONFIG" "$BACKUP"
fi

# Check if kellnr config already exists
if grep -q "kellnr" "$CARGO_CONFIG" 2>/dev/null; then
    echo ""
    echo "WARNING: Kellnr configuration already exists in $CARGO_CONFIG"
    echo "Do you want to overwrite it? (y/N)"
    read -r OVERWRITE
    if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
        echo "Aborted. No changes made."
        exit 0
    fi
    # Remove existing kellnr config sections
    sed -i '/\[registries\.kellnr\]/,/^$/d' "$CARGO_CONFIG" 2>/dev/null || true
    sed -i '/\[source\.crates-io\]/,/^$/d' "$CARGO_CONFIG" 2>/dev/null || true
    sed -i '/\[source\.kellnr-proxy\]/,/^$/d' "$CARGO_CONFIG" 2>/dev/null || true
fi

# Append Kellnr configuration
cat >> "$CARGO_CONFIG" << EOF

# ============================================
# Kellnr Private Registry Configuration
# Generated: $(date)
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

echo ""
echo "================================================"
echo "  Configuration Complete!"
echo "================================================"
echo ""
echo "Config written to: $CARGO_CONFIG"
echo ""
echo "Usage:"
echo ""
echo "  Pull crates.io packages (automatic via proxy):"
echo "    cargo build"
echo ""
echo "  Use a private crate in Cargo.toml:"
echo "    [dependencies]"
echo "    my_crate = { version = \"1.0\", registry = \"kellnr\" }"
echo ""
echo "  Publish a private crate:"
echo "    cargo publish --registry kellnr"
echo ""
echo "  Or add to Cargo.toml:"
echo "    [package]"
echo "    publish = [\"kellnr\"]"
echo ""
echo "Test your setup:"
echo "    cargo search serde"
echo ""
