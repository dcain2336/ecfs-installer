#!/usr/bin/env bash
# ECFS Lite Installer — Multi-platform one-command setup
# Supports: Ubuntu/Debian, RHEL/CentOS/Fedora, Alpine, macOS (dev mode)
set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────
ECFS_PORT=7703
ECFS_RELAY="http://127.0.0.1:7700"
ECFS_PUBLIC_URL=""
ECFS_ADMIN_KEY=""
ECFS_INSTALL_DIR="/opt/ecfs"
ECFS_USER="ecfs"
ECFS_REPO="https://github.com/dcain2336/ecfs.git"
ECFS_BRANCH="main"
INSTALL_NGINX=0
INSTALL_CLOUDFLARE=0
DEV_MODE=0

# ── Colors ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
step()  { echo -e "\n${CYAN}══ $* ══${NC}"; }

# ── Parse Args ────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --port)       ECFS_PORT="$2";       shift 2 ;;
    --relay)      ECFS_RELAY="$2";      shift 2 ;;
    --public-url) ECFS_PUBLIC_URL="$2"; shift 2 ;;
    --admin-key)  ECFS_ADMIN_KEY="$2";  shift 2 ;;
    --install-dir) ECFS_INSTALL_DIR="$2"; shift 2 ;;
    --user)       ECFS_USER="$2";       shift 2 ;;
    --branch)     ECFS_BRANCH="$2";     shift 2 ;;
    --repo)       ECFS_REPO="$2";       shift 2 ;;
    --nginx)      INSTALL_NGINX=1;      shift ;;
    --cloudflare) INSTALL_CLOUDFLARE=1; shift ;;
    --dev)        DEV_MODE=1;           shift ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "  --port PORT          Gateway port (default: 7703)"
      echo "  --relay URL          Relay URL (default: http://127.0.0.1:7700)"
      echo "  --public-url URL     Public URL for peer announcements"
      echo "  --admin-key KEY      Pre-set admin key (auto-generated if empty)"
      echo "  --install-dir DIR    Install path (default: /opt/ecfs)"
      echo "  --user USER          Service user (default: ecfs)"
      echo "  --branch BRANCH      Git branch (default: main)"
      echo "  --repo URL           Git repo URL"
      echo "  --nginx              Install nginx reverse proxy"
      echo "  --cloudflare         Install Cloudflare quick tunnel"
      echo "  --dev                Dev mode (no systemd, run in foreground)"
      exit 0 ;;
    *) error "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Detect OS ─────────────────────────────────────────────────────
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_ID="${ID,,}"
    OS_LIKE="${ID_LIKE,,}"
  elif [[ "$(uname)" == "Darwin" ]]; then
    OS_ID="macos"
    OS_LIKE="macos"
  else
    OS_ID="unknown"
    OS_LIKE=""
  fi
  ARCH=$(uname -m)
  step "Detected: ${OS_ID} (${ARCH})"
}

# ── Install System Packages ───────────────────────────────────────
install_deps() {
  step "Installing dependencies"
  
  case "$OS_ID" in
    ubuntu|debian|pop|linuxmint|zorin)
      apt-get update -qq
      apt-get install -y -qq python3 python3-venv python3-pip git curl nginx-core >/dev/null
      info "Installed via apt"
      ;;
    centos|rhel|rocky|alma|fedora)
      if command -v dnf &>/dev/null; then
        dnf install -y -q python3 python3-pip git curl nginx >/dev/null
      else
        yum install -y -q python3 python3-pip git curl nginx >/dev/null
      fi
      info "Installed via dnf/yum"
      ;;
    alpine)
      apk add --no-cache python3 python3-dev py3-pip git curl nginx >/dev/null
      # Alpine needs venv separately
      apk add --no-cache py3-virtualenv 2>/dev/null || true
      info "Installed via apk"
      ;;
    arch|manjaro)
      pacman -Sy --noconfirm python python-pip git curl nginx >/dev/null
      info "Installed via pacman"
      ;;
    macos)
      if ! command -v brew &>/dev/null; then
        error "Homebrew required for macOS. Install: https://brew.sh"
        exit 1
      fi
      brew install python3 git curl nginx >/dev/null
      info "Installed via Homebrew"
      ;;
    *)
      error "Unsupported OS: $OS_ID"
      error "Install manually: python3, python3-venv, git, curl, nginx"
      exit 1
      ;;
  esac

  # Verify python3
  if ! command -v python3 &>/dev/null; then
    error "python3 not found after install"
    exit 1
  fi
  PYVER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
  info "Python ${PYVER}"
}

