#!/usr/bin/env bash
# Build the Twenty SUT FROM SOURCE and wait until healthy.
# Twenty facts (verified 2026-07-14):
#   Port: 2020 | Health: GET /healthz | Target: twenty-app-dev (all-in-one PG+Redis+server+front)
# NOTE: the first build is slow — yarn+nx monorepo with the frontend compiled from source
#       (nx build twenty-front, ~8GB peak). Expect ~10-25 min on a cold cache.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Building Twenty SUT from source + starting (first build is slow)..."
docker compose -f docker-compose.yml up -d --build

echo "==> Waiting for /healthz (DB migrate + workspace seed run on first boot)..."
for i in $(seq 1 120); do
  if curl -sf -m 3 http://localhost:2020/healthz >/dev/null 2>&1; then
    echo "==> SUT healthy"
    echo "==> Open http://localhost:2020  (prefilled login: tim@apple.dev)"
    exit 0
  fi
  sleep 5
  if [[ $i -eq 120 ]]; then
    echo "!! SUT failed to become healthy in time — recent logs:"
    docker compose -f docker-compose.yml logs --tail 100
    exit 1
  fi
done
