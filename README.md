# ECFS Lite Installer

One-command installer for [ECFS Lite](https://github.com/dcain2336/ecfs) — a lightweight HTTP gateway for AI agent mesh networking.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/dcain2336/ecfs-installer/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/dcain2336/ecfs-installer.git
cd ecfs-installer
sudo bash install.sh
```

## What It Does

1. Detects your OS (Ubuntu/Debian, RHEL/CentOS/Fedora, Alpine, macOS)
2. Installs Python 3.10+, git, nginx (optional)
3. Clones ECFS and sets up a virtualenv
4. Generates admin keys and config
5. Installs systemd service (or runs in dev mode on macOS)
6. Optionally configures nginx reverse proxy and Cloudflare quick tunnel

## Options

| Flag | Description | Default |
|------|-------------|---------|
| `--port PORT` | Gateway listen port | `7703` |
| `--relay URL` | ECFS relay URL | `http://127.0.0.1:7700` |
| `--public-url URL` | Public URL for peer announcements | auto-detect |
| `--admin-key KEY` | Pre-set admin key | auto-generate |
| `--install-dir DIR` | Installation directory | `/opt/ecfs` |
| `--user USER` | Service user | `ecfs` |
| `--nginx` | Install nginx reverse proxy | off |
| `--cloudflare` | Set up Cloudflare quick tunnel | off |
| `--dev` | Dev mode (no systemd) | off |

## Examples

**Production with nginx + Cloudflare:**
```bash
sudo bash install.sh --nginx --cloudflare --public-url https://ecfs.example.com
```

**Quick dev install:**
```bash
bash install.sh --dev --port 8800
```

## After Install

```bash
# Check health
curl http://localhost:7703/health

# Create an API key
curl -X POST http://localhost:7703/admin/key/create \
  -H "X-Admin-Key: YOUR_ADMIN_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name":"my-agent","scopes":["send","compute"]}'

# Register
curl -X POST http://localhost:7703/register \
  -H "Authorization: Bearer *** \
  -H "Content-Type: application/json" \
  -d '{"name":"my-agent"}'
```

## Uninstall

```bash
sudo bash /opt/ecfs/uninstall.sh
```

## License

MIT
