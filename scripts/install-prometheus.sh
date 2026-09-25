#!/usr/bin/env bash
set -euo pipefail

version="2.54.1"
architecture="$(dpkg --print-architecture)"
case "$architecture" in
  amd64) archive_arch='amd64' ;;
  arm64) archive_arch='arm64' ;;
  *) echo "Unsupported architecture: $architecture" >&2; exit 1 ;;
esac

if [[ "$(id -u)" -ne 0 ]]; then
  echo 'Run this script with sudo.' >&2
  exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
archive="prometheus-${version}.linux-${archive_arch}.tar.gz"
curl -fsSLo "$work_dir/$archive" "https://github.com/prometheus/prometheus/releases/download/v${version}/${archive}"
tar -xzf "$work_dir/$archive" -C "$work_dir"

if ! id prometheus >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin prometheus
fi
install -d -o prometheus -g prometheus -m 0755 /etc/prometheus /var/lib/prometheus
install -m 0755 "$work_dir/prometheus-${version}.linux-${archive_arch}/prometheus" /usr/local/bin/prometheus
install -m 0755 "$work_dir/prometheus-${version}.linux-${archive_arch}/promtool" /usr/local/bin/promtool
install -m 0644 "$(dirname "${BASH_SOURCE[0]}")/../config/prometheus/prometheus.yml" /etc/prometheus/prometheus.yml
chown prometheus:prometheus /etc/prometheus/prometheus.yml
install -m 0644 "$(dirname "${BASH_SOURCE[0]}")/../config/systemd/prometheus.service" /etc/systemd/system/prometheus.service
/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml
systemctl daemon-reload
systemctl enable --now prometheus
systemctl --no-pager --full status prometheus