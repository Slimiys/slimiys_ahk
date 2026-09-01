; ============================================================
; Хоткеи разработки (HMI и прочие проекты)
; ============================================================

global hmiAndroidBuildConfigChoice := ""
global hmiAndroidBuildConfigGuiHwnd := ""
global hmiLinuxDeployTargetChoice := ""
global hmiLinuxDeployTargetGuiHwnd := ""
global hmiLinuxDeployTargetHotkeysOn := false
global hmiLinuxActionChoice := ""
global hmiLinuxActionGuiHwnd := ""
global hmiLinuxActionHotkeysOn := false
global hmiDesktopActionChoice := ""
global hmiDesktopActionGuiHwnd := ""
global hmiDesktopActionHotkeysOn := false
global hmiAndroidBuildConfigHotkeysOn := false
global HmiAndroidMenuText := ""
global HmiDesktopMenuText := ""
global hmiTestUiFlagsLoaded := false
global HmiLastBuildLogPath := ""
global hmiBuildWatchLogPath := ""
global hmiBuildWatchTitle := ""
global hmiBuildWatchActive := false

; --- Хоткеи ---
; Сборка и запуск HmiView.Desktop: 1 = запуск, 3 = переключить --test-ui.
^!z::
    RunHmiDesktop()
Return

; Android HMI: 1=release, 2=debug, 3=переключить --test-ui, 4=adb logcat → log.txt.
^!x::
    RunHmiAndroid()
Return

; Linux HMI: деплой или выгрузка логов по SSH (шкаф / пульт / кастом).
^!c::
    RunHmiLinuxMenu()
Return

; Повторный разбор / открытие последнего лога сборки HMI.
^!l::
    ShowLastHmiBuildLogAnalysis()
Return

; --- Функции ---
RunHmiDesktop()
{
    global HmiScriptsDir, HmiDesktopProjectRelative, HmiDesktopRunArgs, HmiDesktopProcessSignature

    if (!FileExist(HmiScriptsDir))
    {
        ShowTemporaryTooltip("Каталог не найден: " . HmiScriptsDir, 3000)
        Return
    }

    choice := PromptHmiDesktopAction()
    if (choice = "")
        Return

    if (StopProcessesByCommandSignature(HmiDesktopProcessSignature))
        ShowTemporaryTooltip("Остановлен предыдущий запуск HmiView.Desktop", 1500)

    runArgs := HmiDesktopRunArgs . GetHmiTestUiArgSuffix("desktop")
    buildCmd := "dotnet build ..\HmiSoftware\HmiView.Desktop\ -c Debug"
        . "; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }"
    ShowTemporaryTooltip("HmiView.Desktop: сборка…", 1500)
    if (!RunHmiLoggedPowerShell("desktop", "HmiView.Desktop", buildCmd, true, "Min"))
        Return

    runCmd := "dotnet run --project " . HmiDesktopProjectRelative . " " . runArgs
    ; Запуск приложения: пишем в тот же лог, разбор не ждём (процесс долгоживущий).
    RunHmiLoggedPowerShell("desktop", "HmiView.Desktop", runCmd, false, "Min", false)
}

; Каталог логов сборок: HmiBuildLogsDir или <корень репо>/logs.
GetHmiBuildLogsDir()
{
    global HmiBuildLogsDir

    if (HmiBuildLogsDir != "")
    {
        dir := HmiBuildLogsDir
        FileCreateDir, %dir%
        Return dir
    }

    ; app\Levorte.ahk или build\Levorte.exe → <repo>\logs
    SplitPath, A_ScriptDir, , repoRoot
    dir := repoRoot . "\logs"
    FileCreateDir, %dir%
    Return dir
}

; Единый файл лога всех сборок HMI (перезаписывается при новом запуске).
GetHmiBuildLogPath()
{
    Return GetHmiBuildLogsDir() . "\hmi-build.log"
}

; Удаляет старые per-kind логи/errors/wrapper, если остались от прежней версии.
CleanupLegacyHmiBuildLogs()
{
    logsDir := GetHmiBuildLogsDir()
    Loop, Files, %logsDir%\hmi-*-build.log
        FileDelete, %A_LoopFileFullPath%
    Loop, Files, %logsDir%\hmi-*-build.errors.txt
        FileDelete, %A_LoopFileFullPath%
    Loop, Files, %logsDir%\_hmi_build_wrapper_*.ps1
        FileDelete, %A_LoopFileFullPath%
    if (FileExist(logsDir . "\hmi-build.errors.txt"))
        FileDelete, %logsDir%\hmi-build.errors.txt
    if (FileExist(logsDir . "\_hmi_build_stdout.tmp"))
        FileDelete, %logsDir%\_hmi_build_stdout.tmp
    if (FileExist(logsDir . "\_hmi_build_stderr.tmp"))
        FileDelete, %logsDir%\_hmi_build_stderr.tmp
}

EscapePowerShellSingleQuoted(text)
{
    Return StrReplace(text, "'", "''")
}

