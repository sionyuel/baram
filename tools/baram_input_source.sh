#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_BUILD_DIR="${SCRIPT_DIR}/../build/baram/Tools"
HELPER="${TOOLS_BUILD_DIR}/baram-input-source"
STATE_FILE="${TOOLS_BUILD_DIR}/previous-input-source.json"
MODE="${1:---help}"

case "$MODE" in
    --help)
        echo "Usage: $0 list|current|enable layout|activate layout|select layout|restore"
        echo "Example: $0 select han3final"
        echo "select saves the current source; restore selects it again."
        exit 0
        ;;
    list|current|restore)
        if [[ $# -ne 1 ]]; then echo "Unexpected argument." >&2; exit 2; fi
        ;;
    enable|activate|select)
        if [[ $# -ne 2 ]]; then echo "Specify a Baram layout suffix." >&2; exit 2; fi
        ;;
    *) echo "Unknown command: $MODE" >&2; exit 2 ;;
esac

mkdir -p "$TOOLS_BUILD_DIR"
if [[ ! -x "$HELPER" || "${SCRIPT_DIR}/baram_input_source.swift" -nt "$HELPER" ]]; then
    xcrun swiftc "${SCRIPT_DIR}/baram_input_source.swift" -o "$HELPER"
fi

case "$MODE" in
    select) exec "$HELPER" select "$2" "$STATE_FILE" ;;
    restore) exec "$HELPER" restore "$STATE_FILE" ;;
    *) exec "$HELPER" "$@" ;;
esac
