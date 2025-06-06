@echo off
setlocal enabledelayedexpansion

:: ============================================================================
:: MANUAL SERVICE STOPPER
:: Manually stops specified services with safety options
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
:: Services to stop (space-separated)
set "SERVICES=EPWD TracSrvWrapper"

:: Force stop services if they don't respond (0=no, 1=yes)
set "FORCE_STOP=0"

:: Set services to manual startup after stopping (0=no, 1=yes)
set "SET_TO_MANUAL=0"

:: Verbose logging mode (0=minimal, 1=verbose)
set "VERBOSE_MODE=1"

:: Wait for service shutdown confirmation (0=no, 1=yes)
set "WAIT_FOR_SHUTDOWN=1"

:: Confirmation prompt before stopping (0=no, 1=yes)
set "REQUIRE_CONFIRMATION=1"
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

:: Show current service status
call :show_current_status

:: Confirmation prompt
if %REQUIRE_CONFIRMATION% equ 1 (
    call :confirm_operation
    if !errorlevel! neq 0 (
        echo [INFO] Operation cancelled by user
        pause
        exit /b 0
    )
)

:: Stop services
call :stop_all_services

:: Configure services to manual if enabled
if %SET_TO_MANUAL% equ 1 (
    call :set_services_to_manual
)

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
echo                        MANUAL SERVICE STOPPER
echo ============================================================================
echo Services to stop:      %SERVICES%
echo Force stop:            %FORCE_STOP%
echo Set to manual:         %SET_TO_MANUAL%
echo Verbose logging:       %VERBOSE_MODE%
echo Wait for shutdown:     %WAIT_FOR_SHUTDOWN%
echo Require confirmation:  %REQUIRE_CONFIRMATION%
echo ============================================================================
echo.
exit /b

:: Show current service status
:show_current_status
echo Current service status:
echo ------------------------
for %%s in (%SERVICES%) do (
    call :get_service_status "%%s"
    if "!SERVICE_STATUS!" equ "RUNNING" (
        echo   %%s: RUNNING
    ) else (
        echo   %%s: STOPPED
    )
)
echo.
exit /b

:: Confirmation prompt
:confirm_operation
echo [WARNING] This will stop the following services:
for %%s in (%SERVICES%) do (
    call :get_service_status "%%s"
    if "!SERVICE_STATUS!" equ "RUNNING" (
        echo   - %%s (currently RUNNING)
    )
)
echo.
set /p "user_choice=Do you want to continue? (Y/N): "
if /i "!user_choice!" neq "Y" (
    exit /b 1
)
exit /b 0

:: Stop all services
:stop_all_services
call :log_message "ACTION" "Stopping services..."
echo.
for %%s in (%SERVICES%) do (
    call :get_service_status "%%s"
    if "!SERVICE_STATUS!" equ "RUNNING" (
        call :log_message "ACTION" "Stopping service %%s..."
        call :stop_service "%%s"
        
        if %WAIT_FOR_SHUTDOWN% equ 1 (
            call :wait_for_service_stop "%%s"
        )
    ) else (
        call :log_message "INFO" "Service %%s already stopped"
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

:: Stop single service
:stop_service
set "service_name=%~1"
if %FORCE_STOP% equ 1 (
    net stop "%service_name%" /y >nul 2>&1
) else (
    net stop "%service_name%" >nul 2>&1
)

if !errorlevel! equ 0 (
    call :log_message "SUCCESS" "Service %service_name% stopped successfully"
) else (
    call :log_message "ERROR" "Failed to stop service %service_name%"
    if %FORCE_STOP% equ 0 (
        call :log_message "WARNING" "Try enabling FORCE_STOP option if service won't stop"
    )
)
exit /b

:: Wait for service to stop
:wait_for_service_stop
set "service_name=%~1"
set "wait_count=0"
set "max_wait=30"

:wait_stop_loop
call :get_service_status "%service_name%"
if "!SERVICE_STATUS!" neq "RUNNING" (
    call :log_message "SUCCESS" "Service %service_name% is now stopped"
    exit /b 0
)

set /a wait_count+=1
if !wait_count! gtr %max_wait% (
    call :log_message "WARNING" "Timeout waiting for service %service_name% to stop"
    if %FORCE_STOP% equ 0 (
        call :log_message "INFO" "Consider enabling FORCE_STOP option"
    )
    exit /b 1
)

if %VERBOSE_MODE% equ 1 (
    call :log_message "DEBUG" "Waiting for service %service_name% to stop... (!wait_count!/%max_wait%)"
)
timeout /t 1 /nobreak >nul
goto :wait_stop_loop

:: Set services to manual startup
:set_services_to_manual
call :log_message "CONFIG" "Setting services to manual startup..."
for %%s in (%SERVICES%) do (
    call :log_message "CONFIG" "Setting service %%s to manual startup"
    sc config "%%s" start=demand >nul 2>&1
    if !errorlevel! equ 0 (
        call :log_message "SUCCESS" "Service %%s set to manual startup"
    ) else (
        call :log_message "ERROR" "Failed to configure service %%s"
    )
)
exit /b

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