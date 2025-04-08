#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CONFIG="${SCRIPT_DIR}/config.ini"
BASE_TEMPLATE="${SCRIPT_DIR}/tasks.base.template.json"
PARTITION_TEMPLATE="${SCRIPT_DIR}/task.partition.template.json"

show_help() {
    echo "Usage: $0 /path/to/project [config_file.ini]"
    echo ""
    echo "This script automatically generates a tasks.json file and adds LittleFS support to your CMakeLists.txt."
    echo ""
    echo "Arguments:"
    echo "  /path/to/project         Path to the ESP-IDF project"
    echo "  [config_file.ini]        (Optional) Path to the .ini configuration file"
    echo ""
    echo "If no second argument is given, it defaults to 'config.ini' located in the same folder as this script."
    exit 0
}

# Show help
[[ "$1" == "--help" || "$1" == "-h" ]] && show_help

# Argument validation
if [ -z "$1" ]; then
    echo "❌ Missing project path."
    show_help
fi

PROJECT_DIR="$(cd "$1" && pwd)"
CONFIG_FILE="${2:-$DEFAULT_CONFIG}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

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

PLATFORM=$(parse_ini "LittleFS" "platform")
RAW_EXPORT_SCRIPT=$(parse_ini "LittleFS" "export_script")

if [[ "$PLATFORM" == "windows" ]]; then
    EXPORT_SCRIPT_ESCAPED=$(echo "$RAW_EXPORT_SCRIPT" | sed 's/\\\\/\\\\\\\\/g')
    EXPORT_SCRIPT="'$EXPORT_SCRIPT_ESCAPED'"
    SHELL_CMD="powershell"
    PORT_VAR="\${config:idf.portWin}"
else
    EXPORT_SCRIPT="'$RAW_EXPORT_SCRIPT'"
    SHELL_CMD="bash"
    PORT_VAR="\${config:idf.port}"
fi

echo "📍 Project: $PROJECT_DIR"
echo "📄 Config: $CONFIG_FILE"
echo "🧠 Platform: $PLATFORM"
echo "🔗 Export script: $EXPORT_SCRIPT"
echo "💻 Shell: $SHELL_CMD"
echo ""

mkdir -p "$VSCODE_DIR"

ALL_TASKS=()
BASE_CONTENT=$(sed -e "s|__EXPORT_SCRIPT__|$EXPORT_SCRIPT|g" \
                   -e "s|__PORT__|$PORT_VAR|g" \
                   -e "s|__SHELL__|$SHELL_CMD|g" \
                   "$BASE_TEMPLATE")
BASE_CONTENT=$(echo "$BASE_CONTENT" | sed '1d;$d')
ALL_TASKS+=("$BASE_CONTENT")

PARTITION_LINES=""

for section in $(awk '/^\[LittleFS_/{gsub(/\[|\]/, "", $0); print $0}' "$CONFIG_FILE"); do
    PARTITION_LABEL=$(parse_ini "$section" "partition_label")
    PARTITION_DIR=$(parse_ini "$section" "partition_dir")
    TAG=$(parse_ini "$section" "tag")
    PARTITION_PATH="${PROJECT_DIR}/${PARTITION_DIR}"

    echo "📦 Partition [$section]: $PARTITION_LABEL → $PARTITION_PATH"

    if [ ! -d "$PARTITION_PATH" ]; then
        echo "📁 Creating folder: $PARTITION_DIR/"
        mkdir -p "$PARTITION_PATH"
        echo "# Files to LittleFS" > "${PARTITION_PATH}/README.txt"
    else
        echo "📁 Folder ${PARTITION_DIR}/ already exists."
    fi

    PARTITION_TASK=$(sed -e "s|__PORT__|$PORT_VAR|g" \
                         -e "s|__PARTITION_LABEL__|$PARTITION_LABEL|g" \
                         -e "s|__EXPORT_SCRIPT__|$EXPORT_SCRIPT|g" \
                         -e "s|__SHELL__|$SHELL_CMD|g" \
                         -e "s|__TAG__|$TAG|g" \
                         "$PARTITION_TEMPLATE")
    ALL_TASKS+=("$PARTITION_TASK")

    PARTITION_LINES="${PARTITION_LINES}    littlefs_create_partition_image(${PARTITION_LABEL} \"${PARTITION_DIR}\" FLASH_AS_IMAGE)\\n"
done

# Write final JSON
{
  echo "{"
  echo "  \"version\": \"2.0.0\","
  echo "  \"tasks\": ["
  IFS=$'\\n'
  echo "${ALL_TASKS[*]}" | paste -sd "," -
  echo "  ]"
  echo "}"
} > "$TASKS_PATH"

# Update CMakeLists.txt if needed
if grep -q "littlefs_create_partition_image" "$CMAKE_FILE"; then
    echo "✅ CMakeLists.txt already contains LittleFS configuration."
else
    echo "➕ Adding LittleFS support to CMakeLists.txt"
    {
        echo ""
        echo "# Support to LittleFS"
        echo "if(DEFINED ENV{LFS_BUILD} AND \"$ENV{LFS_BUILD}\" STREQUAL \"1\")"
        echo -e "$PARTITION_LINES"
        echo "endif()"
    } >> "$CMAKE_FILE"
fi

echo "✅ Done! tasks.json successfully generated."
