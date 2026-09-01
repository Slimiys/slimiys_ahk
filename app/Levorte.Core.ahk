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
    CompileLevorteFromScripts()
Return

; Запуск scripts\Compile-Levorte.ps1 (убивает текущий exe, собирает и стартует заново).
CompileLevorteFromScripts()
{
    scriptPath := ResolveCompileLevorteScriptPath()
    if (!FileExist(scriptPath))
    {
        ShowTemporaryTooltip("Не найден: " . scriptPath, 3000)
        Return
    }

    ShowTemporaryTooltip("Сборка Levorte…", 1500)
    psExe := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    ; *RunAs: нужны права админа, чтобы завершить текущий Levorte.exe и перезаписать build\.
    Run *RunAs "%psExe%" -NoProfile -ExecutionPolicy Bypass -File "%scriptPath%",, Min
}

; Alt снимаем до Win: иначе при повторных нажатиях Win+Alt+W открывает Game Bar (Broadcasting).
$!Q::
    SwitchVirtualDesktop("Left")
Return

$!W::
    SwitchVirtualDesktop("Right")
Return

; --- Вспомогательные функции ---
; Переключение виртуального рабочего стола без залипания Win/Alt.
SwitchVirtualDesktop(direction)
{
    SendInput {Blind}{LAlt up}{RAlt up}{LWin up}{RWin up}
    if (direction = "Left")
        SendInput {LCtrl down}{LWin down}{Left}{LWin up}{LCtrl up}
    else
        SendInput {LCtrl down}{LWin down}{Right}{LWin up}{LCtrl up}
}

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

; Тултип с цветным фоном (результат сборки и т.п.) — левый верхний угол.
ShowColoredTooltip(message, bgColor, durationMs := 3500)
{
    global buildStatusTooltipHwnd, BuildStatusTooltipInner, BuildStatusTooltipText, BuildStatusMeasureText

    ; Скрываем обычный ToolTip, чтобы не перекрывался.
    ToolTip
    SetTimer, RemoveActiveWindowToolTip, Off

    Gui, BuildStatusTooltipMeasure:Destroy
    Gui, BuildStatusTooltipMeasure:New
    Gui, BuildStatusTooltipMeasure:Margin, 0, 0
    Gui, BuildStatusTooltipMeasure:Font, s10 cFFFFFF, Segoe UI
    Gui, BuildStatusTooltipMeasure:Add, Text, vBuildStatusMeasureText x0 y0, %message%
    Gui, BuildStatusTooltipMeasure:Show, Hide x-32000 y-32000
    GuiControlGet, textRect, BuildStatusTooltipMeasure:Pos, BuildStatusMeasureText
    Gui, BuildStatusTooltipMeasure:Destroy

    paddingX := 4
    paddingY := 2
    textWidth := textRectW + 2
    textHeight := textRectH + 1
    outerW := textWidth + (paddingX * 2)
    outerH := textHeight + (paddingY * 2)

    Gui, BuildStatusTooltip:Destroy
    Gui, BuildStatusTooltip:New, +AlwaysOnTop -Caption +ToolWindow +HwndbuildStatusTooltipHwnd +LastFound -Theme
    Gui, BuildStatusTooltip:Margin, 0, 0
    Gui, BuildStatusTooltip:Color, %bgColor%
    Gui, BuildStatusTooltip:Font, s10 cFFFFFF, Segoe UI
    Gui, BuildStatusTooltip:Add, Progress, vBuildStatusTooltipInner x0 y0 w%outerW% h%outerH% c%bgColor% Background%bgColor% Range0-100, 100
    Gui, BuildStatusTooltip:Add, Text, vBuildStatusTooltipText x%paddingX% y%paddingY% w%textWidth% h%textHeight% +BackgroundTrans Center, %message%
    Gui, BuildStatusTooltip:Show, Hide x-32000 y-32000 w%outerW% h%outerH%

    ; Левый верхний угол рабочей области основного монитора.
    SysGet, wa, MonitorWorkArea, 1
    edgeMargin := 8
    posX := waLeft + edgeMargin
    posY := waTop + edgeMargin

    showOpts := "NA x" posX " y" posY " w" outerW " h" outerH
    Gui, BuildStatusTooltip:Show, %showOpts%
    SetTimer, HideBuildStatusTooltip, % -durationMs
}

HideBuildStatusTooltip:
    Gui, BuildStatusTooltip:Hide
Return

; Зелёный «Успех» / красный «Провал».
ShowBuildResultTooltip(success, durationMs := 4000)
{
    global BuildTooltipSuccessBgColor, BuildTooltipFailureBgColor
    if (success)
        ShowColoredTooltip("Успех", BuildTooltipSuccessBgColor, durationMs)
    else
        ShowColoredTooltip("Провал", BuildTooltipFailureBgColor, durationMs)
}
