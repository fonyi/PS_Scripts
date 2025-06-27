# Define where to save exported logs
$UserDesktop = [Environment]::GetFolderPath("Desktop")
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$ExportFolder = Join-Path -Path $UserDesktop -ChildPath "EventLogs_$TimeStamp"

# Create the folder if it doesn't exist
New-Item -Path $ExportFolder -ItemType Directory -Force | Out-Null

# Get list of all event logs
$Logs = Get-WinEvent -ListLog *

Write-Host "Exporting event logs to $ExportFolder..." -ForegroundColor Cyan

foreach ($Log in $Logs) {
    $SafeLogName = $Log.LogName -replace '[\\/:*?"<>|]', '_'
    $ExportFile = Join-Path -Path $ExportFolder -ChildPath ($SafeLogName + ".evtx")
    try {
        # Export the log
        wevtutil epl "$($Log.LogName)" "$ExportFile"
    } catch {
        Write-Warning "Failed to export log: $($Log.LogName) - $_"
    }
}

# Define the zip file path
$ZipFilePath = Join-Path -Path $UserDesktop -ChildPath ("EventLogs_$TimeStamp.zip")

Write-Host "Zipping exported logs to $ZipFilePath..." -ForegroundColor Cyan

try {
    Compress-Archive -Path "$ExportFolder\*" -DestinationPath $ZipFilePath -Force
    Write-Host "Done! Zip file created at: $ZipFilePath" -ForegroundColor Green
} catch {
    Write-Error "Failed to zip the logs: $_"
}
