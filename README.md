# slimiys_ahk (Levorte)

Набор AutoHotkey-скриптов: горячие клавиши для громкости, яркости, схем питания, Path of Exile и системных утилит.

## Структура

- `app/` — исходники Levorte (точка входа `Levorte.ahk`)
- `scripts/Compile-Levorte.ps1` — сборка `build/Levorte.exe` через Ahk2Exe
- `tools/` — вспомогательные утилиты компиляции (BinMod.ahk)
- `app/brightness/` — Python-скрипт синхронизации яркости на всех мониторах

## Сборка

```powershell
cd scripts
.\Compile-Levorte.ps1
```

Требуется [AutoHotkey v1](https://www.autohotkey.com/) и компилятор Ahk2Exe (системный или `tools/Ahk2Exe.exe`).

## Запуск

Скрипт запрашивает права администратора. Можно запускать `app/Levorte.ahk` или собранный `build/Levorte.exe`.
