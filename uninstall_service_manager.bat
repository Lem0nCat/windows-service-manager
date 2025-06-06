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
tasklist /fi "imagename eq cmd.exe" /fi "windowtitle eq service_manager.bat*" >nul 2>&1
if !errorlevel! equ 0 (
    echo Found running service_manager processes. Attempting to stop...
    taskkill /fi "windowtitle eq service_manager.bat*" /f >nul 2>&1
)

:: Remove wrapper file if exists
set "WRAPPER_FILE=%CURRENT_DIR%service_wrapper.bat"
if exist "%WRAPPER_FILE%" (
    echo Removing auxiliary files...
    del "%WRAPPER_FILE%" >nul 2>&1
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
echo.
echo Your service_manager.bat file remains unchanged.
echo.
echo Press any key to exit...
pause >nul