;@Ahk2Exe-UpdateManifest RequireAdmin, Levorte, 1.0.0.0
;@Ahk2Exe-SetMainIcon icon.ico
;@Ahk2Exe-Obey U_Bin,= "%A_BasePath~^.+\.%" = "bin" ? "Cont" : "Nop"
;@Ahk2Exe-Obey U_au, = "%A_IsUnicode%" ? 2 : 1
;@Ahk2Exe-PostExec "%A_ScriptDir%\..\tools\BinMod.exe" "%A_WorkFileName%"
;@Ahk2Exe-%U_Bin%  "%U_au%2.>AUTOHOTKEY SCRIPT<. DATA              "
; Модификаторы хоткеев AHK:
; ^ Ctrl
; ! Alt
; + Shift
; # Win
; < > левый/правый (напр. <^c)
; * срабатывает при любых доп. модификаторах
; ~ не блокировать оригинальную клавишу
; UP суффикс — при отпускании

#NoEnv
#InstallKeybdHook
#InstallMouseHook
#Persistent
SetWorkingDir, %A_ScriptDir%
#Include %A_ScriptDir%\Levorte.Config.ahk
#Include %A_ScriptDir%\Levorte.Core.ahk
#Include %A_ScriptDir%\Levorte.Games.ahk
#Include %A_ScriptDir%\Levorte.TextTools.ahk
#Include %A_ScriptDir%\Levorte.Media.ahk
#Include %A_ScriptDir%\Levorte.System.ahk
#Include %A_ScriptDir%\Levorte.Brightness.ahk