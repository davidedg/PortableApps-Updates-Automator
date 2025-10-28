#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Force

; Author: Davide DG
; Source: https://github.com/davidedg/PortableApps-Updates-Automator
; Version: 1.1 - Parallel Processing

; Configuration: Maximum number of parallel installations
MAX_PARALLEL_INSTALLS := 3
SLEEP_BETWEEN_LAUNCHES := 500  ; ms to wait between launching installers

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
    case "GoogleChromePortable": Installer__GoogleChromePortable_Parallel
    default: Installer__NA
}

MsgBox "All Targets completed",,"T5"
ExitApp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Installer__GoogleChromePortable_Parallel() {
    InstallProcesses := Map()
    TargetQueue := []
    CurrentIndex := 1
    
    ; Populate the queue with all targets
    Loop TargetDirs.Length {
        TargetQueue.Push(TargetDirs[A_Index])
    }
    
    ; Launch initial batch of installers (up to MAX_PARALLEL_INSTALLS)
    Loop Min(MAX_PARALLEL_INSTALLS, TargetQueue.Length) {
        T := TargetQueue[CurrentIndex]
        CurrentIndex++
        Run PA_exefullpath, PA_dir,, &PA_pid
        InstallProcesses[PA_pid] := {target: T, started: A_TickCount, stage: "language"}
        Sleep SLEEP_BETWEEN_LAUNCHES
    }
    
    ; Monitor and control all installations
    MAX_INSTALL_TIMEWAIT := 30000 ; DEBUG 30000
    LatestStartTime := A_TickCount  ; Track the most recent installer start time
    
    while InstallProcesses.Count > 0 or CurrentIndex <= TargetQueue.Length {
        for pid, info in InstallProcesses {
            ; Check if process still exists
            if !ProcessExist(pid) {
                InstallProcesses.Delete(pid)
                continue
            }
            
            ; Check timeout - based on the latest installer start time
            elapsed := A_TickCount - LatestStartTime
            if elapsed >= MAX_INSTALL_TIMEWAIT {
                MsgBox("Installation did not complete in time:`r`n" info.target, "ERROR", "OK Iconx")
                try ProcessClose(pid)
                InstallProcesses.Delete(pid)
                continue
            }
            
            ; Handle each stage
            switch info.stage {
                case "language":
                    if WinExist("ahk_pid " pid) {
                        WinActivate "ahk_pid " pid
                        Sleep 250
                        WinActivate "ahk_pid " pid
                        Send "English"
                        Sleep 250
                        Send "{Enter}"
                        info.stage := "wait_license"
                        info.stageTime := A_TickCount
                    }
                    
                case "wait_license":
                    ; Wait a bit for window transition
                    if (A_TickCount - info.stageTime) > 1000 {
                        if WinExist("ahk_pid " pid) {
                            info.stage := "license"
                        }
                    }
                    
                case "license":
                    if WinExist("ahk_pid " pid) {
                        WinActivate "ahk_pid " pid
                        Sleep 250
                        WinActivate "ahk_pid " pid
                        Send "{Enter}"  ; Send Enter to Start Install
                        Sleep 250
                        Send "{Enter}"  ; Send Enter to acknowledge the License
                        info.stage := "path"
                        info.stageTime := A_TickCount
                    }
                    
                case "path":
                    ; Wait a bit for window to be ready
                    if (A_TickCount - info.stageTime) > 500 {
                        if WinExist("ahk_pid " pid) {
                            WinActivate "ahk_pid " pid
                            Sleep 250
                            WinActivate "ahk_pid " pid
                            Send info.target  ; Send the Target path to the already selected edit input box
                            Sleep 250
                            Send "{Enter}"  ; Enter to confirm install
                            info.stage := "installing"
                        }
                    }
                    
                case "installing":
                    ; now we wait up to 30 seconds for the installation to finish
                    ; Check if Finish button is enabled
                    try {
                        if ControlGetEnabled("Button2", "ahk_pid " pid, "&Finish") {
                            info.stage := "finish"
                        }
                    }
                    
                case "finish":
                    if WinExist("ahk_pid " pid) {
                        WinActivate "ahk_pid " pid
                        Sleep 250
                        WinActivate "ahk_pid " pid
                        Send "{Enter}"  ; Enter to click the default (Finish) button
                        Sleep 500
                        InstallProcesses.Delete(pid)
                        
                        ; Launch next installation from queue if available
                        if CurrentIndex <= TargetQueue.Length {
                            T := TargetQueue[CurrentIndex]
                            CurrentIndex++
                            Run PA_exefullpath, PA_dir,, &PA_pid_new
                            InstallProcesses[PA_pid_new] := {target: T, started: A_TickCount, stage: "language"}
                            LatestStartTime := A_TickCount  ; Reset timeout for the newly started installer
                            Sleep SLEEP_BETWEEN_LAUNCHES
                        }
                    }
            }
        }
        
        Sleep 200  ; Check all processes every 200ms
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
