; ============================================================
; Хоткеи разработки (HMI и прочие проекты)
; ============================================================

global hmiAndroidBuildConfigChoice := ""
global hmiAndroidBuildConfigGuiHwnd := ""
global hmiLinuxDeployTargetChoice := ""
global hmiLinuxDeployTargetGuiHwnd := ""
global hmiLinuxDeployTargetHotkeysOn := false

; --- Хоткеи ---
; Сборка и запуск HmiView.Desktop из каталога scripts репозитория rcs_hmi_xplat.
^!z::
    RunHmiDesktop()
Return

; Android HMI: диалог 1=release, 2=debug, 3=adb logcat → log.txt.
^!x::
    RunHmiAndroid()
Return

; Linux HMI: сборка и деплой по SSH (шкаф / пульт / кастом).
^!c::
    RunHmiLinuxDeploy()
Return

; --- Функции ---
RunHmiDesktop()
{
    global HmiScriptsDir, HmiDesktopShellCommands, HmiDesktopProcessSignature

    if (!FileExist(HmiScriptsDir))
    {
        ShowTemporaryTooltip("Каталог не найден: " . HmiScriptsDir, 3000)
        Return
    }

    if (StopProcessesByCommandSignature(HmiDesktopProcessSignature))
        ShowTemporaryTooltip("Остановлен предыдущий запуск HmiView.Desktop", 1500)

    psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    runCmd := """" psExe """ -NoProfile -Command """ HmiDesktopShellCommands """"
    Run, %runCmd%, %HmiScriptsDir%, Min
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

    psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    runCmd := """" psExe """ -NoProfile -Command ""& '" . HmiAndroidScript . "' " . HmiAndroidRobotsArgs . " " . choice . " " . HmiAndroidExtraArgs . """"
    Run, %runCmd%, %HmiScriptsDir%, Min
    ShowTemporaryTooltip("Android HMI: " . choice, 2000)
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
}

; Сборка linux-x64 и отправка HMI по SSH (шкаф / пульт / кастом).
RunHmiLinuxDeploy()
{
    global HmiScriptsDir, HmiLinuxDeployScript, HmiLinuxDeployProcessSignature
    global HmiLinuxDeployShkafUser, HmiLinuxDeployShkafHost
    global HmiLinuxDeployPultUser, HmiLinuxDeployPultHost
    global HmiLinuxDeployRemotePath

    if (!FileExist(HmiScriptsDir))
    {
        ShowTemporaryTooltip("Каталог не найден: " . HmiScriptsDir, 3000)
        Return
    }

    target := PromptHmiLinuxDeployTarget()
    if (target = "")
        Return

    sshUser := ""
    sshHost := ""

    if (target = "shkaf")
    {
        sshUser := HmiLinuxDeployShkafUser
        sshHost := HmiLinuxDeployShkafHost
    }
    else if (target = "pult")
    {
        sshUser := HmiLinuxDeployPultUser
        sshHost := HmiLinuxDeployPultHost
    }
    else if (target = "custom")
    {
        customTarget := PromptHmiLinuxDeployCustomTarget()
        if (customTarget = "")
            Return

        ParseHmiLinuxDeployUserHost(customTarget, sshUser, sshHost)
        if (sshUser = "" || sshHost = "")
        {
            ShowTemporaryTooltip("Некорректные данные для SSH", 3000)
            Return
        }

        setupChoice := PromptHmiSshPasswordlessSetup(sshUser, sshHost)
        if (setupChoice = "cancel")
            Return
        if (setupChoice = "yes")
            RunHmiSshPasswordlessSetup(sshUser, sshHost)
    }
    else
        Return

    if (StopProcessesByCommandSignature(HmiLinuxDeployProcessSignature))
        ShowTemporaryTooltip("Остановлен предыдущий деплой Linux HMI", 1500)

    ; Интерактивное окно: при необходимости ввод пароля SSH.
    psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    scriptArgs := "-File """ . HmiLinuxDeployScript . """"
        . " -SshUser """ . sshUser . """"
        . " -SshHost """ . sshHost . """"
        . " -RemotePath """ . HmiLinuxDeployRemotePath . """"
    runCmd := """" . psExe . """ -NoProfile -ExecutionPolicy Bypass " . scriptArgs
    Run, %runCmd%, %HmiScriptsDir%
    ShowTemporaryTooltip("Деплой Linux HMI → " . sshUser . "@" . sshHost, 2500)
}

