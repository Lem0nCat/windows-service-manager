@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: UNIVERSAL SERVICE MANAGER
:: Monitors specified process and manages services automatically
:: ============================================================================

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

:: CONFIGURATION (configure your parameters here)
:: ----------------------------------------------------------------------------
:: Process to monitor
set "PROCESS_NAME=TrGUI.exe"

:: Services to manage (space-separated)
set "SERVICES=EPWD TracSrvWrapper"

:: Check interval in seconds
set "CHECK_INTERVAL=10"

:: Service startup type configuration (auto/delayed-auto/demand/disabled)
set "SERVICE_STARTUP_TYPE=delayed-auto"

:: Logging mode (0=minimal, 1=verbose)
set "VERBOSE_MODE=1"
:: ----------------------------------------------------------------------------

:: Validate services
call :validate_services
if !errorlevel! neq 0 (
    echo [ERROR] One or more services not found in system!
    pause
    exit /b 1
)

:: Display startup information
call :display_startup_info

:: Configure services
call :configure_services

:: Main monitoring loop
:monitor_loop
call :check_process_status
if !errorlevel! equ 0 (
    if "!PROCESS_STATE!" neq "RUNNING" (
        set "PROCESS_STATE=RUNNING"
        call :log_message "INFO" "Process %PROCESS_NAME% STARTED"
        call :manage_services "start"
    )
) else (
    if "!PROCESS_STATE!" neq "STOPPED" (
        set "PROCESS_STATE=STOPPED"
        call :log_message "INFO" "Process %PROCESS_NAME% STOPPED"
        call :manage_services "stop"
    )
)

if %VERBOSE_MODE% equ 1 (
    call :log_message "DEBUG" "Status: %PROCESS_NAME% - !PROCESS_STATE!"
)

:: Wait before next check
timeout /t %CHECK_INTERVAL% /nobreak >nul
goto :monitor_loop

:: ============================================================================
:: FUNCTIONS
:: ============================================================================

:: Validate service existence
:validate_services
set "validation_failed=0"
for %%s in (%SERVICES%) do (
    sc query "%%s" >nul 2>&1
    if !errorlevel! neq 0 (
        call :log_message "ERROR" "Service '%%s' not found in system"
        set "validation_failed=1"
    )
)
exit /b !validation_failed!

:: Display startup information
:display_startup_info
echo.
echo ============================================================================
echo                        UNIVERSAL SERVICE MANAGER
echo ============================================================================
echo Monitored process:     %PROCESS_NAME%
echo Managed services:      %SERVICES%
echo Check interval:        %CHECK_INTERVAL% sec.
echo Service startup type:  %SERVICE_STARTUP_TYPE%
echo Verbose logging:       %VERBOSE_MODE%
echo.
echo Press Ctrl+C to exit
echo ============================================================================
echo.
exit /b

:: Configure service startup types
:configure_services
call :log_message "CONFIG" "Checking service configurations..."
for %%s in (%SERVICES%) do (
    call :check_service_config "%%s"
    if !errorlevel! neq 0 (
        call :log_message "CONFIG" "Configuring service %%s to %SERVICE_STARTUP_TYPE%"
        sc config "%%s" start=%SERVICE_STARTUP_TYPE% >nul 2>&1
        if !errorlevel! equ 0 (
            call :log_message "CONFIG" "Service %%s configured successfully"
        ) else (
            call :log_message "ERROR" "Failed to configure service %%s"
        )
    ) else (
        if %VERBOSE_MODE% equ 1 (
            call :log_message "CONFIG" "Service %%s already configured correctly"
        )
    )
)
exit /b

:: Check service configuration
:check_service_config
set "service_name=%~1"
if "%SERVICE_STARTUP_TYPE%"=="delayed-auto" (
    sc qc "%service_name%" | findstr /C:"DELAYED" >nul 2>&1
) else if "%SERVICE_STARTUP_TYPE%"=="auto" (
    sc qc "%service_name%" | findstr /C:"AUTO_START" >nul 2>&1
) else if "%SERVICE_STARTUP_TYPE%"=="demand" (
    sc qc "%service_name%" | findstr /C:"DEMAND_START" >nul 2>&1
) else if "%SERVICE_STARTUP_TYPE%"=="disabled" (
    sc qc "%service_name%" | findstr /C:"DISABLED" >nul 2>&1
)
exit /b !errorlevel!

:: Check process status
:check_process_status
tasklist /FI "IMAGENAME eq %PROCESS_NAME%" 2>nul | find /i "%PROCESS_NAME%" >nul
exit /b !errorlevel!

:: Manage services
:manage_services
set "action=%~1"
for %%s in (%SERVICES%) do (
    call :get_service_status "%%s"
    if "%action%"=="start" (
        if "!SERVICE_STATUS!" neq "RUNNING" (
            call :log_message "ACTION" "Starting service %%s"
            call :start_service "%%s"
        ) else (
            if %VERBOSE_MODE% equ 1 (
                call :log_message "INFO" "Service %%s already running"
            )
        )
    ) else if "%action%"=="stop" (
        if "!SERVICE_STATUS!" equ "RUNNING" (
            call :log_message "ACTION" "Stopping service %%s"
            call :stop_service "%%s"
        ) else (
            if %VERBOSE_MODE% equ 1 (
                call :log_message "INFO" "Service %%s already stopped"
            )
        )
    )
)
exit /b

:: Get service status
:get_service_status
set "service_name=%~1"
sc query "%service_name%" | find "RUNNING" >nul 2>&1
if !errorlevel! equ 0 (
    set "SERVICE_STATUS=RUNNING"
) else (
    set "SERVICE_STATUS=STOPPED"
)
exit /b

:: Start service
:start_service
set "service_name=%~1"
net start "%service_name%" >nul 2>&1
if !errorlevel! equ 0 (
    call :log_message "SUCCESS" "Service %service_name% started successfully"
) else (
    call :log_message "ERROR" "Failed to start service %service_name%"
)
exit /b

:: Stop service
:stop_service
set "service_name=%~1"
net stop "%service_name%" >nul 2>&1
if !errorlevel! equ 0 (
    call :log_message "SUCCESS" "Service %service_name% stopped successfully"
) else (
    call :log_message "ERROR" "Failed to stop service %service_name%"
)
exit /b

:: Logging function
:log_message
set "log_level=%~1"
set "log_text=%~2"
set "timestamp="
for /f "tokens=1-4 delims=/ " %%a in ('date /t') do set "current_date=%%a/%%b/%%c"
for /f "tokens=1-2 delims=: " %%a in ('time /t') do set "current_time=%%a:%%b"
set "timestamp=%current_date% %current_time%"

echo [%timestamp%] [%log_level%] %log_text%
exit /b