; ============================================================
; Системные утилиты (IP, корзина, схемы питания)
; ============================================================

; --- Хоткеи ---
; Показывает окно с кнопками IP-адресов; клик по кнопке копирует IP в буфер
^!i::
    global ipPickerTargetWindowId
    WinGet, ipPickerTargetWindowId, ID, A
    ipList := GetCurrentIP()
    if (ipList = "")
    {
        MsgBox, 48, IP-адреса, IP-адрес не найден
        Return
    }
    ShowIpPicker(ipList)
Return

; Публичный IP и страна с api.myip.com
^!o::
    ShowPublicIpFromApi()
Return

#Del::
    {
        FileRecycleEmpty
        return
    }

; Переключение схем питания
#NumpadEnd::
    SetPowerScheme(PowerSchemeMax)
Return

#NumpadDown::
    SetPowerScheme(PowerSchemeBalanced)
Return

#NumpadPgDn::
    SetPowerScheme(PowerSchemeSilent)
Return

; Alt+СКМ в проводнике: распаковать архив(ы) в открытую папку (отложенно — после отпускания Alt).
; Только над окном проводника — не перехватываем !MButton у Яндекс Музыки.
#If IsExplorerUnderMouseForArchiveExtract()
!MButton::
    CoordMode, Mouse, Screen
    global extractPendingX, extractPendingY, extractPendingHwnd
    MouseGetPos, extractPendingX, extractPendingY, extractPendingHwnd
    SetTimer, ExtractExplorerArchivesDeferred, -40
Return
#If

ExtractExplorerArchivesDeferred:
    SetTimer, ExtractExplorerArchivesDeferred, Off
    global extractPendingX, extractPendingY, extractPendingHwnd, extractArchivesBusy
    if (extractArchivesBusy)
        Return
    extractArchivesBusy := true
    ExtractExplorerArchivesAtMouse(extractPendingX, extractPendingY, extractPendingHwnd)
    extractArchivesBusy := false
Return

; Защита от повторного входа, пока идёт распаковка (в т.ч. долгая/с ошибкой).
global extractArchivesBusy := false

; true — курсор над окном проводника (CabinetWClass / ExploreWClass).
IsExplorerUnderMouseForArchiveExtract()
{
    CoordMode, Mouse, Screen
    MouseGetPos,,, hwndUnderMouse
    return ResolveExplorerRootHwnd(hwndUnderMouse) != ""
}

; --- Функции ---
SetPowerScheme(powerSchemeGuid)
{
    savedBrightness := GetEffectiveBrightness()
    RunWait, %ComSpec% /c powercfg /setactive %powerSchemeGuid%,, Hide
    ; Windows подставляет яркость, сохранённую в новом плане — возвращаем прежнюю.
    Sleep, 200
    SetBrightnessLevel(savedBrightness)
}

ExtractExplorerArchivesAtMouse(mouseX, mouseY, mouseHwnd)
{
    ; Всегда снимаем залипший Alt и прячем прогресс — иначе после ошибки хоткей «молчит».
    try
    {
        ExtractExplorerArchivesAtMouseImpl(mouseX, mouseY, mouseHwnd)
    }
    catch e
    {
        ShowArchiveProgressTooltip("Ошибка распаковки", 2500)
    }
    SendInput {Blind}{LAlt up}{RAlt up}
}

