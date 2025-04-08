#!/usr/bin/env python3
import shutil
import sys
import json
import configparser
from pathlib import Path
from string import Template

def escape_json_string(value: str) -> str:
    return value.replace('\\', '\\\\')

def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(f"Usage: {Path(sys.argv[0]).name} /path/to/project [config_file.ini]")
        print("Options:")
        print("  --copy /path/to/destination  Copies the default config.ini to the specified path.")
        print("Generates VSCode tasks.json and adds LittleFS support to CMakeLists.txt.")
        sys.exit(0)

    # Manage command --copy
    if sys.argv[1] == "--copy":
        if len(sys.argv) < 3:
            print("❌ Error: You must specify a destination path for --copy.")
            sys.exit(1)

        destination_path = Path(sys.argv[2]).resolve()
        source_config = Path(__file__).parent / "config.ini"

        if not source_config.exists():
            print(f"❌ Error: Default config.ini not found at {source_config}")
            sys.exit(1)
        try:
            shutil.copy(source_config, destination_path)
            print(f"✅ config.ini copied to: {destination_path}")
        except Exception as e:
            print(f"❌ Error copying config.ini: {e}")
        sys.exit(0)

    project_path = Path(sys.argv[1]).resolve()
    config_path = Path(sys.argv[2]) if len(sys.argv) >= 3 else Path(__file__).parent / "config.ini"
    base_template_path = Path(__file__).parent / "templates" / "tasks.base.template.json"
    partition_template_path = Path(__file__).parent / "templates" / "task.partition.template.json"

    if not config_path.exists():
        print(f"❌ Error: Config file not found: {config_path}")
        sys.exit(1)

    if not project_path.exists():
        print(f"❌ Error: Project directory not found: {project_path}")
        sys.exit(1)

    config = configparser.ConfigParser()
    config.read(config_path)

    platform = config.get("LittleFS", "platform", fallback=None)
    export_script = config.get("LittleFS", "export_script", fallback="")

    if not platform:
        print("❌ Error: platform not defined in [LittleFS]")
        sys.exit(1)

    shell_cmd = "powershell" if platform == "windows" else "bash"
    port_var = "${config:idf.portWin}" if platform == "windows" else "${config:idf.port}"
    escaped_export_script = escape_json_string(export_script)

    # Aquí adaptamos el comando y el wrapper de ejecución
    command_flag = "-Command" if platform == "windows" else "-c"
    export_wrapper = "&" if platform == "windows" else "."

    print("📍 Project directory:", project_path)
    print("📄 Config file:", config_path)
    print("🧠 Platform:", platform)
    print("💻 Shell:", shell_cmd)
    print("🔗 Export script:", export_script)
    print("")

    with open(base_template_path, "r", encoding="utf-8") as f:
        base_template_text = f.read()

    base_template = Template(base_template_text)
    rendered_base = base_template.safe_substitute(
        SHELL=shell_cmd,
        PORT=port_var,
        EXPORT_SCRIPT=escaped_export_script,
        COMMAND_FLAG=command_flag,
        EXPORT_WRAPPER=export_wrapper
    )
    final_tasks = json.loads(rendered_base)

    with open(partition_template_path, "r", encoding="utf-8") as f:
        partition_template_raw = f.read()

    partition_template = Template(partition_template_raw)

    cmake_append = ""
    vscode_dir = project_path / ".vscode"
    vscode_dir.mkdir(exist_ok=True)

    print("🧩 Checking LittleFS partitions...")

    for section in config.sections():
        if not section.startswith("LittleFS_"):
            continue

        label = config.get(section, "partition_label", fallback=None)
        directory = config.get(section, "partition_dir", fallback=None)
        tag = config.get(section, "tag", fallback="")

        if not label or not directory:
            print(f"⚠️  Skipping [{section}] due to missing 'partition_label' or 'partition_dir'")
            continue

        full_dir = project_path / directory
        if not full_dir.exists():
            full_dir.mkdir(parents=True)
            (full_dir / "README.txt").write_text(f"# Files for LittleFS [{section}]\n", encoding="utf-8")
            print(f"📁 Created directory: {directory}")
        else:
            print(f"📦 Directory already exists: {directory}")

        # Renderizar las tareas desde la plantilla
        rendered_tasks = partition_template.safe_substitute(
            SHELL=shell_cmd,
            PORT=port_var,
            EXPORT_SCRIPT=escaped_export_script,
            COMMAND_FLAG=command_flag,
            EXPORT_WRAPPER=export_wrapper,
            PARTITION_LABEL=label,
            TAG=tag
        )

        # Convertir las tareas renderizadas en una lista de JSON
        tasks = json.loads(rendered_tasks)
        if isinstance(tasks, list):
            final_tasks.extend(tasks)  # Añadir todas las tareas al archivo final
        else:
            final_tasks.append(tasks)  # En caso de que sea una sola tarea

        cmake_append += f'    littlefs_create_partition_image({label} "{directory}" FLASH_AS_IMAGE)\n'

    print("✅ All partitions processed.\n")

    tasks_json_path = vscode_dir / "tasks.json"
    with open(tasks_json_path, "w", encoding="utf-8") as f:
        json.dump({
            "version": "2.0.0",
            "tasks": final_tasks
        }, f, indent=2, ensure_ascii=False)

    print(f"🧾 tasks.json written to: {tasks_json_path}")

    cmake_file = project_path / "CMakeLists.txt"
    if not cmake_file.exists():
        print(f"⚠️  CMakeLists.txt not found at {cmake_file}, skipping patch.")
    else:
        cmake_content = cmake_file.read_text(encoding="utf-8")
        if "littlefs_create_partition_image" in cmake_content:
            print("✅ CMakeLists.txt already contains LittleFS logic.")
        else:
            patch = (
                "\n# Support to LittleFS\n"
                "if(DEFINED ENV{LFS_BUILD} AND \"$ENV{LFS_BUILD}\" STREQUAL \"1\")\n"
                f"{cmake_append}"
                "endif()\n"
            )
            cmake_file.write_text(cmake_content + patch, encoding="utf-8")
            print("🔧 CMakeLists.txt updated with LittleFS support.")

    print("\n🏁 All done. You're ready to roll 🚀")

if __name__ == "__main__":
    main()
