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
echo      Service Manager Uninstallation
echo ======================================

set "SERVICE_NAME=ServiceManager"
set "TASK_NAME=ServiceManagerAutorun"
set "CURRENT_DIR=%~dp0"
set "VBS_FILE=%CURRENT_DIR%run_hidden.vbs"

:: Remove scheduled task
echo Checking for scheduled task...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if !errorlevel! equ 0 (
    echo Removing scheduled task "%TASK_NAME%"...
    schtasks /delete /tn "%TASK_NAME%" /f
    if !errorlevel! equ 0 (
        echo Scheduled task removed successfully!
    ) else (
        echo ERROR: Failed to remove scheduled task!
    )
) else (
    echo Scheduled task "%TASK_NAME%" not found.
)

:: Remove registry startup entry
echo Removing registry startup entry...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" /f >nul 2>&1
if !errorlevel! equ 0 (
    echo Registry entry removed successfully!
) else (
    echo Registry entry not found or already removed.
)

:: Try to stop any running instances
echo Checking for running service_manager.bat processes...
tasklist /fi "imagename eq cmd.exe" >nul 2>&1
if !errorlevel! equ 0 (
    echo Attempting to stop service_manager processes...
    wmic process where "name='cmd.exe' and commandline like '%%service_manager.bat%%'" delete >nul 2>&1
)

:: Stop any VBS processes
echo Checking for VBS launcher processes...
tasklist /fi "imagename eq wscript.exe" >nul 2>&1
if !errorlevel! equ 0 (
    echo Stopping VBS processes related to service manager...
    wmic process where "name='wscript.exe' and commandline like '%%run_hidden.vbs%%'" delete >nul 2>&1
)

:: Remove VBS file (optional - ask user)
if exist "%VBS_FILE%" (
    set /p REMOVE_VBS="Remove VBS launcher file? (y/n): "
    if /i "!REMOVE_VBS!"=="y" (
        echo Removing VBS launcher file...
        del "%VBS_FILE%" >nul 2>&1
        if !errorlevel! equ 0 (
            echo VBS file removed successfully!
        )
    ) else (
        echo VBS file kept for manual use.
    )
)

echo.
echo ======================================
echo      Uninstallation completed
echo ======================================
echo.
echo All autostart configurations have been removed:
echo   - Scheduled task removed
echo   - Registry startup entry removed  
echo   - Running processes terminated
echo   - VBS launcher handled per user choice
echo.
echo Your service_manager.bat file remains unchanged.
echo.
echo Press any key to exit...
pause >nul