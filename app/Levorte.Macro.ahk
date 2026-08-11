; ============================================================
; Запись и воспроизведение действий клавиатуры и мыши
; ============================================================

global macroRecording := false
global macroPlaying := false
global macroEvents := []
global macroLastEventTick := 0
global macroLastMouseX := ""
global macroLastMouseY := ""
global macroInputHook := ""

; Интервал опроса курсора при записи (мс).
global MacroMousePollMs := 15
; Минимальный сдвиг курсора (пиксели), чтобы записать MOVE.
global MacroMouseMinDelta := 2
; Фиксированное удержание кнопки мыши между Down и Up (мс).
global MacroMouseClickHoldMs := 8
; Пауза после MouseMove перед кликом (мс), чтобы hit-test успел обновиться.
global MacroMouseSettleMs := 15
; Погрешность проверки курсора перед кликом (пиксели), режим «2» при Alt+F2.
global MacroMouseCoordTolerancePx := 50
; Максимум попыток довести курсор до цели при проверке координат.
global MacroMouseCoordVerifyMaxTries := 40
; true — перед кликом сверять фактическую позицию с целевой (±tolerance).
global macroVerifyMouseCoords := false
; Шаг ожидания при Sleep, чтобы Alt+F2 мог прервать воспроизведение.
global MacroSleepChunkMs := 50

EnsureMacroSaveDir()
LoadMacroEventsFromDisk()

; --- Хоткеи ---
; Начать запись всех действий (с учётом пауз между ними).
!F1::
    if (macroPlaying || macroRecording)
        Return
    ; Ждём отпускания хоткея, чтобы Alt/F1 не попали в запись.
    KeyWait, F1
    KeyWait, Alt
    StartMacroRecording()
Return

; Если идёт воспроизведение — прервать.
; Если запись — остановить и сохранить (без автозапуска).
; Иначе — диалог режима и зацикленное воспроизведение.
!F2::
    if (macroPlaying)
    {
        macroPlaying := false
        ShowTemporaryTooltip("Воспроизведение прервано", 1500)
        Return
    }
    if (macroRecording)
    {
        StopMacroRecording()
        KeyWait, F2
        KeyWait, Alt
        if (macroEvents.MaxIndex() < 1)
            ShowTemporaryTooltip("Макрос пуст — файл не сохранён", 2000)
        else
            ShowTemporaryTooltip("Запись сохранена (Alt+F2 — воспроизвести)", 2500)
        Return
    }
    KeyWait, F2
    KeyWait, Alt
    if (macroEvents.MaxIndex() < 1)
        LoadMacroEventsFromDisk()
    if (macroEvents.MaxIndex() < 1)
    {
        ShowTemporaryTooltip("Макрос пуст", 1500)
        Return
    }

    playMode := PromptMacroPlayMode()
    if (playMode = 0)
    {
        ShowTemporaryTooltip("Запуск отменён", 1200)
        Return
    }

    global macroVerifyMouseCoords
    macroVerifyMouseCoords := (playMode = 2)
    SetTimer, MacroPlayLoopStart, -10
Return

MacroPlayLoopStart:
    PlayMacroRecordingLoop()
Return

