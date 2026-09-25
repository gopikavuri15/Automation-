#!/usr/bin/env bash
set -euo pipefail

source_dir="$(realpath "${1:-}")"
install_root="${APP_INSTALL_ROOT:-/opt/devops-monitoring}"
releases_dir="$install_root/releases"
release_id="$(date -u +%Y%m%dT%H%M%SZ)-${BUILD_NUMBER:-manual}-$$"
release_dir="$releases_dir/$release_id"

if [[ ! -f "$source_dir/dist/server.js" || ! -f "$source_dir/dist/public/index.html" ]]; then
  echo 'Built application not found. Run npm run build before deployment.' >&2
  exit 1
fi

mkdir -p "$releases_dir"
mkdir "$release_dir"
cp -a "$source_dir/dist/." "$release_dir/"
ln -sfn "$release_dir" "$install_root/current.next"
mv -Tf "$install_root/current.next" "$install_root/current"

sudo systemctl restart devops-app.service
bash "$(dirname "${BASH_SOURCE[0]}")/health-check.sh" "${APP_HEALTH_URL:-http://127.0.0.1/health}"
printf 'Deployed release %s\n' "$release_id"