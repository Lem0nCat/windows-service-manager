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

:: Get current directory
set "CURRENT_DIR=%~dp0"
set "SERVICE_NAME=ServiceManager"
set "SERVICE_DISPLAY_NAME=Service Manager"
set "SERVICE_DESCRIPTION=Automated system services management (by Lem0nCat)"
set "BATCH_FILE=%CURRENT_DIR%service_manager.bat"
set "TASK_NAME=ServiceManagerAutorun"

:: Check if service_manager.bat exists
if not exist "%BATCH_FILE%" (
    echo ERROR: service_manager.bat not found in current directory!
    echo Make sure the file is in the same folder as this installer.
    pause
    exit /b 1
)

echo Found file: %BATCH_FILE%

:: Remove existing scheduled task if exists
echo Checking for existing scheduled task...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if !errorlevel! equ 0 (
    echo Removing existing scheduled task...
    schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)

:: Create scheduled task that runs at startup with highest privileges
echo Creating scheduled task for system startup...
schtasks /create /tn "%TASK_NAME%" ^
    /tr "\"%BATCH_FILE%\"" ^
    /sc onstart ^
    /ru "SYSTEM" ^
    /rl highest ^
    /f

if !errorlevel! neq 0 (
    echo ERROR: Failed to create scheduled task!
    pause
    exit /b 1
)

:: Configure task to run even if no user is logged on
echo Configuring advanced task settings...
schtasks /change /tn "%TASK_NAME%" /ru "SYSTEM" /rp

:: Create a registry entry for additional startup method (fallback)
echo Creating registry startup entry...
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" /t REG_SZ /d "\"%BATCH_FILE%\"" /f >nul 2>&1

echo.
echo ======================================
echo    Installation completed successfully!
echo ======================================
echo.
echo Your service manager has been configured to start automatically using:
echo   1. Windows Task Scheduler ^(primary method^)
echo   2. Registry startup entry ^(fallback method^)
echo.
echo The script will run:
echo   - At system startup
echo   - With SYSTEM privileges
echo   - In background mode
echo.
echo Management commands:
echo   View task:   schtasks /query /tn "%TASK_NAME%" /fo list /v
echo   Run now:     schtasks /run /tn "%TASK_NAME%"
echo   Disable:     schtasks /change /tn "%TASK_NAME%" /disable
echo   Enable:      schtasks /change /tn "%TASK_NAME%" /enable
echo.
echo You can also manage it via Task Scheduler ^(taskschd.msc^)
echo.

:: Offer to run the task now
set /p START_NOW="Run the task now for testing? (y/n): "
if /i "!START_NOW!"=="y" (
    echo Running scheduled task...
    schtasks /run /tn "%TASK_NAME%"
    if !errorlevel! equ 0 (
        echo Task started successfully!
        echo Check Task Manager to verify your service_manager.bat is running.
    ) else (
        echo Failed to start task. Check Task Scheduler for details.
    )
)

echo.
echo Press any key to exit...
pause >nul