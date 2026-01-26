# Aurum EC2 Deployment Guide

## Prerequisites

- AWS account with EC2 access
- Domain name (optional, for HTTPS)
- SSH key pair for EC2

## Quick Start

### 1. Launch EC2 Instance

**Recommended specs:**
- **Instance type**: t3.small or t3.micro (for low traffic)
- **AMI**: Amazon Linux 2023 or Ubuntu 22.04
- **Storage**: 20GB gp3 (increase for more vault data)
- **Security Group**: Allow ports 22 (SSH), 80 (HTTP), 443 (HTTPS)

### 2. Connect and Setup

```bash
ssh -i your-key.pem ec2-user@your-instance-ip  # Amazon Linux
# or
ssh -i your-key.pem ubuntu@your-instance-ip    # Ubuntu

# Run setup script
curl -sSL https://raw.githubusercontent.com/YOUR_REPO/main/deploy/ec2-setup.sh | bash
```

### 3. Deploy Application

```bash
# Clone your repo
git clone https://github.com/YOUR_REPO/aurum.git
cd aurum

# Configure environment
cp .env.example .env

# Generate secret key
podman run --rm hexpm/elixir:1.18.4-erlang-27.3.4-debian-bookworm-20250428-slim \
  sh -c "mix local.hex --force && mix phx.gen.secret"

# Edit .env with your values
nano .env

# Build and start
podman-compose up -d --build

# Check logs
podman-compose logs -f
```

### 4. Setup HTTPS with Caddy (Recommended)

```bash
# Install Caddy
sudo yum install -y yum-plugin-copr  # Amazon Linux
sudo yum copr enable @caddy/caddy -y
sudo yum install -y caddy
# or for Ubuntu:
# sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
# curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
# curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
# sudo apt update && sudo apt install -y caddy

# Copy Caddyfile
sudo cp deploy/Caddyfile /etc/caddy/Caddyfile

# Edit domain name
sudo nano /etc/caddy/Caddyfile

# Start Caddy (auto-HTTPS happens automatically)
sudo systemctl enable caddy
sudo systemctl start caddy
```

## Management Commands

```bash
# View logs
podman-compose logs -f

# Restart
podman-compose restart

# Stop
podman-compose down

# Update (after git pull)
podman-compose up -d --build

# Access IEx console
podman-compose exec aurum bin/aurum remote

# Backup database
podman-compose exec aurum tar -czf - /app/data > backup.tar.gz
```

## Backup Strategy

SQLite databases are stored in a Podman volume. For backups:

```bash
# Create backup
podman run --rm -v aurum_aurum_data:/data -v $(pwd):/backup:Z alpine \
  tar -czf /backup/aurum-backup-$(date +%Y%m%d).tar.gz -C /data .

# Restore from backup
podman-compose down
podman run --rm -v aurum_aurum_data:/data -v $(pwd):/backup:Z alpine \
  sh -c "rm -rf /data/* && tar -xzf /backup/aurum-backup-YYYYMMDD.tar.gz -C /data"
podman-compose up -d
```

## Monitoring

Access Phoenix LiveDashboard at `https://your-domain.com/dev/dashboard` (if enabled in prod).

## Troubleshooting

**Container won't start:**
```bash
podman-compose logs aurum
```

**Database errors:**
```bash
# Check if volume has correct permissions
podman-compose exec aurum ls -la /app/data
```

**Out of memory:**
Consider upgrading to t3.small or adding swap:
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```
