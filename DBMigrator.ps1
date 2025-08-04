# DB Migrator Script with Error Handling and Logging
# Can be compiled with ps2exe to a standalone EXE

[CmdletBinding()]
param()

# --- Configuration ---
# Set the default path for the log file
$LogFilePath = ".\migration_log.txt"
# Set the default path for the orphan fix script
$OrphanScriptPath = ".\orphan_fix.sql"

# --- Functions ---

# Function to write messages to log and console
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Path = $LogFilePath
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    try {
        # Append the log message to the specified file
        Add-Content -Path $Path -Value $logMessage -ErrorAction Stop
        # Also write the message to the console
        Write-Host $logMessage
    }
    catch {
        # If logging fails, write a critical error to the console
        Write-Host "FATAL ERROR: Could not write to log file '$Path'. Error: $_" -ForegroundColor Red
    }
}

# Function to execute sqlcmd safely
# It handles credential passing and checks the process exit code
function Invoke-Sqlcmd {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Instance,
        [Parameter(Mandatory=$true)]
        [string]$User,
        [Parameter(Mandatory=$true)]
        [System.Security.SecureString]$Password,
        [Parameter(Mandatory=$false)]
        [string]$Database = "",
        [Parameter(Mandatory=$false)]
        [string]$Query,
        [Parameter(Mandatory=$false)]
        [string]$InputFile,
        [Parameter(Mandatory=$true)]
        [string]$TaskName
    )

    Write-Log "Executing SQL Task: $TaskName..."

    # Use a try/finally block to ensure the password is cleared from memory
    try {
        # Convert the secure string to a plain text string for sqlcmd
        $passwordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $plainTextPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($passwordBSTR)

        # Build the argument list for sqlcmd
        $sqlCmdArgs = @(
            "-S", $Instance,
            "-U", $User,
            "-P", $plainTextPassword,
            "-b" # Exit on error
        )
        
        if (-not [string]::IsNullOrEmpty($Database)) {
            $sqlCmdArgs += ("-d", $Database)
        }
        if (-not [string]::IsNullOrEmpty($Query)) {
            $sqlCmdArgs += ("-Q", $Query)
        }
        if (-not [string]::IsNullOrEmpty($InputFile)) {
            $sqlCmdArgs += ("-i", $InputFile)
        }

        # Start the sqlcmd process and wait for it to finish.
        # The -b flag ensures a non-zero exit code on failure, which we check.
        $process = Start-Process -FilePath "sqlcmd" -ArgumentList $sqlCmdArgs -NoNewWindow -PassThru -Wait -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            throw "sqlcmd returned a non-zero exit code: $($process.ExitCode). Check the sqlcmd output for more details."
        }

        Write-Log "Task '$TaskName' completed successfully."
    }
    catch {
        Write-Log "ERROR during '$TaskName': $_"
        throw # Re-throw the error to stop the script execution
    }
    finally {
        # This is a critical step for security: clear the password from memory
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordBSTR)
    }
}

# --- Main Script Logic ---

Write-Log "Starting database migration script..."

# Check if the orphan fix script exists at the start to provide an early warning
if (-not (Test-Path $OrphanScriptPath)) {
    Write-Log "WARNING: Orphan fix script not found at '$OrphanScriptPath'. The orphan fix step will be skipped."
}

# --- Prompt for details ---
$Instance = Read-Host "Enter SQL Instance (e.g., localhost\SQLEXPRESS)"
$SAUser = Read-Host "Enter SQL Admin Username"
Write-Host "Enter SQL Admin Password:" -NoNewline
# Use -AsSecureString for secure password input
$SAPassword = Read-Host -AsSecureString

# --- File selection dialog ---
Write-Log "Opening file selection dialog..."
Add-Type -AssemblyName System.Windows.Forms
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.Filter = "MDF Files (*.mdf)|*.mdf"
$OpenFileDialog.Title = "Select the MDF file for the database"

if ($OpenFileDialog.ShowDialog() -eq "OK") {
    $DBPath = $OpenFileDialog.FileName
    $DBName = [System.IO.Path]::GetFileNameWithoutExtension($DBPath)
    Write-Log "Selected database file: $DBPath"
}
else {
    Write-Log "No file selected. Exiting script."
    exit
}

# --- Detach DB if it exists ---
$DetachSQL = @"
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$DBName')
BEGIN
    ALTER DATABASE [$DBName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    EXEC sp_detach_db '$DBName';
END
"@
Invoke-Sqlcmd -Instance $Instance -User $SAUser -Password $SAPassword -Query $DetachSQL -TaskName "Detach existing database"

# --- Attach new DB ---
# Use Path methods for robust file path construction
$LogFilePathForDB = "$([System.IO.Path]::GetDirectoryName($DBPath))\$DBName.ldf"
$AttachSQL = @"
CREATE DATABASE [$DBName] ON 
(FILENAME = N'$DBPath'),
(FILENAME = N'$LogFilePathForDB')
FOR ATTACH;
"@
Invoke-Sqlcmd -Instance $Instance -User $SAUser -Password $SAPassword -Query $AttachSQL -TaskName "Attach new database"

# --- Run orphan fix script ---
if (Test-Path $OrphanScriptPath) {
    Invoke-Sqlcmd -Instance $Instance -User $SAUser -Password $SAPassword -Database $DBName -InputFile $OrphanScriptPath -TaskName "Run orphan fix script"
}
else {
    Write-Log "Skipping orphan fix script as it was not found."
}

# --- Final message ---
Write-Log "✅ Migration completed successfully!"
pause
