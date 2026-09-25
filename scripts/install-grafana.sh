#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo 'Run this script with sudo.' >&2
  exit 1
fi

apt-get update
apt-get install -y ca-certificates curl gnupg
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://apt.grafana.com/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg
chmod 0644 /etc/apt/keyrings/grafana.gpg
printf 'deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main\n' > /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y grafana

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install -d -o root -g grafana -m 0750 /etc/grafana/provisioning/datasources /etc/grafana/provisioning/dashboards /var/lib/grafana/dashboards
install -m 0640 -o root -g grafana "$repo_root/config/grafana/provisioning/datasources/prometheus.yml" /etc/grafana/provisioning/datasources/prometheus.yml
install -m 0640 -o root -g grafana "$repo_root/config/grafana/provisioning/dashboards/dashboard.yml" /etc/grafana/provisioning/dashboards/devops-dashboard.yml
install -m 0640 -o root -g grafana "$repo_root/config/grafana/dashboards/node-exporter.json" /var/lib/grafana/dashboards/node-exporter.json
systemctl enable --now grafana-server
systemctl --no-pager --full status grafana-server