; Диалог режима запуска: 0 — отмена (Esc), 1 — без проверок, 2 — с проверкой координат.
PromptMacroPlayMode()
{
    global macroPlayModeResult
    macroPlayModeResult := ""

    Gui, MacroPlayMode:New, +AlwaysOnTop -MinimizeBox +ToolWindow
    Gui, MacroPlayMode:Margin, 16, 14
    Gui, MacroPlayMode:Font, s10, Segoe UI
    Gui, MacroPlayMode:Add, Text, w360,
    (
Выберите режим воспроизведения:

1 — без проверок (по умолчанию)
2 — с проверкой координат мыши (±50 px)
Esc — отмена
    )
    Gui, MacroPlayMode:Add, Text, y+8 c666666, Нажмите 1, 2 или Esc
    Gui, MacroPlayMode:Show, AutoSize Center, Воспроизведение макроса

    ; Пока открыт диалог — ловим выбор с клавиатуры.
    Hotkey, IfWinActive, Воспроизведение макроса
    Hotkey, 1, MacroPlayModeChoose1, On
    Hotkey, Numpad1, MacroPlayModeChoose1, On
    Hotkey, 2, MacroPlayModeChoose2, On
    Hotkey, Numpad2, MacroPlayModeChoose2, On
    Hotkey, Escape, MacroPlayModeChooseEsc, On
    Hotkey, IfWinActive

    WinWaitClose, Воспроизведение макроса

    Hotkey, IfWinActive, Воспроизведение макроса
    Hotkey, 1, MacroPlayModeChoose1, Off
    Hotkey, Numpad1, MacroPlayModeChoose1, Off
    Hotkey, 2, MacroPlayModeChoose2, Off
    Hotkey, Numpad2, MacroPlayModeChoose2, Off
    Hotkey, Escape, MacroPlayModeChooseEsc, Off
    Hotkey, IfWinActive

    if (macroPlayModeResult = "1")
        Return 1
    if (macroPlayModeResult = "2")
        Return 2
    Return 0
}

MacroPlayModeChoose1:
    global macroPlayModeResult
    macroPlayModeResult := "1"
    Gui, MacroPlayMode:Destroy
Return

MacroPlayModeChoose2:
    global macroPlayModeResult
    macroPlayModeResult := "2"
    Gui, MacroPlayMode:Destroy
Return

MacroPlayModeChooseEsc:
    global macroPlayModeResult
    macroPlayModeResult := "0"
    Gui, MacroPlayMode:Destroy
Return

MacroPlayModeGuiClose:
    global macroPlayModeResult
    if (macroPlayModeResult = "")
        macroPlayModeResult := "0"
    Gui, MacroPlayMode:Destroy
Return

; --- Функции ---
EnsureMacroSaveDir()
{
    ; Литерал — не зависим от того, подтянулся ли global MacroLastDir.
    dir := "C:\Work\scripts\switcher\macros"
    if (FileExist(dir))
        Return true

    FileCreateDir, %dir%
    if (FileExist(dir))
        Return true

    RunWait, %ComSpec% /c mkdir "%dir%",, Hide UseErrorLevel
    Return FileExist(dir) != ""
}

; Начинает запись клавиатуры и мыши с временными метками.
StartMacroRecording()
{
    global macroRecording, macroPlaying, macroEvents, macroLastEventTick
    global macroLastMouseX, macroLastMouseY, MacroMousePollMs

    if (macroPlaying || macroRecording)
        Return

    macroEvents := []
    macroLastEventTick := A_TickCount
    CoordMode, Mouse, Screen
    MouseGetPos, macroLastMouseX, macroLastMouseY
    macroRecording := true

    StartMacroKeyboardHook()
    EnableMacroMouseHotkeys(true)
    SetTimer, MacroWatchMouse, %MacroMousePollMs%

    ShowTemporaryTooltip("Запись макроса…", 1500)
}

; Останавливает запись, чистит хоткей остановки и сразу сохраняет на диск.
StopMacroRecording()
{
    global macroRecording, macroEvents

    if (!macroRecording)
        Return

    macroRecording := false
    SetTimer, MacroWatchMouse, Off
    StopMacroKeyboardHook()
    EnableMacroMouseHotkeys(false)
    TrimMacroStopHotkeyEvents()
    SaveMacroEventsToDisk()
}

