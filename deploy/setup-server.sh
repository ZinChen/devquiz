#!/usr/bin/env bash
# First-time setup for a fresh Ubuntu 24.04 VDS hosting devquiz.
# Run once, as root, on the new server:
#   bash setup-server.sh <deploy-user>
#
# It is idempotent: re-running is safe.

set -euo pipefail

DEPLOY_USER="${1:-deploy}"
APP_DIR="/opt/devquiz"
REPO_URL="https://github.com/ZinChen/devquiz.git"
ENV_CREATED=no

if [[ $EUID -ne 0 ]]; then
  echo "Run as root." >&2
  exit 1
fi

echo "==> Updating packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq

echo "==> Installing base tools"
apt-get install -y -qq ca-certificates curl git gnupg ufw fail2ban unattended-upgrades

echo "==> Creating deploy user: ${DEPLOY_USER}"
if ! id -u "${DEPLOY_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${DEPLOY_USER}"
fi
usermod -aG sudo "${DEPLOY_USER}"

# The account has no password (login is key-only), so `sudo` would otherwise
# demand one that can never be entered. Key possession is already the sole
# factor for reaching this account, so a second factor here adds no security.
echo "${DEPLOY_USER} ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${DEPLOY_USER}"
chmod 440 "/etc/sudoers.d/90-${DEPLOY_USER}"
visudo -cf "/etc/sudoers.d/90-${DEPLOY_USER}" >/dev/null

# Carry root's authorized_keys over so you are not locked out.
if [[ -f /root/.ssh/authorized_keys ]]; then
  install -d -m 700 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "/home/${DEPLOY_USER}/.ssh"
  install -m 600 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" \
    /root/.ssh/authorized_keys "/home/${DEPLOY_USER}/.ssh/authorized_keys"
fi

echo "==> Hardening SSH (key-only, no root login)"
cat > /etc/ssh/sshd_config.d/99-devquiz.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
EOF
# Ubuntu 24.04 ships socket-activated ssh; restarting both covers either unit name.
systemctl restart ssh 2>/dev/null || systemctl restart sshd

echo "==> Firewall: allow 22/80/443 only"
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo "==> Enabling unattended security upgrades"
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "==> Adding 4G swap (2 GB RAM is tight for Postgres + Puma)"
if [[ ! -f /swapfile ]]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  # Prefer RAM; use swap only under real pressure.
  sysctl -w vm.swappiness=10
  echo 'vm.swappiness=10' > /etc/sysctl.d/99-swappiness.conf
fi

echo "==> Installing Docker from the official repository"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
fi
usermod -aG docker "${DEPLOY_USER}"
systemctl enable --now docker

echo "==> Preparing ${APP_DIR}"
# Layout: the git clone holds tracked config and can be reset at will; .env and
# backups live beside it, never inside, so a hard reset cannot destroy them.
#   /opt/devquiz/repo/   -> git clone, refreshed by CI from main
#   /opt/devquiz/.env    -> secrets, chmod 600, never in git
#   /opt/devquiz/backups -> nightly dumps
install -d -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${APP_DIR}"
install -d -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${APP_DIR}/backups"

echo "==> Cloning the repository"
if [[ ! -d "${APP_DIR}/repo/.git" ]]; then
  sudo -u "${DEPLOY_USER}" git clone --quiet "${REPO_URL}" "${APP_DIR}/repo"
else
  sudo -u "${DEPLOY_USER}" git -C "${APP_DIR}/repo" pull --ff-only --quiet
fi
chmod +x "${APP_DIR}/repo/deploy/init-db/"*.sh

echo "==> Installing the ./dc compose wrapper"
install -m 0755 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" \
  "${APP_DIR}/repo/deploy/dc" "${APP_DIR}/dc"

# Create .env from the template on first run, with tight permissions.
if [[ ! -f "${APP_DIR}/.env" ]]; then
  install -m 600 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" \
    "${APP_DIR}/repo/deploy/env.example" "${APP_DIR}/.env"
  ENV_CREATED=yes
fi

echo "==> Installing nightly database backup (14-day retention)"
# pg_dumpall captures both databases and the roles in one file.
cat > "${APP_DIR}/backup.sh" <<'BACKUP'
#!/usr/bin/env bash
set -euo pipefail
cd /opt/devquiz
# shellcheck disable=SC1091
source .env
stamp="$(date +%F)"
./dc exec -T db pg_dumpall -U "${POSTGRES_USER}" \
  | gzip > "backups/devquiz-${stamp}.sql.gz"
find backups -name '*.sql.gz' -mtime +14 -delete
BACKUP
chmod 0750 "${APP_DIR}/backup.sh"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${APP_DIR}/backup.sh"

cat > /etc/cron.d/devquiz-backup <<EOF
17 3 * * * ${DEPLOY_USER} ${APP_DIR}/backup.sh >>${APP_DIR}/backups/backup.log 2>&1
EOF
chmod 0644 /etc/cron.d/devquiz-backup

echo "==> Installing weekly docker image cleanup"
cat > /etc/cron.d/devquiz-prune <<EOF
# Reclaim disk from superseded images; 25 GB fills up otherwise.
41 4 * * 0 ${DEPLOY_USER} docker system prune -af --filter 'until=168h' >/dev/null 2>&1
EOF
chmod 0644 /etc/cron.d/devquiz-prune

cat <<EOF

==> Done.

Repository cloned to ${APP_DIR}/repo
Compose wrapper installed at ${APP_DIR}/dc
$(if [[ "${ENV_CREATED}" == "yes" ]]; then
    echo ".env created from the template — IT STILL HAS EMPTY VALUES."
  else
    echo ".env already existed and was left untouched."
  fi)

Next, as ${DEPLOY_USER}:

  1. Fill in the secrets:
       nano ${APP_DIR}/.env
     Generate them with:
       openssl rand -hex 32   # POSTGRES_PASSWORD, DEV_DB_PASSWORD
       openssl rand -hex 64   # SECRET_KEY_BASE and DEV_SECRET_KEY_BASE (must differ)

  2. Confirm both hostnames already resolve here, or Caddy cannot get a cert:
       dig +short devquiz.zinchenlab.ru
       dig +short dev.devquiz.zinchenlab.ru

  3. Start everything:
       cd ${APP_DIR} && ./dc up -d

     The app images come from ghcr and only exist after CI has run at least
     once on main (and on dev, for the staging service).

Day-to-day, ./dc is docker compose with the right flags:
    ./dc ps · ./dc logs -f caddy · ./dc exec app ./bin/rails console

Log in again before using docker: group membership applies to new sessions only.

Backups land in ${APP_DIR}/backups — on the same disk as the database, so copy
them off this box as well (rclone to object storage, or scp from home).
EOF
