<#
.SYNOPSIS
    Collects DCS ENQ logs for a configured date range and outputs one ZIP file.

.DESCRIPTION
    This script collects DCS_ENQ_yyyyMMdd.log files based on ExtractionStartDate and
    ExtractionEndDate configured in config.ps1.

    Current month and previous month logs are read from:
        SourceOnlineLogPath\yyyyMMdd\DCS_ENQ_yyyyMMdd.log

    Older logs are read from archived monthly ZIP files matching:
        SourceArchiveLogPath\Log*OnlineyyyyMM.zip

    Inside each archive ZIP, the script looks for:
        yyyyMMdd\DCS_ENQ_yyyyMMdd.log

    Each collected log file is cleaned by keeping only lines that start with
    the timestamp format:
        yyyy-MM-dd HH:mm:ss

    The script outputs one ZIP file to DestinationZipPath:
        DCS_ENQ_StartDate_to_EndDate_HOSTNAME_TIMESTAMP.zip

    Temporary working files are created under ProcessingWorkPath and removed after
    the final ZIP is created.

    If BackupPath is configured in config.ps1, the final ZIP file is copied there
    after successful creation.

    The script is designed to run daily.
    If ExtractionStartDate or ExtractionEndDate in config.ps1 is empty, the script
    skips processing.

    If the final ZIP file is generated successfully and the temporary folder is
    cleaned up successfully, ExtractionStartDate and ExtractionEndDate in config.ps1
    are cleared.

.SCRIPT NAME
    Get-DcsEnqLogs.ps1

.VERSION
    1.1.0

.AUTHOR
    ITU2

.CREATED
    2026-06-12

.LAST UPDATED
    2026-06-29

.CHANGELOG
    1.1.0 - 2026-06-29
        - Renamed config variables to follow consistent naming conventions.
        - Renamed Clear-ConfigDateRange to Reset-ConfigDateRange.

    1.0.2 - 2026-06-29
        - Added WorkRoot config for temporary working files.
        - OutputRoot is now used only for the final ZIP destination.

    1.0.1 - 2026-06-29
        - Added BkRoot config support to back up the final ZIP file.

    1.0.0 - 2026-06-12
        - Initial release.
        - Added config.ps1 based execution.
        - Added configured hostname support.
        - Added daily-run skip behavior when date range is empty.
        - Added DCS ENQ log collection from online and archived sources.
        - Added final ZIP output format:
          DCS_ENQ_yyyyMMdd_to_yyyyMMdd_HOSTNAME_TIMESTAMP.zip
        - Added automatic clearing of StartDate and EndDate after successful ZIP creation.

.NOTES
    - Compatible with Windows PowerShell 5.1.
    - Source logs are never modified or deleted.
    - Source archive ZIP files are never modified or deleted.
#>

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

# ============================================================
# Script Paths
# ============================================================

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $ScriptRoot "config.ps1"

# ============================================================
# Load Config
# ============================================================

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

try {
    . $ConfigPath
}
catch {
    throw "Failed to load config file: $ConfigPath. Error: $($_.Exception.Message)"
}

# ============================================================
# Default Config Safety
# ============================================================

if (-not (Get-Variable -Name ExtractionStartDate -Scope Script -ErrorAction SilentlyContinue)) {
    $ExtractionStartDate = ""
}

if (-not (Get-Variable -Name ExtractionEndDate -Scope Script -ErrorAction SilentlyContinue)) {
    $ExtractionEndDate = ""
}

if (-not (Get-Variable -Name TargetHostName -Scope Script -ErrorAction SilentlyContinue)) {
    $TargetHostName = ""
}

if (-not (Get-Variable -Name SourceOnlineLogPath -Scope Script -ErrorAction SilentlyContinue)) {
    $SourceOnlineLogPath = "O:\Log\Online"
}

if (-not (Get-Variable -Name SourceArchiveLogPath -Scope Script -ErrorAction SilentlyContinue)) {
    $SourceArchiveLogPath = "O:\ArchivedLog"
}

if (-not (Get-Variable -Name DestinationZipPath -Scope Script -ErrorAction SilentlyContinue)) {
    $DestinationZipPath = "O:\Batch\dcs_enq_log_extracter"
}

