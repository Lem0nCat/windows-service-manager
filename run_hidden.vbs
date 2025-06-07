' run_hidden.vbs - Silent launcher for service_manager.bat 
' This script runs the batch file silently in background without UAC prompts 
 
On Error Resume Next 
 
' Get the directory where this VBS script is located 
Dim fso, scriptDir, batFile 
Set fso = CreateObject("Scripting.FileSystemObject") 
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName) 
batFile = scriptDir & "\service_manager.bat" 
 
' Check if batch file exists 
If Not fso.FileExists(batFile) Then 
    WScript.Quit 1 
End If 
 
' Create WScript.Shell object 
Set WshShell = CreateObject("WScript.Shell") 
 
' Run the batch file hidden (window style 0 = hidden) 
WshShell.Run """" & batFile & """", 0, False 
 
' Cleanup 
Set WshShell = Nothing 
Set fso = Nothing 
WScript.Quit 0 