# ── Create Service User ───────────────────────────────────────────
create_user() {
  if [[ "$DEV_MODE" -eq 1 ]]; then
    ECFS_USER="$(whoami)"
    info "Dev mode: running as $(whoami)"
    return
  fi
  
  if [[ "$OS_ID" == "macos" ]]; then
    ECFS_USER="$(whoami)"
    info "macOS: running as $(whoami)"
    return
  fi

  if id "$ECFS_USER" &>/dev/null; then
    info "User '$ECFS_USER' exists"
  else
    useradd --system --shell /bin/false --home-dir "$ECFS_INSTALL_DIR" "$ECFS_USER" 2>/dev/null || \
      adduser --system --shell /bin/false --home "$ECFS_INSTALL_DIR" "$ECFS_USER" 2>/dev/null
    info "Created user '$ECFS_USER'"
  fi
}

# ── Clone ECFS ────────────────────────────────────────────────────
clone_ecfs() {
  step "Cloning ECFS"
  
  if [[ -d "${ECFS_INSTALL_DIR}/.git" ]]; then
    warn "ECFS already cloned at ${ECFS_INSTALL_DIR}"
    cd "$ECFS_INSTALL_DIR"
    git pull --ff-only || warn "Pull failed, using existing code"
  else
    mkdir -p "$(dirname "$ECFS_INSTALL_DIR")"
    git clone --depth 1 --branch "$ECFS_BRANCH" "$ECFS_REPO" "$ECFS_INSTALL_DIR"
    cd "$ECFS_INSTALL_DIR"
    info "Cloned to ${ECFS_INSTALL_DIR}"
  fi
}

# ── Setup Virtualenv ──────────────────────────────────────────────
setup_venv() {
  step "Setting up virtual environment"
  
  cd "$ECFS_INSTALL_DIR"
  
  if [[ ! -d .venv ]]; then
    python3 -m venv .venv
    info "Created venv"
  fi
  
  source .venv/bin/activate
  pip install --quiet --upgrade pip
  pip install --quiet fastapi uvicorn httpx
  info "Installed Python packages"
}

# ── Generate Config ───────────────────────────────────────────────
generate_config() {
  step "Generating configuration"
  
  cd "$ECFS_INSTALL_DIR"
  
  # Generate admin key if not provided
  if [[ -z "$ECFS_ADMIN_KEY" ]]; then
    ECFS_ADMIN_KEY=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    info "Generated admin key"
  fi
  
  # Auto-detect public URL
  if [[ -z "$ECFS_PUBLIC_URL" ]]; then
    PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "")
    if [[ -n "$PUBLIC_IP" ]]; then
      ECFS_PUBLIC_URL="http://${PUBLIC_IP}:${ECFS_PORT}"
      info "Auto-detected public URL: ${ECFS_PUBLIC_URL}"
    else
      ECFS_PUBLIC_URL="http://localhost:${ECFS_PORT}"
      warn "Could not detect public IP, using localhost"
    fi
  fi
  
  # Generate relay auth token
  RELAY_AUTH=$(python3 -c "import secrets; print(secrets.token_hex(32))")
  
  # Write .env.ecfs-lite
  cat > .env.ecfs-lite << EOF
