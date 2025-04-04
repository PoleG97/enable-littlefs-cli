#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.ini"
TEMPLATE_FILE="${SCRIPT_DIR}/tasks.template.json"

if [ -z "$1" ]; then
    echo "❌ Uso: $0 /ruta/al/proyecto"
    exit 1
fi

PROJECT_DIR="$(cd "$1" && pwd)"
CMAKE_FILE="${PROJECT_DIR}/CMakeLists.txt"
VSCODE_DIR="${PROJECT_DIR}/.vscode"
TASKS_PATH="${VSCODE_DIR}/tasks.json"

parse_ini() {
    local section="$1"
    local key="$2"
    awk -F '=' -v section="$section" -v key="$key" '
        BEGIN { in_section=0 }
        $0 ~ "^[[:space:]]*\\[" section "\\][[:space:]]*$" { in_section=1; next }
        in_section && $1 ~ "^[[:space:]]*"key"[[:space:]]*$" {
            gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit
        }
    ' "$CONFIG_FILE"
}

PARTITION_LABEL=$(parse_ini "LittleFS" "partition_label")
PARTITION_DIR=$(parse_ini "LittleFS" "partition_dir")
PLATFORM=$(parse_ini "LittleFS" "platform")
RAW_EXPORT_SCRIPT=$(parse_ini "LittleFS" "export_script")
if [[ "$PLATFORM" == "windows" ]]; then
    EXPORT_SCRIPT_ESCAPED=$(echo "$RAW_EXPORT_SCRIPT" | sed 's/\\/\\\\/g')
    EXPORT_SCRIPT="'$EXPORT_SCRIPT_ESCAPED'"
else
    EXPORT_SCRIPT="'$RAW_EXPORT_SCRIPT'"
fi



if [[ -z "$PARTITION_LABEL" || -z "$PARTITION_DIR" || -z "$PLATFORM" || -z "$EXPORT_SCRIPT" ]]; then
    echo "❌ Error: Missing values in config.ini"
    exit 1
fi

PORT_VAR="\${config:idf.port}"
[[ "$PLATFORM" == "windows" ]] && PORT_VAR="\${config:idf.portWin}"

PARTITION_PATH="${PROJECT_DIR}/${PARTITION_DIR}"

echo "📍 Proyect: $PROJECT_DIR"
echo "📦 Partition: $PARTITION_LABEL → $PARTITION_PATH"
echo "🧠 Platform: $PLATFORM"
echo "🔗 Export script: $EXPORT_SCRIPT"
echo ""

if [ ! -d "$PARTITION_PATH" ]; then
    echo "📁 Creating folder: $PARTITION_DIR/"
    mkdir -p "$PARTITION_PATH"
    echo "# Files to LittleFS" > "${PARTITION_PATH}/README.txt"
else
    echo "📁 Folder ${PARTITION_DIR}/ exists."
fi

mkdir -p "$VSCODE_DIR"

if [ ! -f "$TASKS_PATH" ]; then
    echo "🧠 Generating VSCode tasks from template..."
    sed \
      -e "s|__PORT__|$PORT_VAR|g" \
      -e "s|__PARTITION_LABEL__|$PARTITION_LABEL|g" \
      -e "s|__EXPORT_SCRIPT__|$EXPORT_SCRIPT|g" \
      "$TEMPLATE_FILE" > "$TASKS_PATH"
else
    echo "ℹ️ Tasks exists. Are not overwritten."
fi

if grep -q "littlefs_create_partition_image(${PARTITION_LABEL}" "$CMAKE_FILE"; then
    echo "✅ CMakeLists.txt contents LittleFS instructions yet."
else
    echo "➕ Adding LittleFS support to CMakeLists.txt"
    echo -e "\n# Support to LittleFS\nif (DEFINED ENV{LFS_BUILD})\n    littlefs_create_partition_image(${PARTITION_LABEL} \"${PARTITION_DIR}\" FLASH_IN_PROJECT)\nendif()" >> "$CMAKE_FILE"
fi

echo "✅ Completed! Now you can use the tasks in VSCode."
