; ============================================================
; Системные утилиты (IP, корзина, scp из проводника, схемы питания)
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

; Ctrl+Alt+СКМ в проводнике: Ctrl+Shift+C (копировать как путь) → scp на Шкаф / Пульт / кастом.
; Только над окном проводника — не перехватываем !MButton у Яндекс Музыки.
#If IsExplorerUnderMouseForSshCopy()
^!MButton::
    CoordMode, Mouse, Screen
    global sshCopyPendingHwnd
    MouseGetPos,,, sshCopyPendingHwnd
    SetTimer, SshCopyExplorerDeferred, -40
Return
#If

SshCopyExplorerDeferred:
    SetTimer, SshCopyExplorerDeferred, Off
    global sshCopyPendingHwnd, sshCopyBusy
    if (sshCopyBusy)
        Return
    sshCopyBusy := true
    SshCopyExplorerSelectionOverSsh(sshCopyPendingHwnd)
    sshCopyBusy := false
Return

; Защита от повторного входа, пока идёт отправка.
global sshCopyBusy := false

; true — курсор над окном проводника (CabinetWClass / ExploreWClass).
IsExplorerUnderMouseForSshCopy()
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

; Путь через Ctrl+Shift+C в проводнике, затем диалог цели и scp.
SshCopyExplorerSelectionOverSsh(mouseHwnd)
{
    SendInput {Blind}{LAlt up}{RAlt up}{LCtrl up}{RCtrl up}

    explorerHwnd := ResolveExplorerRootHwnd(mouseHwnd)
    if (!explorerHwnd)
        return

    filePath := GetExplorerPathViaCopyAsPath(explorerHwnd)
    if (filePath = "")
    {
        ShowTemporaryTooltip("Путь не получен (выделите файл и повторите)", 2500)
        return
    }

    global HmiLinuxDeployShkafUser, HmiLinuxDeployShkafHost
    global HmiLinuxDeployPultUser, HmiLinuxDeployPultHost
    global SshCopyRemotePath

    target := PromptSshCopyTarget(filePath)
    if (target = "")
        return

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
        customTarget := PromptSshCopyCustomTarget()
        if (customTarget = "")
            return
        ParseSshCopyUserHost(customTarget, sshUser, sshHost)
    }
    else
        return

    if (sshUser = "" || sshHost = "")
    {
        MsgBox, 48, SSH, Не удалось определить user@host
        return
    }

    remotePath := SshCopyRemotePath
    if (remotePath = "")
        remotePath := "~/Desktop/"

    filePaths := []
    filePaths.Push(filePath)
    SendPathsOverSsh(filePaths, sshUser, sshHost, remotePath)
}

; Win11 «Копировать как путь» (Ctrl+Shift+C) → первый существующий путь из буфера.
GetExplorerPathViaCopyAsPath(explorerHwnd)
{
    if (!WinExist("ahk_id " . explorerHwnd))
        return ""

    clipSaved := ClipboardAll
    Clipboard := ""
    WinActivate, ahk_id %explorerHwnd%
    Sleep, 80
    SendInput, ^+c
    ClipWait, 1.5
    if ErrorLevel
    {
        Clipboard := clipSaved
        return ""
    }

    clipText := Clipboard
    Clipboard := clipSaved

    Loop, Parse, clipText, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        ; Обычно путь в кавычках: "C:\folder\file"
        line := RegExReplace(line, "^""|""$", "")
        if (FileExist(line))
            return line
    }
    return ""
}

; Диалог цели: 1 = шкаф, 2 = пульт, 3 = кастом. Пустая строка — отмена.
PromptSshCopyTarget(filePath := "")
{
    global sshCopyTargetChoice, sshCopyTargetGuiHwnd
    global HmiLinuxDeployShkafUser, HmiLinuxDeployShkafHost
    global HmiLinuxDeployPultUser, HmiLinuxDeployPultHost

    sshCopyTargetChoice := ""
    DisableSshCopyTargetHotkeys()

    shkafLabel := "Шкаф (" . HmiLinuxDeployShkafUser . "@" . HmiLinuxDeployShkafHost . ")"
    pultLabel := "Пульт (" . HmiLinuxDeployPultUser . "@" . HmiLinuxDeployPultHost . ")"

    Gui, SshCopyTarget:Destroy
    Gui, SshCopyTarget:New, +AlwaysOnTop +ToolWindow +HwndsshCopyTargetGuiHwnd, Отправка по SSH
    Gui, SshCopyTarget:Margin, 12, 12
    Gui, SshCopyTarget:Font, s10, Segoe UI
    Gui, SshCopyTarget:Add, Text, w400, Будет отправлен этот путь:
    Gui, SshCopyTarget:Add, Edit, w400 r2 ReadOnly -WantReturn, %filePath%
    Gui, SshCopyTarget:Add, Text, w400 y+12,
    (
Куда отправить?

[1] %shkafLabel%
[2] %pultLabel%
[3] Задать самостоятельно имя и адрес
[Esc] Отмена
    )
    EnableSshCopyTargetHotkeys()
    Gui, SshCopyTarget:Show, AutoSize Center

    WinWaitClose, ahk_id %sshCopyTargetGuiHwnd%
    Return sshCopyTargetChoice
}

