#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_TEMPLATE="${SCRIPT_DIR}/tasks.base.template.json"
PARTITION_TEMPLATE="${SCRIPT_DIR}/task.partition.template.json"

# Verify if the script has proyect path as argument
if [ -z "$1" ]; then
    echo "❌ Uso: $0 /ruta/al/proyecto"
    exit 1
fi

# Determinate if the second argument is provided, otherwise use default config file
if [ -z "$2" ]; then
    echo "❌ No se ha proporcionado un archivo de configuración. Usando el predeterminado."
    CONFIG_FILE="${SCRIPT_DIR}/config.ini"
else
    CONFIG_FILE="$2"
    if [ ! -f "$2" ]; then
        echo "❌ El archivo de configuración no existe: $2"
        exit 1
    else
        echo "✅ Archivo de configuración encontrado: $2"
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

echo "📍 Proyecto: $PROJECT_DIR"
echo "🧠 Plataforma: $PLATFORM"
echo "🔗 Script de export: $EXPORT_SCRIPT"
echo "💻 Shell: $SHELL_CMD"
echo ""

mkdir -p "$VSCODE_DIR"

# Crear una lista temporal para tareas
ALL_TASKS=()

# Añadir tareas base (como bloque)
BASE_CONTENT=$(sed -e "s|__EXPORT_SCRIPT__|$EXPORT_SCRIPT|g" \
                   -e "s|__PORT__|$PORT_VAR|g" \
                   -e "s|__SHELL__|$SHELL_CMD|g" \
                   "$BASE_TEMPLATE")
# Quitar encabezado y apertura del array
BASE_CONTENT=$(echo "$BASE_CONTENT" | sed '1d;$d')
ALL_TASKS+=("$BASE_CONTENT")

# Instrucciones para CMakeLists
PARTITION_LINES=""

# Procesar particiones dinámicamente
for section in $(awk '/\\[LittleFS_/{gsub(/\\[|\\]/,""); print $1}' "$CONFIG_FILE"); do
    PARTITION_LABEL=$(parse_ini "$section" "partition_label")
    PARTITION_DIR=$(parse_ini "$section" "partition_dir")
    TAG=$(parse_ini "$section" "tag")
    PARTITION_PATH="${PROJECT_DIR}/${PARTITION_DIR}"

    echo "📦 Partición [$section]: $PARTITION_LABEL → $PARTITION_PATH"

    if [ ! -d "$PARTITION_PATH" ]; then
        echo "📁 Creando carpeta: $PARTITION_DIR/"
        mkdir -p "$PARTITION_PATH"
        echo "# Files to LittleFS" > "${PARTITION_PATH}/README.txt"
    else
        echo "📁 Carpeta ${PARTITION_DIR}/ ya existe."
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
    echo "✅ CMakeLists.txt ya contiene instrucciones LittleFS."
else
    echo "➕ Añadiendo soporte LittleFS al CMakeLists.txt"
    {
        echo ""
        echo "# Support to LittleFS"
        echo "if(DEFINED ENV{LFS_BUILD} AND \"$ENV{LFS_BUILD}\" STREQUAL \"1\")"
        echo -e "$PARTITION_LINES"
        echo "endif()"
    } >> "$CMAKE_FILE"
fi

echo "✅ ¡Completado! tasks.json generado correctamente."