if (-not (Get-Variable -Name ProcessingWorkPath -Scope Script -ErrorAction SilentlyContinue)) {
    $ProcessingWorkPath = "O:\Batch\dcs_enq_log_extracter\work"
}

if (-not (Get-Variable -Name LogPath -Scope Script -ErrorAction SilentlyContinue)) {
    $LogPath = ""
}

if (-not (Get-Variable -Name BackupPath -Scope Script -ErrorAction SilentlyContinue)) {
    $BackupPath = ""
}

# ============================================================
# Runtime Values
# ============================================================

$RunTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ([string]::IsNullOrWhiteSpace($TargetHostName)) {
    $ResolvedHostName = $env:COMPUTERNAME
}
else {
    $ResolvedHostName = $TargetHostName
}

$InvalidFileNameCharsPattern = '[\\/:*?"<>|]'
$SafeHostName = $ResolvedHostName -replace $InvalidFileNameCharsPattern, "_"

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $ProcessingWorkPath "log"
}

# ============================================================
# Prepare Logging
# ============================================================

try {
    if (-not (Test-Path -LiteralPath $DestinationZipPath)) {
        New-Item -Path $DestinationZipPath -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $ProcessingWorkPath)) {
        New-Item -Path $ProcessingWorkPath -ItemType Directory -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $LogPath)) {
        New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
    }
}
catch {
    throw "Failed to create destination, work, or log folder. Error: $($_.Exception.Message)"
}

$ScriptLogFilePath = Join-Path $LogPath ("Get-DcsEnqLogs_{0}_{1}.log" -f $SafeHostName, $RunTimestamp)

function Write-Log {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [string]$Message = ""
    )

    $line = ""

    if ([string]::IsNullOrEmpty($Message)) {
        $line = ""
    }
    else {
        $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    }

    Add-Content -Path $ScriptLogFilePath -Value $line -Encoding UTF8
    Write-Host $line
}

function Reset-ConfigDateRange {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $content = Get-Content -LiteralPath $Path -Raw

    $content = [regex]::Replace(
        $content,
        '(?m)^\s*\$ExtractionStartDate\s*=.*$',
        '$ExtractionStartDate = ""'
    )

    $content = [regex]::Replace(
        $content,
        '(?m)^\s*\$ExtractionEndDate\s*=.*$',
        '$ExtractionEndDate = ""'
    )

    Set-Content -LiteralPath $Path -Value $content -Encoding UTF8
}

function Clean-LogFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $timestampPattern = '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}'
    $tempFile = "$Path.tmp"

    Get-Content -LiteralPath $Path | Where-Object {
        $_ -match $timestampPattern
    } | Set-Content -LiteralPath $tempFile -Encoding UTF8

    Move-Item -LiteralPath $tempFile -Destination $Path -Force
}

function Get-MonthStart {
    param(
        [Parameter(Mandatory = $true)]
        [datetime]$Date
    )

    return Get-Date -Year $Date.Year -Month $Date.Month -Day 1 -Hour 0 -Minute 0 -Second 0
}

# ============================================================
# Start Log
# ============================================================

Write-Log "INFO" "Script started."
Write-Log "INFO" "Script path: $($MyInvocation.MyCommand.Path)"
Write-Log "INFO" "Config path: $ConfigPath"
Write-Log "INFO" "User name: $env:USERNAME"
Write-Log "INFO" "Computer name: $env:COMPUTERNAME"
Write-Log "INFO" "Target host name: $TargetHostName"
Write-Log "INFO" "Resolved host name: $ResolvedHostName"
Write-Log "INFO" "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Log "INFO" "Source online log path: $SourceOnlineLogPath"
Write-Log "INFO" "Source archive log path: $SourceArchiveLogPath"
Write-Log "INFO" "Destination ZIP path: $DestinationZipPath"
Write-Log "INFO" "Processing work path: $ProcessingWorkPath"
Write-Log "INFO" "Log path: $LogPath"
Write-Log "INFO" "Backup path: $BackupPath"
Write-Log "INFO" "Configured extraction start date: $ExtractionStartDate"
Write-Log "INFO" "Configured extraction end date: $ExtractionEndDate"
Write-Log -Message ""

# ============================================================
# Skip If Date Range Empty
# ============================================================