SshCopyTargetShkaf:
    SelectSshCopyTarget("shkaf")
Return

SshCopyTargetPult:
    SelectSshCopyTarget("pult")
Return

SshCopyTargetCustom:
    SelectSshCopyTarget("custom")
Return

SshCopyTargetCancel:
    SelectSshCopyTarget("")
Return

SshCopyTargetGuiEscape:
    SelectSshCopyTarget("")
Return

SshCopyTargetGuiClose:
    SelectSshCopyTarget("")
Return

SelectSshCopyTarget(choice)
{
    global sshCopyTargetChoice
    sshCopyTargetChoice := choice
    DisableSshCopyTargetHotkeys()
    Gui, SshCopyTarget:Destroy
}

EnableSshCopyTargetHotkeys()
{
    global sshCopyTargetGuiHwnd, sshCopyTargetHotkeysOn

    Hotkey, IfWinActive, ahk_id %sshCopyTargetGuiHwnd%
    Hotkey, 1, SshCopyTargetShkaf, On
    Hotkey, Numpad1, SshCopyTargetShkaf, On
    Hotkey, 2, SshCopyTargetPult, On
    Hotkey, Numpad2, SshCopyTargetPult, On
    Hotkey, 3, SshCopyTargetCustom, On
    Hotkey, Numpad3, SshCopyTargetCustom, On
    Hotkey, IfWinActive
    sshCopyTargetHotkeysOn := true
}

DisableSshCopyTargetHotkeys()
{
    global sshCopyTargetGuiHwnd, sshCopyTargetHotkeysOn

    ; Нельзя вызывать Hotkey Off, пока хоткеи ещё не регистрировались.
    if (!sshCopyTargetHotkeysOn)
        Return

    Hotkey, IfWinActive, ahk_id %sshCopyTargetGuiHwnd%
    Hotkey, 1, Off
    Hotkey, Numpad1, Off
    Hotkey, 2, Off
    Hotkey, Numpad2, Off
    Hotkey, 3, Off
    Hotkey, Numpad3, Off
    Hotkey, IfWinActive
    sshCopyTargetHotkeysOn := false
}

; Запрос user и IP. Возвращает "user@host" или "".
PromptSshCopyCustomTarget()
{
    InputBox, sshUser, SSH — кастом, Имя пользователя SSH:, , 360, 140
    if (ErrorLevel || sshUser = "")
        Return ""

    InputBox, sshHost, SSH — кастом, IP-адрес / хост:, , 360, 140
    if (ErrorLevel || sshHost = "")
        Return ""

    sshUser := Trim(sshUser)
    sshHost := Trim(sshHost)
    if (sshUser = "" || sshHost = "")
        Return ""

    Return sshUser . "@" . sshHost
}

ParseSshCopyUserHost(userHost, ByRef sshUser, ByRef sshHost)
{
    sshUser := ""
    sshHost := ""
    atPos := InStr(userHost, "@")
    if (atPos <= 1)
        Return
    sshUser := SubStr(userHost, 1, atPos - 1)
    sshHost := SubStr(userHost, atPos + 1)
}

; scp -r выбранных путей на user@host:remotePath (окно консоли видно для пароля).
SendPathsOverSsh(filePaths, sshUser, sshHost, remotePath)
{
    if (filePaths.MaxIndex() < 1)
        return

    sources := ""
    for index, localPath in filePaths
        sources .= " """ . localPath . """"

    remoteSpec := sshUser . "@" . sshHost . ":" . remotePath
    ; Одно окно scp на все файлы; -r — и файлы, и папки.
    scpCmd := "scp -r" . sources . " " . remoteSpec
    ShowTemporaryTooltip("SCP → " . remoteSpec, 1500)
    RunWait, %ComSpec% /c %scpCmd%,, UseErrorLevel
    if (ErrorLevel = 0)
        ShowTemporaryTooltip("Отправлено: " . filePaths.MaxIndex(), 2000)
    else
        ShowTemporaryTooltip("Ошибка scp (код " . ErrorLevel . ")", 3000)
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

ShowIpPicker(ipList)
{
    global ipPickerByNumber, ipPickerGuiHwnd
    ipPickerByNumber := {}
    DisableIpPickerHotkeys()

    Gui, IpPicker:Destroy
    Gui, IpPicker:New, +AlwaysOnTop +ToolWindow +HwndipPickerGuiHwnd, Выбор IP-адреса
    Gui, IpPicker:Margin, 12, 12
    Gui, IpPicker:Font, s10, Segoe UI
    pickerText := "Нажмите цифру, чтобы скопировать и вставить:`n`n"

    addressIndex := 0
    Loop, Parse, ipList, `n, `r
    {
        line := Trim(A_LoopField)
        if (line = "")
            continue

        addressIndex++
        if (addressIndex <= 9)
        {
            ipPickerByNumber[addressIndex] := line
            pickerText .= "[" . addressIndex . "] " . line . "`n"
        }
    }

    EnableIpPickerHotkeys(addressIndex)
    pickerText .= "`n[Esc] Закрыть"
    Gui, IpPicker:Add, Text, w290, %pickerText%
    Gui, IpPicker:Show, AutoSize Center
}

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