ExtractExplorerArchivesAtMouseImpl(mouseX, mouseY, mouseHwnd)
{
    ; MouseGetPos часто возвращает HWND дочернего контрола (ListView/DirectUI), не CabinetWClass.
    explorerHwnd := ResolveExplorerRootHwnd(mouseHwnd)
    if (!explorerHwnd)
        return

    shellWindow := GetExplorerShellWindowFromHwnd(explorerHwnd)
    destFolder := ""
    if (shellWindow)
    {
        try
            destFolder := shellWindow.Document.Folder.Self.Path
    }

    ; Сначала читаем выделение (COM и Ctrl+C — надёжнее на Win11, чем только SelectedItems).
    archivePaths := []
    AppendArchivePathsFromShell(shellWindow, destFolder, archivePaths)
    AppendArchivePathsFromClipboard(explorerHwnd, archivePaths)

    if (archivePaths.MaxIndex() < 1)
    {
        ; Alt+клик в проводнике может мешать — снимаем Alt перед синтетическим ЛКМ.
        SendInput {Blind}{LAlt up}{RAlt up}
        Sleep, 40
        archivePaths := CollectExplorerArchivePathsAfterClick(shellWindow, explorerHwnd, mouseX, mouseY, destFolder)
    }

    if (archivePaths.MaxIndex() < 1)
    {
        ShowTemporaryTooltip("Архив под курсором не найден", 2000)
        return
    }

    if (destFolder = "")
    {
        for index, firstArchivePath in archivePaths
        {
            SplitPath, firstArchivePath,, destFolder
            break
        }
    }

    totalCount := archivePaths.MaxIndex()
    extractedCount := 0
    failedCount := 0
    for index, archivePath in archivePaths
    {
        SplitPath, archivePath, archiveFileName
        archiveFileName := ShortenArchiveProgressName(archiveFileName)
        extractFolder := GetArchiveExtractFolderPath(destFolder, archivePath)
        ShowArchiveProgressTooltip("Распаковка " . index . "/" . totalCount . ": " . archiveFileName)
        if (ExtractArchiveToFolder(archivePath, extractFolder))
            extractedCount++
        else
            failedCount++
    }

    if (extractedCount > 0)
        ShowArchiveProgressTooltip("Готово: " . extractedCount . " из " . totalCount, 2000)
    else if (failedCount > 0)
        ShowArchiveProgressTooltip("Ошибка распаковки", 2500)
    else
        Gosub, HideArchiveProgressTooltip
}

CollectExplorerArchivePathsAfterClick(shellWindow, explorerHwnd, mouseX, mouseY, destFolder)
{
    paths := []

    ; Выделить элемент под курсором кликом в клиентских координатах окна.
    VarSetCapacity(clientPt, 8, 0)
    NumPut(mouseX, clientPt, 0, "Int")
    NumPut(mouseY, clientPt, 4, "Int")
    DllCall("ScreenToClient", "Ptr", explorerHwnd, "Ptr", &clientPt)
    clientX := NumGet(clientPt, 0, "Int")
    clientY := NumGet(clientPt, 4, "Int")
    ControlClick, x%clientX% y%clientY%, ahk_id %explorerHwnd%,,,, NA Pos
    Sleep, 150

    AppendArchivePathsFromShell(shellWindow, destFolder, paths)
    AppendArchivePathsFromClipboard(explorerHwnd, paths)
    if (paths.MaxIndex() >= 1)
        return paths

    ; Запасной путь: имя файла из SysListView + текущая папка.
    fileName := GetExplorerListItemNameAtScreenPos(explorerHwnd, mouseX, mouseY)
    if (fileName != "")
        PushArchivePathIfValid(paths, destFolder . "\" . fileName)
    return paths
}

AppendArchivePathsFromShell(shellWindow, destFolder, ByRef paths)
{
    if (!shellWindow)
        return

    try
    {
        selectedItems := shellWindow.Document.SelectedItems()
        selectedCount := selectedItems.Count + 0
        Loop % selectedCount
            PushArchivePathFromShellItem(paths, selectedItems.Item(A_Index - 1), destFolder)
    }

    if (paths.MaxIndex() >= 1)
        return

    try
    {
        folderView := shellWindow.Document.FolderView
        selectedItems := folderView.SelectedItems()
        selectedCount := selectedItems.Count + 0
        Loop % selectedCount
            PushArchivePathFromShellItem(paths, selectedItems.Item(A_Index - 1), destFolder)
    }

    if (paths.MaxIndex() >= 1)
        return

    try
        PushArchivePathFromShellItem(paths, shellWindow.Document.FolderView.FocusedItem, destFolder)
}

AppendArchivePathsFromClipboard(explorerHwnd, ByRef paths)
{
    if (!WinExist("ahk_id " . explorerHwnd))
        return

    clipSaved := ClipboardAll
    Clipboard := ""
    WinActivate, ahk_id %explorerHwnd%
    Sleep, 80
    SendInput, ^c
    ClipWait, 1.5
    if ErrorLevel
    {
        Clipboard := clipSaved
        return
    }

    Loop, Parse, Clipboard, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        line := RegExReplace(line, "^""|""$", "")
        PushArchivePathIfValid(paths, line)
    }
    Clipboard := clipSaved
}

