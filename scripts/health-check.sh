#!/usr/bin/env bash
set -euo pipefail

url="${1:-http://127.0.0.1/health}"
attempts="${HEALTH_CHECK_ATTEMPTS:-15}"
delay="${HEALTH_CHECK_DELAY:-2}"

for ((attempt = 1; attempt <= attempts; attempt++)); do
  if curl --fail --silent --show-error --max-time 3 "$url" >/dev/null; then
    printf 'Health check passed: %s\n' "$url"
    exit 0
  fi
  if (( attempt < attempts )); then
    sleep "$delay"
  fi
done

printf 'Health check failed after %s attempts: %s\n' "$attempts" "$url" >&2
exit 1