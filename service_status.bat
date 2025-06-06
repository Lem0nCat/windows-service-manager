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

echo ================================================
echo         Service Manager Status Check
echo ================================================

set "SERVICE_NAME=ServiceManager"
set "TASK_NAME=ServiceManagerAutorun"
set "CURRENT_DIR=%~dp0"
set "BATCH_FILE=%CURRENT_DIR%service_manager.bat"

echo Current time: %date% %time%
echo Script location: %CURRENT_DIR%
echo.

:: Check if service_manager.bat exists
echo [1/3] Checking service_manager.bat file...
if exist "%BATCH_FILE%" (
    echo [OK] Found: %BATCH_FILE%
    for %%I in ("%BATCH_FILE%") do echo     Size: %%~zI bytes
    for %%I in ("%BATCH_FILE%") do echo     Modified: %%~tI
) else (
    echo [X] NOT FOUND: service_manager.bat
    echo     Expected location: %BATCH_FILE%
)
echo.

:: Check scheduled task status
echo [2/3] Checking scheduled task status...
schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] Scheduled task "%TASK_NAME%" is INSTALLED
    
    :: Get detailed task information
    for /f "tokens=2 delims=:" %%a in ('schtasks /query /tn "%TASK_NAME%" /fo list ^| findstr /i "Status"') do (
        set "TASK_STATUS=%%a"
        set "TASK_STATUS=!TASK_STATUS:~1!"
    )
    
    for /f "tokens=2 delims=:" %%a in ('schtasks /query /tn "%TASK_NAME%" /fo list ^| findstr /i "Next Run Time"') do (
        set "NEXT_RUN=%%a"
        set "NEXT_RUN=!NEXT_RUN:~1!"
    )
    
    for /f "tokens=2 delims=:" %%a in ('schtasks /query /tn "%TASK_NAME%" /fo list ^| findstr /i "Last Run Time"') do (
        set "LAST_RUN=%%a"
        set "LAST_RUN=!LAST_RUN:~1!"
    )
    
    echo     Status: !TASK_STATUS!
    echo     Last run: !LAST_RUN!
    echo     Next run: !NEXT_RUN!
) else (
    echo [X] Scheduled task "%TASK_NAME%" is NOT INSTALLED
)
echo.

:: Check registry startup entry
echo [3/3] Checking registry startup entry...
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" >nul 2>&1
if !errorlevel! equ 0 (
    echo [OK] Registry startup entry EXISTS
    for /f "tokens=3*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" ^| findstr /i "%SERVICE_NAME%"') do (
        echo     Path: %%a %%b
    )
) else (
    echo [X] Registry startup entry NOT FOUND
)
echo.

:: Summary
echo ================================================
echo                    SUMMARY
echo ================================================

if exist "%BATCH_FILE%" (
    echo File Status:      [OK] service_manager.bat found
) else (
    echo File Status:      [X] service_manager.bat missing
)

schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if !errorlevel! equ 0 (
    echo Task Status:      [OK] Scheduled task installed
) else (
    echo Task Status:      [X] Scheduled task not installed
)

reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "%SERVICE_NAME%" >nul 2>&1
if !errorlevel! equ 0 (
    echo Registry Status:  [OK] Startup entry exists
) else (
    echo Registry Status:  [X] Startup entry missing
)

echo.
echo ================================================
echo               MANAGEMENT COMMANDS
echo ================================================
echo Manual start:     schtasks /run /tn "%TASK_NAME%"
echo Disable task:     schtasks /change /tn "%TASK_NAME%" /disable
echo Enable task:      schtasks /change /tn "%TASK_NAME%" /enable
echo View details:     schtasks /query /tn "%TASK_NAME%" /fo list /v
echo Task Scheduler:   taskschd.msc
echo Services:         services.msc
echo.

echo Press any key to exit...
pause >nul