; Пишет единственный wrapper.ps1: дублирует вывод в лог + маркер __LEVORTE_EXIT_CODE__.
; Chr(36) = "$": иначе конструкции вроде `"$_"` ломают разбор строк AHK.
; Лог через оператор *>: Start-Process+cmd /c ломает кавычки (пустой лог, код 1).
WriteHmiBuildWrapperScript(logPath, workDir, innerCommand, appendLog)
{
    wrapperPath := GetHmiBuildLogsDir() . "\_hmi_build_wrapper.ps1"
    innerPath := GetHmiBuildLogsDir() . "\_hmi_build_inner.ps1"
    combinedPath := GetHmiBuildLogsDir() . "\_hmi_build_output.tmp"

    logPs := EscapePowerShellSingleQuoted(logPath)
    workPs := EscapePowerShellSingleQuoted(workDir)
    innerFilePs := EscapePowerShellSingleQuoted(innerPath)
    combinedPs := EscapePowerShellSingleQuoted(combinedPath)
    d := Chr(36)
    appendPs := appendLog ? (d . "true") : (d . "false")

    innerScript := innerCommand . "`r`n"
        . "if (" . d . "null -ne " . d . "LASTEXITCODE -and " . d . "LASTEXITCODE -ne 0) { exit " . d . "LASTEXITCODE }`r`n"
    FileDelete, %innerPath%
    FileAppend, %innerScript%, %innerPath%

    script := "# levorte-wrapper-v3`r`n"
        . d . "ErrorActionPreference = 'Continue'`r`n"
        . d . "log = '" . logPs . "'`r`n"
        . d . "workDir = '" . workPs . "'`r`n"
        . d . "innerPath = '" . innerFilePs . "'`r`n"
        . d . "combinedPath = '" . combinedPs . "'`r`n"
        . d . "append = " . appendPs . "`r`n"
        . "Set-Location -LiteralPath " . d . "workDir`r`n"
        . d . "header = '=== ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' ==='`r`n"
        . "if (" . d . "append) { Add-Content -LiteralPath " . d . "log -Value " . d . "header -Encoding UTF8 }`r`n"
        . "else { Set-Content -LiteralPath " . d . "log -Value " . d . "header -Encoding UTF8 }`r`n"
        . "Remove-Item -LiteralPath " . d . "combinedPath -Force -ErrorAction SilentlyContinue`r`n"
        . d . "psExe = Join-Path " . d . "env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'`r`n"
        . d . "code = 0`r`n"
        . "try {`r`n"
        . "  & " . d . "psExe -NoProfile -ExecutionPolicy Bypass -File " . d . "innerPath *>" . d . "combinedPath`r`n"
        . "  if (" . d . "null -ne " . d . "LASTEXITCODE) { " . d . "code = " . d . "LASTEXITCODE }`r`n"
        . "  if (Test-Path -LiteralPath " . d . "combinedPath) {`r`n"
        . "    Get-Content -LiteralPath " . d . "combinedPath -ErrorAction SilentlyContinue | ForEach-Object {`r`n"
        . "      Add-Content -LiteralPath " . d . "log -Value ([string]" . d . "_) -Encoding UTF8`r`n"
        . "      Write-Host ([string]" . d . "_)`r`n"
        . "    }`r`n"
        . "  }`r`n"
        . "} catch {`r`n"
        . "  " . d . "PSItem | Add-Content -LiteralPath " . d . "log -Encoding UTF8`r`n"
        . "  " . d . "code = 1`r`n"
        . "}`r`n"
        . "Remove-Item -LiteralPath " . d . "combinedPath -Force -ErrorAction SilentlyContinue`r`n"
        . "Add-Content -LiteralPath " . d . "log -Value ('__LEVORTE_EXIT_CODE__=' + " . d . "code) -Encoding UTF8`r`n"
        . "exit " . d . "code`r`n"

    FileDelete, %wrapperPath%
    FileAppend, %script%, %wrapperPath%
    Return wrapperPath
}

; Запуск PowerShell с логом. wait=true → RunWait + разбор; analyzeOnFinish — async-watch.
; showWindow: "Min" | "Hide" | "" (обычное окно).
RunHmiLoggedPowerShell(kind, title, innerCommand, wait := true, showWindow := "Min", analyzeOnFinish := true)
{
    global HmiScriptsDir, HmiLastBuildLogPath

    logPath := GetHmiBuildLogPath()
    HmiLastBuildLogPath := logPath

    appendLog := false
    if (!wait && !analyzeOnFinish && FileExist(logPath))
        appendLog := true
    else
        CleanupLegacyHmiBuildLogs()

    wrapperPath := WriteHmiBuildWrapperScript(logPath, HmiScriptsDir, innerCommand, appendLog)
    psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    runCmd := """" . psExe . """ -NoProfile -ExecutionPolicy Bypass -File """ . wrapperPath . """"

    if (wait)
    {
        if (showWindow = "Hide")
            RunWait, %runCmd%, %HmiScriptsDir%, Hide UseErrorLevel
        else if (showWindow = "Min")
            RunWait, %runCmd%, %HmiScriptsDir%, Min UseErrorLevel
        else
            RunWait, %runCmd%, %HmiScriptsDir%, UseErrorLevel

        Return AnalyzeHmiBuildLog(logPath, title)
    }

    if (showWindow = "Hide")
        Run, %runCmd%, %HmiScriptsDir%, Hide
    else if (showWindow = "Min")
        Run, %runCmd%, %HmiScriptsDir%, Min
    else
        Run, %runCmd%, %HmiScriptsDir%

    if (analyzeOnFinish)
        StartHmiBuildLogWatch(title, logPath)
    Return true
}

StartHmiBuildLogWatch(title, logPath)
{
    global hmiBuildWatchLogPath, hmiBuildWatchTitle, hmiBuildWatchActive

    hmiBuildWatchTitle := title
    hmiBuildWatchLogPath := logPath
    hmiBuildWatchActive := true
    SetTimer, HmiBuildLogWatchTick, 1000
}

HmiBuildLogWatchTick:
    global hmiBuildWatchActive, hmiBuildWatchLogPath, hmiBuildWatchTitle
    if (!hmiBuildWatchActive)
    {
        SetTimer, HmiBuildLogWatchTick, Off
        Return
    }
    if (!FileExist(hmiBuildWatchLogPath))
        Return

    FileRead, watchContent, %hmiBuildWatchLogPath%
    if (!InStr(watchContent, "__LEVORTE_EXIT_CODE__="))
        Return

    SetTimer, HmiBuildLogWatchTick, Off
    hmiBuildWatchActive := false
    AnalyzeHmiBuildLog(hmiBuildWatchLogPath, hmiBuildWatchTitle)
Return

IsHmiBuildLogErrorLine(line)
{
    if (RegExMatch(line, "i)Build FAILED"))
        Return true
    if (RegExMatch(line, "i)error CS\d+"))
        Return true
    if (RegExMatch(line, "i):\s*error\s+"))
        Return true
    if (RegExMatch(line, "i)error MSB\d+"))
        Return true
    if (RegExMatch(line, "i)FATAL:"))
        Return true
    ; Игнорируем итоговые «0 Error(s)» / «1 Warning(s)».
    if (RegExMatch(line, "i)\d+\s+Error\(s\)"))
        Return false
    Return false
}