# ECFS Lite Configuration — generated by installer
ECFS_LITE_PORT=${ECFS_PORT}
ECFS_RELAY_URL=${ECFS_RELAY}
ECFS_LITE_KEYS=${ECFS_INSTALL_DIR}/ecfs-lite-keys.json
ECFS_LITE_STATE=${ECFS_INSTALL_DIR}/lite-state
ECFS_LITE_ADMIN_KEY=${ECFS_ADMIN_KEY}
ECFS_PUBLIC_URL=${ECFS_PUBLIC_URL}
ECFS_RELAY_AUTH=${RELAY_AUTH}
EOF

  chmod 600 .env.ecfs-lite
  info "Wrote .env.ecfs-lite"
  
  # Create state directory
  mkdir -p lite-state payments
  
  # Print admin key
  echo ""
  echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
  echo -e "${GREEN}  Admin Key (save this!):${NC}"
  echo -e "${GREEN}  ${ECFS_ADMIN_KEY}${NC}"
  echo -e "${GREEN}═══════════════════════════════════════════════${NC}"
  echo ""
}

# ── Install Systemd Service ───────────────────────────────────────
install_systemd() {
  if [[ "$DEV_MODE" -eq 1 ]]; then
    info "Dev mode: skipping systemd"
    return
  fi
  if [[ "$OS_ID" == "macos" ]]; then
    info "macOS: skipping systemd (use launchctl or run manually)"
    return
  fi
  
  step "Installing systemd service"
  
  cat > /etc/systemd/system/ecfs-lite.service << EOF
[Unit]
Description=ECFS Lite Gateway
After=network.target

[Service]
Type=simple
User=${ECFS_USER}
WorkingDirectory=${ECFS_INSTALL_DIR}
ExecStart=${ECFS_INSTALL_DIR}/.venv/bin/python3 ${ECFS_INSTALL_DIR}/ecfs-lite.py
Restart=always
RestartSec=5
Environment=PYTHONUNBUFFERED=1
EnvironmentFile=${ECFS_INSTALL_DIR}/.env.ecfs-lite

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=${ECFS_INSTALL_DIR}

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ecfs-lite 2>/dev/null || true
  info "Service installed and enabled"
}

# ── Install nginx Config ──────────────────────────────────────────
install_nginx_config() {
  if [[ "$INSTALL_NGINX" -ne 1 ]]; then return; fi
  
  step "Configuring nginx"
  
  if [[ "$OS_ID" == "macos" ]]; then
    warn "nginx config not auto-installed on macOS — configure manually"
    return
  fi
  
  cat > /etc/nginx/sites-available/ecfs-lite << EOF
server {
    listen 80;
    server_name ecfs.*;

    # Landing page
    location / {
        root ${ECFS_INSTALL_DIR}/landing;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # API proxy
    location /health {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/health;
    }
    location /status {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/status;
    }
    location /register {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/register;
    }
    location /send {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/send;
    }
    location /trial {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/trial;
    }
    location /pay {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/pay;
    }
    location /ipn {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/ipn;
    }
    location /peers {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/peers;
    }
    location /share/ {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/share/;
    }
    location /tasks/ {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/tasks/;
    }
    location /credits/ {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/credits/;
    }
    location /trust/ {
        proxy_pass http://127.0.0.1:${ECFS_PORT}/trust;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/ecfs-lite /etc/nginx/sites-enabled/ecfs-lite
  nginx -t 2>&1 && systemctl reload nginx 2>/dev/null || warn "nginx reload failed — check config"
  info "nginx configured"
}

# ── Install Cloudflare Tunnel ────────────────────────────────────
install_cloudflare() {
  if [[ "$INSTALL_CLOUDFLARE" -ne 1 ]]; then return; fi
  if [[ "$OS_ID" == "macos" ]]; then return; fi
  
  step "Setting up Cloudflare quick tunnel"
  
  if ! command -v cloudflared &>/dev/null; then
    # Install cloudflared
    case "$OS_ID" in
      ubuntu|debian|pop|linuxmint|zorin)
        curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -o /tmp/cloudflared.deb
        dpkg -i /tmp/cloudflared.deb 2>/dev/null || apt-get install -f -y -qq
        ;;
      centos|rhel|rocky|alma|fedora)
        curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.rpm -o /tmp/cloudflared.rpm
        rpm -i /tmp/cloudflared.rpm 2>/dev/null || dnf install -y /tmp/cloudflared.rpm
        ;;
      alpine)
        curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
        ;;
    esac
    info "Installed cloudflared"
  fi
  
  # Create systemd service for tunnel
  cat > /etc/systemd/system/ecfs-cloudflare.service << EOF
[Unit]
Description=ECFS Cloudflare Quick Tunnel
After=network.target ecfs-lite.service

[Service]
Type=simple
ExecStart=$(which cloudflared) tunnel --url http://127.0.0.1:${ECFS_PORT}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable ecfs-cloudflare 2>/dev/null || true
  info "Cloudflare tunnel service installed"
}

