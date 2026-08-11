; ============================================================
; Игровые хоткеи (Path of Exile)
; ============================================================

; --- Хоткеи ---
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