IsHmiBuildLogWarningLine(line)
{
    if (RegExMatch(line, "i)\d+\s+Warning\(s\)"))
        Return false
    if (RegExMatch(line, "i)warning CS\d+"))
        Return true
    if (RegExMatch(line, "i):\s*warning\s+"))
        Return true
    Return false
}

; Разбор лога: ошибки/предупреждения → tooltip + MsgBox; итог в конце того же файла.
AnalyzeHmiBuildLog(logPath, title := "HMI", writeSummary := true)
{
    global HmiBuildLogErrorPreviewLimit

    if (!FileExist(logPath))
    {
        ShowBuildResultTooltip(false, 3500)
        Return false
    }

    FileRead, content, %logPath%
    ; Убираем предыдущий блок разбора, чтобы файл не разрастался.
    analysisPos := InStr(content, "__LEVORTE_ANALYSIS__")
    if (analysisPos > 0)
        content := SubStr(content, 1, analysisPos - 1)

    errorCount := 0
    warnCount := 0
    exitCode := ""
    errorLines := ""
    previewLimit := HmiBuildLogErrorPreviewLimit
    if (previewLimit < 1)
        previewLimit := 20

    Loop, Parse, content, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            Continue

        if (InStr(line, "__LEVORTE_EXIT_CODE__="))
        {
            if (RegExMatch(line, "-?\d+$", codeOnly))
                exitCode := codeOnly
            Continue
        }

        if (IsHmiBuildLogErrorLine(line))
        {
            errorCount++
            if (errorCount <= previewLimit)
                errorLines .= line . "`r`n"
            Continue
        }

        if (IsHmiBuildLogWarningLine(line))
            warnCount++
    }

    if (exitCode != "" && exitCode != "0" && errorCount = 0)
    {
        errorCount := 1
        errorLines .= "Процесс завершился с кодом " . exitCode . "`r`n"
    }

    if (writeSummary)
    {
        summary := RTrim(content, "`r`n") . "`r`n`r`n__LEVORTE_ANALYSIS__`r`n"
            . title . "`r`n"
            . "Ошибок: " . errorCount . "`r`n"
            . "Предупреждений: " . warnCount . "`r`n"
        if (exitCode != "")
            summary .= "Exit: " . exitCode . "`r`n"
        summary .= "`r`n"
        if (errorLines != "")
            summary .= errorLines
        else
            summary .= "Ошибок компиляции не найдено.`r`n"
        FileDelete, %logPath%
        FileAppend, %summary%, %logPath%
    }

    if (errorCount > 0)
    {
        ShowBuildResultTooltip(false, 4000)
        MsgBox, 48, %title% — ошибки сборки, %errorLines%`nПолный лог:`n%logPath%`n`nПовтор: Ctrl+Alt+L
        Return false
    }

    ShowBuildResultTooltip(true, 3500)
    Return true
}

ShowLastHmiBuildLogAnalysis()
{
    global HmiLastBuildLogPath

    logPath := HmiLastBuildLogPath
    if (logPath = "" || !FileExist(logPath))
        logPath := GetHmiBuildLogPath()

    if (!FileExist(logPath))
    {
        ShowTemporaryTooltip("Лога сборки HMI ещё нет:`n" . logPath, 3000)
        Return
    }

    HmiLastBuildLogPath := logPath
    AnalyzeHmiBuildLog(logPath, "Последний лог HMI")
    Run, notepad.exe "%logPath%"
}

GetLevorteStateIniPath()
{
    Return A_ScriptDir . "\Levorte.state.ini"
}

EnsureHmiTestUiFlagsLoaded()
{
    global hmiTestUiFlagsLoaded
    if (hmiTestUiFlagsLoaded)
        Return
    hmiTestUiFlagsLoaded := true
    LoadHmiTestUiFlags()
}

LoadHmiTestUiFlags()
{
    global HmiDesktopTestUiEnabled, HmiAndroidTestUiEnabled, HmiTestUiIterations

    iniPath := GetLevorteStateIniPath()
    IniRead, desktopVal, %iniPath%, Hmi, DesktopTestUi, 0
    IniRead, androidVal, %iniPath%, Hmi, AndroidTestUi, 0
    IniRead, iterationsVal, %iniPath%, Hmi, TestUiIterations, %HmiTestUiIterations%
    HmiDesktopTestUiEnabled := (desktopVal = "1")
    HmiAndroidTestUiEnabled := (androidVal = "1")
    if (iterationsVal is integer)
    {
        if (iterationsVal < 1)
            iterationsVal := 1
        HmiTestUiIterations := iterationsVal + 0
    }
}

SaveHmiTestUiFlags()
{
    global HmiDesktopTestUiEnabled, HmiAndroidTestUiEnabled, HmiTestUiIterations

    iniPath := GetLevorteStateIniPath()
    desktopVal := HmiDesktopTestUiEnabled ? 1 : 0
    androidVal := HmiAndroidTestUiEnabled ? 1 : 0
    IniWrite, %desktopVal%, %iniPath%, Hmi, DesktopTestUi
    IniWrite, %androidVal%, %iniPath%, Hmi, AndroidTestUi
    IniWrite, %HmiTestUiIterations%, %iniPath%, Hmi, TestUiIterations
}

IsHmiTestUiEnabled(kind)
{
    global HmiDesktopTestUiEnabled, HmiAndroidTestUiEnabled
    EnsureHmiTestUiFlagsLoaded()
    if (kind = "android")
        Return HmiAndroidTestUiEnabled
    Return HmiDesktopTestUiEnabled
}

