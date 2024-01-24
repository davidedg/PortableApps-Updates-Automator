#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Force

; Author: Davide DG
; Source: https://github.com/davidedg/PortableApps-Updates-Automator
; Version: 1.0


PA_exefullpath := FileSelect(1+2, A_ScriptDir, "Pick Portable Apps Installer", "PA Installer (*.paf.exe)")
if PA_exefullpath = ""
    ExitApp
; PA_exefullpath := "W:\cp\GoogleChromePortable_120.0.6099.225_online.paf.exe"


SplitPath PA_exefullpath, &PA_exename, &PA_dir ; e.g.: F:\Downloads\GoogleChromePortable_120.0.6099.225_online.paf.exe -> GoogleChromePortable_120.0.6099.225_online.paf.exe
PA_name := StrSplit(PA_exename,"_",1)[1] ; GoogleChromePortable_120.0.6099.225_online.paf.exe -> [1]: GoogleChromePortable



TargetDirs_cfgfname := PA_name ".targets"
TargetDirs_cfgpath :=  PA_dir "\" TargetDirs_cfgfname

if not FileExist(TargetDirs_cfgpath) {
    MsgBox TargetDirs_cfgpath "`r`n`r`ndoes not exists. Creating a default one.`r`nPlease modify it and then re-rerun this script", "Cfg File does not exist"
    FileAppend
    (
        "; this is the default path`r`n"
        ".\" PA_name "`r`n"
        "`r`n"
        "; uncomment and modify to add more targets`r`n"
        "; .\" PA_name "-2" "`r`n"
        "; .\" PA_name "-3" "`r`n"
        "; " A_MyDocuments "\" PA_name "-4`r`n"
    ), TargetDirs_cfgpath
    ExitApp
}


TargetDirs := Array()
Loop read, TargetDirs_cfgpath {
    if InStr(A_LoopReadLine, "\")   ; lines must contain a path separator ('\') to be considered valid
    AND NOT A_LoopReadLine ~= "^[\s\t]*;" ; allows commenting with a starting semicolon
        TargetDirs.push GetFullPathName(A_LoopReadLine)
}


switch PA_name {
    case "GoogleChromePortable": Installer__GoogleChromePortable
    default: Installer__NA
}

MsgBox "All Targets completed",,"T5"
ExitApp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Installer__GoogleChromePortable() {
Loop TargetDirs.Length {
    T := TargetDirs[A_Index]
    failed := false

    Run PA_exefullpath ,PA_dir,,&PA_pid


    WinWaitActive "ahk_pid " PA_pid,,5
    Sleep 250
    WinActivate
  

    Send "English" ; Set the Installer Language to English (this is required to then catch the "&Finish" button at the end)
    Sleep 250
    Send "{Enter}" ; confirm the language

    WinWaitNotActive "ahk_pid " PA_pid,,2
    WinWaitActive "ahk_pid " PA_pid,,5
    WinActivate

    Sleep 250
    WinWaitActive "ahk_pid " PA_pid,,5
    WinActivate
    Send "{Enter}" ; Send Enter to Start Install
    Sleep 250
    WinWaitActive "ahk_pid " PA_pid,,5
    WinActivate
    Send "{Enter}" ; Send Enter to acknowledge the License
    Sleep 250
    WinWaitActive "ahk_pid " PA_pid,,5
    WinActivate
    Send T ; Send the Target path to the already selected edit input box
    Sleep 250
    WinWaitActive "ahk_pid " PA_pid,,5
    WinActivate
    Send "{Enter}" ; Enter to confirm install


    ; now we wait up to 30 seconds for the installation to finish
    MAX_INSTALL_TIMEWAIT := 30000 ; DEBUG 30000
    _starttime := A_TickCount
    _elapsed := 0
    waiting_finish_button  := true
    while (waiting_finish_button and (_elapsed < MAX_INSTALL_TIMEWAIT)) { 
        try {
            waiting_finish_button := ControlGetEnabled("Button2",, "&Finish") = false
        } catch TargetError {
            sleep 250
            _elapsed := A_TickCount - _starttime
        }
    }

    if _elapsed >= MAX_INSTALL_TIMEWAIT {
        MsgBox("Installation did not complete in time:`r`n" T, "ERROR","OK Iconx")
        ExitApp
    }


    Sleep 1000
    WinWaitActive "ahk_pid " PA_pid,,5
    WinActivate
    Send "{Enter}" ; Enter to click the default (Finish) button
}
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Installer__NA() {
    MsgBox "Installer for " PA_name " not yet implemented"
    ExitApp
}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

GetFullPathName(path) {
    cc := DllCall("GetFullPathNameW", "str", path, "uint", 0, "ptr", 0, "ptr", 0, "uint")
    buf := Buffer(cc*2)
    DllCall("GetFullPathNameW", "str", path, "uint", cc, "ptr", buf, "ptr", 0, "uint")
    return StrGet(buf)
}
