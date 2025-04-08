#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_TEMPLATE="${SCRIPT_DIR}/tasks.base.template.json"
PARTITION_TEMPLATE="${SCRIPT_DIR}/task.partition.template.json"

# Help
show_help() {
    echo "Usage: $0 /path/to/project [config_file.ini]"
    echo ""
    echo "This script automatically generates tasks.json and adds LittleFS support to CMakeLists.txt."
    echo ""
    echo "Parameters:"
    echo "  /path/to/project         Path to the ESP-IDF project directory"
    echo "  [config_file.ini]        (Optional) Path to the .ini configuration file to use"
    echo ""
    echo "If the second parameter is not provided, the config.ini file located next to the script will be used."
    exit 0
}

# Show help if the first argument is --help or -h
[[ "$1" == "--help" || "$1" == "-h" ]] && show_help

# Verify if the script has proyect path as argument
if [ -z "$1" ]; then
    echo "❌ Usage: $0 /path/to/project"
    exit 1
fi

# Determine if the second argument is provided, otherwise use the default config file
if [ -z "$2" ]; then
    echo "❌ No configuration file provided. Using the default one."
    CONFIG_FILE="${SCRIPT_DIR}/config.ini"
else
    CONFIG_FILE="$2"
    if [ ! -f "$2" ]; then
        echo "❌ The configuration file does not exist: $2"
        exit 1
    else
        echo "✅ Configuration file found: $2"
    fi
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
echo "🧠 Platform: $PLATFORM"
echo "🔗 Export script: $EXPORT_SCRIPT"
echo "💻 Shell: $SHELL_CMD"
echo ""

mkdir -p "$VSCODE_DIR"

# Create a temporary list for tasks
ALL_TASKS=()

# Add base tasks (as a block)
BASE_CONTENT=$(sed -e "s|__EXPORT_SCRIPT__|$EXPORT_SCRIPT|g" \
                   -e "s|__PORT__|$PORT_VAR|g" \
                   -e "s|__SHELL__|$SHELL_CMD|g" \
                   "$BASE_TEMPLATE")

# Remove header and array opening
BASE_CONTENT=$(echo "$BASE_CONTENT" | sed '1d;$d')
ALL_TASKS+=("$BASE_CONTENT")

# Instructions for CMakeLists
PARTITION_LINES=""

# Process partitions dynamically
for section in $(awk '/\\[LittleFS_/{gsub(/\\[|\\]/,""); print $1}' "$CONFIG_FILE"); do
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
        echo "📁 Folder ${PARTITION_DIR}/ exists."
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

# Generar JSON completo
{
  echo "{"
  echo "  \"version\": \"2.0.0\","
  echo "  \"tasks\": ["
  IFS=$'\\n'
  echo "${ALL_TASKS[*]}" | paste -sd "," -
  echo "  ]"
  echo "}"
} > "$TASKS_PATH"

# Modificar CMakeLists.txt si es necesario
if grep -q "littlefs_create_partition_image" "$CMAKE_FILE"; then
    echo "✅ CMakeLists.txt already contains LittleFS instructions."
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

echo "✅ Completed! tasks.json successfully generated."