; Бесконечно воспроизводит макрос, пока macroPlaying = true.
PlayMacroRecordingLoop()
{
    global macroPlaying, macroRecording, macroEvents, macroVerifyMouseCoords

    if (macroPlaying || macroRecording)
        Return
    if (macroEvents.MaxIndex() < 1)
    {
        ShowTemporaryTooltip("Макрос пуст", 1500)
        Return
    }

    macroPlaying := true
    modeHint := macroVerifyMouseCoords ? "с проверкой координат" : "без проверок"
    ShowTemporaryTooltip("Зацикленное воспроизведение (" . modeHint . ")… Alt+F2 — стоп", 2500)
    CoordMode, Mouse, Screen

    Loop
    {
        if (!macroPlaying)
            Break
        if (!PlayMacroRecordingOnce())
            Break
    }

    macroPlaying := false
    ShowTemporaryTooltip("Воспроизведение остановлено", 1500)
}

; Один проход макроса. false — прервано пользователем.
PlayMacroRecordingOnce()
{
    global macroPlaying, macroEvents, MacroMouseClickHoldMs

    lastMouseDown := ""
    for index, eventLine in macroEvents
    {
        if (!macroPlaying)
            Return false

        parts := StrSplit(eventLine, "|")
        delayMs := parts[1] + 0
        action := parts[2]

        ; Удержание кнопки мыши всегда MacroMouseClickHoldMs.
        if ((action = "LU" || action = "RU" || action = "MU") && lastMouseDown != "")
            delayMs := MacroMouseClickHoldMs

        if (!SleepMacroInterruptible(delayMs))
            Return false

        if (action = "MOVE")
        {
            x := parts[3] + 0
            y := parts[4] + 0
            MouseMove, %x%, %y%, 0
        }
        else if (action = "LD")
        {
            lastMouseDown := "LD"
            if (!PlayMacroMouseButton("Left", "Down", parts))
                Return false
        }
        else if (action = "LU")
        {
            lastMouseDown := ""
            if (!PlayMacroMouseButton("Left", "Up", parts))
                Return false
        }
        else if (action = "RD")
        {
            lastMouseDown := "RD"
            if (!PlayMacroMouseButton("Right", "Down", parts))
                Return false
        }
        else if (action = "RU")
        {
            lastMouseDown := ""
            if (!PlayMacroMouseButton("Right", "Up", parts))
                Return false
        }
        else if (action = "MD")
        {
            lastMouseDown := "MD"
            if (!PlayMacroMouseButton("Middle", "Down", parts))
                Return false
        }
        else if (action = "MU")
        {
            lastMouseDown := ""
            if (!PlayMacroMouseButton("Middle", "Up", parts))
                Return false
        }
        else if (action = "WU")
            Click, WheelUp
        else if (action = "WD")
            Click, WheelDown
        else if (action = "KD")
        {
            lastMouseDown := ""
            keyTok := parts[3]
            layoutHex := parts[4]
            if (keyTok != "")
            {
                EnsureMacroKeyboardLayout(layoutHex)
                Send, {%keyTok% down}
            }
        }
        else if (action = "KU")
        {
            lastMouseDown := ""
            keyTok := parts[3]
            layoutHex := parts[4]
            if (keyTok != "")
            {
                EnsureMacroKeyboardLayout(layoutHex)
                Send, {%keyTok% up}
            }
        }
    }

    Return macroPlaying
}

; Перемещает курсор к координатам события (если есть) и жмёт кнопку.
; parts — результат StrSplit строки макроса: delay|action|x|y
PlayMacroMouseButton(button, state, parts)
{
    global macroPlaying, MacroMouseSettleMs, macroVerifyMouseCoords
    global MacroMouseCoordTolerancePx, MacroMouseCoordVerifyMaxTries

    CoordMode, Mouse, Screen
    hasCoords := (parts.MaxIndex() >= 4 && parts[3] != "" && parts[4] != "")
    if (hasCoords)
    {
        x := parts[3] + 0
        y := parts[4] + 0
        MouseMove, %x%, %y%, 0

        settleMs := MacroMouseSettleMs
        if (settleMs < 0)
            settleMs := 0
        if (settleMs > 0 && !SleepMacroInterruptible(settleMs))
            Return false

        ; Режим «2»: перед нажатием кнопки мыши сверяем позицию (±tolerance).
        if (macroVerifyMouseCoords && state = "Down")
        {
            if (!EnsureMacroMouseAtTarget(x, y))
                Return false
        }

        MouseClick, %button%, %x%, %y%, 1, 0, %state%
    }
    else
    {
        ; Старые макросы без координат в LD/LU.
        MouseClick, %button%, , , 1, 0, %state%
    }

    Return macroPlaying
}