GetHmiTestUiArgSuffix(kind)
{
    global HmiTestUiArg, HmiTestUiTarget, HmiTestUiIterations, HmiTestUiExtraFlags
    if (!IsHmiTestUiEnabled(kind))
        Return ""
    ; Одинарные кавычки: в powershell -Command точка с запятой не разбивает команду.
    spec := HmiTestUiIterations . ";" . HmiTestUiTarget
    if (HmiTestUiExtraFlags != "")
        spec .= ";" . HmiTestUiExtraFlags
    Return " " . HmiTestUiArg . " '" . spec . "'"
}

GetHmiTestUiStatusText(kind)
{
    if (IsHmiTestUiEnabled(kind))
        Return "вкл"
    Return "выкл"
}

GetHmiTestUiStatusSuffix(kind)
{
    if (IsHmiTestUiEnabled(kind))
        Return " (--test-ui)"
    Return ""
}

ToggleHmiTestUi(kind)
{
    global HmiDesktopTestUiEnabled, HmiAndroidTestUiEnabled
    EnsureHmiTestUiFlagsLoaded()
    if (kind = "android")
        HmiAndroidTestUiEnabled := !HmiAndroidTestUiEnabled
    else
        HmiDesktopTestUiEnabled := !HmiDesktopTestUiEnabled
    SaveHmiTestUiFlags()
}

ChangeHmiTestUiIterations(delta)
{
    global HmiTestUiIterations
    EnsureHmiTestUiFlagsLoaded()
    HmiTestUiIterations += delta
    if (HmiTestUiIterations < 1)
        HmiTestUiIterations := 1
    SaveHmiTestUiFlags()
}

; Диалог Desktop: 1 = запуск, 3 = переключить --test-ui, 5/6 = iterations -/+.
PromptHmiDesktopAction()
{
    global hmiDesktopActionChoice, hmiDesktopActionGuiHwnd, HmiDesktopMenuText

    hmiDesktopActionChoice := ""
    DisableHmiDesktopActionHotkeys()
    HmiDesktopMenuText := BuildHmiDesktopMenuText()

    Gui, HmiDesktopAction:Destroy
    Gui, HmiDesktopAction:New, +AlwaysOnTop +ToolWindow +HwndhmiDesktopActionGuiHwnd, HmiView.Desktop
    Gui, HmiDesktopAction:Margin, 12, 12
    Gui, HmiDesktopAction:Font, s10, Segoe UI
    Gui, HmiDesktopAction:Add, Text, w360 vHmiDesktopMenuText, %HmiDesktopMenuText%
    EnableHmiDesktopActionHotkeys()
    Gui, HmiDesktopAction:Show, AutoSize Center

    WinWaitClose, ahk_id %hmiDesktopActionGuiHwnd%
    Return hmiDesktopActionChoice
}

BuildHmiDesktopMenuText()
{
    global HmiTestUiIterations
    status := GetHmiTestUiStatusText("desktop")
    EnsureHmiTestUiFlagsLoaded()
    return "Выберите действие:`n`n[1] Сборка и запуск`n[3] --test-ui: " . status . "`n[5] Итерации -1`n[6] Итерации +1`n[Esc] Отмена`n`nТекущее значение: " . HmiTestUiIterations
}

HmiDesktopActionRun:
    SelectHmiDesktopAction("run")
Return

HmiDesktopToggleTestUi:
    ToggleHmiTestUi("desktop")
    RefreshHmiDesktopMenuText()
Return

HmiDesktopIterationsDown:
    ChangeHmiTestUiIterations(-1)
    RefreshHmiDesktopMenuText()
Return

HmiDesktopIterationsUp:
    ChangeHmiTestUiIterations(1)
    RefreshHmiDesktopMenuText()
Return

HmiDesktopActionCancel:
HmiDesktopActionGuiEscape:
HmiDesktopActionGuiClose:
    SelectHmiDesktopAction("")
Return

SelectHmiDesktopAction(choice)
{
    global hmiDesktopActionChoice
    hmiDesktopActionChoice := choice
    DisableHmiDesktopActionHotkeys()
    Gui, HmiDesktopAction:Destroy
}

RefreshHmiDesktopMenuText()
{
    global HmiDesktopMenuText
    HmiDesktopMenuText := BuildHmiDesktopMenuText()
    GuiControl, HmiDesktopAction:, HmiDesktopMenuText, %HmiDesktopMenuText%
}

EnableHmiDesktopActionHotkeys()
{
    global hmiDesktopActionGuiHwnd, hmiDesktopActionHotkeysOn

    Hotkey, IfWinActive, ahk_id %hmiDesktopActionGuiHwnd%
    Hotkey, 1, HmiDesktopActionRun, On
    Hotkey, Numpad1, HmiDesktopActionRun, On
    Hotkey, 3, HmiDesktopToggleTestUi, On
    Hotkey, Numpad3, HmiDesktopToggleTestUi, On
    Hotkey, 5, HmiDesktopIterationsDown, On
    Hotkey, Numpad5, HmiDesktopIterationsDown, On
    Hotkey, 6, HmiDesktopIterationsUp, On
    Hotkey, Numpad6, HmiDesktopIterationsUp, On
    Hotkey, IfWinActive
    hmiDesktopActionHotkeysOn := true
}

DisableHmiDesktopActionHotkeys()
{
    global hmiDesktopActionGuiHwnd, hmiDesktopActionHotkeysOn

    if (!hmiDesktopActionHotkeysOn)
        Return

    Hotkey, IfWinActive, ahk_id %hmiDesktopActionGuiHwnd%
    Hotkey, 1, Off
    Hotkey, Numpad1, Off
    Hotkey, 3, Off
    Hotkey, Numpad3, Off
    Hotkey, 5, Off
    Hotkey, Numpad5, Off
    Hotkey, 6, Off
    Hotkey, Numpad6, Off
    Hotkey, IfWinActive
    hmiDesktopActionHotkeysOn := false
}

