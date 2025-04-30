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
git clone https://github.com/...
cd esp_littlefs_cli
pip install .
```
### 💡 Or use `pipx` (recommended)

```bash
git clone https://github.com/...
cd esp_littlefs_cli
pipx install /.
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


### What it does:
- 📁 Creates missing littlefs_* directories

- 🧠 Generates .vscode/tasks.json with correct build targets

- 📌 Patches CMakeLists.txt only if needed (non-invasive)

---

## 📁 Recommended Folder Structure
To ensure consistent and error-free builds, place your LittleFS folders (e.g. littlefs_data, littlefs_user) inside the lfs_partitions/ directory created by the tool.

```
your-project/
├── lfs_partitions/
│   ├── CMakeLists.txt               # Auto-generated with partition build logic
│   ├── littlefs_data/               # Internal files to flash (e.g., config, certs)
│   └── littlefs_user/               # External/user files to flash
├── main/
├── components/
├── CMakeLists.txt
└── partitions.csv
```

### 💡 Why?
ESP-IDF uses add_subdirectory() to include the partition image generation logic from a dedicated directory.
By placing the LittleFS data folders inside lfs_partitions/, paths are resolved consistently by CMake, avoiding FileNotFoundError issues due to mismatches between declared paths and actual structure.

> ✅ This approach ensures that you don’t need to modify your partitions.csv file — the build system will correctly find and package the data into the corresponding partition image.

>[!CAUTION]
> If you switch between builds with and without LittleFS support (e.g. toggling `LFS_BUILD=1`), you must run `idf.py fullclean` to clear the CMake cache. Otherwise, previously cached targets may remain active and cause inconsistencies.
>💡 This process is **transparent to you** if you're using the generated `tasks.json`, as it handles L`FS_BUILD` configuration automatically.

---

## 💻 Platform Support

✅ Native Linux  
✅ Windows 
✅ macOS

---

## ♻️ Idempotency

The CLI safely detects existing configurations:

- Skips tasks.json if already configured

- Avoids duplicate entries in CMakeLists.txt

- Can be re-run without side effects

---

## 🧠 Real-world Example

Let’s say you want to set this up in an existing ESP-IDF project:

```bash
cd ~/esp/myproject
enable-littlefs . .vscode/partition.ini
```


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

# 📄 License
This project is licensed under the MIT License.

# 🙌 Contributing
Contributions are welcome! Feel free to open issues or pull requests for bugs, features, or improvements. Just make sure you follow standard Python formatting and write clear commit messages.


## 🧠 Author

Created by [PoleG97](https://github.com/PoleG97)  
Maintained as a CLI tool with ❤️ and 🐍 power.