; Доводит курсор до (targetX, targetY) в пределах MacroMouseCoordTolerancePx.
; false — прервано или не удалось уложиться в число попыток.
EnsureMacroMouseAtTarget(targetX, targetY)
{
    global macroPlaying, MacroMouseSettleMs
    global MacroMouseCoordTolerancePx, MacroMouseCoordVerifyMaxTries

    tolerance := MacroMouseCoordTolerancePx
    if (tolerance < 0)
        tolerance := 0

    maxTries := MacroMouseCoordVerifyMaxTries
    if (maxTries < 1)
        maxTries := 1

    settleMs := MacroMouseSettleMs
    if (settleMs < 1)
        settleMs := 5

    CoordMode, Mouse, Screen
    Loop, %maxTries%
    {
        if (!macroPlaying)
            Return false

        MouseGetPos, curX, curY
        dx := Abs(curX - targetX)
        dy := Abs(curY - targetY)
        if (dx <= tolerance && dy <= tolerance)
            Return true

        MouseMove, %targetX%, %targetY%, 0
        if (!SleepMacroInterruptible(settleMs))
            Return false
    }

    MouseGetPos, curX, curY
    if (Abs(curX - targetX) <= tolerance && Abs(curY - targetY) <= tolerance)
        Return true

    ShowTemporaryTooltip("Курсор далеко от цели (" . curX . "," . curY . " ≠ " . targetX . "," . targetY . ")", 2500)
    Return false
}

; Sleep с проверкой macroPlaying, чтобы Alt+F2 мог прервать цикл.
SleepMacroInterruptible(delayMs)
{
    global macroPlaying, MacroSleepChunkMs

    if (delayMs <= 0)
        Return macroPlaying

    chunk := MacroSleepChunkMs
    if (chunk < 1)
        chunk := 1

    endTick := A_TickCount + delayMs
    Loop
    {
        if (!macroPlaying)
            Return false
        remain := endTick - A_TickCount
        if (remain <= 0)
            Break
        sleepMs := remain < chunk ? remain : chunk
        Sleep, %sleepMs%
    }
    Return macroPlaying
}

SaveMacroEventsToDisk()
{
    global macroEvents, MacroLastFilePath

    dir := "C:\Work\scripts\switcher\macros"
    filePath := "C:\Work\scripts\switcher\macros\last_macro.txt"
    MacroLastFilePath := filePath

    if (!EnsureMacroSaveDir())
    {
        ShowTemporaryTooltip("Не удалось создать папку: " . dir, 3000)
        Return false
    }

    NormalizeMacroMouseClickHolds()

    count := 0
    if (macroEvents.MaxIndex() >= 1)
        count := macroEvents.MaxIndex()

    if (count < 1)
    {
        if (FileExist(filePath))
            FileDelete, %filePath%
        ShowTemporaryTooltip("Макрос пуст — файл не сохранён", 2000)
        Return false
    }

    content := ""
    Loop, %count%
        content .= macroEvents[A_Index] . "`r`n"

    file := FileOpen(filePath, "w")
    if (!IsObject(file))
    {
        ; Fallback через cmd, если FileOpen недоступен/заблокирован.
        tmpFile := dir . "\last_macro.tmp"
        FileDelete, %tmpFile%
        FileAppend, %content%, %tmpFile%
        if (!FileExist(tmpFile))
        {
            ShowTemporaryTooltip("Ошибка записи макроса", 3000)
            Return false
        }
        FileMove, %tmpFile%, %filePath%, 1
    }
    else
    {
        file.Write(content)
        file.Close()
    }

    if (!FileExist(filePath))
    {
        ShowTemporaryTooltip("Файл макроса не создан: " . filePath, 3000)
        Return false
    }

    ShowTemporaryTooltip("Сохранено: " . filePath . " (" . count . ")", 3000)
    Return true
}