RunHmiAndroid()
{
    global HmiScriptsDir, HmiAndroidScript, HmiAndroidRobotsArgs, HmiAndroidExtraArgs
    global HmiAndroidProcessSignature

    if (!FileExist(HmiScriptsDir))
    {
        ShowTemporaryTooltip("Каталог не найден: " . HmiScriptsDir, 3000)
        Return
    }

    choice := PromptHmiAndroidAction()
    if (choice = "")
        Return

    if (choice = "logcat")
    {
        RunHmiAndroidLogcat()
        Return
    }

    ; choice = --release | --debug
    if (StopProcessesByCommandSignature(HmiAndroidProcessSignature))
        ShowTemporaryTooltip("Остановлен предыдущий запуск Android HMI", 1500)

    extraArgs := HmiAndroidExtraArgs . GetHmiTestUiArgSuffix("android")
    innerCmd := "& '" . HmiAndroidScript . "' " . HmiAndroidRobotsArgs . " " . choice . " " . extraArgs
    ShowTemporaryTooltip("Android HMI: " . choice . "…", 1500)
    RunHmiLoggedPowerShell("android", "Android HMI (" . choice . ")", innerCmd, false, "Min", true)
    ShowTemporaryTooltip("Android HMI: " . choice . GetHmiTestUiStatusSuffix("android") . "`nЛог пишется…", 2500)
}

; adb logcat → log.txt в каталоге scripts.
RunHmiAndroidLogcat()
{
    global HmiScriptsDir, HmiAndroidLogcatCommand, HmiAndroidLogcatOutputFile

    if (!FileExist(HmiScriptsDir))
    {
        ShowTemporaryTooltip("Каталог не найден: " . HmiScriptsDir, 3000)
        Return
    }

    ShowTemporaryTooltip("Снимаю adb logcat…", 1500)
    RunWait, %ComSpec% /c %HmiAndroidLogcatCommand%, %HmiScriptsDir%, Hide UseErrorLevel
    if (ErrorLevel)
    {
        ShowTemporaryTooltip("adb logcat завершился с ошибкой (" . ErrorLevel . ")", 3000)
        Return
    }

    logPath := HmiScriptsDir . "\" . HmiAndroidLogcatOutputFile
    if (FileExist(logPath))
        ShowTemporaryTooltip("Сохранено: " . logPath, 3000)
    else
        ShowTemporaryTooltip("logcat выполнен, но файл не найден: " . logPath, 3000)

    ; После выгрузки очищаем буферы logcat на планшете, чтобы не копить старые сообщения.
    ShowTemporaryTooltip("Очищаю logcat на планшете…", 1500)
    RunWait, %ComSpec% /c adb logcat -c, %HmiScriptsDir%, Hide UseErrorLevel
}

; Сначала действие (деплой / логи), затем цель SSH.
RunHmiLinuxMenu()
{
    action := PromptHmiLinuxAction()
    if (action = "")
        Return

    if (action = "logs")
        RunHmiLinuxLogsPull()
    else
        RunHmiLinuxDeploy()
}

; Сборка linux-x64 и отправка HMI по SSH (шкаф / пульт / кастом).
RunHmiLinuxDeploy()
{
    global HmiScriptsDir, HmiLinuxDeployScript, HmiLinuxDeployProcessSignature
    global HmiLinuxDeployRemotePath, HmiLinuxDeployAppArgs

    if (!FileExist(HmiScriptsDir))
    {
        ShowTemporaryTooltip("Каталог не найден: " . HmiScriptsDir, 3000)
        Return
    }

    if (!ResolveHmiLinuxSshTarget("Linux HMI — деплой", "Куда отправить сборку?", true, sshUser, sshHost))
        Return

    if (StopProcessesByCommandSignature(HmiLinuxDeployProcessSignature))
        ShowTemporaryTooltip("Остановлен предыдущий деплой Linux HMI", 1500)

    ; Интерактивное окно: при необходимости ввод пароля SSH; вывод дублируется в лог.
    innerCmd := "& '" . HmiLinuxDeployScript . "'"
        . " -SshUser '" . sshUser . "'"
        . " -SshHost '" . sshHost . "'"
        . " -RemotePath '" . HmiLinuxDeployRemotePath . "'"
        . " -AppArgs '" . HmiLinuxDeployAppArgs . "'"
    ShowTemporaryTooltip("Деплой Linux HMI → " . sshUser . "@" . sshHost, 2500)
    RunHmiLoggedPowerShell("linux", "Linux HMI deploy", innerCmd, false, "Min", true)
}

