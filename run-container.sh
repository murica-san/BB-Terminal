#!/usr/bin/env bash
# BBterminal — build + launch in a Podman pod (container auto-removes on stop).
# Persistent data (OpenBB settings + cache) survives in the named volume.

set -euo pipefail
cd "$(dirname "$0")"

AMBER="\033[33m"; GREEN="\033[32m"; RED="\033[31m"; DIM="\033[2m"; RST="\033[0m"
step() { printf "${AMBER}▸ %s${RST}\n" "$*"; }
ok()   { printf "${GREEN}✓ %s${RST}\n" "$*"; }
fail() { printf "${RED}✗ %s${RST}\n" "$*" >&2; exit 1; }

NAME="bbterminal"
POD="${NAME}-pod"
VOL="${NAME}-data"
UI_PORT=5173

# ── Build image if missing ────────────────────────────────
if ! podman image exists "localhost/${NAME}"; then
  step "Building image (first time or after changes)"
  podman build --security-opt seccomp=unconfined -t "${NAME}" .
  ok "Image built"
fi

# ── Volume ────────────────────────────────────────────────
if ! podman volume exists "${VOL}"; then
  step "Creating volume ${VOL}"
  podman volume create "${VOL}"
fi

# ── Clean up any previous pod ─────────────────────────────
if podman pod exists "${POD}"; then
  step "Removing old pod"
  podman pod rm -f "${POD}" >/dev/null
fi

# ── Launch ────────────────────────────────────────────────
step "Creating pod ${POD} (port ${UI_PORT})"
podman pod create --name "${POD}" -p "${UI_PORT}:${UI_PORT}"

step "Starting container (--rm = auto-removed when stopped)"
podman run -d --rm \
  --pod "${POD}" \
  --name "${NAME}" \
  -v "${VOL}:/root/.openbb_platform" \
  "localhost/${NAME}"

# ── Wait for readiness ────────────────────────────────────
printf "  ${DIM}waiting for BBterminal"
for i in $(seq 1 30); do
  if curl -s -o /dev/null "http://127.0.0.1:${UI_PORT}/" 2>/dev/null; then
    printf "${RST}\n"; ok "BBterminal is live"; break
  fi
  printf "."; sleep 1
  if [ "$i" = "30" ]; then
    printf "${RST}\n"
    fail "Timed out waiting for http://localhost:${UI_PORT}/"
  fi
done

# ── Open browser ──────────────────────────────────────────
URL="http://127.0.0.1:${UI_PORT}/"
if command -v open >/dev/null 2>&1; then open "$URL"
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$URL"
fi

cat <<EOF

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}
${AMBER}  BBterminal running in pod "${POD}"${RST}

  UI:         ${AMBER}${URL}${RST}
  Volume:     ${DIM}${VOL} → /root/.openbb_platform${RST}
  Container:  ${DIM}auto-removed on stop (--rm)${RST}

  Stop pod:   ${AMBER}podman pod stop ${POD}${RST}
  Delete:     ${AMBER}podman pod rm -f ${POD}${RST} && ${AMBER}podman volume rm ${VOL}${RST}
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RST}
EOF