LoadMacroEventsFromDisk()
{
    global macroEvents, MacroLastFilePath

    filePath := "C:\Work\scripts\switcher\macros\last_macro.txt"
    MacroLastFilePath := filePath
    macroEvents := []
    if (!FileExist(filePath))
        Return

    FileRead, content, %filePath%
    if (ErrorLevel || content = "")
        Return

    Loop, Parse, content, `n, `r
    {
        line := Trim(A_LoopField)
        if (line != "")
            macroEvents.Push(line)
    }
    NormalizeMacroMouseClickHolds()
}

; Добавляет событие в лог с задержкой от предыдущего события.
AppendMacroEvent(action, arg1 := "", arg2 := "")
{
    global macroRecording, macroPlaying, macroEvents, macroLastEventTick

    if (!macroRecording || macroPlaying)
        Return

    nowTick := A_TickCount
    delayMs := nowTick - macroLastEventTick
    if (delayMs < 0)
        delayMs := 0
    macroLastEventTick := nowTick

    line := delayMs . "|" . action
    if (arg1 != "")
        line := line . "|" . arg1
    if (arg2 != "")
        line := line . "|" . arg2
    macroEvents.Push(line)
}

MacroWatchMouse:
    global macroRecording, macroLastMouseX, macroLastMouseY, MacroMouseMinDelta

    if (!macroRecording)
    {
        SetTimer, MacroWatchMouse, Off
        Return
    }

    CoordMode, Mouse, Screen
    MouseGetPos, mouseX, mouseY
    if (macroLastMouseX = "" || macroLastMouseY = "")
    {
        macroLastMouseX := mouseX
        macroLastMouseY := mouseY
        Return
    }

    dx := Abs(mouseX - macroLastMouseX)
    dy := Abs(mouseY - macroLastMouseY)
    if (dx >= MacroMouseMinDelta || dy >= MacroMouseMinDelta)
    {
        AppendMacroEvent("MOVE", mouseX, mouseY)
        macroLastMouseX := mouseX
        macroLastMouseY := mouseY
    }
Return

StartMacroKeyboardHook()
{
    global macroInputHook

    StopMacroKeyboardHook()
    ; V — не блокировать ввод; N на всех клавишах — уведомления down/up.
    hook := InputHook("V L0")
    hook.KeyOpt("{All}", "N")
    hook.OnKeyDown := Func("MacroOnKeyDown")
    hook.OnKeyUp := Func("MacroOnKeyUp")
    hook.Start()
    macroInputHook := hook
}

StopMacroKeyboardHook()
{
    global macroInputHook

    if (IsObject(macroInputHook))
    {
        try macroInputHook.Stop()
    }
    macroInputHook := ""
}

MacroOnKeyDown(hook, vk, sc)
{
    keyName := GetMacroKeyName(vk, sc)
    if (keyName = "" || IsMacroControlKey(keyName))
        Return
    ; Сканкод + раскладка: воспроизведение не зависит от текущей раскладки.
    AppendMacroEvent("KD", Format("sc{:x}", sc), GetForegroundKeyboardLayoutHex())
}

MacroOnKeyUp(hook, vk, sc)
{
    keyName := GetMacroKeyName(vk, sc)
    if (keyName = "" || IsMacroControlKey(keyName))
        Return
    AppendMacroEvent("KU", Format("sc{:x}", sc), GetForegroundKeyboardLayoutHex())
}

