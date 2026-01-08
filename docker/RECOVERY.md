# Kellnr Disaster Recovery Documentation

**Last Updated:** 2026-01-08
**Host:** rpi02
**IP Address:** 192.168.1.102

---

## Quick Reference

| Item | Value |
|------|-------|
| **Web URL** | http://crates.rustystack.io |
| **Health Check** | http://crates.rustystack.io/api/v1/health |
| **Admin Username** | admin |
| **Admin Password** | Clouddev249! |
| **Admin API Token** | c3dcbTHTn3yoHUbMoJ2Bi201f2hmtnH3 |

---

## Developer Setup

### Automated Setup (Recommended)

Run the setup script to install Rust (if needed) and configure cargo:

```bash
# One-liner setup (replace YOUR_TOKEN with your actual token)
curl -sSL https://raw.githubusercontent.com/osobh/kellnr/main/docker/setup-cargo.sh | bash -s -- -t YOUR_TOKEN

# Or if you have the repo cloned:
./docker/setup-cargo.sh -t YOUR_TOKEN
```

The script will:
1. Install Rust 1.92.0 if not already installed
2. Configure cargo to use Kellnr as the crates.io proxy
3. Set up authentication for private crates

### Manual Configuration

Add to `~/.cargo/config.toml` on developer machines:

```toml
# ============================================
# Kellnr Private Registry Configuration
# ============================================

# Private crate registry
[registries.kellnr]
index = "sparse+http://crates.rustystack.io/api/v1/crates/"
credential-provider = ["cargo:token"]
token = "YOUR_API_TOKEN_HERE"

# Replace crates.io with Kellnr proxy
# All crates.io downloads are cached through Kellnr
[source.crates-io]
replace-with = "kellnr-proxy"

[source.kellnr-proxy]
registry = "sparse+http://crates.rustystack.io/api/v1/cratesio/"
```

### Getting Your API Token

1. Log in to http://crates.rustystack.io with your credentials
2. Go to Settings > Tokens
3. Create a new token or use the admin token (for admins only)

### Usage Examples

**Pull any crate (automatically proxied through Kellnr):**
```bash
cargo build  # All crates.io dependencies are cached locally
```

**Use a private crate in Cargo.toml:**
```toml
[dependencies]
my_private_crate = { version = "1.0", registry = "kellnr" }
```

**Publish a private crate:**
```bash
cargo publish --registry kellnr
```

**Or set default publish target in Cargo.toml:**
```toml
[package]
name = "my_crate"
version = "0.1.0"
publish = ["kellnr"]
```

### Verify Setup

```bash
# Test crates.io proxy
cargo search serde

# Test private registry access
cargo search --registry kellnr
```

---

## Infrastructure Details

### Server
| Setting | Value |
|---------|-------|
| Hostname | rpi02 |
| IP Address | 192.168.1.102 |
| OS | Linux (Raspberry Pi) |

### Storage Disk
| Setting | Value |
|---------|-------|
| Device | /dev/sda1 |
| UUID | 26b84b58-a918-4f48-871b-d401911dd48b |
| Filesystem | XFS |
| Size | 3.7 TB |
| Mount Point | /mnt/kellnr-data |

### fstab Entry
```
UUID=26b84b58-a918-4f48-871b-d401911dd48b /mnt/kellnr-data xfs defaults 0 2
```

---

## Docker Services

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| kellnr | ghcr.io/kellnr/kellnr:5 | 8000 (internal) | Crate registry |
| kellnr-nginx | nginx:alpine | 80 | Reverse proxy |
| kellnr-postgres | postgres:16 | 5432 (internal) | Database |
| kellnr-postgres-backup | prodrigestivill/postgres-backup-local:16 | - | Daily backups |

---

## Credentials

### PostgreSQL Database
| Setting | Value |
|---------|-------|
| Host | postgres (container) / localhost |
| Port | 5432 |
| Database | kellnr |
| Username | kellnr |
| Password | iL6vnWNV5J42WOMAMvaFqGKY |

### Kellnr Admin
| Setting | Value |
|---------|-------|
| Username | admin |
| Password | Clouddev249! |
| API Token | c3dcbTHTn3yoHUbMoJ2Bi201f2hmtnH3 |

---

## Enabled Features

| Feature | Status | Notes |
|---------|--------|-------|
| PostgreSQL Backend | Enabled | Using postgres:16 |
| Crates.io Proxy Cache | Enabled | 10 threads |
| Rustdoc Generation | Enabled | Max 100MB |
| Daily Backups | Enabled | 7 days / 4 weeks / 6 months retention |
| JSON Logging | Enabled | For log aggregation |

---

## Data Directories

