; ============================================================
; Базовая инициализация и общие хоткеи
; ============================================================

; --- Инициализация окружения ---
if (!A_IsAdmin)
{
    try
    {
        Run *RunAs "%A_ScriptFullPath%"
        ExitApp
    }
    catch
    {
        MsgBox, 16, Ошибка, Скрипт требует права администратора для работы!
        ExitApp
    }
}

CoordMode, Mouse, Window
CoordMode, ToolTip, Window
SetMouseDelay, 5

SetCapsLockState, Off
SetNumLockState, Off
SetTitleMatchMode, 1

; --- Хоткеи ---
; Вывод заголовка и класса активного окна (для отладки WinActive)
^!w::
    WinGetTitle, ActiveTitle, A
    WinGetClass, ActiveClass, A
    ShowTemporaryTooltip("Заголовок: " . ActiveTitle . "`nКласс: " . ActiveClass, 3000)
Return

^NumpadSub::
    Send, masterkey{Enter}
Return

^NumpadDel::
    MsgBox,,, Restart, 0.5
    Reload
Return

!Q::
    SendInput, ^#{Left}
Return

!W::
    SendInput, ^#{Right}
Return

; --- Вспомогательные функции ---
; Экранные координаты курсора (не зависят от CoordMode, Mouse).
GetCursorScreenPos(ByRef screenX, ByRef screenY)
{
    VarSetCapacity(pt, 8, 0)
    DllCall("GetCursorPos", "Ptr", &pt)
    screenX := NumGet(pt, 0, "Int")
    screenY := NumGet(pt, 4, "Int")
}

RemoveActiveWindowToolTip:
    ToolTip
Return

ShowTemporaryTooltip(message, durationMs := 2000)
{
    ToolTip, %message%
    SetTimer, RemoveActiveWindowToolTip, % -durationMs
}
