#!/usr/bin/env bash
# ECFS Lite Uninstaller — clean removal of all installed components
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }

INSTALL_DIR="${1:-/opt/ecfs}"

echo -e "\n${RED}══ ECFS Lite Uninstaller ══${NC}\n"
echo "This will remove:"
echo "  - systemd service (ecfs-lite)"
echo "  - Cloudflare tunnel (ecfs-cloudflare)"
echo "  - nginx config (ecfs-lite)"
echo "  - Installation directory: ${INSTALL_DIR}"
echo ""

read -p "Continue? [y/N] " confirm
if [[ "${confirm,,}" != "y" ]]; then
  echo "Aborted."
  exit 0
fi

# Stop and disable services
for svc in ecfs-lite ecfs-cloudflare; do
  if systemctl is-active "$svc" &>/dev/null; then
    systemctl stop "$svc"
    info "Stopped $svc"
  fi
  if systemctl is-enabled "$svc" &>/dev/null; then
    systemctl disable "$svc" 2>/dev/null || true
    info "Disabled $svc"
  fi
  rm -f "/etc/systemd/system/${svc}.service"
done
systemctl daemon-reload 2>/dev/null || true

# Remove nginx config
if [[ -f /etc/nginx/sites-available/ecfs-lite ]]; then
  rm -f /etc/nginx/sites-available/ecfs-lite
  rm -f /etc/nginx/sites-enabled/ecfs-lite
  nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
  info "Removed nginx config"
fi

# Remove installation directory
if [[ -d "$INSTALL_DIR" ]]; then
  rm -rf "$INSTALL_DIR"
  info "Removed ${INSTALL_DIR}"
fi

# Optionally remove the ecfs user
if id ecfs &>/dev/null && [[ "$(id -u ecfs)" -ge 999 ]]; then
  userdel ecfs 2>/dev/null || true
  info "Removed ecfs user"
fi

echo -e "\n${GREEN}ECFS Lite uninstalled.${NC}\n"