| Path | Purpose |
|------|---------|
| /mnt/kellnr-data/kellnr | Kellnr data (crates, index, docs) |
| /mnt/kellnr-data/postgres | PostgreSQL database files |
| /mnt/kellnr-data/backups | PostgreSQL backup files |

---

## Configuration Files

### Location
```
/home/osobh/projects/kellnr/docker/
├── docker-compose.yml    # Main compose file
├── .env                  # Secrets (DO NOT COMMIT)
├── .env.example          # Template for .env
├── setup-cargo.sh        # Developer setup script
├── nginx/
│   └── nginx.conf        # Nginx reverse proxy config
└── RECOVERY.md           # This file
```

### .env File Contents
```env
# PostgreSQL Configuration
POSTGRES_USER=kellnr
POSTGRES_PASSWORD=iL6vnWNV5J42WOMAMvaFqGKY
POSTGRES_DB=kellnr

# Kellnr Admin Credentials (only used on first startup)
KELLNR_ADMIN_PWD=Clouddev249!
KELLNR_ADMIN_TOKEN=c3dcbTHTn3yoHUbMoJ2Bi201f2hmtnH3
```

---

## Recovery Procedures

### 1. Full Recovery from Backup

```bash
# 1. Mount the data disk
sudo mkdir -p /mnt/kellnr-data
sudo mount /dev/sda1 /mnt/kellnr-data

# 2. Add to fstab for persistence
echo "UUID=26b84b58-a918-4f48-871b-d401911dd48b /mnt/kellnr-data xfs defaults 0 2" | sudo tee -a /etc/fstab

# 3. Navigate to docker directory
cd /home/osobh/projects/kellnr/docker

# 4. Start the services
docker compose up -d

# 5. Verify health
curl http://localhost/api/v1/health
```

### 2. Restore PostgreSQL from Backup

```bash
# List available backups
ls -la /mnt/kellnr-data/backups/

# Stop Kellnr (keep postgres running)
docker compose stop kellnr

# Restore from backup (replace filename)
docker exec -i kellnr-postgres psql -U kellnr -d kellnr < /mnt/kellnr-data/backups/daily/kellnr-YYYYMMDD-HHMMSS.sql.gz

# Start Kellnr
docker compose start kellnr
```

### 3. Fresh Installation

```bash
# 1. Mount disk
sudo mkdir -p /mnt/kellnr-data
sudo mount /dev/sda1 /mnt/kellnr-data

# 2. Create directories
sudo mkdir -p /mnt/kellnr-data/{postgres,kellnr,backups}
sudo chown -R 1000:1000 /mnt/kellnr-data/kellnr
sudo chown -R 999:999 /mnt/kellnr-data/backups

# 3. Create .env file with credentials above

# 4. Start services
docker compose up -d
```

---

## Management Commands

```bash
# Navigate to docker directory
cd /home/osobh/projects/kellnr/docker

# View running containers
docker compose ps

# View logs
docker compose logs -f
docker compose logs -f kellnr

# Restart all services
docker compose restart

# Stop all services
docker compose down

# Start all services
docker compose up -d

# Manual backup now
docker exec kellnr-postgres-backup /backup.sh

# Connect to PostgreSQL
docker exec -it kellnr-postgres psql -U kellnr -d kellnr
```

---

## Troubleshooting

### Health Check Fails
```bash
# Check container status
docker compose ps

# Check Kellnr logs
docker compose logs kellnr

# Check PostgreSQL logs
docker compose logs postgres
```

### Disk Not Mounted
```bash
# Check if mounted
df -h /mnt/kellnr-data

# Mount manually
sudo mount /dev/sda1 /mnt/kellnr-data

# Or by UUID
sudo mount UUID=26b84b58-a918-4f48-871b-d401911dd48b /mnt/kellnr-data
```

### Reset Admin Password
Admin password can only be changed through the UI after first startup.
To reset completely:
```bash
# WARNING: This deletes all data!
docker compose down -v
sudo rm -rf /mnt/kellnr-data/kellnr/* /mnt/kellnr-data/postgres/*
# Update KELLNR_ADMIN_PWD in .env
docker compose up -d
```

---

## URLs Summary

| Purpose | URL |
|---------|-----|
| Web UI | http://crates.rustystack.io |
| Health Check | http://crates.rustystack.io/api/v1/health |
| Private Crates Index | sparse+http://crates.rustystack.io/api/v1/crates/ |
| Crates.io Proxy Index | sparse+http://crates.rustystack.io/api/v1/cratesio/ |

---

## Contact / Notes

- Project repository: /home/osobh/projects/kellnr
- Kellnr documentation: https://kellnr.io/documentation
- Kellnr GitHub: https://github.com/kellnr/kellnr
