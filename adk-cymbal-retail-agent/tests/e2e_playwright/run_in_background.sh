#!/usr/bin/env bash
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Launches `provision_and_run_e2e.py` completely detached in its own OS session
# (`nohup setsid ... </dev/null & disown`) so closing Jetski, switching tabs,
# or disconnecting from SSH/CRD will NEVER kill the Playwright E2E run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QL_PORT=9222
QL_PROFILE_DIR="${HOME}/.config/qwiklabs-chrome-profile"
DEFAULT_LAB_URL="https://gcpstaging.qwiklabs.com/labs/663130"

if [[ "${1:-}" == "--init-qwiklabs-browser" ]]; then
  mkdir -p "${QL_PROFILE_DIR}"
  if curl -s "http://127.0.0.1:${QL_PORT}/json/version" >/dev/null 2>&1; then
    echo "[INFO] Qwiklabs Chrome is already listening on http://127.0.0.1:${QL_PORT}"
    exit 0
  fi
  rm -f "${QL_PROFILE_DIR}/SingletonLock" "${QL_PROFILE_DIR}/SingletonCookie" "${QL_PROFILE_DIR}/SingletonSocket"
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
  export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
  export DISPLAY="${DISPLAY:-:0}"

  if systemctl --user status >/dev/null 2>&1; then
    systemd-run --user --unit="qwiklabs-chrome-${QL_PORT}" --collect \
      --setenv="XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
      --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY}" \
      --setenv="DISPLAY=${DISPLAY}" \
      /usr/bin/google-chrome \
      --user-data-dir="${QL_PROFILE_DIR}" \
      --remote-debugging-address=127.0.0.1 \
      --remote-debugging-port="${QL_PORT}" \
      --disable-background-timer-throttling \
      --disable-backgrounding-occluded-windows \
      --disable-renderer-backgrounding \
      --no-first-run \
      --no-default-browser-check \
      "${DEFAULT_LAB_URL}"
  else
    nohup setsid /usr/bin/google-chrome \
      --user-data-dir="${QL_PROFILE_DIR}" \
      --remote-debugging-address=127.0.0.1 \
      --remote-debugging-port="${QL_PORT}" \
      --disable-background-timer-throttling \
      --disable-backgrounding-occluded-windows \
      --disable-renderer-backgrounding \
      --no-first-run \
      --no-default-browser-check \
      "${DEFAULT_LAB_URL}" </dev/null >/tmp/qwiklabs_chrome_9222.log 2>&1 &
    disown || true
  fi
  echo "[SUCCESS] Launched persistent Qwiklabs Chrome on port ${QL_PORT} (Profile: ${QL_PROFILE_DIR})."
  echo "Log in once via Chrome Remote Desktop, and all future runs will auto-start Lab 663130 and scrape the password off the screen!"
  exit 0
fi

if [[ "${1:-}" == "--status" ]]; then
  if [[ -f /tmp/enbl080_e2e_latest.pid ]]; then
    PID=$(cat /tmp/enbl080_e2e_latest.pid)
    if ps -p "${PID}" >/dev/null 2>&1; then
      echo "[RUNNING] Background E2E process is ACTIVE (PID: ${PID})"
    else
      echo "[FINISHED] Background E2E process (PID: ${PID}) has exited."
    fi
  else
    echo "[INFO] No PID file found at /tmp/enbl080_e2e_latest.pid"
  fi
  echo "=== Recent Log Output (/tmp/enbl080_e2e_latest.log) ==="
  tail -n 35 /tmp/enbl080_e2e_latest.log 2>/dev/null || true
  exit 0
fi

TIMESTAMP="$(date -u +%Y%m%d_%H%M%S)"
LOG_FILE="/tmp/enbl080_e2e_${TIMESTAMP}.log"
OUT_DIR="${SCRIPT_DIR}/artifacts_e2e_${TIMESTAMP}"
UNIT_NAME="enbl080-e2e-${TIMESTAMP}"

export PATH="${HOME}/.local/bin:${PATH}"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export DISPLAY="${DISPLAY:-:0}"

# Build properly escaped argument string for the inner runner
RUNNER_CMD=(
  uv run --with playwright --with websockets python3 -u
  "${SCRIPT_DIR}/provision_and_run_e2e.py"
  --output-dir "${OUT_DIR}"
  "$@"
)

# Launch in user's systemd slice (or tmux session) so it escapes any agent/IDE subreaper cgroup
if systemctl --user status >/dev/null 2>&1; then
  systemd-run --user --unit="${UNIT_NAME}" --collect \
    --setenv="PATH=${PATH}" \
    --setenv="HOME=${HOME}" \
    --setenv="XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR}" \
    --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY}" \
    --setenv="DISPLAY=${DISPLAY}" \
    /bin/bash -c 'exec "$@" >>"'"${LOG_FILE}"'" 2>&1' _ "${RUNNER_CMD[@]}"
  sleep 1
  BG_PID=$(systemctl --user show --property MainPID --value "${UNIT_NAME}.service" 2>/dev/null || echo "0")
else
  nohup setsid "${RUNNER_CMD[@]}" </dev/null >"${LOG_FILE}" 2>&1 &
  BG_PID=$!
  disown "${BG_PID}" 2>/dev/null || true
fi

ln -sf "${LOG_FILE}" /tmp/enbl080_e2e_latest.log
echo "${BG_PID}" >/tmp/enbl080_e2e_latest.pid
echo "${UNIT_NAME}" >/tmp/enbl080_e2e_latest.unit

echo "========================================================================"
echo "✅ Launched Detached Background Playwright E2E Suite!"
echo "   Systemd Unit:   ${UNIT_NAME}.service"
echo "   PID:            ${BG_PID} (saved to /tmp/enbl080_e2e_latest.pid)"
echo "   Live Log:       ${LOG_FILE} (symlinked to /tmp/enbl080_e2e_latest.log)"
echo "   Artifacts Dir:  ${OUT_DIR}"
echo ""
echo "You can safely close Jetski or walk away — this process runs in your"
echo "OS systemd --user slice and will NOT be killed when your session closes."
echo ""
echo "Check progress anytime with:"
echo "  ${SCRIPT_DIR}/run_in_background.sh --status"
echo "  tail -f /tmp/enbl080_e2e_latest.log"
echo "========================================================================"
