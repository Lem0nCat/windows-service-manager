@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: MANUAL SERVICE STARTER
:: Manually starts specified services with configuration options
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
:: Services to start (space-separated)
set "SERVICES=EPWD TracSrvWrapper"

:: Service startup type configuration (auto/delayed-auto/demand/disabled)
set "SERVICE_STARTUP_TYPE=delayed-auto"

:: Configure services before starting (0=no, 1=yes)
set "CONFIGURE_SERVICES=1"

:: Verbose logging mode (0=minimal, 1=verbose)
set "VERBOSE_MODE=1"

:: Wait for service startup confirmation (0=no, 1=yes)
set "WAIT_FOR_STARTUP=1"
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

:: Configure services if enabled
if %CONFIGURE_SERVICES% equ 1 (
    call :configure_services
)

:: Start services
call :start_all_services

:: Final status report
call :display_final_status

echo.
echo [INFO] Operation completed. Press any key to exit...
pause >nul
exit /b 0

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
echo                        MANUAL SERVICE STARTER
echo ============================================================================
echo Services to start:     %SERVICES%
echo Service startup type:  %SERVICE_STARTUP_TYPE%
echo Configure services:    %CONFIGURE_SERVICES%
echo Verbose logging:       %VERBOSE_MODE%
echo Wait for startup:      %WAIT_FOR_STARTUP%
echo ============================================================================
echo.
exit /b

:: Configure service startup types
:configure_services
call :log_message "CONFIG" "Configuring service startup types..."
for %%s in (%SERVICES%) do (
    call :check_service_config "%%s"
    if !errorlevel! neq 0 (
        call :log_message "CONFIG" "Setting service %%s to %SERVICE_STARTUP_TYPE%"
        sc config "%%s" start=%SERVICE_STARTUP_TYPE% >nul 2>&1
        if !errorlevel! equ 0 (
            call :log_message "SUCCESS" "Service %%s configured successfully"
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

:: Start all services
:start_all_services
call :log_message "ACTION" "Starting services..."
echo.
for %%s in (%SERVICES%) do (
    call :get_service_status "%%s"
    if "!SERVICE_STATUS!" neq "RUNNING" (
        call :log_message "ACTION" "Starting service %%s..."
        call :start_service "%%s"
        
        if %WAIT_FOR_STARTUP% equ 1 (
            call :wait_for_service_start "%%s"
        )
    ) else (
        call :log_message "INFO" "Service %%s already running"
    )
    echo.
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

:: Start single service
:start_service
set "service_name=%~1"
net start "%service_name%" >nul 2>&1
if !errorlevel! equ 0 (
    call :log_message "SUCCESS" "Service %service_name% started successfully"
) else (
    call :log_message "ERROR" "Failed to start service %service_name%"
)
exit /b

:: Wait for service to start
:wait_for_service_start
set "service_name=%~1"
set "wait_count=0"
set "max_wait=30"

:wait_loop
call :get_service_status "%service_name%"
if "!SERVICE_STATUS!" equ "RUNNING" (
    call :log_message "SUCCESS" "Service %service_name% is now running"
    exit /b 0
)

set /a wait_count+=1
if !wait_count! gtr %max_wait% (
    call :log_message "WARNING" "Timeout waiting for service %service_name% to start"
    exit /b 1
)

if %VERBOSE_MODE% equ 1 (
    call :log_message "DEBUG" "Waiting for service %service_name% to start... (!wait_count!/%max_wait%)"
)
timeout /t 1 /nobreak >nul
goto :wait_loop

:: Display final status
:display_final_status
echo.
echo ============================================================================
echo                           FINAL STATUS REPORT
echo ============================================================================
for %%s in (%SERVICES%) do (
    call :get_service_status "%%s"
    if "!SERVICE_STATUS!" equ "RUNNING" (
        call :log_message "STATUS" "Service %%s: RUNNING"
    ) else (
        call :log_message "STATUS" "Service %%s: STOPPED"
    )
)
echo ============================================================================
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