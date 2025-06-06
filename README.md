# Windows Service Manager Scripts

A collection of powerful batch scripts for managing Windows services automatically and manually. Perfect for applications that require specific services to be running only when needed. Includes system-level installation and management tools.

## Features

- **Automatic Service Management**: Monitor processes and automatically start/stop services
- **Manual Service Control**: Quick scripts for manual service management
- **System Installation**: Install service manager as Windows startup task
- **Status Monitoring**: Comprehensive status checking and diagnostics
- **Universal Configuration**: Support for any number of services
- **Robust Error Handling**: Administrator privilege checks and service validation
- **Detailed Logging**: Timestamped logs with different severity levels
- **Flexible Configuration**: Easy-to-modify configuration sections

## Scripts Included

### Core Service Management
1. **`service_manager.bat`** - Automatic Service Monitor
   - Monitors a specified process and automatically manages services based on process state

2. **`start_services.bat`** - Manual Service Starter
   - Manually starts specified services with configuration options

3. **`stop_services.bat`** - Manual Service Stopper
   - Manually stops specified services with safety features

### System Installation and Management
4. **`install_service.bat`** - System Installation
   - Installs service_manager.bat as Windows startup task
   - Uses Task Scheduler for reliable system-level execution
   - Configures SYSTEM privileges and auto-start behavior

5. **`uninstall_service.bat`** - System Removal
   - Removes all autostart configurations
   - Cleans scheduled tasks and registry entries
   - Stops running processes safely

6. **`check_service_status.bat`** - Status Checker
   - Comprehensive status verification
   - Checks file existence, scheduled tasks, registry entries
   - Provides management commands and troubleshooting info

## Installation

### Quick Setup
1. Download or clone this repository
2. Place all batch files in your desired directory
3. Run `install_service.bat` to install system-level autostart

### Manual Setup
1. Download the scripts you need
2. Configure the service management scripts
3. Run files manually

## Configuration

### Basic Setup

Edit the configuration section at the top of service management scripts:

```batch
:: CONFIGURATION
set "PROCESS_NAME=YourProcess.exe"
set "SERVICES=Service1 Service2 Service3"
set "CHECK_INTERVAL=10"
set "SERVICE_STARTUP_TYPE=delayed-auto"
set "VERBOSE_MODE=1"
```

### Configuration Options

| Parameter | Description | Values |
|-----------|-------------|---------|
| `PROCESS_NAME` | Process to monitor (service_manager.bat only) | Any .exe filename |
| `SERVICES` | Space-separated list of service names | Windows service names |
| `CHECK_INTERVAL` | Check interval in seconds | Any positive integer |
| `SERVICE_STARTUP_TYPE` | Service startup configuration | `auto`, `delayed-auto`, `demand`, `disabled` |
| `VERBOSE_MODE` | Detailed logging | `0` (minimal), `1` (verbose) |

## Usage

### System-Level Installation

```cmd
# Install as Windows startup task
install_service.bat

# Check installation status
check_service_status.bat

# Remove from system
uninstall_service.bat
```

### Automatic Service Management

```cmd
# Run script (or install system-wide)
service_manager.bat
```

**What it does:**
- Monitors specified process continuously
- Starts services when process is detected
- Stops services when process terminates
- Configures service startup types
- Provides real-time status updates

### Manual Service Management

#### Start Services
```cmd
# Run script
start_services.bat
```

#### Stop Services
```cmd
# Run script
stop_services.bat
```

## System Installation Details

### Installation Method
The system installation uses **Windows Task Scheduler** instead of Windows Services for better compatibility:

- **Primary**: Scheduled task running at system startup
- **Fallback**: Registry startup entry
- **Privileges**: SYSTEM level access
- **Background**: Runs without visible windows
- **Reliability**: No service timeout errors

### Management Commands
After installation, use these commands:

```cmd
# Manual start
schtasks /run /tn "ServiceManagerAutorun"

# Disable/Enable
schtasks /change /tn "ServiceManagerAutorun" /disable
schtasks /change /tn "ServiceManagerAutorun" /enable

# View details
schtasks /query /tn "ServiceManagerAutorun" /fo list /v

# GUI management
taskschd.msc
```

### Status Checking
The status checker provides comprehensive information:

- **File Status**: Verifies service_manager.bat exists and shows file details
- **Task Status**: Checks scheduled task installation and execution status
- **Registry Status**: Validates registry startup entries
- **Process Status**: Detects currently running instances
- **Event Log**: Reviews recent execution history

