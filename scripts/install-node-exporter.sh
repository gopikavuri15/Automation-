#!/usr/bin/env bash
set -euo pipefail

version="1.8.2"
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
archive="node_exporter-${version}.linux-${archive_arch}.tar.gz"
curl -fsSLo "$work_dir/$archive" "https://github.com/prometheus/node_exporter/releases/download/v${version}/${archive}"
tar -xzf "$work_dir/$archive" -C "$work_dir"

if ! id node_exporter >/dev/null 2>&1; then
  useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter
fi
install -m 0755 "$work_dir/node_exporter-${version}.linux-${archive_arch}/node_exporter" /usr/local/bin/node_exporter
install -m 0644 "$(dirname "${BASH_SOURCE[0]}")/../config/systemd/node-exporter.service" /etc/systemd/system/node-exporter.service
systemctl daemon-reload
systemctl enable --now node-exporter
systemctl --no-pager --full status node-exporter