if ([string]::IsNullOrWhiteSpace([string]$ExtractionStartDate) -or [string]::IsNullOrWhiteSpace([string]$ExtractionEndDate)) {
    Write-Log "WARN" "ExtractionStartDate or ExtractionEndDate is empty. Skipping processing."
    Write-Log "INFO" "Config file date range was not changed."
    Write-Log "INFO" "Script completed."
    exit 0
}

# ============================================================
# Validate Dates
# ============================================================

try {
    $ParsedStartDate = [datetime]::Parse($ExtractionStartDate).Date
}
catch {
    Write-Log "ERROR" "Invalid ExtractionStartDate value: $ExtractionStartDate"
    throw
}

try {
    $ParsedEndDate = [datetime]::Parse($ExtractionEndDate).Date
}
catch {
    Write-Log "ERROR" "Invalid ExtractionEndDate value: $ExtractionEndDate"
    throw
}

if ($ParsedStartDate -gt $ParsedEndDate) {
    Write-Log "ERROR" "ExtractionStartDate is later than ExtractionEndDate. StartDate=$($ParsedStartDate.ToString('yyyy-MM-dd')), EndDate=$($ParsedEndDate.ToString('yyyy-MM-dd'))"
    throw "Invalid date range. ExtractionStartDate cannot be later than ExtractionEndDate."
}

$StartDateCompact = $ParsedStartDate.ToString("yyyyMMdd")
$EndDateCompact = $ParsedEndDate.ToString("yyyyMMdd")

Write-Log "INFO" "Date range is valid."
Write-Log "INFO" "Start date: $($ParsedStartDate.ToString('yyyy-MM-dd'))"
Write-Log "INFO" "End date: $($ParsedEndDate.ToString('yyyy-MM-dd'))"
Write-Log -Message ""

# ============================================================
# Prepare Temporary Folder
# ============================================================

$WorkingSessionName = "DCS_ENQ_{0}_to_{1}_{2}_{3}_work" -f $StartDateCompact, $EndDateCompact, $SafeHostName, $RunTimestamp
$WorkingSessionPath = Join-Path $ProcessingWorkPath $WorkingSessionName

try {
    if (Test-Path -LiteralPath $WorkingSessionPath) {
        Remove-Item -LiteralPath $WorkingSessionPath -Recurse -Force
    }

    New-Item -Path $WorkingSessionPath -ItemType Directory -Force | Out-Null
    Write-Log "INFO" "Temporary working folder created: $WorkingSessionPath"
}
catch {
    Write-Log "ERROR" "Failed to prepare temporary working folder: $WorkingSessionPath. Error: $($_.Exception.Message)"
    throw
}

# ============================================================
# Load ZIP Assembly
# ============================================================

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Write-Log "INFO" "Loaded ZIP assembly: System.IO.Compression.FileSystem"
}
catch {
    Write-Log "ERROR" "Failed to load ZIP assembly. Error: $($_.Exception.Message)"
    throw
}

# ============================================================
# Determine Online Months
# ============================================================

$Today = Get-Date
$CurrentMonthStart = Get-MonthStart -Date $Today
$PreviousMonthStart = $CurrentMonthStart.AddMonths(-1)

Write-Log "INFO" "Current month start: $($CurrentMonthStart.ToString('yyyy-MM-dd'))"
Write-Log "INFO" "Previous month start: $($PreviousMonthStart.ToString('yyyy-MM-dd'))"
Write-Log -Message ""

# ============================================================
# Process Dates
# ============================================================

$CollectedLogCount = 0
$CurrentDate = $ParsedStartDate

