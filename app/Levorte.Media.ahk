; ============================================================
; Мультимедиа (Яндекс Музыка и системная громкость)
; ============================================================

; --- Хоткеи ---
#if WinExist("Яндекс")

    !^d::
        ControlYandexMusic("d")
    Return

    !^f::
        ControlYandexMusic("f")
    Return

    !WheelUp::
        Send, {Media_Prev}
    Return

    !WheelDown::
        Send, {Media_Next}
    Return

    !MButton::
        Send, {Media_Play_Pause}
    Return

#if

^!NumpadDiv::
    ToggleMute()
Return

^NumpadDiv::
    ChangeMasterVolumeByStep(-10)
Return

^NumpadMult::
    ChangeMasterVolumeByStep(10)
Return

; --- Функции ---
ControlYandexMusic(key)
{
    WinGetActiveTitle, CurrentWinTitle
    WinActivate, Яндекс Музыка
    Sleep, 50
    Send, {%key%}
    WinActivate, %CurrentWinTitle%
    WinMinimize, Яндекс Музыка
}

ToggleMute()
{
    SoundSet, 0
    SoundGet, master_mute,, Mute
    if (master_mute = "Off")
        SoundSet, +1,, Mute
}

; Индекс монитора (1…MonitorCount), в чей прямоугольник попадает точка; иначе основной.
GetMonitorIndexAtPoint(mx, my)
{
    SysGet, monitorCount, MonitorCount
    Loop %monitorCount%
    {
        idx := A_Index
        SysGet, mo, Monitor, %idx%
        if (mx >= moLeft && mx < moRight && my >= moTop && my < moBottom)
            return idx
    }
    SysGet, primaryIdx, MonitorPrimary
    return primaryIdx
}

ChangeMasterVolumeByStep(step)
{
    SoundGet, master_volume
    SoundGet, master_mute,, Mute
    if (step > 0 and master_mute = "On")
        SoundSet, +1,, Mute
    if (step < 0 and master_volume + step <= 0 and master_mute = "Off")
        SoundSet, +1,, Mute

    master_volume := Round(master_volume + step, -1)
    SoundSet, master_volume
    ShowVolumeTooltip()
}

ShowVolumeTooltip()
{
    ; Конфиг tooltip и переменные контролов — иначе внутри функции читаются как пустые локальные.
    global volumeTooltipHwnd, VolumeTooltipInner, VolumeTooltipText, MeasureText
    global VolumeTooltipBorderColor, VolumeTooltipBgColor
    SoundGet, currentVolume
    SoundGet, currentMute,, Mute
    currentVolume := Round(currentVolume)
    if (currentMute = "On")
        text := "Громкость: " . currentVolume . "% (Mute)"
    else
        text := "Громкость: " . currentVolume . "%"

    ; 1) Отдельное окно только для измерения текста (после Hide размеры корректны).
    Gui, VolumeTooltipMeasure:Destroy
    Gui, VolumeTooltipMeasure:New
    Gui, VolumeTooltipMeasure:Margin, 0, 0
    Gui, VolumeTooltipMeasure:Font, s10 cFFFFFF, Segoe UI
    Gui, VolumeTooltipMeasure:Add, Text, vMeasureText x0 y0, %text%
    Gui, VolumeTooltipMeasure:Show, Hide x-32000 y-32000
    GuiControlGet, textRect, VolumeTooltipMeasure:Pos, MeasureText
    Gui, VolumeTooltipMeasure:Destroy

    ; Компактнее прежних 14×8 — меньше «воздуха» вокруг строки.
    paddingX := 10
    paddingY := 5
    ; Минимальный запас под символ «%» и DPI.
    textWidth := textRectW + 3
    textHeight := textRectH + 2
    ; Рамка 1 px (Progress-полоски); скругление отключено — WinSet Region давал артефакты на части конфигураций.
    borderSize := 1
    innerW := textWidth + (paddingX * 2)
    innerH := textHeight + (paddingY * 2)
    outerW := innerW + (borderSize * 2) + 2
    outerH := innerH + (borderSize * 2) + 2
    borderBottomY := outerH - borderSize
    borderMidHeight := outerH - (borderSize * 2)
    borderRightX := outerW - borderSize

    innerX := borderSize
    innerY := borderSize
    textX := borderSize + paddingX
    ; Лёгкий сдвиг по вертикали под метрики шрифта (при меньшем paddingY оставляем 1 px).
    textY := borderSize + paddingY + 1

    ; 2) Финальный GUI: Progress реально красит прямоугольники; -Theme отключает стили, из‑за которых Text Background часто не виден.
    Gui, VolumeTooltip:Destroy
    Gui, VolumeTooltip:New, +AlwaysOnTop -Caption +ToolWindow +HwndvolumeTooltipHwnd +LastFound -Theme
    Gui, VolumeTooltip:Margin, 0, 0
    Gui, VolumeTooltip:Color, %VolumeTooltipBgColor%
    Gui, VolumeTooltip:Font, s10 cFFFFFF, Segoe UI
    bc := VolumeTooltipBorderColor
    gc := VolumeTooltipBgColor
    Gui, VolumeTooltip:Add, Progress, x0 y0 w%outerW% h%borderSize% c%bc% Background%bc% Range0-100, 100
    Gui, VolumeTooltip:Add, Progress, x0 y%borderBottomY% w%outerW% h%borderSize% c%bc% Background%bc% Range0-100, 100
    Gui, VolumeTooltip:Add, Progress, x0 y%borderSize% w%borderSize% h%borderMidHeight% c%bc% Background%bc% Range0-100, 100
    Gui, VolumeTooltip:Add, Progress, x%borderRightX% y%borderSize% w%borderSize% h%borderMidHeight% c%bc% Background%bc% Range0-100, 100
    Gui, VolumeTooltip:Add, Progress, vVolumeTooltipInner x%innerX% y%innerY% w%innerW% h%innerH% c%gc% Background%gc% Range0-100, 100
    Gui, VolumeTooltip:Add, Text, vVolumeTooltipText x%textX% y%textY% w%textWidth% h%textHeight% +BackgroundTrans Center, %text%

    Gui, VolumeTooltip:Show, Hide x-32000 y-32000 w%outerW% h%outerH%

    ; Позиционирование рядом с курсором; рабочая область того монитора, где сейчас указатель.
    GetCursorScreenPos(mouseX, mouseY)
    posX := mouseX + 16
    posY := mouseY + 18
    mouseMon := GetMonitorIndexAtPoint(mouseX, mouseY)
    SysGet, wa, MonitorWorkArea, %mouseMon%
    edgeMargin := 8
    if (posX + outerW > waRight - edgeMargin)
        posX := mouseX - outerW - 16
    if (posY + outerH > waBottom - edgeMargin)
        posY := mouseY - outerH - 18
    if (posX < waLeft + edgeMargin)
        posX := waLeft + edgeMargin
    if (posY < waTop + edgeMargin)
        posY := waTop + edgeMargin
    showOpts := "NA x" posX " y" posY " w" outerW " h" outerH
    Gui, VolumeTooltip:Show, %showOpts%
    SetTimer, HideVolumeTooltip, -1200
}

HideVolumeTooltip:
    Gui, VolumeTooltip:Hide
Return
