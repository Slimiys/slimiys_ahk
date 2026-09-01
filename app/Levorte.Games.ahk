; ============================================================
; Игровые хоткеи (Path of Exile)
; ============================================================

; --- Hotkey Torchlight Infinite ---
; toggle удержания клавиши A
global TorchlightInfiniteAToggled := false
global TorchlightInfiniteModeEnabled := false

OnExit, TorchlightInfiniteARelease

TorchlightInfiniteARelease:
if (TorchlightInfiniteAToggled)
    TorchlightInfiniteReleaseA()
Return

IsTorchlightInfiniteWindowActive()
{
    return WinActive("Torchlight: Infinite")
}

IsTorchlightInfiniteRButtonModeActive()
{
    global TorchlightInfiniteModeEnabled
    return TorchlightInfiniteModeEnabled && IsTorchlightInfiniteWindowActive()
}

ToggleTorchlightInfiniteRButtonMode()
{
    global TorchlightInfiniteModeEnabled
    TorchlightInfiniteModeEnabled := !TorchlightInfiniteModeEnabled
    if (TorchlightInfiniteModeEnabled)
        ShowTemporaryTooltip("Режим ПКМ→A: включён", 1500)
    else
    {
        if (TorchlightInfiniteAToggled)
            TorchlightInfiniteReleaseA()
        ShowTemporaryTooltip("Режим ПКМ→A: выключен", 1500)
    }
}

TorchlightInfinitePressA()
{
    global TorchlightInfiniteAToggled
    SendInput {Blind}{a down}
    TorchlightInfiniteAToggled := true
    ; Периодически переотправляем down, чтобы A не «отлипала» в игре/при потере фокуса.
    SetTimer, TorchlightInfiniteAHoldPulse, 120
    SetTimer, TorchlightInfiniteAEnsureRelease, 200
}

TorchlightInfiniteReleaseA()
{
    global TorchlightInfiniteAToggled
    SendInput {Blind}{a up}
    TorchlightInfiniteAToggled := false
    SetTimer, TorchlightInfiniteAHoldPulse, Off
    SetTimer, TorchlightInfiniteAEnsureRelease, Off
}

; Alt+Ctrl+A — включить/выключить режим «ПКМ отпустил → A зажата».
#If IsTorchlightInfiniteWindowActive()
!^a::
    ToggleTorchlightInfiniteRButtonMode()
Return
#If

; Режим активен только после включения через Alt+Ctrl+A.
#If IsTorchlightInfiniteRButtonModeActive()
~RButton::
    if (TorchlightInfiniteAToggled)
        TorchlightInfiniteReleaseA()
Return

~RButton Up::
    ; Небольшая задержка: сначала завершается обработка нажатия ПКМ, затем зажимаем A.
    SetTimer, TorchlightInfiniteAOnRButtonUp, -15
Return
#If

TorchlightInfiniteAOnRButtonUp:
    if (!IsTorchlightInfiniteRButtonModeActive())
        Return
    TorchlightInfinitePressA()
Return

TorchlightInfiniteAHoldPulse:
    if (!TorchlightInfiniteAToggled)
        Return
    if (!IsTorchlightInfiniteRButtonModeActive())
        Return
    SendInput {Blind}{a down}
Return

TorchlightInfiniteAEnsureRelease:
    if (!TorchlightInfiniteAToggled)
        Return
    if (!IsTorchlightInfiniteRButtonModeActive())
        TorchlightInfiniteReleaseA()
Return

#if WinActive("Path of Exile")

    !Enter::
        ToggleAutoEnter()
    Return

#if Toggle
    Enter::
        ToggleAutoEnter()
    Return
#if

AutoEnter:
    if (Toggle)
    {
        Send, {Enter}
    }
Return

+NumpadLeft::
    UpdatePoEFilter(True)
Return

+NumpadRight::
    UpdatePoEFilter(False)
Return

; Временно отключено
; +NumpadHome::
;     UpdatePoEBuild(True)
; Return

+NumpadPgUp::
    UpdatePoEBuild(False)
Return

; --- Функции ---
ToggleAutoEnter()
{
    global Toggle
    Toggle := !Toggle
    if (Toggle)
        SetTimer, AutoEnter, 500
    else
        SetTimer, AutoEnter, Off
}

UpdatePoEFilter(isPoE1)
{
    global Poe1FilterPath, Poe2FilterPath, DownloadsFilterMask
    path := Poe1FilterPath
    if isPoE1 = 0
    {
        path := Poe2FilterPath
    }

    IfExist, %DownloadsFilterMask%
    {
        Loop, %DownloadsFilterMask%
        {
            FileMove, %A_LoopFileFullPath%, %path%\defaultFilter.filter, 1
        }
        MsgBox,,, Success, 0.5
        WinActivate, Path of Exile
        Return
    }
    MsgBox,,, File not exist
}

UpdatePoEBuild(isPoE1)
{
    global Poe1BuildPath, Poe2BuildPath, DownloadsBuildMask
    path := Poe1BuildPath
    if isPoE1 = 0
    {
        path := Poe2BuildPath
    }

    IfExist, %DownloadsBuildMask%
    {
        if !FileExist(path)
            FileCreateDir, %path%
        Loop, %DownloadsBuildMask%
        {
            FileCopy, %A_LoopFileFullPath%, %path%\%A_LoopFileName%, 1
        }
        MsgBox,,, Success, 0.5
        WinActivate, Path of Exile
        Return
    }
    MsgBox,,, File not exist
}

CheckAndDownloadPoEFilter()
{
    global DownloadsFilterMask
    WinGetClass, WinClass, A
    if (WinClass != "Chrome_WidgetWin_1")
    {
        return true
    }

    ClipboardOld := ClipboardAll
    Send, ^l
    Sleep, 200
    Send, ^c
    Sleep, 200
    CurrentURL := Clipboard
    Clipboard := ClipboardOld

    if (InStr(CurrentURL, "poe2filter.com"))
    {
        Send, ^f
        Sleep, 300
        Send, Download
        Sleep, 300
        Send, {Esc}
        Sleep, 200
        Send, {Enter}
        Sleep, 200

        Loop, 150
        {
            IfExist, %DownloadsFilterMask%
            {
                Sleep, 1000
                return true
            }
            Sleep, 100
        }

        MsgBox,,, Не удалось скачать файл
        return false
    }

    return true
}
