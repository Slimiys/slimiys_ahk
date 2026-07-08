; ============================================================
; Хоткеи разработки (HMI и прочие проекты)
; ============================================================

; --- Хоткеи ---
; Сборка и запуск HmiView.Desktop из каталога scripts репозитория rcs_hmi_xplat.
^!z::
    RunHmiDesktop()
Return

; --- Функции ---
RunHmiDesktop()
{
    global HmiScriptsDir, HmiDesktopShellCommands

    if (!FileExist(HmiScriptsDir))
    {
        ShowTemporaryTooltip("Каталог не найден: " . HmiScriptsDir, 3000)
        Return
    }

    if (StopMatchingHmiDesktopProcesses())
        ShowTemporaryTooltip("Остановлен предыдущий запуск HmiView.Desktop", 1500)

    psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    runCmd := """" psExe """ -NoProfile -Command """ HmiDesktopShellCommands """"
    Run, %runCmd%, %HmiScriptsDir%, Min
}

; Завершает PowerShell / dotnet с той же командой и аргументами, что и хоткей.
StopMatchingHmiDesktopProcesses()
{
    global HmiDesktopProcessSignature

    if (HmiDesktopProcessSignature = "")
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
            if (cmdLine = "" || !InStr(cmdLine, HmiDesktopProcessSignature))
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