; scp логов ~/.Eidos_robotics/HMI/Logs → C:\ProgramData\Eidos_robotics\HMI\Logs.
RunHmiLinuxLogsPull()
{
    global HmiLinuxLogsRemotePath, HmiLinuxLogsLocalDir

    if (!ResolveHmiLinuxSshTarget("Linux HMI — логи", "Откуда выгрузить логи?", false, sshUser, sshHost))
        Return

    localDest := HmiLinuxLogsLocalDir
    FileCreateDir, %localDest%
    if (ErrorLevel)
    {
        ShowTemporaryTooltip("Не удалось создать папку: " . localDest, 3000)
        Return
    }

    remoteRel := NormalizeSshRemoteHomePath(HmiLinuxLogsRemotePath)
    ; /. — содержимое Logs в локальную папку, без вложенного Logs\Logs.
    remoteSpec := sshUser . "@" . sshHost . ":" . remoteRel . "/."
    scpCmd := "scp -r " . remoteSpec . " """ . localDest . """"
    ShowTemporaryTooltip("Логи ← " . sshUser . "@" . sshHost, 1500)
    RunWait, %ComSpec% /c %scpCmd%,, Min UseErrorLevel
    if (ErrorLevel)
    {
        ShowTemporaryTooltip("Ошибка scp логов (код " . ErrorLevel . ")", 3000)
        Return
    }

    ; После выгрузки очищаем remote-папку, чтобы не копить логи.
    ShowTemporaryTooltip("Очищаю логи на удалённой машине…", 1500)
    sshClearCmd := "ssh " . sshUser . "@" . sshHost . " " . Chr(34) . "rm -rf $HOME/" . remoteRel . "/*" . Chr(34)
    RunWait, %ComSpec% /c %sshClearCmd%,, Min UseErrorLevel
    if (ErrorLevel)
    {
        ShowTemporaryTooltip("Не удалось очистить логи на удалённой машине (код " . ErrorLevel . ")", 3000)
        Return
    }

    ShowTemporaryTooltip("Логи сохранены: " . localDest, 3000)
}

; Диалог: 1 = деплой, 2 = логи. Пустая строка — отмена.
PromptHmiLinuxAction()
{
    global hmiLinuxActionChoice, hmiLinuxActionGuiHwnd

    hmiLinuxActionChoice := ""
    DisableHmiLinuxActionHotkeys()

    Gui, HmiLinuxAction:Destroy
    Gui, HmiLinuxAction:New, +AlwaysOnTop +ToolWindow +HwndhmiLinuxActionGuiHwnd, Linux HMI
    Gui, HmiLinuxAction:Margin, 12, 12
    Gui, HmiLinuxAction:Font, s10, Segoe UI
    Gui, HmiLinuxAction:Add, Text, w360,
    (
Что сделать?

[1] Деплой сборки (шкаф / пульт / кастом)
[2] Выгрузить логи (~/.Eidos_robotics/HMI/Logs)
[Esc] Отмена
    )
    EnableHmiLinuxActionHotkeys()
    Gui, HmiLinuxAction:Show, AutoSize Center

    WinWaitClose, ahk_id %hmiLinuxActionGuiHwnd%
    Return hmiLinuxActionChoice
}

HmiLinuxActionDeploy:
    SelectHmiLinuxAction("deploy")
Return

HmiLinuxActionLogs:
    SelectHmiLinuxAction("logs")
Return

HmiLinuxActionCancel:
HmiLinuxActionGuiEscape:
HmiLinuxActionGuiClose:
    SelectHmiLinuxAction("")
Return

SelectHmiLinuxAction(choice)
{
    global hmiLinuxActionChoice
    hmiLinuxActionChoice := choice
    DisableHmiLinuxActionHotkeys()
    Gui, HmiLinuxAction:Destroy
}

EnableHmiLinuxActionHotkeys()
{
    global hmiLinuxActionGuiHwnd, hmiLinuxActionHotkeysOn

    Hotkey, IfWinActive, ahk_id %hmiLinuxActionGuiHwnd%
    Hotkey, 1, HmiLinuxActionDeploy, On
    Hotkey, Numpad1, HmiLinuxActionDeploy, On
    Hotkey, 2, HmiLinuxActionLogs, On
    Hotkey, Numpad2, HmiLinuxActionLogs, On
    Hotkey, IfWinActive
    hmiLinuxActionHotkeysOn := true
}

DisableHmiLinuxActionHotkeys()
{
    global hmiLinuxActionGuiHwnd, hmiLinuxActionHotkeysOn

    if (!hmiLinuxActionHotkeysOn)
        Return

    Hotkey, IfWinActive, ahk_id %hmiLinuxActionGuiHwnd%
    Hotkey, 1, Off
    Hotkey, Numpad1, Off
    Hotkey, 2, Off
    Hotkey, Numpad2, Off
    Hotkey, IfWinActive
    hmiLinuxActionHotkeysOn := false
}

; Цель SSH. false — отмена; askPasswordless — только для кастомного деплоя.
ResolveHmiLinuxSshTarget(dialogTitle, promptText, askPasswordless, ByRef sshUser, ByRef sshHost)
{
    global HmiLinuxDeployShkafUser, HmiLinuxDeployShkafHost
    global HmiLinuxDeployPultUser, HmiLinuxDeployPultHost

    sshUser := ""
    sshHost := ""
    target := PromptHmiLinuxDeployTarget(dialogTitle, promptText)
    if (target = "")
        Return false

    if (target = "shkaf")
    {
        sshUser := HmiLinuxDeployShkafUser
        sshHost := HmiLinuxDeployShkafHost
        Return true
    }
    if (target = "pult")
    {
        sshUser := HmiLinuxDeployPultUser
        sshHost := HmiLinuxDeployPultHost
        Return true
    }
    if (target != "custom")
        Return false

    customTarget := PromptHmiLinuxDeployCustomTarget()
    if (customTarget = "")
        Return false

    ParseHmiLinuxDeployUserHost(customTarget, sshUser, sshHost)
    if (sshUser = "" || sshHost = "")
    {
        ShowTemporaryTooltip("Некорректные данные для SSH", 3000)
        Return false
    }

    if (!askPasswordless)
        Return true

    setupChoice := PromptHmiSshPasswordlessSetup(sshUser, sshHost)
    if (setupChoice = "cancel")
        Return false
    if (setupChoice = "yes")
        RunHmiSshPasswordlessSetup(sshUser, sshHost)
    Return true
}

; "~/path" → "path": scp на Windows не всегда раскрывает ~ на удалённой стороне.
NormalizeSshRemoteHomePath(remotePath)
{
    if (SubStr(remotePath, 1, 2) = "~/")
        Return SubStr(remotePath, 3)
    if (remotePath = "~")
        Return "."
    Return remotePath
}

; Диалог цели: 1 = шкаф, 2 = пульт, 3 = кастом. Пустая строка — отмена.
PromptHmiLinuxDeployTarget(dialogTitle := "Linux HMI — деплой", promptText := "Куда отправить сборку?")
{
    global hmiLinuxDeployTargetChoice, hmiLinuxDeployTargetGuiHwnd
    global HmiLinuxDeployShkafUser, HmiLinuxDeployShkafHost
    global HmiLinuxDeployPultUser, HmiLinuxDeployPultHost

    hmiLinuxDeployTargetChoice := ""
    DisableHmiLinuxDeployTargetHotkeys()

    shkafLabel := "Шкаф (" . HmiLinuxDeployShkafUser . "@" . HmiLinuxDeployShkafHost . ")"
    pultLabel := "Пульт (" . HmiLinuxDeployPultUser . "@" . HmiLinuxDeployPultHost . ")"

    Gui, HmiLinuxDeployTarget:Destroy
    Gui, HmiLinuxDeployTarget:New, +AlwaysOnTop +ToolWindow +HwndhmiLinuxDeployTargetGuiHwnd, %dialogTitle%
    Gui, HmiLinuxDeployTarget:Margin, 12, 12
    Gui, HmiLinuxDeployTarget:Font, s10, Segoe UI
    Gui, HmiLinuxDeployTarget:Add, Text, w360,
    (
%promptText%

[1] %shkafLabel%
[2] %pultLabel%
[3] Кастом (свой user@IP)
[Esc] Отмена
    )
    EnableHmiLinuxDeployTargetHotkeys()
    Gui, HmiLinuxDeployTarget:Show, AutoSize Center

    WinWaitClose, ahk_id %hmiLinuxDeployTargetGuiHwnd%
    Return hmiLinuxDeployTargetChoice
}

HmiLinuxDeployTargetShkaf:
    SelectHmiLinuxDeployTarget("shkaf")
Return

HmiLinuxDeployTargetPult:
    SelectHmiLinuxDeployTarget("pult")
Return

HmiLinuxDeployTargetCustom:
    SelectHmiLinuxDeployTarget("custom")
Return

HmiLinuxDeployTargetCancel:
    SelectHmiLinuxDeployTarget("")
Return

HmiLinuxDeployTargetGuiEscape:
    SelectHmiLinuxDeployTarget("")
Return

HmiLinuxDeployTargetGuiClose:
    SelectHmiLinuxDeployTarget("")
Return

SelectHmiLinuxDeployTarget(choice)
{
    global hmiLinuxDeployTargetChoice
    hmiLinuxDeployTargetChoice := choice
    DisableHmiLinuxDeployTargetHotkeys()
    Gui, HmiLinuxDeployTarget:Destroy
}

EnableHmiLinuxDeployTargetHotkeys()
{
    global hmiLinuxDeployTargetGuiHwnd, hmiLinuxDeployTargetHotkeysOn

    Hotkey, IfWinActive, ahk_id %hmiLinuxDeployTargetGuiHwnd%
    Hotkey, 1, HmiLinuxDeployTargetShkaf, On
    Hotkey, Numpad1, HmiLinuxDeployTargetShkaf, On
    Hotkey, 2, HmiLinuxDeployTargetPult, On
    Hotkey, Numpad2, HmiLinuxDeployTargetPult, On
    Hotkey, 3, HmiLinuxDeployTargetCustom, On
    Hotkey, Numpad3, HmiLinuxDeployTargetCustom, On
    Hotkey, IfWinActive
    hmiLinuxDeployTargetHotkeysOn := true
}

DisableHmiLinuxDeployTargetHotkeys()
{
    global hmiLinuxDeployTargetGuiHwnd, hmiLinuxDeployTargetHotkeysOn

    ; Нельзя вызывать Hotkey Off, пока хоткеи ещё не регистрировались.
    if (!hmiLinuxDeployTargetHotkeysOn)
        Return

    Hotkey, IfWinActive, ahk_id %hmiLinuxDeployTargetGuiHwnd%
    Hotkey, 1, Off
    Hotkey, Numpad1, Off
    Hotkey, 2, Off
    Hotkey, Numpad2, Off
    Hotkey, 3, Off
    Hotkey, Numpad3, Off
    Hotkey, IfWinActive
    hmiLinuxDeployTargetHotkeysOn := false
}

; Запрос user и IP для кастомного деплоя. Возвращает "user@host" или "".
PromptHmiLinuxDeployCustomTarget()
{
    InputBox, sshUser, Linux HMI — кастом, Имя пользователя SSH:, , 360, 140
    if (ErrorLevel || sshUser = "")
        Return ""

    InputBox, sshHost, Linux HMI — кастом, IP-адрес удалённой машины:, , 360, 140
    if (ErrorLevel || sshHost = "")
        Return ""

    sshUser := Trim(sshUser)
    sshHost := Trim(sshHost)
    if (sshUser = "" || sshHost = "")
        Return ""

    Return sshUser . "@" . sshHost
}

ParseHmiLinuxDeployUserHost(userHost, ByRef sshUser, ByRef sshHost)
{
    sshUser := ""
    sshHost := ""
    atPos := InStr(userHost, "@")
    if (atPos <= 1)
        Return
    sshUser := SubStr(userHost, 1, atPos - 1)
    sshHost := SubStr(userHost, atPos + 1)
}

; yes / no / cancel — настройка беспарольного SSH для кастома.
PromptHmiSshPasswordlessSetup(sshUser, sshHost)
{
    MsgBox, 3, Linux HMI — SSH, Настроить беспарольный доступ для %sshUser%@%sshHost%?`n`nДа — запустить setup_ssh_passwordless.ps1`nНет — сразу деплой`nОтмена — прервать
    IfMsgBox, Yes
        Return "yes"
    IfMsgBox, No
        Return "no"
    Return "cancel"
}

; Интерактивный запуск настройки SSH-ключей (пароль вводится в консоли).
RunHmiSshPasswordlessSetup(sshUser, sshHost)
{
    global HmiScriptsDir, HmiSshPasswordlessScript

    psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    scriptArgs := "-File """ . HmiSshPasswordlessScript . """"
        . " -SshUser """ . sshUser . """"
        . " -SshHost """ . sshHost . """"
    runCmd := """" . psExe . """ -NoProfile -ExecutionPolicy Bypass " . scriptArgs
    ShowTemporaryTooltip("Настройка SSH: " . sshUser . "@" . sshHost, 2000)
    RunWait, %runCmd%, %HmiScriptsDir%, Min
}

