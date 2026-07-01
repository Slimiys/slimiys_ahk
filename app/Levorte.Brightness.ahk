; ============================================================
; Управление яркостью
; ============================================================

global brightnessManualCache := ""

; --- Хоткеи ---
+NumpadDiv::
    DecreaseBrightness()
Return

+NumpadMult::
    IncreaseBrightness()
Return

^+NumpadDiv::
    ; Быстро установить минимальную яркость.
    AdjustBrightness(-1000)
Return

^+NumpadMult::
    ; Быстро установить максимальную яркость.
    AdjustBrightness(1000)
Return

; --- Функции ---
DecreaseBrightness()
{
    AdjustBrightness(-10)
}

IncreaseBrightness()
{
    AdjustBrightness(10)
}

AdjustBrightness(delta)
{
    global brightnessManualCache
    if (brightnessManualCache = "")
        brightnessManualCache := GetCurrentBrightness()

    targetBrightness := ClampBrightness(brightnessManualCache + delta)

    ; Быстрый локальный отклик (обычно основной/встроенный монитор).
    SetBrightnessNative(targetBrightness)

    ; Синхронизация всех мониторов через Python в фоне (без блокировки хоткея).
    QueueBrightnessSync(targetBrightness)
    brightnessManualCache := targetBrightness
}

; Установить яркость на всех мониторах (синхронно, без debounce).
SetBrightnessLevel(brightness)
{
    global brightnessManualCache
    targetBrightness := ClampBrightness(brightness)
    SetBrightnessNative(targetBrightness)
    ChangeBrightness(targetBrightness)
    brightnessManualCache := targetBrightness
}

; Текущая яркость: из кэша хоткеев или из WMI.
GetEffectiveBrightness()
{
    global brightnessManualCache
    if (brightnessManualCache != "")
        return brightnessManualCache
    return GetCurrentBrightness()
}

QueueBrightnessSync(brightness)
{
    global queuedBrightnessTarget
    queuedBrightnessTarget := ClampBrightness(brightness)
    ; Debounce: при удержании клавиши не запускать python на каждый тик.
    SetTimer, ApplyQueuedBrightness, -80
}

ApplyQueuedBrightness:
    global queuedBrightnessTarget
    if (queuedBrightnessTarget = "")
        return
    target := queuedBrightnessTarget
    queuedBrightnessTarget := ""
    ChangeBrightness(target)
    ; За время RunWait могло накопиться новое значение — применить без задержки.
    if (queuedBrightnessTarget != "")
        SetTimer, ApplyQueuedBrightness, -1
Return

ChangeBrightness(brightness := 50)
{
    return RunBrightnessPythonScript(ClampBrightness(brightness))
}

RunBrightnessPythonScript(argument)
{
    global BrightnessPythonScript, BrightnessPythonExe, BrightnessPythonExeArgs
    if (!FileExist(BrightnessPythonScript) || BrightnessPythonExe = "")
        return false

    if (BrightnessPythonExeArgs != "")
        RunWait, %BrightnessPythonExe% %BrightnessPythonExeArgs% "%BrightnessPythonScript%" %argument%,, Hide UseErrorLevel
    else
        RunWait, %BrightnessPythonExe% "%BrightnessPythonScript%" %argument%,, Hide UseErrorLevel
    return (ErrorLevel = 0)
}

ClampBrightness(brightness)
{
    if (brightness > 100)
        return 100
    if (brightness < 0)
        return 0
    return brightness
}

SetBrightnessNative(brightness)
{
    try
    {
        wmi := ComObjGet("winmgmts:\\.\root\WMI")
        methods := wmi.ExecQuery("SELECT * FROM WmiMonitorBrightnessMethods")
        hasMethods := false
        For method in methods
        {
            hasMethods := true
            method.WmiSetBrightness(1, brightness)
        }
        return hasMethods
    }
    catch
    {
        return false
    }
}

GetCurrentBrightness()
{
    wmi := ComObjGet("winmgmts:\\.\root\WMI")
    monitors := wmi.ExecQuery("SELECT * FROM WmiMonitorBrightness")
    
    totalBrightness := 0
    monitorCount := 0
    
    For monitor in monitors
    {
        totalBrightness += monitor.CurrentBrightness
        monitorCount++
    }
    
    if (monitorCount > 0)
    {
        return Round(totalBrightness / monitorCount)
    }
    
    return 50
}