; Возвращает имя клавиши (для фильтрации служебных хоткеев).
GetMacroKeyName(vk, sc)
{
    keyName := GetKeyName(Format("vk{:x}", vk))
    if (keyName = "")
        keyName := GetKeyName(Format("sc{:x}", sc))
    return keyName
}

; HKL активного окна в виде 8 hex-символов (например 04090409 = EN, 04190419 = RU).
GetForegroundKeyboardLayoutHex()
{
    hwnd := WinExist("A")
    if (!hwnd)
        Return ""
    threadId := DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0, "UInt")
    hkl := DllCall("GetKeyboardLayout", "UInt", threadId, "Ptr")
    Return Format("{:08x}", hkl & 0xFFFFFFFF)
}

; Переключает раскладку активного окна на сохранённую при записи.
EnsureMacroKeyboardLayout(layoutHex)
{
    if (layoutHex = "" || StrLen(layoutHex) < 8)
        Return

    current := GetForegroundKeyboardLayoutHex()
    if (current = layoutHex)
        Return

    hwnd := WinExist("A")
    if (!hwnd)
        Return

    hkl := "0x" . layoutHex
    ; WM_INPUTLANGCHANGEREQUEST = 0x0050
    PostMessage, 0x50, 0, %hkl%,, ahk_id %hwnd%
    Sleep, 40
}

; Служебные клавиши хоткеев записи (не попадают в макрос).
IsMacroControlKey(keyName)
{
    return keyName = "F1" || keyName = "F2"
}

; Убирает аккорд остановки Alt+F2: с последнего нажатия Alt до конца лога.
TrimMacroStopHotkeyEvents()
{
    global macroEvents

    if (macroEvents.MaxIndex() < 1)
        Return

    lastAltDownIndex := 0
    for index, eventLine in macroEvents
    {
        parts := StrSplit(eventLine, "|")
        action := parts[2]
        keyName := parts[3]
        if (action = "KD" && IsMacroStopChordKey(keyName) && keyName != "F2")
            lastAltDownIndex := index
    }

    if (lastAltDownIndex < 1)
    {
        ; На случай, если Alt записался иначе — снимаем только хвост F2/Alt.
        Loop
        {
            if (macroEvents.MaxIndex() < 1)
                Break
            lastIndex := macroEvents.MaxIndex()
            parts := StrSplit(macroEvents[lastIndex], "|")
            action := parts[2]
            keyName := parts[3]
            if ((action = "KD" || action = "KU") && IsMacroStopChordKey(keyName))
            {
                macroEvents.RemoveAt(lastIndex)
                Continue
            }
            Break
        }
        Return
    }

    ; Всё после начала аккорда Alt+F2 (включая сам Alt) — служебное.
    while (macroEvents.MaxIndex() >= lastAltDownIndex)
        macroEvents.RemoveAt(macroEvents.MaxIndex())
}

; Клавиши аккорда остановки записи Alt+F2.
IsMacroStopChordKey(keyName)
{
    return keyName = "F2"
        || keyName = "Alt"
        || keyName = "LAlt"
        || keyName = "RAlt"
}

EnableMacroMouseHotkeys(enable)
{
    state := enable ? "On" : "Off"
    Hotkey, ~*LButton, MacroMouseLButtonDown, %state%
    Hotkey, ~*LButton Up, MacroMouseLButtonUp, %state%
    Hotkey, ~*RButton, MacroMouseRButtonDown, %state%
    Hotkey, ~*RButton Up, MacroMouseRButtonUp, %state%
    Hotkey, ~*MButton, MacroMouseMButtonDown, %state%
    Hotkey, ~*MButton Up, MacroMouseMButtonUp, %state%
    Hotkey, ~*WheelUp, MacroMouseWheelUp, %state%
    Hotkey, ~*WheelDown, MacroMouseWheelDown, %state%
}

MacroMouseLButtonDown:
    AppendMacroMouseButton("LD")
Return

MacroMouseLButtonUp:
    AppendMacroMouseButton("LU")
Return

MacroMouseRButtonDown:
    AppendMacroMouseButton("RD")