; Диалог: 1 = --release, 2 = --debug, 3 = переключить --test-ui, 4 = logcat, 5/6 = iterations -/+.
PromptHmiAndroidAction()
{
    global hmiAndroidBuildConfigChoice, hmiAndroidBuildConfigGuiHwnd, HmiAndroidMenuText

    hmiAndroidBuildConfigChoice := ""
    DisableHmiAndroidBuildConfigHotkeys()
    HmiAndroidMenuText := BuildHmiAndroidMenuText()

    Gui, HmiAndroidBuildConfig:Destroy
    Gui, HmiAndroidBuildConfig:New, +AlwaysOnTop +ToolWindow +HwndhmiAndroidBuildConfigGuiHwnd, Android HMI
    Gui, HmiAndroidBuildConfig:Margin, 12, 12
    Gui, HmiAndroidBuildConfig:Font, s10, Segoe UI
    Gui, HmiAndroidBuildConfig:Add, Text, w360 vHmiAndroidMenuText, %HmiAndroidMenuText%
    EnableHmiAndroidBuildConfigHotkeys()
    Gui, HmiAndroidBuildConfig:Show, AutoSize Center

    WinWaitClose, ahk_id %hmiAndroidBuildConfigGuiHwnd%
    Return hmiAndroidBuildConfigChoice
}