PushArchivePathFromShellItem(ByRef paths, shellItem, destFolder)
{
    if (!shellItem)
        return
    archivePath := ""
    try
        archivePath := shellItem.Path
    if (archivePath = "")
    {
        try
            archivePath := destFolder . "\" . shellItem.Name
    }
    PushArchivePathIfValid(paths, archivePath)
}

PushArchivePathIfValid(ByRef paths, archivePath)
{
    if (!IsArchiveFilePath(archivePath))
        return
    if (!FileExist(archivePath))
        return
    for index, existingPath in paths
    {
        if (existingPath = archivePath)
            return
    }
    paths.Push(archivePath)
}

ResolveExplorerRootHwnd(hwnd)
{
    if (!hwnd)
        return 0
    Loop, 30
    {
        WinGetClass, winClass, ahk_id %hwnd%
        if (winClass = "CabinetWClass" || winClass = "ExploreWClass")
            return hwnd
        parentHwnd := DllCall("GetParent", "Ptr", hwnd, "Ptr")
        if (!parentHwnd || parentHwnd = hwnd)
            break
        hwnd := parentHwnd
    }
    return 0
}

GetExplorerListItemNameAtScreenPos(explorerHwnd, screenX, screenY)
{
    ControlGet, listHwnd, Hwnd,, SysListView321, ahk_id %explorerHwnd%
    if (!listHwnd)
        return ""

    VarSetCapacity(clientPt, 8, 0)
    NumPut(screenX, clientPt, 0, "Int")
    NumPut(screenY, clientPt, 4, "Int")
    DllCall("ScreenToClient", "Ptr", listHwnd, "Ptr", &clientPt)
    lx := NumGet(clientPt, 0, "Int")
    ly := NumGet(clientPt, 4, "Int")

    VarSetCapacity(hitInfo, 24, 0)
    NumPut(lx, hitInfo, 0, "Int")
    NumPut(ly, hitInfo, 4, "Int")
    SendMessage, 0x1012, 0, &hitInfo,, ahk_id %listHwnd%
    itemIndex := NumGet(hitInfo, 12, "Int")
    if (itemIndex < 0)
        return ""

    return ListView_GetItemText(listHwnd, itemIndex)
}

