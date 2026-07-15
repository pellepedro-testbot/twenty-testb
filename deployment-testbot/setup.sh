#!/usr/bin/env bash
# Build the Twenty SUT FROM SOURCE and wait until healthy.
# Twenty facts (verified 2026-07-14):
#   Port: 2020 | Health: GET /healthz | Target: twenty-app-dev (all-in-one PG+Redis+server+front)
#
# The build is slow on a COLD cache (yarn+nx monorepo, frontend compiled from source,
# ~8GB peak, ~15-25 min). In GitHub Actions we layer-cache the expensive dependency stages
# via a docker-container buildx builder + the GHA cache backend (see docker-compose.ci.yml),
# which turns most reruns into a few minutes. Locally we build plainly (no gha backend).
set -euo pipefail
cd "$(dirname "$0")"

# Base compose always applies. In CI, overlay the GHA build cache and route the build
# through buildx bake (which honors cache_from/cache_to). The overlay is CI-only because
# `type=gha` needs the Actions cache tokens, which don't exist on a laptop.
COMPOSE=(-f docker-compose.yml)
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  COMPOSE+=(-f docker-compose.ci.yml)
  export COMPOSE_BAKE=true
  echo "==> CI detected: enabling buildx GHA layer cache (docker-compose.ci.yml)"
fi

echo "==> Building Twenty SUT from source + starting..."
docker compose "${COMPOSE[@]}" up -d --build

echo "==> Waiting for /healthz (DB migrate + workspace seed run on first boot)..."
# Generous window (240 * 5s = 20 min) so a cold uncached build+boot never trips setup itself;
# the action's targetReadyCheckTimeout is the outer gate.
for i in $(seq 1 240); do
  if curl -sf -m 3 http://localhost:2020/healthz >/dev/null 2>&1; then
    echo "==> SUT healthy"
    echo "==> Open http://localhost:2020  (prefilled login: tim@apple.dev)"
    exit 0
  fi
  sleep 5
  if [[ $i -eq 240 ]]; then
    echo "!! SUT failed to become healthy in time — recent logs:"
    docker compose "${COMPOSE[@]}" logs --tail 100
    exit 1
  fi
done
