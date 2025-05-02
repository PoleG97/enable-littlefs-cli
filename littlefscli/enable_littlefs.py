#!/usr/bin/env python3
import shutil
import sys
import json
import configparser
from pathlib import Path
from string import Template


def escape_json_string(value: str) -> str:
    """
    Escapes backslashes in a JSON string by replacing each backslash with a double backslash.

    Args:
        value (str): The input string to be escaped.

    Returns:
        str: The escaped string with backslashes doubled.
    """
    return value.replace('\\', '\\\\')


def main():
    """
    Main function to enable LittleFS support for a project.

    This script performs the following tasks:
    1. Copies a default `config.ini` file to a specified destination using the `--copy` option.
    2. Generates a `tasks.json` file for VSCode based on the provided configuration.
    3. Adds LittleFS support to the `CMakeLists.txt` file of the project.

    Usage:
        python enable_littlefs.py /path/to/project [config_file.ini]
        python enable_littlefs.py --copy /path/to/destination

    Arguments:
        /path/to/project         Path to the project directory where LittleFS support will be added.
        [config_file.ini]        Optional path to a custom configuration file. Defaults to `config.ini` in the script's directory.
        --copy                   Copies the default `config.ini` to the specified destination path.

    Options:
        --copy /path/to/destination
            Copies the default `config.ini` file to the specified destination path.

    Functionality:
    - Validates the provided project path and configuration file.
    - Reads the configuration file to determine platform-specific settings and LittleFS partition details.
    - Creates necessary directories for LittleFS partitions if they do not exist.
    - Generates a `tasks.json` file for VSCode with tasks for flashing LittleFS partitions.
    - Updates the `CMakeLists.txt` file to include LittleFS partition creation logic.

    Raises:
        SystemExit: Exits the script with an error message if invalid arguments are provided or required files are missing.

    """

    # Check if the script is run with the correct number of arguments
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

        # Check if the destination path is valid
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

    # Obtain the project path and config file from command line arguments
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

    # Check if the config file has the required sections
    platform = config.get("LittleFS", "platform", fallback=None)
    export_script = config.get("LittleFS", "export_script", fallback="")

    if not platform:
        print("❌ Error: platform not defined in [LittleFS]")
        sys.exit(1)

    # Determine the shell command based on the platform
    shell_cmd = "powershell" if platform == "windows" else "bash"
    port_var = "${config:idf.portWin}" if platform == "windows" else "${config:idf.port}"
    escaped_export_script = escape_json_string(export_script)

    # Adapt the command flag and export wrapper based on the platform
    command_flag = "-Command" if platform == "windows" else "-c"
    export_wrapper = "&" if platform == "windows" else "."

    # Adapt env variables based on the platform
    env_var_wrapper = "$env:LFS_BUILD='1';" if platform == "windows" else "export LFS_BUILD=1;"

    # User feedback
    print("📍 Project directory:", project_path)
    print("📄 Config file:", config_path)
    print("🧠 Platform:", platform)
    print("💻 Shell:", shell_cmd)
    print("🔗 Export script:", export_script)
    print("")

    with open(base_template_path, "r", encoding="utf-8") as f:
        base_template_text = f.read()

    # Find all LittleFS partition labels in the config file
    partitions_info = [
        {
            "section": section,
            "label": config.get(section, "partition_label"),
            "directory": config.get(section, "partition_dir"),
            "tag": config.get(section, "tag", fallback=""),
        }
        
        for section in config.sections()
        if section.startswith("LittleFS_")
        and config.get(section, "partition_label", fallback=None)
        and config.get(section, "partition_dir", fallback=None)
    ]

    # Substitute variables in the base template (tasks.base.template.json)
    base_template = Template(base_template_text)
    rendered_base = base_template.safe_substitute(
        SHELL=shell_cmd,
        PORT=port_var,
        EXPORT_SCRIPT=escaped_export_script,
        COMMAND_FLAG=command_flag,
        EXPORT_WRAPPER=export_wrapper,
        ENV_VAR_WRAPPER=env_var_wrapper
    )
    final_tasks = json.loads(rendered_base)

    with open(partition_template_path, "r", encoding="utf-8") as f:
        partition_template_raw = f.read()


    partition_template = Template(partition_template_raw)

    cmake_lfs_partitions = ""
    vscode_dir = project_path / ".vscode"
    vscode_dir.mkdir(exist_ok=True)

    print("🧩 Checking LittleFS partitions...")

    # Iterate through the sections in the config file to find LittleFS partitions
    for part in partitions_info:
        label = part["label"]
        directory = part["directory"]
        tag = part["tag"]

        rendered_tasks = partition_template.safe_substitute(
            SHELL=shell_cmd,
            PORT=port_var,
            EXPORT_SCRIPT=escaped_export_script,
            COMMAND_FLAG=command_flag,
            EXPORT_WRAPPER=export_wrapper,
            PARTITION_LABEL=label,
            TAG=tag
        )

        # Convert the rendered JSON string to a Python object
        tasks = json.loads(rendered_tasks)
        if isinstance(tasks, list):
            final_tasks.extend(tasks)  # Add the list of tasks
        else:
            final_tasks.append(tasks)  # In case it's a single task

        cmake_lfs_partitions += f'littlefs_create_partition_image({label} "{directory}" FLASH_AS_IMAGE)\n'

    print("✅ All partitions processed.\n")

    # Write the final tasks to tasks.json
    tasks_json_path = vscode_dir / "tasks.json"
    with open(tasks_json_path, "w", encoding="utf-8") as f:
        json.dump({
            "version": "2.0.0",
            "tasks": final_tasks
        }, f, indent=2, ensure_ascii=False)

    print(f"🧾 tasks.json written to: {tasks_json_path}")

    # 🛠️ Escribimos lfs_partitions/CMakeLists.txt
    lfs_dir = project_path / "lfs_partitions"
    lfs_dir.mkdir(exist_ok=True)
    cmake_lfs_path = lfs_dir / "CMakeLists.txt"
    cmake_lfs_path.write_text(cmake_lfs_partitions, encoding="utf-8")
    print(f"🛠️ lfs_partitions/CMakeLists.txt written to: {cmake_lfs_path}")

    # Check if the CMakeLists.txt file exists and append the LittleFS logic
    cmake_file = project_path / "CMakeLists.txt"
    if not cmake_file.exists():
        print(f"⚠️  CMakeLists.txt not found at {cmake_file}, skipping patch.")
    else:

        # Check if the CMakeLists.txt already contains LittleFS logic
        cmake_content = cmake_file.read_text(encoding="utf-8")
        if "add_subdirectory(lfs_partitions)" in cmake_content:
            print("✅ CMakeLists.txt already contains LittleFS logic.")
        else:
            # Append the LittleFS logic to the CMakeLists.txt file
            patch = (
                "\n# Support to LittleFS\n"
                "if(DEFINED ENV{LFS_BUILD} AND \"$ENV{LFS_BUILD}\" STREQUAL \"1\")\n"
                "    add_subdirectory(lfs_partitions)\n"
                "endif()\n"
            )
            cmake_file.write_text(cmake_content + patch, encoding="utf-8")
            print("🔧 CMakeLists.txt updated with LittleFS support.")

    print("\n🏁 All done. You're ready to roll 🚀")

if __name__ == "__main__":
    main()
