# 🧰 ESP-IDF LittleFS CLI Tool

This project provides a modern **Python CLI tool** to **quickly configure LittleFS partitions** in **ESP-IDF projects**, including:

- ✅ Automatic creation of partition data folders
- ✅ Generation of `tasks.json` for Visual Studio Code
- ✅ Safe insertion of LittleFS support in `CMakeLists.txt`
- ✅ 🧠 Smart platform detection (Windows/Linux)

> [!WARNING]  
> Requires Python 3.6+ and ESP-IDF installed in your system

---

## 📁 Project Structure

```
esp_littlefs_cli/
├── littlefscli/
│   ├── enable_littlefs.py       # Main CLI logic (with def main())
│   ├── config.ini               # Example config
│   └── templates/
│       ├── tasks.base.template.json
│       └── task.partition.template.json
├── setup.py                     # Installation config
├── README.md                    # This file
└── MANIFEST.in                  # Includes templates in package
```

---

## 🚀 Installation

### 📦 Install globally with `pip`

```bash
git clone https://github.com/YOUR_USER/esp_littlefs_cli.git
cd esp_littlefs_cli
pip install .
```
### 💡 Or use `pipx` (recommended)

```bash
pipx install /path/to/esp_littlefs_cli
```

---

## ⚙️ Configuration (`config.ini`)

Create or edit a config file like this:

```ini
[LittleFS]
platform = windows
export_script = C:\Users\YOUR_USER\Espressif\v5.4\esp-idf\export.ps1

[LittleFS_interna]
partition_label = littlefs_chip
partition_dir = littlefs_data
tag = INTERNOS (chip)

[LittleFS_externa]
partition_label = littlefs_user
partition_dir = littlefs_user
tag = EXTERNOS (user)
```

### Parameters

| Key                | Description |
|--------------------|-------------|
| `platform`         | `windows` or `linux` (affects VSCode task port) |
| `export_script`    | Absolute path to the ESP-IDF export script|
| `partition_label`  | Name of the partition (e.g., `littlefs`) |
| `partition_dir`    | Folder with files to flash |
| `tag`              | Friendly name for VSCode task label |

> [!IMPORTANT]  
> `export_script` should point to the ESP-IDF export script, usually located in the installation path (`export.ps1` or `export.sh`).  
> `partition_label` and `partition_dir` must match your `partitions.csv` entries and your code's mount points.


> [!CAUTION]
> Before it, don't forget execute `install.ps1` or `install.sh` from your terminal

---

## 🧪 Usage

Once installed, simply run:

```bash
enable-littlefs /path/to/your/project [.vscode/partition.ini]
```

> [!NOTE]  
> `.vscode/partition.ini` is optional. If not provided, the tool will use `config.ini` from the CLI script's directory.


✅ The tool will:

- Create `littlefs_data/`, `littlefs_user/`, etc. if missing  
- Generate `.vscode/tasks.json` based on templates  
- Patch `CMakeLists.txt` with `littlefs_create_partition_image(...)` only if not already present

---

## 💻 Platform Support

✅ Native Linux  
✅ Windows (Git Bash or WSL)
✅ PowerShell (via proper platform config)  
✅ macOS

---

## 🧼 What if it's already configured?

- The CLI detects and skips existing `tasks.json` or CMake blocks.
- It won't overwrite anything unless needed.
- It’s safe to run multiple times.

---

## 🧠 Real-world Example

Let’s say you want to set this up in an existing ESP-IDF project:

```bash
cd ~/esp/myproject
enable-littlefs . .vscode/partition.ini
```

### 🔍 What does this tool actually do?

- Parses your config `.ini` file
- Creates folders if they don’t exist
- Loads task templates and injects parameters
- Generates `.vscode/tasks.json` with proper flash commands
- Patches your `CMakeLists.txt` with `littlefs_create_partition_image(...)` only once
- Detects and skips existing config to avoid duplication

### ⚙️ Expected output

Even `enable-littlefs project/path` or `enable-littlefs project/path config/path`

#### Case with archives folders already created

```
📍 Project directory: /.../
📄 Config file: /.../xxxx.ini
🧠 Platform: /.../
💻 Shell: /.../
🔗 Export script: /.../

🧩 Checking LittleFS partitions...
📦 Directory already exists: littlefs_data
📦 Directory already exists: littlefs_user
✅ All partitions processed.

🧾 tasks.json written to: /.../
✅ CMakeLists.txt already contains LittleFS logic.

🏁 All done. You're ready to roll 🚀
```




## 🧠 Author

Created by [PoleG97](https://github.com/PoleG97)  
Maintained as a CLI tool with ❤️ and Python power.
