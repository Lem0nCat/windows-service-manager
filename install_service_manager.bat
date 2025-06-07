@echo off
setlocal EnableDelayedExpansion

:: Check administrator privileges
IF "%PROCESSOR_ARCHITECTURE%" EQU "amd64" (
	>nul 2>&1 "%SYSTEMROOT%\SysWOW64\cacls.exe" "%SYSTEMROOT%\SysWOW64\config\system"
) ELSE (
	>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
)

:: If error flag set, we do not have admin.
if !errorlevel! neq 0 (
    echo Requesting administrative privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    set params= %*
    echo UAC.ShellExecute "cmd.exe", "/c ""%~s0"" %params:"=""%", "", "runas", 1 >> "%temp%\getadmin.vbs"

    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:gotAdmin
    pushd "%CD%"
    CD /D "%~dp0" 

echo ======================================
echo      Service Manager Installation
echo ======================================

:: Get current directory and file paths
set "CURRENT_DIR=%~dp0"
set "SERVICE_NAME=ServiceManager"
set "TASK_NAME=ServiceManagerAutorun"
set "BATCH_FILE=%CURRENT_DIR%service_manager.bat"
set "VBS_FILE=%CURRENT_DIR%run_hidden.vbs"

:: Check if required files exist
if not exist "%BATCH_FILE%" (
    echo ERROR: service_manager.bat not found in current directory!
    echo Make sure the file is in the same folder as this installer.
    pause
    exit /b 1
)

echo Found batch file: %BATCH_FILE%

:: Create VBS launcher if it doesn't exist
if not exist "%VBS_FILE%" (
    echo Creating VBS launcher script...
    echo ' run_hidden.vbs - Silent launcher for service_manager.bat > "%VBS_FILE%"
    echo ' This script runs the batch file silently in background without UAC prompts >> "%VBS_FILE%"
    echo. >> "%VBS_FILE%"
    echo On Error Resume Next >> "%VBS_FILE%"
    echo. >> "%VBS_FILE%"
    echo ' Get the directory where this VBS script is located >> "%VBS_FILE%"
    echo Dim fso, scriptDir, batFile >> "%VBS_FILE%"
    echo Set fso = CreateObject^("Scripting.FileSystemObject"^) >> "%VBS_FILE%"
    echo scriptDir = fso.GetParentFolderName^(WScript.ScriptFullName^) >> "%VBS_FILE%"
    echo batFile = scriptDir ^& "\service_manager.bat" >> "%VBS_FILE%"
    echo. >> "%VBS_FILE%"
    echo ' Check if batch file exists >> "%VBS_FILE%"
    echo If Not fso.FileExists^(batFile^) Then >> "%VBS_FILE%"
    echo     WScript.Quit 1 >> "%VBS_FILE%"
    echo End If >> "%VBS_FILE%"
    echo. >> "%VBS_FILE%"
    echo ' Create WScript.Shell object >> "%VBS_FILE%"
    echo Set WshShell = CreateObject^("WScript.Shell"^) >> "%VBS_FILE%"
    echo. >> "%VBS_FILE%"
    echo ' Run the batch file hidden ^(window style 0 = hidden^) >> "%VBS_FILE%"
    echo WshShell.Run """" ^& batFile ^& """", 0, False >> "%VBS_FILE%"
    echo. >> "%VBS_FILE%"
    echo ' Cleanup >> "%VBS_FILE%"
    echo Set WshShell = Nothing >> "%VBS_FILE%"
    echo Set fso = Nothing >> "%VBS_FILE%"
    echo WScript.Quit 0 >> "%VBS_FILE%"
    echo VBS launcher created successfully!
) else (
    echo Found existing VBS launcher: %VBS_FILE%
)

:: Remove existing scheduled task if exists
echo Checking for existing scheduled task...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if !errorlevel! equ 0 (
    echo Removing existing scheduled task...
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)

:: Remove existing registry entry if exists
echo Removing any existing registry entries...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" /f >nul 2>&1

:: Create scheduled task that runs VBS script at startup
echo Creating scheduled task for system startup...
schtasks /create /tn "%TASK_NAME%" ^
    /tr "wscript.exe \"%VBS_FILE%\"" ^
    /sc onstart ^
    /ru "SYSTEM" ^
    /rl highest ^
    /f

if !errorlevel! neq 0 (
    echo ERROR: Failed to create scheduled task!
    pause
    exit /b 1
)

:: Configure task to run without user interaction
echo Configuring advanced task settings...
schtasks /change /tn "%TASK_NAME%" /ru "SYSTEM"

:: Create registry startup entry as backup (using VBS)
echo Creating registry startup entry ^(backup method^)...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" /t REG_SZ /d "wscript.exe \"%VBS_FILE%\"" /f >nul 2>&1

echo.
echo ======================================
echo    Installation completed successfully!
echo ======================================
echo.
echo Your service manager has been configured to start automatically using:
echo   1. Windows Task Scheduler ^(primary method^)
echo   2. Registry startup entry ^(backup method^)
echo   3. VBS launcher for silent execution
echo.
echo The system will now:
echo   - Run your service_manager.bat at startup
echo   - Execute silently without UAC prompts
echo   - Work in complete background mode
echo   - Start before user login
echo.
echo Files created/used:
echo   - %VBS_FILE%
echo   - Scheduled Task: %TASK_NAME%
echo   - Registry Entry: %SERVICE_NAME%
echo.
echo Management commands:
echo   View task:   schtasks /query /tn "%TASK_NAME%" /fo list /v
echo   Run now:     schtasks /run /tn "%TASK_NAME%"
echo   Disable:     schtasks /change /tn "%TASK_NAME%" /disable
echo   Enable:      schtasks /change /tn "%TASK_NAME%" /enable
echo.

:: Offer to test the VBS script now
set /p TEST_NOW="Test the VBS launcher now? (y/n): "
if /i "!TEST_NOW!"=="y" (
    echo Testing VBS launcher...
    wscript.exe "%VBS_FILE%"
    echo VBS script executed. Check Task Manager to verify service_manager.bat is running.
    echo ^(Look for cmd.exe processes^)
)

echo.
echo Press any key to exit...
pause >nul