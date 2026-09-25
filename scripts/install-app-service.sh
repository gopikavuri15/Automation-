#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo 'Run this script with sudo.' >&2
  exit 1
fi

if ! id jenkins >/dev/null 2>&1; then
  echo 'Install Jenkins before configuring the application service.' >&2
  exit 1
fi

if ! id devopsapp >/dev/null 2>&1; then
  useradd --system --home-dir /opt/devops-monitoring --shell /usr/sbin/nologin devopsapp
fi

install -d -o jenkins -g devopsapp -m 2755 /opt/devops-monitoring /opt/devops-monitoring/releases
install -m 0644 "$(dirname "${BASH_SOURCE[0]}")/../config/systemd/devops-app.service" /etc/systemd/system/devops-app.service
systemctl daemon-reload
systemctl enable devops-app.service