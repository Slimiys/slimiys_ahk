; ============================================================
; Конфигурация: константы и общие параметры
; ============================================================
global Poe1FilterPath := "C:\Users\Slimiys\Documents\My Games\Path of Exile"
global Poe2FilterPath := "C:\Users\Slimiys\Documents\My Games\Path of Exile 2"
global DownloadsFilterMask := "C:\Users\Slimiys\Downloads\*.filter"
; Каталоги BuildPlanner для импорта билдов из Downloads.
global Poe1BuildPath := "C:\Users\Slimiys\Documents\My Games\Path of Exile\BuildPlanner"
global Poe2BuildPath := "C:\Users\Slimiys\Documents\My Games\Path of Exile 2\BuildPlanner"
global DownloadsBuildMask := "C:\Users\Slimiys\Downloads\*.build"
global BrightnessPythonScript := ResolveBrightnessPythonScriptPath()
global BrightnessPythonExe := ""
global BrightnessPythonExeArgs := ""
InitBrightnessPythonCommand()
global PowerSchemeMax := "5da85d85-eb0c-4710-a805-6da8bbcf1f02"
global PowerSchemeBalanced := "653fbb7f-248b-41d0-aa49-03fabbfd5e8e"
global PowerSchemeSilent := "a9932169-f1fb-4dff-9034-fe1c4ca1886e"

; Всплывающая подсказка громкости (Gui): фон внутренней панели и цвет рамки (полоски Progress).
global VolumeTooltipBgColor := "18181B"
global VolumeTooltipBorderColor := "7D7D94"
; Пусто — авто-поиск 7z.exe; иначе полный путь к 7-Zip.
global Archive7zPath := ""
; Пусто — авто-поиск python.exe / py.exe; иначе полный путь к интерпретатору.
global BrightnessPythonExePath := ""
; Каталог scripts репозитория rcs_hmi_xplat (рабочая папка для сборки HMI).
global HmiScriptsDir := "C:\Work\rcs_hmi_xplat\scripts"
global HmiDesktopProjectRelative := "..\HmiSoftware\HmiView.Desktop\HmiView.Desktop.csproj"
global HmiDesktopRunArgs := "--robots a12:192.168.1.9:8003 --clear-logs"
global HmiDesktopShellCommands := "dotnet build ..\HmiSoftware\HmiView.Desktop\ -c Debug; dotnet run --project " . HmiDesktopProjectRelative . " " . HmiDesktopRunArgs
; Подстрока командной строки для поиска уже запущенного экземпляра (PowerShell / dotnet).
global HmiDesktopProcessSignature := "HmiView.Desktop.csproj " . HmiDesktopRunArgs
; Сборка и запуск Android HMI.
global HmiAndroidScript := ".\build_and_run_android.ps1"
global HmiAndroidRobotsArgs := "-robots a12:192.168.1.9:8003"
global HmiAndroidExtraArgs := "--auto --dotnet 10"
; Подстрока командной строки для поиска уже запущенного Android-запуска.
global HmiAndroidProcessSignature := "build_and_run_android.ps1 " . HmiAndroidRobotsArgs
; Дамп logcat в log.txt (рабочая папка — HmiScriptsDir).
global HmiAndroidLogcatCommand := "adb logcat -d -v time -s DOTNET:I PERF:I DIAG:I PERF_SIGNAL_VM:I SCROLL_TRACE:I *:S > log.txt"
global HmiAndroidLogcatOutputFile := "log.txt"
; Сборка linux-x64 и деплой HMI по SSH (шкаф / пульт / кастом).
global HmiLinuxDeployScript := ".\build_and_deploy_linux_shkaf.ps1"
global HmiSshPasswordlessScript := ".\setup_ssh_passwordless.ps1"
global HmiLinuxDeployRemotePath := "~/Desktop/hmi_lin"
global HmiLinuxDeployShkafUser := "shkaf"
global HmiLinuxDeployShkafHost := "192.168.1.205"
global HmiLinuxDeployPultUser := "hmi"
global HmiLinuxDeployPultHost := "192.168.1.108"
; Подстрока для остановки предыдущего деплоя.
global HmiLinuxDeployProcessSignature := "build_and_deploy_linux_shkaf.ps1"
; Последний записанный макрос (клавиатура/мышь).
global MacroLastDir := "C:\Work\scripts\switcher\macros"
global MacroLastFilePath := "C:\Work\scripts\switcher\macros\last_macro.txt"

ResolveBrightnessPythonScriptPath()
{
    ; Запуск из исходника: <project>\app\Levorte.ahk
    candidateFromApp := A_ScriptDir . "\brightness\auto_brightness.py"
    if (FileExist(candidateFromApp))
        return candidateFromApp

    ; Запуск с корня проекта (редко, но оставляем на случай ручного старта).
    candidateFromRoot := A_ScriptDir . "\app\brightness\auto_brightness.py"
    if (FileExist(candidateFromRoot))
        return candidateFromRoot

    ; Запуск из собранного exe: <project>\build\Levorte.exe
    candidateFromBuild := A_ScriptDir . "\..\app\brightness\auto_brightness.py"
    if (FileExist(candidateFromBuild))
        return candidateFromBuild

    ; Возвращаем основной путь как fallback.
    return candidateFromApp
}

; Команда Python для фоновой синхронизации яркости (важно при запуске от администратора).
InitBrightnessPythonCommand()
{
    global BrightnessPythonExe, BrightnessPythonExeArgs, BrightnessPythonExePath

    if (BrightnessPythonExePath != "" && FileExist(BrightnessPythonExePath))
    {
        BrightnessPythonExe := BrightnessPythonExePath
        BrightnessPythonExeArgs := ""
        return
    }

    pyLauncher := A_WinDir . "\py.exe"
    if (FileExist(pyLauncher))
    {
        BrightnessPythonExe := pyLauncher
        BrightnessPythonExeArgs := "-3"
        return
    }

    EnvGet, localAppData, LocalAppData
    pythonVersions := ["312", "311", "310", "39", "38"]
    for index, version in pythonVersions
    {
        candidate := "C:\Python" . version . "\python.exe"
        if (FileExist(candidate))
        {
            BrightnessPythonExe := candidate
            BrightnessPythonExeArgs := ""
            return
        }

        candidate := localAppData . "\Programs\Python\Python" . version . "\python.exe"
        if (FileExist(candidate))
        {
            BrightnessPythonExe := candidate
            BrightnessPythonExeArgs := ""
            return
        }
    }

    BrightnessPythonExe := "python.exe"
    BrightnessPythonExeArgs := ""
}
