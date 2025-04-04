# 🧰 ESP-IDF LittleFS Configurator

This project provides a set of tools to **quickly configure a LittleFS partition** in an **ESP-IDF-based project**, including:

- ✅ Automatic creation of the files folder
- ✅ Generation of `tasks.json` for Visual Studio Code
- ✅ Insertion of LittleFS support into `CMakeLists.txt`

> ⚠️ This script is intended for ESP-IDF projects using CMake.  
> Currently supported only on UNIX-like environments (Linux, WSL, Git Bash).

---

## 📁 Project Structure

```
esp_littlefs_config/ 
├── enable_littlefs.sh  # Main configuration script 
├── tasks.template.json # Template to generate tasks.json 
├── config.ini          # Project-specific configuration 
└── README.md           # This file
```


---

## 🧪 Requirements

- ESP-IDF installed and accessible in the environment
- Using VSCode (or manually edit `tasks.json`)
- **Bash-compatible environment**:
  - Linux
  - WSL (Windows Subsystem for Linux)
  - Git Bash

---

## ⚙️ Initial Setup

Edit the `config.ini` file with your project parameters:

```ini
[LittleFS]
partition_label = littlefs
partition_dir = littlefs_data
platform = windows
export_script = C:\Users\YOUR_USER\Espressif\v5.4\esp-idf\export.ps1
```
> Change `export_script` with your path, It'll works on linux too

### Parameters

| Clave             | Descripción                                           |
|-------------------|-------------------------------------------------------|
| `partition_label` | Etiqueta de la partición en `partitions.csv`          |
| `partition_dir`   | Carpeta donde se almacenarán los archivos a subir     |
| `platform`        | Solo `windows` o `linux` (afecta al nombre del puerto en `tasks.json`) |
| `export_script`   | Ruta absoluta al script de export de entorno de ESP-IDF |

# 🚀 How to Use
Run the script by passing your ESP-IDF project path:

```bash
./enable_littlefs.sh /path/to/your/project
```

> ![TIP] If you create an alias to this script or include it in your path, you can run it from your project directory using . as the path.

## This script:

🆕 Creates the littlefs_data/ folder if it doesn’t exist

✍️ Modifies CMakeLists.txt only if it doesn’t already contain a littlefs_create_partition_image(...) block

🧠 Generates .vscode/tasks.json with ready-to-use ESP-IDF commands

# 🖥️ Notes on Windows and PowerShell
There is no official support for PowerShell.
It is recommended to use WSL or Git Bash to run the .sh script.

##  Platforms:

✅ Native Linux

✅ Windows (WSL)

✅ Windows (Git Bash)

❌ Native Windows (PowerShell)

# 🧼 What if I’ve already configured it?
The script checks if tasks.json or the CMake block already exist, and won’t overwrite them if they do.

# 🧠 Real Example of Use
Let’s say you want to add LittleFS support to a new project. Just do:

```bash
cp -r esp_littlefs_config/ ~/esp/myproject/tools/
cd ~/esp/myproject
../tools/esp_littlefs_config/enable_littlefs.sh .
```
And that’s it!

But hey, that’s just one way—I personally have it aliased, but that’s up to you.