# ── Run E2E Test ──────────────────────────────────────────────────
run_test() {
  step "Running health check"
  
  if [[ "$DEV_MODE" -eq 1 ]]; then
    info "Dev mode: start manually with 'cd ${ECFS_INSTALL_DIR} && .venv/bin/python3 ecfs-lite.py'"
    return
  fi
  
  # Start the service
  systemctl start ecfs-lite 2>/dev/null || true
  sleep 2
  
  if curl -sf "http://127.0.0.1:${ECFS_PORT}/health" >/dev/null 2>&1; then
    HEALTH=$(curl -sf "http://127.0.0.1:${ECFS_PORT}/health" 2>/dev/null)
    info "Health check passed: ${HEALTH}"
  else
    warn "Service not responding yet — may need a moment to start"
  fi
}

# ── Summary ───────────────────────────────────────────────────────
print_summary() {
  step "Installation Complete"
  
  echo ""
  echo -e "  ${GREEN}Install Dir:${NC}   ${ECFS_INSTALL_DIR}"
  echo -e "  ${GREEN}Port:${NC}          ${ECFS_PORT}"
  echo -e "  ${GREEN}Relay:${NC}         ${ECFS_RELAY}"
  echo -e "  ${GREEN}Public URL:${NC}    ${ECFS_PUBLIC_URL}"
  echo -e "  ${GREEN}Admin Key:${NC}     ${ECFS_ADMIN_KEY}"
  echo -e "  ${GREEN}Service:${NC}       systemctl status ecfs-lite"
  echo -e "  ${GREEN}Logs:${NC}          journalctl -u ecfs-lite -f"
  echo ""
  
  if [[ "$DEV_MODE" -eq 1 ]]; then
    echo -e "  ${YELLOW}Dev mode — run manually:${NC}"
    echo -e "  cd ${ECFS_INSTALL_DIR}"
    echo -e "  source .venv/bin/activate"
    echo -e "  python3 ecfs-lite.py"
    echo ""
  fi
  
  echo -e "  ${CYAN}Quick test:${NC}"
  echo -e "  curl http://localhost:${ECFS_PORT}/health"
  echo ""
  echo -e "  ${CYAN}Create API key:${NC}"
  echo -e "  curl -X POST http://localhost:${ECFS_PORT}/admin/key/create \\"
  echo -e "    -H 'X-Admin-Key: ${ECFS_ADMIN_KEY}' \\"
  echo -e "    -H 'Content-Type: application/json' \\"
  echo -e "    -d '{\"name\":\"my-agent\",\"scopes\":[\"send\",\"compute\"]}'"
  echo ""
}

# ── Main ──────────────────────────────────────────────────────────
main() {
  echo -e "\n${CYAN}╔══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║    ECFS Lite Installer v1.0.0        ║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════╝${NC}\n"
  
  detect_os
  install_deps
  create_user
  clone_ecfs
  setup_venv
  generate_config
  install_systemd
  install_nginx_config
  install_cloudflare
  run_test
  print_summary
}

main "$@"