Return

MacroMouseRButtonUp:
    AppendMacroMouseButton("RU")
Return

MacroMouseMButtonDown:
    AppendMacroMouseButton("MD")
Return

MacroMouseMButtonUp:
    AppendMacroMouseButton("MU")
Return

MacroMouseWheelUp:
    AppendMacroEvent("WU")
Return

MacroMouseWheelDown:
    AppendMacroEvent("WD")
Return

AppendMacroMouseButton(action)
{
    global macroLastMouseX, macroLastMouseY, macroEvents, macroLastEventTick
    global MacroMouseClickHoldMs

    CoordMode, Mouse, Screen
    MouseGetPos, mouseX, mouseY

    ; Отпускание: убрать MOVE после Down и зафиксировать удержание + координаты Up.
    if (action = "LU" || action = "RU" || action = "MU")
    {
        while (macroEvents.MaxIndex() >= 1)
        {
            lastIndex := macroEvents.MaxIndex()
            parts := StrSplit(macroEvents[lastIndex], "|")
            lastAction := parts[2]
            if (lastAction = "MOVE")
            {
                macroEvents.RemoveAt(lastIndex)
                Continue
            }
            Break
        }

        holdMs := MacroMouseClickHoldMs
        if (holdMs < 0)
            holdMs := 0
        macroLastEventTick := A_TickCount
        macroLastMouseX := mouseX
        macroLastMouseY := mouseY
        ; Координаты в событии — клик не зависит от того, успел ли предыдущий MOVE.
        macroEvents.Push(holdMs . "|" . action . "|" . mouseX . "|" . mouseY)
        Return
    }

    ; Перед Down всегда MOVE к точке клика + координаты в самом Down.
    AppendMacroEvent("MOVE", mouseX, mouseY)
    macroLastMouseX := mouseX
    macroLastMouseY := mouseY
    AppendMacroEvent(action, mouseX, mouseY)
}

; Нормализует в файле/памяти все пары Down→Up кнопок мыши до MacroMouseClickHoldMs.
NormalizeMacroMouseClickHolds()
{
    global macroEvents, MacroMouseClickHoldMs

    if (macroEvents.MaxIndex() < 1)
        Return

    holdMs := MacroMouseClickHoldMs
    if (holdMs < 0)
        holdMs := 0

    normalized := []
    pendingMoves := []
    lastDown := ""

    for index, eventLine in macroEvents
    {
        parts := StrSplit(eventLine, "|")
        action := parts[2]

        if (action = "MOVE")
        {
            if (lastDown != "")
                pendingMoves.Push(eventLine)
            else
                normalized.Push(eventLine)
            Continue
        }

        if (action = "LD" || action = "RD" || action = "MD")
        {
            for mi, moveLine in pendingMoves
                normalized.Push(moveLine)
            pendingMoves := []
            lastDown := action
            normalized.Push(eventLine)
            Continue
        }

        if (action = "LU" || action = "RU" || action = "MU")
        {
            expectedDown := "LD"
            if (action = "RU")
                expectedDown := "RD"
            else if (action = "MU")
                expectedDown := "MD"

            if (lastDown = expectedDown)
            {
                upLine := holdMs . "|" . action
                if (parts.MaxIndex() >= 4 && parts[3] != "" && parts[4] != "")
                    upLine := upLine . "|" . parts[3] . "|" . parts[4]
                normalized.Push(upLine)
                lastDown := ""
                ; MOVE во время удержания переносим после отпускания.
                for mi, moveLine in pendingMoves
                    normalized.Push(moveLine)
                pendingMoves := []
                Continue
            }
        }

        for mi, moveLine in pendingMoves
            normalized.Push(moveLine)
        pendingMoves := []
        lastDown := ""
        normalized.Push(eventLine)
    }

    for mi, moveLine in pendingMoves
        normalized.Push(moveLine)

    macroEvents := normalized
}
