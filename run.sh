#!/usr/bin/env bash
set -euo pipefail

PROGRAM_NAME="${JKS_PROGRAM_NAME:-$(basename "$0")}"
CONFIG_NAME="${JKS_CONFIG_NAME:-${PROGRAM_NAME%.*}}"
BRAND_NAME="JKSync"

APP_DIR="${JKS_APP_DIR:-${HOME}/.config/${CONFIG_NAME}}"
LOG_DIR="${JKS_LOG_DIR:-${APP_DIR}/logs}"
RUN_DIR="${JKS_RUN_DIR:-${APP_DIR}/run}"
QUEUE_FILE="${JKS_QUEUE_FILE:-queue}"
REMOTE="${JKS_REMOTE:-${1:-}}"

usage() {
  cat <<EOF
${BRAND_NAME} remote queue runner

Usage:
  ${PROGRAM_NAME} user@example.com

Environment overrides:
  JKS_REMOTE=user@example.com
  JKS_QUEUE_FILE=queue
  JKS_CONFIG_NAME=jksctl
EOF
}

if [ -z "${REMOTE}" ]; then
  usage
  exit 2
fi

if [ ! -f "${QUEUE_FILE}" ]; then
  echo "Queue file not found: ${QUEUE_FILE}"
  exit 1
fi

if [ ! -s "${QUEUE_FILE}" ]; then
  echo "Queue file is empty: ${QUEUE_FILE}"
  exit 1
fi

mkdir -p "${LOG_DIR}" "${RUN_DIR}"

TS="$(date '+%Y.%m.%dT%H-%M-%S')"
QUEUE_BASENAME="$(basename "${QUEUE_FILE}")"
LOG_FILE="${LOG_DIR}/${TS}.remote.log"
ARCHIVE_FILE="${LOG_DIR}/${TS}.${QUEUE_BASENAME}"
RUN_PAYLOAD="${RUN_DIR}/${TS}.${QUEUE_BASENAME}"

cp "${QUEUE_FILE}" "${RUN_PAYLOAD}"

{
  echo "=== ${BRAND_NAME} remote run ==="
  echo "Date: $(date)"
  echo "Program: ${PROGRAM_NAME}"
  echo "Config: ${CONFIG_NAME}"
  echo "Remote: ${REMOTE}"
  echo "Queue file: ${QUEUE_FILE}"
  echo "Log file: ${LOG_FILE}"
  echo

  echo "=== Queue content ==="
  cat "${RUN_PAYLOAD}"
  echo

  echo "=== Remote output ==="

  ssh "${REMOTE}" 'bash -se' <<EOF
set -euo pipefail

$(cat "${RUN_PAYLOAD}")
EOF

  echo
  echo "=== Completed ==="
  echo "Exit code: 0"
} 2>&1 | tee "${LOG_FILE}"

EXIT_CODE=${PIPESTATUS[0]}

cp "${RUN_PAYLOAD}" "${ARCHIVE_FILE}"
rm -f "${RUN_PAYLOAD}"

if [ "${EXIT_CODE}" -eq 0 ]; then
  : > "${QUEUE_FILE}"
else
  {
    echo
    echo "=== Failed ==="
    echo "Exit code: ${EXIT_CODE}"
    echo "Queue was not cleared."
  } | tee -a "${LOG_FILE}"

  exit "${EXIT_CODE}"
fi

echo "Saved log: ${LOG_FILE}"
echo "Archived queue: ${ARCHIVE_FILE}"