## Examples

### Example 1: Database Application
Monitor database GUI and manage related services:

```batch
set "PROCESS_NAME=DatabaseGUI.exe"
set "SERVICES=MSSQLSERVER SQLSERVERAGENT"
set "CHECK_INTERVAL=5"
```

### Example 2: Development Environment
Manage multiple development services:

```batch
set "PROCESS_NAME=VisualStudio.exe"
set "SERVICES=Docker IIS W3SVC MSSQLSERVER Redis"
set "CHECK_INTERVAL=15"
```

### Example 3: Gaming Setup
Control game-related services:

```batch
set "PROCESS_NAME=GameLauncher.exe"
set "SERVICES=SteamService EpicGamesLauncher"
set "CHECK_INTERVAL=10"
```

## Advanced Configuration

### Service Startup Types

| Type | Description |
|------|-------------|
| `auto` | Start automatically at boot |
| `delayed-auto` | Start automatically but delayed |
| `demand` | Start manually when needed |
| `disabled` | Prevent service from starting |

### Script-Specific Options

#### service_manager.bat
```batch
set "CHECK_INTERVAL=10"        # How often to check process (seconds)
set "VERBOSE_MODE=1"           # Show detailed status messages
```

#### start_services.bat
```batch
set "CONFIGURE_SERVICES=1"     # Configure startup type before starting
set "WAIT_FOR_STARTUP=1"       # Wait for services to fully start
```

#### stop_services.bat
```batch
set "FORCE_STOP=1"             # Force stop unresponsive services
set "SET_TO_MANUAL=1"          # Set services to manual after stopping
set "REQUIRE_CONFIRMATION=1"   # Ask for confirmation before stopping
```

## Log Levels

The scripts provide different log levels for better monitoring:

- **INFO**: General information messages
- **ACTION**: Service start/stop actions
- **SUCCESS**: Successful operations
- **ERROR**: Error messages and failures
- **CONFIG**: Configuration changes
- **DEBUG**: Detailed debugging information (verbose mode only)
- **WARNING**: Warning messages
- **STATUS**: Service status reports

## Requirements

- **Windows Operating System**: Windows 7/8/10/11 or Windows Server
- **Administrator Privileges**: Required for service management and system installation
- **Valid Service Names**: Services must exist in Windows Services
- **Task Scheduler**: Required for system-level installation

## Troubleshooting

### Common Issues

**Script requires administrator privileges**
- The script will automatically request administrator rights
- Using PowerShell: Run PowerShell as Administrator and execute scripts

**Service not found error**
- Check service names in Windows Services (services.msc)
- Ensure service names are spelled correctly
- Use exact service names, not display names

**Process not detected**
- Verify process name includes .exe extension
- Check if process name is correct in Task Manager
- Ensure process is running when testing

**Services won't start/stop**
- Check service dependencies
- Verify service is not disabled
- Review Windows Event Logs for service errors

**Installation issues**
- Ensure all files are in the same directory
- Verify service_manager.bat exists before installing
- Check Task Scheduler for created tasks

### Debug Mode

Enable verbose logging for detailed troubleshooting:

```batch
set "VERBOSE_MODE=1"
```

Use `check_service_status.bat` for comprehensive diagnostics.

## Customization

### Adding New Services

Simply add service names to the SERVICES variable:

```batch
set "SERVICES=Service1 Service2 NewService AnotherService"
```

### Modifying Check Intervals

Adjust based on your needs:

```batch
set "CHECK_INTERVAL=5"    # Fast checking (5 seconds)
set "CHECK_INTERVAL=30"   # Slower checking (30 seconds)
```

### Custom Startup Types

Choose the appropriate startup type:

```batch
set "SERVICE_STARTUP_TYPE=delayed-auto"  # Recommended for most cases
set "SERVICE_STARTUP_TYPE=auto"          # Immediate startup
set "SERVICE_STARTUP_TYPE=demand"        # Manual startup only
```

## File Structure

```
project/
├── service_manager.bat          # Core automatic service monitor
├── start_services.bat           # Manual service starter
├── stop_services.bat            # Manual service stopper
├── install_service.bat          # System installation
├── uninstall_service.bat        # System removal
├── check_service_status.bat     # Status checker and diagnostics
├── LICENSE     				 # License
└── README.md                    # This file
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Pro Tip**: Always test scripts with non-critical services first to ensure they work correctly in your environment. Use the system installation for reliable background operation.