while ($CurrentDate -le $ParsedEndDate) {
    $DateText = $CurrentDate.ToString("yyyyMMdd")
    $MonthText = $CurrentDate.ToString("yyyyMM")
    $DateMonthStart = Get-MonthStart -Date $CurrentDate

    $LogFileName = "DCS_ACCESS_{0}.log" -f $DateText

    Write-Log "INFO" "Processing date: $($CurrentDate.ToString('yyyy-MM-dd'))"

    $DestinationFolder = Join-Path $WorkingSessionPath (Join-Path $MonthText $DateText)
    $DestinationFile = Join-Path $DestinationFolder $LogFileName

    $FoundForDate = $false

    if ($DateMonthStart -ge $PreviousMonthStart) {
        # Online source
        $OnlineDateFolder = Join-Path $SourceOnlineLogPath $DateText
        $OnlineFile = Join-Path $OnlineDateFolder $LogFileName

        Write-Log "INFO" "Selected source: online"
        Write-Log "INFO" "Looking for online log: $OnlineFile"

        if (Test-Path -LiteralPath $OnlineFile) {
            try {
                New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null
                Copy-Item -LiteralPath $OnlineFile -Destination $DestinationFile -Force

                Clean-LogFile -Path $DestinationFile

                $CollectedLogCount++
                $FoundForDate = $true

                Write-Log "INFO" "Copied and cleaned online log: $DestinationFile"
            }
            catch {
                Write-Log "ERROR" "Failed to copy or clean online log for $DateText. Error: $($_.Exception.Message)"

                if (Test-Path -LiteralPath $DestinationFolder) {
                    try {
                        Remove-Item -LiteralPath $DestinationFolder -Recurse -Force
                    }
                    catch {
                        Write-Log "WARN" "Failed to remove incomplete destination folder: $DestinationFolder"
                    }
                }
            }
        }
        else {
            Write-Log "WARN" "Online log not found: $OnlineFile"
        }
    }
    else {
    # Archive source
    $ArchivePattern = "Log*Online{0}.zip" -f $MonthText
    $ArchiveFiles = @(Get-ChildItem -Path $SourceArchiveLogPath -Filter $ArchivePattern -File -ErrorAction SilentlyContinue)

    Write-Log "INFO" "Selected source: archive"
    Write-Log "INFO" "Archive search pattern: $(Join-Path $SourceArchiveLogPath $ArchivePattern)"

    if ($ArchiveFiles.Count -eq 0) {
        Write-Log "WARN" "No archive ZIP files found for month $MonthText using pattern $ArchivePattern"
    }
    else {
        foreach ($ArchiveFile in $ArchiveFiles) {
            if ($FoundForDate) {
                break
            }

            Write-Log "INFO" "Checking archive ZIP: $($ArchiveFile.FullName)"

            $zip = $null

            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($ArchiveFile.FullName)

                $ExpectedEntryForward = "{0}/{1}" -f $DateText, $LogFileName
                $ExpectedEntryBackslash = "{0}\{1}" -f $DateText, $LogFileName

                $entry = $zip.Entries | Where-Object {
                    $_.FullName -eq $ExpectedEntryForward -or
                    $_.FullName -eq $ExpectedEntryBackslash
                } | Select-Object -First 1

                if ($null -eq $entry) {
                    Write-Log "WARN" "Entry not found in archive: $($ArchiveFile.Name) -> $ExpectedEntryForward"
                }
                else {
                    New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null

                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile(
                        $entry,
                        $DestinationFile,
                        $true
                    )

                    Clean-LogFile -Path $DestinationFile

                    $CollectedLogCount++
                    $FoundForDate = $true

                    Write-Log "INFO" "Extracted and cleaned archived log: $DestinationFile"
                }
            }
            catch {
                Write-Log "ERROR" "Failed to process archive ZIP: $($ArchiveFile.FullName). Error: $($_.Exception.Message)"

                if (Test-Path -LiteralPath $DestinationFolder) {
                    try {
                        Remove-Item -LiteralPath $DestinationFolder -Recurse -Force
                    }
                    catch {
                        Write-Log "WARN" "Failed to remove incomplete destination folder: $DestinationFolder"
                    }
                }
            }
            finally {
                if ($null -ne $zip) {
                    $zip.Dispose()
                }
            }
        }
    }
}

    if (-not $FoundForDate) {
        Write-Log "WARN" "No log collected for date: $DateText"

        if (Test-Path -LiteralPath $DestinationFolder) {
            try {
                $remainingItems = Get-ChildItem -LiteralPath $DestinationFolder -Force -ErrorAction SilentlyContinue

                if (-not $remainingItems -or $remainingItems.Count -eq 0) {
                    Remove-Item -LiteralPath $DestinationFolder -Recurse -Force
                    Write-Log "INFO" "Removed empty destination folder: $DestinationFolder"
                }
            }
            catch {
                Write-Log "WARN" "Failed to clean empty destination folder: $DestinationFolder"
            }
        }
    }

    Write-Log -Message ""
    $CurrentDate = $CurrentDate.AddDays(1)
}