; Диалог цели: 1 = шкаф, 2 = пульт, 3 = кастом. Пустая строка — отмена.
PromptHmiLinuxDeployTarget()
{
    global hmiLinuxDeployTargetChoice, hmiLinuxDeployTargetGuiHwnd
    global HmiLinuxDeployShkafUser, HmiLinuxDeployShkafHost
    global HmiLinuxDeployPultUser, HmiLinuxDeployPultHost

    hmiLinuxDeployTargetChoice := ""
    DisableHmiLinuxDeployTargetHotkeys()

    shkafLabel := "Шкаф (" . HmiLinuxDeployShkafUser . "@" . HmiLinuxDeployShkafHost . ")"
    pultLabel := "Пульт (" . HmiLinuxDeployPultUser . "@" . HmiLinuxDeployPultHost . ")"

    Gui, HmiLinuxDeployTarget:Destroy
    Gui, HmiLinuxDeployTarget:New, +AlwaysOnTop +ToolWindow +HwndhmiLinuxDeployTargetGuiHwnd, Linux HMI — деплой
    Gui, HmiLinuxDeployTarget:Margin, 12, 12
    Gui, HmiLinuxDeployTarget:Font, s10, Segoe UI
    Gui, HmiLinuxDeployTarget:Add, Text, w360,
    (
Куда отправить сборку?

[1] %shkafLabel%
[2] %pultLabel%
[3] Кастом (свой user@IP)
    )
    Gui, HmiLinuxDeployTarget:Add, Button, x12 y130 w112 h28 gHmiLinuxDeployTargetShkaf Default, 1 — Шкаф
    Gui, HmiLinuxDeployTarget:Add, Button, x132 y130 w112 h28 gHmiLinuxDeployTargetPult, 2 — Пульт
    Gui, HmiLinuxDeployTarget:Add, Button, x252 y130 w120 h28 gHmiLinuxDeployTargetCustom, 3 — Кастом
    Gui, HmiLinuxDeployTarget:Add, Button, x12 y168 w360 h28 gHmiLinuxDeployTargetCancel, Отмена (Esc)
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
    RunWait, %runCmd%, %HmiScriptsDir%
}

; Диалог: 1 = --release, 2 = --debug, 3 = logcat. Пустая строка — отмена.
PromptHmiAndroidAction()
{
    global hmiAndroidBuildConfigChoice, hmiAndroidBuildConfigGuiHwnd

    hmiAndroidBuildConfigChoice := ""
    DisableHmiAndroidBuildConfigHotkeys()

    Gui, HmiAndroidBuildConfig:Destroy
    Gui, HmiAndroidBuildConfig:New, +AlwaysOnTop +ToolWindow +HwndhmiAndroidBuildConfigGuiHwnd, Android HMI
    Gui, HmiAndroidBuildConfig:Margin, 12, 12
    Gui, HmiAndroidBuildConfig:Font, s10, Segoe UI
    Gui, HmiAndroidBuildConfig:Add, Text, w280,
    (
Выберите действие:

[1] --release
[2] --debug
[3] adb logcat → log.txt
    )
    Gui, HmiAndroidBuildConfig:Add, Button, x12 y130 w88 h28 gHmiAndroidBuildConfigRelease Default, 1 — release
    Gui, HmiAndroidBuildConfig:Add, Button, x108 y130 w88 h28 gHmiAndroidBuildConfigDebug, 2 — debug
    Gui, HmiAndroidBuildConfig:Add, Button, x204 y130 w88 h28 gHmiAndroidBuildConfigLogcat, 3 — logcat
    Gui, HmiAndroidBuildConfig:Add, Button, x12 y168 w280 h28 gHmiAndroidBuildConfigCancel, Отмена (Esc)
    EnableHmiAndroidBuildConfigHotkeys()
    Gui, HmiAndroidBuildConfig:Show, AutoSize Center

    WinWaitClose, ahk_id %hmiAndroidBuildConfigGuiHwnd%
    Return hmiAndroidBuildConfigChoice
}

HmiAndroidBuildConfigRelease:
    SelectHmiAndroidBuildConfig("--release")
Return

HmiAndroidBuildConfigDebug:
    SelectHmiAndroidBuildConfig("--debug")
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
        SelectHmiAndroidBuildConfig("logcat")
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

EnableHmiAndroidBuildConfigHotkeys()
{
    global hmiAndroidBuildConfigGuiHwnd

    Hotkey, IfWinActive, ahk_id %hmiAndroidBuildConfigGuiHwnd%
    Hotkey, 1, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad1, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, 2, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad2, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, 3, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, Numpad3, HmiAndroidBuildConfigNumberHotkey, On
    Hotkey, IfWinActive
}

DisableHmiAndroidBuildConfigHotkeys()
{
    global hmiAndroidBuildConfigGuiHwnd

    if (hmiAndroidBuildConfigGuiHwnd)
        Hotkey, IfWinActive, ahk_id %hmiAndroidBuildConfigGuiHwnd%
    Hotkey, 1, HmiAndroidBuildConfigNumberHotkey, Off
    Hotkey, Numpad1, HmiAndroidBuildConfigNumberHotkey, Off
    Hotkey, 2, HmiAndroidBuildConfigNumberHotkey, Off
    Hotkey, Numpad2, HmiAndroidBuildConfigNumberHotkey, Off
    Hotkey, 3, HmiAndroidBuildConfigNumberHotkey, Off
    Hotkey, Numpad3, HmiAndroidBuildConfigNumberHotkey, Off
    Hotkey, IfWinActive
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
