#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY_SCRIPT="$SCRIPT_DIR/enable_littlefs.py"

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    python3 "$PY_SCRIPT" --help
    exit 0
fi

if [ -z "$1" ]; then
    echo "❌ Missing project path."
    python3 "$PY_SCRIPT" --help
    exit 1
fi

PROJECT_PATH="$1"
CONFIG_FILE="$2"

# Execute the Python logic
if [ -z "$CONFIG_FILE" ]; then
    python3 "$PY_SCRIPT" "$PROJECT_PATH"
else
    python3 "$PY_SCRIPT" "$PROJECT_PATH" "$CONFIG_FILE"
fi