Write-Log "INFO" "Date processing completed."
Write-Log "INFO" "Collected log count: $CollectedLogCount"
Write-Log -Message ""

# ============================================================
# No Logs Found
# ============================================================

if ($CollectedLogCount -eq 0) {
    Write-Log "WARN" "No logs were collected. Final ZIP will not be created."

    if (Test-Path -LiteralPath $WorkingSessionPath) {
        try {
            Remove-Item -LiteralPath $WorkingSessionPath -Recurse -Force
            Write-Log "INFO" "Temporary working folder removed: $WorkingSessionPath"
        }
        catch {
            Write-Log "ERROR" "Failed to remove temporary working folder: $WorkingSessionPath. Error: $($_.Exception.Message)"
            throw
        }
    }

    Write-Log "INFO" "Config file date range was not cleared because no ZIP was created."
    Write-Log "INFO" "Script completed."
    exit 0
}

# ============================================================
# Create Final ZIP
# ============================================================

$ZipFileName = "DCS_ENQ_{0}_to_{1}_{2}_{3}.zip" -f $StartDateCompact, $EndDateCompact, $SafeHostName, $RunTimestamp
$ZipFilePath = Join-Path $DestinationZipPath $ZipFileName

try {
    if (Test-Path -LiteralPath $ZipFilePath) {
        Remove-Item -LiteralPath $ZipFilePath -Force
    }

    Compress-Archive -Path (Join-Path $WorkingSessionPath "*") -DestinationPath $ZipFilePath -Force

    if (-not (Test-Path -LiteralPath $ZipFilePath)) {
        throw "ZIP file was not created: $ZipFilePath"
    }

    Write-Log "INFO" "Final ZIP file created successfully: $ZipFilePath"
}
catch {
    Write-Log "ERROR" "Failed to create final ZIP file. Error: $($_.Exception.Message)"
    throw
}

# ============================================================
# Backup Final ZIP
# ============================================================

if (-not [string]::IsNullOrWhiteSpace($BackupPath)) {
    $BackupZipFilePath = Join-Path $BackupPath $ZipFileName

    try {
        if (-not (Test-Path -LiteralPath $BackupPath)) {
            New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
            Write-Log "INFO" "Backup folder created: $BackupPath"
        }

        if (Test-Path -LiteralPath $BackupZipFilePath) {
            Remove-Item -LiteralPath $BackupZipFilePath -Force
        }

        Copy-Item -LiteralPath $ZipFilePath -Destination $BackupZipFilePath -Force

        if (-not (Test-Path -LiteralPath $BackupZipFilePath)) {
            throw "Backup ZIP file was not created: $BackupZipFilePath"
        }

        Write-Log "INFO" "Final ZIP file backed up successfully: $BackupZipFilePath"
    }
    catch {
        Write-Log "ERROR" "Failed to back up final ZIP file. Error: $($_.Exception.Message)"
        Write-Log "ERROR" "Config file date range will not be cleared."
        throw
    }
}
else {
    Write-Log "INFO" "Backup path is empty. Skipping ZIP backup."
}

# ============================================================
# Cleanup Temporary Folder
# ============================================================

try {
    Remove-Item -LiteralPath $WorkingSessionPath -Recurse -Force
    Write-Log "INFO" "Temporary working folder removed: $WorkingSessionPath"
}
catch {
    Write-Log "ERROR" "Failed to remove temporary working folder after ZIP creation. Error: $($_.Exception.Message)"
    Write-Log "ERROR" "Config file date range will not be cleared."
    throw
}

# ============================================================
# Reset Config Date Range
# ============================================================

try {
    Reset-ConfigDateRange -Path $ConfigPath
    Write-Log "INFO" "Config file date range reset successfully."
}
catch {
    Write-Log "ERROR" "Failed to reset ExtractionStartDate and ExtractionEndDate in config file. Error: $($_.Exception.Message)"
    throw
}

Write-Log "INFO" "Script completed successfully."
exit 0
