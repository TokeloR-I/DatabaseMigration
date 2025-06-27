# DB Migrator Script with Error Handling and Logging
# Can be compiled with ps2exe to a standalone EXE

[CmdletBinding()]
param()

# Function to log messages
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path ".\migration_log.txt" -Value $logMessage
    Write-Host $logMessage
}

# Prompt for details
$Instance = Read-Host "Enter SQL Instance (e.g., localhost\SQLEXPRESS)"
$SAUser = Read-Host "Enter SQL Admin Username"
$SAPassword = Read-Host "Enter SQL Admin Password" 

# File selection dialog
Add-Type -AssemblyName System.Windows.Forms
$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
$OpenFileDialog.Filter = "MDF Files (*.mdf)|*.mdf"
$OpenFileDialog.Title = "Select the MDF file for the database"

if ($OpenFileDialog.ShowDialog() -eq "OK") {
    $DBPath = $OpenFileDialog.FileName
    $DBName = [System.IO.Path]::GetFileNameWithoutExtension($DBPath)
    Write-Log "Selected database file: $DBPath"
} else {
    Write-Host "No file selected. Exiting..."
    exit
}

# Detach DB if exists
$DetachSQL = @"
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$DBName')
BEGIN
    ALTER DATABASE [$DBName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    EXEC sp_detach_db '$DBName';
END
"@

Write-Log "Detaching existing database (if any)..."
try {
    sqlcmd -S $Instance -U $SAUser -P $SAPassword -Q $DetachSQL -b
    Write-Log "Database detached successfully or did not exist."
} catch {
    Write-Log "ERROR during detach: $_"
    exit 1
}

# Attach new DB
$LogFilePath = $DBPath.Replace(".mdf", "log.ldf")
$AttachSQL = @"
CREATE DATABASE [$DBName] ON 
(FILENAME = N'$DBPath'),
(FILENAME = N'$LogFilePath')
FOR ATTACH;
"@

Write-Log "Attaching selected database..."
try {
    sqlcmd -S $Instance -U $SAUser -P $SAPassword -Q $AttachSQL -b
    Write-Log "Database attached successfully."
} catch {
    Write-Log "ERROR during attach: $_"
    exit 1
}

# Run orphan fix script
$OrphanScriptPath = ".\orphan_fix.sql"
if (Test-Path $OrphanScriptPath) {
    Write-Log "Running orphan fix script..."
    try {
        sqlcmd -S $Instance -U $SAUser -P $SAPassword -d $DBName -i $OrphanScriptPath -b
        Write-Log "Orphan users fixed successfully."
    } catch {
        Write-Log "ERROR during orphan fix: $_"
        exit 1
    }
} else {
    Write-Log "WARNING: Orphan fix script not found at $OrphanScriptPath. Skipping..."
}

Write-Log "✅ Migration completed!"
pause