ListView_GetItemText(lvHwnd, rowIndex)
{
    textBufSize := 520
    VarSetCapacity(textBuf, textBufSize, 0)
    itemSize := A_PtrSize = 8 ? 88 : 60
    VarSetCapacity(lvItem, itemSize, 0)
    NumPut(0x0001, lvItem, 0, "UInt")
    if (A_PtrSize = 8)
    {
        NumPut(rowIndex, lvItem, 8, "Int")
        NumPut(0, lvItem, 12, "Int")
        NumPut(&textBuf, lvItem, 16, "Ptr")
        NumPut(textBufSize // 2 - 1, lvItem, 24, "Int")
    }
    else
    {
        NumPut(rowIndex, lvItem, 4, "Int")
        NumPut(0, lvItem, 8, "Int")
        NumPut(&textBuf, lvItem, 12, "Ptr")
        NumPut(textBufSize // 2 - 1, lvItem, 16, "Int")
    }
    SendMessage, 0x1073, 0, &lvItem,, ahk_id %lvHwnd%
    return StrGet(&textBuf, "UTF-16")
}

GetExplorerShellWindowFromHwnd(hwnd)
{
    hwnd += 0
    shellApp := ComObjCreate("Shell.Application")
    for window in shellApp.Windows
    {
        wHwnd := window.hwnd + 0
        if (wHwnd = hwnd)
            return window
    }
    rootHwnd := DllCall("GetAncestor", "Ptr", hwnd, "UInt", 2, "Ptr")
    for window in shellApp.Windows
    {
        if ((window.hwnd + 0) = rootHwnd)
            return window
    }
    return ""
}

IsArchiveFilePath(path)
{
    return RegExMatch(path, "i)\.(zip|7z|rar|tar|gz|bz2|xz|tgz|tbz2|txz|tar\.gz|tar\.bz2|tar\.xz)$")
}

; Подпапка в текущем каталоге проводника: «archive.zip» → «...\archive\».
GetArchiveExtractFolderPath(baseFolder, archivePath)
{
    SplitPath, archivePath, fileName
    folderName := fileName
    if RegExMatch(fileName, "i)^(.+)\.(zip|7z|rar|tar|gz|bz2|xz|tgz|tbz2|txz|tar\.gz|tar\.bz2|tar\.xz)$", nameMatch)
        folderName := nameMatch1
    return RTrim(baseFolder, "\") . "\" . folderName
}

ExtractArchiveToFolder(archivePath, destFolder)
{
    if !FileExist(destFolder)
        FileCreateDir, %destFolder%
    destOut := RTrim(destFolder, "\") . "\"
    sevenZip := Resolve7ZipPath()
    if (sevenZip != "")
    {
        ; -y — без вопросов; -p"" — не ждать пароль; иначе 7z зависает и хоткей «умирает».
        extractCmd := """" . sevenZip . """ x """ . archivePath . """ -o""" . destOut . """ -y -p"""" -bso0 -bsp0"
        exitCode := RunProcessWithTimeout(extractCmd, 120000)
        ; 0 = OK, 1 = warning — считаем успехом.
        return (exitCode = 0 || exitCode = 1)
    }

    SplitPath, archivePath,,,, fileExt
    StringLower, fileExt, fileExt
    if (fileExt = "zip")
    {
        psCmd := "Expand-Archive -LiteralPath '" . archivePath . "' -DestinationPath '" . destFolder . "' -Force"
        fullCmd := "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command " . psCmd
        exitCode := RunProcessWithTimeout(fullCmd, 120000)
        return (exitCode = 0)
    }

    tarCmd := "tar -xf """ . archivePath . """ -C """ . destFolder . """"
    exitCode := RunProcessWithTimeout(tarCmd, 120000)
    return (exitCode = 0)
}

; Запускает команду через cmd с таймаутом (мс).
; Возврат: код выхода; -1 — не запустился; -2 — таймаут (процесс убит).
RunProcessWithTimeout(commandLine, timeoutMs := 120000)
{
    if (timeoutMs < 1000)
        timeoutMs := 1000

    exitFile := A_Temp . "\levorte_extract_exit_" . A_TickCount . ".txt"
    FileDelete, %exitFile%

    ; /v:on — !ERRORLEVEL! после команды; <nul — без ожидания ввода в консоли.
    wrapped := ComSpec . " /v:on /c " . commandLine . " <nul & >""" . exitFile . """ echo !ERRORLEVEL!"
    Run, %wrapped%,, Hide UseErrorLevel, procPid
    if (ErrorLevel || !procPid)
        return -1

    startTick := A_TickCount
    Loop
    {
        Process, Exist, %procPid%
        if (!ErrorLevel)
            Break
        if (A_TickCount - startTick >= timeoutMs)
        {
            Process, Close, %procPid%
            Sleep, 200
            Process, Exist, %procPid%
            if (ErrorLevel)
                Process, Close, %procPid%
            FileDelete, %exitFile%
            return -2
        }
        Sleep, 100
    }

    exitCode := ""
    if (FileExist(exitFile))
    {
        FileRead, exitCode, %exitFile%
        FileDelete, %exitFile%
    }
    exitCode := Trim(exitCode, " `t`r`n")
    if (exitCode = "" || exitCode is not integer)
        return 0
    return exitCode + 0
}

Resolve7ZipPath()
{
    global Archive7zPath
    if (Archive7zPath != "" && FileExist(Archive7zPath))
        return Archive7zPath

    if FileExist("C:\Program Files\7-Zip\7z.exe")
        return "C:\Program Files\7-Zip\7z.exe"
    if FileExist("C:\Program Files (x86)\7-Zip\7z.exe")
        return "C:\Program Files (x86)\7-Zip\7z.exe"
    return ""
}

ShortenArchiveProgressName(fileName)
{
    if (StrLen(fileName) <= 42)
        return fileName
    return SubStr(fileName, 1, 39) . "..."
}

ShowArchiveProgressTooltip(message, autoHideMs := 0)
{
    global archiveProgressTooltipHwnd, ArchiveProgressTooltipText, ArchiveProgressMeasureText, ArchiveProgressTooltipInner
    global VolumeTooltipBorderColor, VolumeTooltipBgColor

    Gui, ArchiveProgressTooltipMeasure:Destroy
    Gui, ArchiveProgressTooltipMeasure:New
    Gui, ArchiveProgressTooltipMeasure:Margin, 0, 0
    Gui, ArchiveProgressTooltipMeasure:Font, s10 cFFFFFF, Segoe UI
    Gui, ArchiveProgressTooltipMeasure:Add, Text, vArchiveProgressMeasureText x0 y0, %message%
    Gui, ArchiveProgressTooltipMeasure:Show, Hide x-32000 y-32000
    GuiControlGet, textRect, ArchiveProgressTooltipMeasure:Pos, ArchiveProgressMeasureText
    Gui, ArchiveProgressTooltipMeasure:Destroy

    paddingX := 10
    paddingY := 5
    textWidth := textRectW + 3
    textHeight := textRectH + 2
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
    textY := borderSize + paddingY + 1

    Gui, ArchiveProgressTooltip:Destroy
    Gui, ArchiveProgressTooltip:New, +AlwaysOnTop -Caption +ToolWindow +HwndarchiveProgressTooltipHwnd +LastFound -Theme
    Gui, ArchiveProgressTooltip:Margin, 0, 0
    Gui, ArchiveProgressTooltip:Color, %VolumeTooltipBgColor%
    Gui, ArchiveProgressTooltip:Font, s10 cFFFFFF, Segoe UI
    bc := VolumeTooltipBorderColor
    gc := VolumeTooltipBgColor
    Gui, ArchiveProgressTooltip:Add, Progress, x0 y0 w%outerW% h%borderSize% c%bc% Background%bc% Range0-100, 100
    Gui, ArchiveProgressTooltip:Add, Progress, x0 y%borderBottomY% w%outerW% h%borderSize% c%bc% Background%bc% Range0-100, 100
    Gui, ArchiveProgressTooltip:Add, Progress, x0 y%borderSize% w%borderSize% h%borderMidHeight% c%bc% Background%bc% Range0-100, 100
    Gui, ArchiveProgressTooltip:Add, Progress, x%borderRightX% y%borderSize% w%borderSize% h%borderMidHeight% c%bc% Background%bc% Range0-100, 100
    Gui, ArchiveProgressTooltip:Add, Progress, vArchiveProgressTooltipInner x%innerX% y%innerY% w%innerW% h%innerH% c%gc% Background%gc% Range0-100, 100
    Gui, ArchiveProgressTooltip:Add, Text, vArchiveProgressTooltipText x%textX% y%textY% w%textWidth% h%textHeight% +BackgroundTrans Center, %message%

    Gui, ArchiveProgressTooltip:Show, Hide x-32000 y-32000 w%outerW% h%outerH%

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
    Gui, ArchiveProgressTooltip:Show, %showOpts%

    SetTimer, HideArchiveProgressTooltip, Off
    if (autoHideMs > 0)
        SetTimer, HideArchiveProgressTooltip, % -autoHideMs
}

HideArchiveProgressTooltip:
    SetTimer, HideArchiveProgressTooltip, Off
    Gui, ArchiveProgressTooltip:Hide
Return

ShowIpPicker(ipList)
{
    global ipPickerByNumber, ipPickerGuiHwnd
    ipPickerByNumber := {}
    DisableIpPickerHotkeys()

    Gui, IpPicker:Destroy
    Gui, IpPicker:New, +AlwaysOnTop +ToolWindow +HwndipPickerGuiHwnd, Выбор IP-адреса
    Gui, IpPicker:Margin, 12, 12
    Gui, IpPicker:Font, s10, Segoe UI
    Gui, IpPicker:Add, Text,, Нажмите на адрес, чтобы скопировать и вставить:

    yPos := 40
    addressIndex := 0
    Loop, Parse, ipList, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue

        addressIndex++
        buttonText := line
        if (addressIndex <= 9)
        {
            ipPickerByNumber[addressIndex] := line
            buttonText := "[" . addressIndex . "] " . line
        }

        Gui, IpPicker:Add, Button, x12 y%yPos% w290 h28 hwndhButton gIpPickerCopyIp, %buttonText%
        yPos += 34
    }

    EnableIpPickerHotkeys(addressIndex)
    Gui, IpPicker:Add, Button, x12 y%yPos% w290 h28 gIpPickerClose, Закрыть
    Gui, IpPicker:Show, AutoSize Center
}

IpPickerCopyIp:
    selectedLine := ""
    if (A_GuiControlHwnd)
        ControlGetText, selectedLine,, ahk_id %A_GuiControlHwnd%
    if (selectedLine = "" and A_GuiControl != "")
        GuiControlGet, selectedLine, IpPicker:, %A_GuiControl%
    selectedLine := RegExReplace(selectedLine, "^\[\d\]\s*")
    CopySelectedIpAndPaste(selectedLine)
Return

IpPickerNumberHotkey:
    global ipPickerByNumber
    key := A_ThisHotkey + 0
    if (key >= 1 and key <= 9 and ipPickerByNumber.HasKey(key))
        CopySelectedIpAndPaste(ipPickerByNumber[key])
Return

CopySelectedIpAndPaste(selectedLine)
{
    global ipPickerTargetWindowId
    selectedIp := ""
    if RegExMatch(selectedLine, "^\d{1,3}(?:\.\d{1,3}){3}", ipMatch)
        selectedIp := ipMatch
    if (selectedIp != "")
    {
        Clipboard := selectedIp
        ClipWait, 0.5
        Gui, IpPicker:Destroy
        if (ipPickerTargetWindowId)
        {
            WinActivate, ahk_id %ipPickerTargetWindowId%
            Sleep, 120
            SendInput, ^v
        }
        ToolTip, Скопировано: %selectedIp%
        SetTimer, RemoveActiveWindowToolTip, -1200
    }
}

EnableIpPickerHotkeys(addressCount)
{
    global ipPickerGuiHwnd
    Hotkey, IfWinActive, ahk_id %ipPickerGuiHwnd%
    Loop, 9
    {
        key := A_Index
        mode := (key <= addressCount) ? "On" : "Off"
        Hotkey, %key%, IpPickerNumberHotkey, %mode%
    }
    Hotkey, IfWinActive
}

DisableIpPickerHotkeys()
{
    Hotkey, IfWinActive
    Loop, 9
    {
        key := A_Index
        Hotkey, %key%, IpPickerNumberHotkey, Off
    }
}

IpPickerClose:
IpPickerGuiClose:
IpPickerGuiEscape:
    DisableIpPickerHotkeys()
    Gui, IpPicker:Destroy
    ipPickerTargetWindowId := ""
Return

; Возвращает строку с локальными IPv4 (по одному на строку) в формате "IP (Маска)"
GetCurrentIP()
{
    shell := ComObjCreate("WScript.Shell")
    exec := shell.Exec(ComSpec " /c ipconfig")
    output := exec.StdOut.ReadAll()
    ipList := ""
    pos := 1
    ; Ищем блоки IPv4 и следующую за ним маску (англ. "Subnet Mask" или рус. "Маска подсети")
    While pos := RegExMatch(output, "Oi)IPv4[^:]*:\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", match, pos)
    {
        ip := match.Value(1)
        rest := SubStr(output, pos + match.Len)
        mask := ""
        if RegExMatch(rest, "Oi)(?:Subnet Mask|Маска подсети)[^:]*:\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})", maskMatch)
            mask := maskMatch.Value(1)
        if (ipList != "")
            ipList .= "`n"
        ipList .= ip . (mask ? " (" . mask . ")" : "")
        pos += match.Len
    }
    return ipList
}

ShowPublicIpFromApi()
{
    response := ""
    errorKind := ""
    if (!FetchMyIpApiResponse(response, errorKind))
    {
        errorMessage := GetPublicIpErrorMessage(errorKind)
        MsgBox, 48, Публичный IP, %errorMessage%
        return
    }

    publicIp := ""
    publicCountry := ""
    if (!ParseMyIpApiResponse(response, publicIp, publicCountry))
    {
        MsgBox, 48, Публичный IP, Сервер вернул неожиданный ответ.`nПопробуйте позже.
        return
    }

    MsgBox, 64, Публичный IP, % "IP: " . publicIp . "`nСтрана: " . publicCountry
}

FetchMyIpApiResponse(ByRef response, ByRef errorKind)
{
    response := ""
    errorKind := ""

    if (!IsNetworkConnected())
    {
        errorKind := "no_network"
        return false
    }

    try
    {
        response := HttpGetMyIpApiText()
        if (Trim(response) = "")
        {
            errorKind := "empty_response"
            return false
        }
        return true
    }
    catch e
    {
        errorKind := ClassifyPublicIpRequestError(e)
        return false
    }
}

; Тот же сетевой стек, что у IE/Edge — корректнее учитывает системный прокси и VPN.
HttpGetMyIpApiText()
{
    http := ComObjCreate("MSXML2.ServerXMLHTTP.6.0")
    http.open("GET", "https://api.myip.com/", false)
    http.setRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Levorte")
    http.setRequestHeader("Accept", "application/json")
    http.setRequestHeader("Cache-Control", "no-cache")
    http.setRequestHeader("Pragma", "no-cache")
    http.send()

    status := http.status
    if (status != 200)
        throw Exception("HTTP " . status)
    return http.responseText
}

IsNetworkConnected()
{
    connected := 0
    if !DllCall("Wininet\InternetGetConnectedState", "UIntP", connected, "UInt", 0)
        return false
    return connected
}

ClassifyPublicIpRequestError(exception)
{
    errorText := exception.Message . " " . exception.Extra
    if RegExMatch(errorText, "i)HTTP (\d+)", httpMatch)
        return "http_" . httpMatch1
    if RegExMatch(errorText, "i)0x80072EE7|12007")
        return "dns"
    if RegExMatch(errorText, "i)0x80072EE2|12002")
        return "timeout"
    if RegExMatch(errorText, "i)0x80072EFD|12029|0x80072EF7|0x80072F78")
        return "connection"
    return "request_failed"
}

GetPublicIpErrorMessage(errorKind)
{
    if (errorKind = "no_network")
        return "Нет подключения к сети.`nПроверьте кабель, Wi-Fi или VPN."
    if (errorKind = "dns")
        return "Не удалось найти сервер api.myip.com.`nВозможно, нет доступа в интернет или сбой DNS."
    if (errorKind = "timeout")
        return "Сервер api.myip.com не ответил вовремя.`nПопробуйте позже."
    if (errorKind = "connection")
        return "Не удалось подключиться к api.myip.com.`nСервер может быть недоступен."
    if (errorKind = "empty_response")
        return "Сервер api.myip.com вернул пустой ответ.`nПопробуйте позже."
    if (errorKind = "request_failed")
        return "Не удалось выполнить запрос к api.myip.com.`nПроверьте подключение к интернету."
    if (InStr(errorKind, "http_") = 1)
        return "Сервер api.myip.com вернул ошибку HTTP " . SubStr(errorKind, 5) . "."
    return "Не удалось получить данные с api.myip.com.`nПроверьте подключение к интернету."
}

ParseMyIpApiResponse(json, ByRef ip, ByRef country)
{
    ip := ""
    country := ""

    json := Trim(json)
    if (SubStr(json, 1, 1) = Chr(0xFEFF))
        json := SubStr(json, 2)

    if (TryParseMyIpApiJson(json, ip, country))
        return true

    if RegExMatch(json, "i)""ip""\s*:\s*""([^""]+)""", ipMatch)
        ip := ipMatch1
    if RegExMatch(json, "i)""country""\s*:\s*""([^""]+)""", countryMatch)
        country := countryMatch1
    return (IsPublicIpv4Address(ip) && country != "")
}

TryParseMyIpApiJson(json, ByRef ip, ByRef country)
{
    try
    {
        htmlDoc := ComObjCreate("htmlfile")
        htmlDoc.parentWindow.eval("window.__levorteMyIp = " . json . ";")
        parsed := htmlDoc.parentWindow.__levorteMyIp
        ip := parsed.ip
        country := parsed.country
        return (IsPublicIpv4Address(ip) && country != "")
    }
    catch
    {
        return false
    }
}

IsPublicIpv4Address(value)
{
    return RegExMatch(value, "^\d{1,3}(\.\d{1,3}){3}$")
}
