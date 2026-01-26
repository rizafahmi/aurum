#!/bin/bash
# EC2 Instance Setup Script for Aurum
# Run this on a fresh Amazon Linux 2023 or Ubuntu 22.04 instance

set -e

echo "=== Aurum EC2 Setup Script ==="

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"
    exit 1
fi

echo "Detected OS: $OS"

# Install Podman
if [ "$OS" = "amzn" ]; then
    echo "Installing Podman on Amazon Linux..."
    sudo yum update -y
    sudo yum install -y podman podman-compose git
elif [ "$OS" = "ubuntu" ]; then
    echo "Installing Podman on Ubuntu..."
    sudo apt-get update
    sudo apt-get install -y podman podman-compose git
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Enable podman socket for rootless mode
systemctl --user enable --now podman.socket 2>/dev/null || true

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Clone your repo: git clone <your-repo-url> aurum"
echo "2. cd aurum"
echo "3. cp .env.example .env"
echo "4. Generate secret: podman run --rm hexpm/elixir:1.18.4-erlang-27.3.4-debian-bookworm-20250428-slim sh -c 'mix local.hex --force && mix phx.gen.secret'"
echo "5. Edit .env with your SECRET_KEY_BASE and PHX_HOST"
echo "6. podman-compose up -d --build"
echo ""
