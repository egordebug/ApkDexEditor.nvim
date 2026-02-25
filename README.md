# 📱 ApkDexEditor.nvim

# English 🇬🇧

Plugin for Neovim designed for reverse engineering and modification of Android applications directly in the editor.

Allows decompiling APK, working with Dalvik/ART bytecode (smali), .class files and Java source code, as well as quickly rebuilding a modified APK.

## Key Features

- Built-in tools (apktool, smali/baksmali, android.jar) — no manual path configuration required
- Automatic context: file tree and terminal open in the current session folder
- Direct support for .dex, .class and .java files
- Built-in floating terminal (Ctrl+T) for adb, logcat, shell, etc.
- Quick commands for switching between smali ↔ dex ↔ java

## Installation

Using **lazy.nvim**:

```lua
    {
        "egordebug/ApkDexEditor.nvim",
        dependencies = {
        "nvim-neo-tree/neo-tree.nvim",
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("apkdexeditor").setup()
    end
    }
```

## Main Commands

### APK Operations

- `:ApkOpen DexEditor <path_to_apk>`    — decompile APK and select DEX file to work with
- `:ApkOpen DexEditor Compile`        — build changes and repack APK
- `:ApkOpen DexEditor Back`           — close current decompilation session

### Smali / dex / java

- `:Dex2Smali <path_to_file.dex>`     — decompile .dex → smali
- `:Dex2Smali Compile`                — assemble smali back to .dex
- `:Java2Smali <path_to_file.java>`   — compile java → smali (uses android.jar)
- `:Dex2Smali Search <string>`        — search across all smali files in current session

### Additional

- `:AdbInstall`          — install current APK to connected device
- `Ctrl+T`               — toggle floating terminal

## Requirements

- Java 11 or newer
- `zip` utility in PATH
- System-wide **apktool** (recommended ≥ 2.9.0)

## License

MIT. Third-party licenses are located in the NOTICE file.

---

# Russian 🇷🇺

# 📱 ApkDexEditor.nvim

Плагин для Neovim, предназначенный для реверс-инжиниринга и модификации Android-приложений прямо в редакторе.

Поддерживает декомпиляцию APK, редактирование smali, .class и .java файлов, быструю пересборку APK.

## Основные возможности

- Все необходимые инструменты (apktool, smali/baksmali, android.jar) встроены в плагин
- Контекстная файловая структура и терминал открываются автоматически в папке сессии
- Поддержка работы напрямую с .dex, .class и .java
- Встроенный плавающий терминал (Ctrl+T) для adb, shell, logcat и других утилит
- Быстрые команды для конвертации и поиска по smali

## Установка

Через **lazy.nvim**:

```lua
{
    "egordebug/ApkDexEditor.nvim",
    dependencies = {
        "nvim-neo-tree/neo-tree.nvim",
        "nvim-lua/plenary.nvim",
    },
    config = function()
        require("apk-editor").setup()
    end,
}
```

## Основные команды

### Работа с APK

- `:ApkOpen DexEditor <путь_к_apk>`    — декомпилировать APK и открыть выбор DEX
- `:ApkOpen DexEditor Compile`        — собрать изменения и упаковать APK заново
- `:ApkOpen DexEditor Back`           — завершить сессию

### Smali / dex / java

- `:Dex2Smali <файл.dex>`             — декомпилировать DEX в smali
- `:Dex2Smali Compile`                — собрать smali → DEX
- `:Java2Smali <файл.java>`           — java → smali (через android.jar)
- `:Dex2Smali Search <текст>`         — поиск по smali-файлам сессии

### Прочее

- `:AdbInstall`          — установить текущий APK на устройство через adb
- `Ctrl+T`               — открыть/закрыть встроенный терминал

## Требования

- Java 11+
- Утилита `zip`
- apktool (желательно версии 2.9.0 и выше) установлен в системе

## Лицензия

MIT. Лицензии третьих компонентов — в файле NOTICE.