BuildHmiAndroidMenuText()
{
    global HmiTestUiIterations
    status := GetHmiTestUiStatusText("android")
    EnsureHmiTestUiFlagsLoaded()
    return "Выберите действие:`n`n[1] --release`n[2] --debug`n[3] --test-ui: " . status . "`n[4] adb logcat → log.txt`n[5] Итерации -1`n[6] Итерации +1`n[Esc] Отмена`n`nТекущее значение: " . HmiTestUiIterations
}

HmiAndroidBuildConfigRelease:
    SelectHmiAndroidBuildConfig("--release")
Return

HmiAndroidBuildConfigDebug:
    SelectHmiAndroidBuildConfig("--debug")
Return

HmiAndroidToggleTestUi:
    ToggleHmiTestUi("android")
    RefreshHmiAndroidMenuText()
Return

HmiAndroidIterationsDown:
    ChangeHmiTestUiIterations(-1)
    RefreshHmiAndroidMenuText()
Return

HmiAndroidIterationsUp:
    ChangeHmiTestUiIterations(1)
    RefreshHmiAndroidMenuText()
Return

HmiAndroidBuildConfigLogcat:
    SelectHmiAndroidBuildConfig("logcat")
Return

HmiAndroidBuildConfigNumberHotkey:
    if (A_ThisHotkey = "1" || A_ThisHotkey = "Numpad1")
        SelectHmiAndroidBuildConfig("--release")
    else if (A_ThisHotkey = "2" || A_ThisHotkey = "Numpad2")
        SelectHmiAndroidBuildConfig("--debug")
    else if (A_ThisHotkey = "3" || A_ThisHotkey = "Numpad3")
        Gosub, HmiAndroidToggleTestUi
    else if (A_ThisHotkey = "4" || A_ThisHotkey = "Numpad4")
        SelectHmiAndroidBuildConfig("logcat")
    else if (A_ThisHotkey = "5" || A_ThisHotkey = "Numpad5")
        Gosub, HmiAndroidIterationsDown
    else if (A_ThisHotkey = "6" || A_ThisHotkey = "Numpad6")
        Gosub, HmiAndroidIterationsUp
Return

HmiAndroidBuildConfigCancel:
HmiAndroidBuildConfigGuiClose:
HmiAndroidBuildConfigGuiEscape:
    SelectHmiAndroidBuildConfig("")
Return

SelectHmiAndroidBuildConfig(buildConfig)
{
    global hmiAndroidBuildConfigChoice

    hmiAndroidBuildConfigChoice := buildConfig
    DisableHmiAndroidBuildConfigHotkeys()
    Gui, HmiAndroidBuildConfig:Destroy
}

RefreshHmiAndroidMenuText()
{
    global HmiAndroidMenuText
    HmiAndroidMenuText := BuildHmiAndroidMenuText()
    GuiControl, HmiAndroidBuildConfig:, HmiAndroidMenuText, %HmiAndroidMenuText%
}

EnableHmiAndroidBuildConfigHotkeys()
{
    global hmiAndroidBuildConfigGuiHwnd, hmiAndroidBuildConfigHotkeysOn

    Hotkey, IfWinActive, ahk_id %hmiAndroidBuildConfigGuiHwnd%
    Hotkey, 1, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad1, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, 2, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad2, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, 3, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad3, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, 4, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad4, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, 5, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad5, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, 6, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad6, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, IfWinActive
    hmiAndroidBuildConfigHotkeysOn := true
}

DisableHmiAndroidBuildConfigHotkeys()
{
    global hmiAndroidBuildConfigGuiHwnd, hmiAndroidBuildConfigHotkeysOn

    if (!hmiAndroidBuildConfigHotkeysOn)
        Return

    Hotkey, IfWinActive, ahk_id %hmiAndroidBuildConfigGuiHwnd%
    Hotkey, 1, Off
    Hotkey, Numpad1, Off
    Hotkey, 2, Off
    Hotkey, Numpad2, Off
    Hotkey, 3, Off
    Hotkey, Numpad3, Off
    Hotkey, 4, Off
    Hotkey, Numpad4, Off
    Hotkey, 5, Off
    Hotkey, Numpad5, Off
    Hotkey, 6, Off
    Hotkey, Numpad6, Off
    Hotkey, IfWinActive
    hmiAndroidBuildConfigHotkeysOn := false
}

; Завершает процессы PowerShell / pwsh / dotnet, в командной строке которых есть signature.
StopProcessesByCommandSignature(signature)
{
    if (signature = "")
        Return false

    killedAny := false
    currentPid := DllCall("GetCurrentProcessId")

    try
    {
        query := "SELECT ProcessId, CommandLine FROM Win32_Process"
            . " WHERE Name='powershell.exe' OR Name='pwsh.exe' OR Name='dotnet.exe'"
        processes := ComObjGet("winmgmts:").ExecQuery(query)

        for process in processes
        {
            cmdLine := process.CommandLine
            if (cmdLine = "" || !InStr(cmdLine, signature))
                Continue

            pid := process.ProcessId + 0
            if (pid <= 0 || pid = currentPid)
                Continue

            RunWait, %ComSpec% /c taskkill /PID %pid% /T /F,, Hide UseErrorLevel
            if (!ErrorLevel)
                killedAny := true
        }
    }
    catch
    {
    }

    if (killedAny)
        Sleep, 500

    Return killedAny
}
