; ============================================================
; Текстовые инструменты (SVG -> XAML через буфер обмена)
; ============================================================

; --- Хоткеи ---
^NumpadAdd::
    TxtIn:=Clipboard
    TxtSec:=""

    TxtFound:=""
    StringReplace, TxtSec, TxtIn, fill-rule="evenodd" clip-rule="evenodd"%A_Space%,, All
    StringReplace, TxtSec, TxtSec, path d, Path`r`n`tFill="{TemplateBinding ContentControl.Foreground}"`r`n`tData, All
    TxtSec:=RegExReplace(TxtSec,"stroke=", "Fill=")
    TxtSec:=RegExReplace(TxtSec,"stroke-width=""[#A-z0-9.]+""")
    TxtSec:=RegExReplace(TxtSec,"fill=""[#0-9A-Za-z]+""")
    TxtSec:=RegExReplace(TxtSec,"<svg .+>", "HeaderStart")
    TxtSec:=RegExReplace(TxtSec,"</svg>", "HeaderEnd")
    StringReplace, TxtSec, TxtSec, HeaderStart, <Grid>, All
    StringReplace, TxtSec, TxtSec, HeaderEnd, </Grid>, All

    Clipboard := TxtSec
Return

^+NumpadAdd::
    TxtIn:=Clipboard
    TxtSec:=""

    TxtFound:=""
    TxtSec:=RegExReplace(TxtIn,"U)<svg .+>", "HeaderStart")
    TxtSec:=RegExReplace(TxtSec,"stroke=", "Fill=")
    TxtSec:=RegExReplace(TxtSec,"stroke-width=""[#A-z0-9.]+""")
    StringReplace, TxtSec, TxtSec, fill-rule="evenodd" clip-rule="evenodd"%A_Space%,, All
    StringReplace, TxtSec, TxtSec, path d, Path`r`n`tData, All
    StringReplace, TxtSec, TxtSec, fill, `r`n`tFill, All
    TxtSec:=RegExReplace(TxtSec,"</svg>", "HeaderEnd")
    StringReplace, TxtSec, TxtSec, HeaderStart, <Grid>, All
    StringReplace, TxtSec, TxtSec, HeaderEnd, </Grid>, All

    Clipboard := TxtSec
Return
