<#
.SYNOPSIS
    Configuration file for Get-DcsEnqLogs.ps1

.DESCRIPTION
    This file contains all configurable values for Get-DcsEnqLogs.ps1.

    The script is designed to run daily.

    If ExtractionStartDate or ExtractionEndDate is empty, the script will skip processing.

    If both ExtractionStartDate and ExtractionEndDate contain valid dates, the script
    will collect DCS ENQ logs for the inclusive date range.

    After the final ZIP file is generated successfully and the temporary working
    folder is removed successfully, the script will automatically clear
    ExtractionStartDate and ExtractionEndDate.

.DATE FORMAT
    Recommended date format:
        yyyy-MM-dd

.EXAMPLE
    To enable log extraction, set:
$ExtractionStartDate = "2026-03-01"
$ExtractionEndDate   = "2026-06-04"

    After successful ZIP generation, the script will reset them to:
$ExtractionStartDate = ""
$ExtractionEndDate   = ""

.NOTES
    If TargetHostName is empty, the script uses the local computer name.

    If LogPath is empty, the script writes execution logs to:
        ProcessingWorkPath\log

    If BackupPath is empty, the script skips backing up the final ZIP file.
#>

# ============================================================
# Run Control
# Leave empty to skip processing.
# The script clears these values after successful ZIP creation.
# ============================================================
$ExtractionStartDate = ""
$ExtractionEndDate = ""

# Example:
# $ExtractionStartDate = "2026-03-01"
# $ExtractionEndDate   = "2026-06-04"

# ============================================================
# Identity
# If empty, the script uses $env:COMPUTERNAME.
# This value is used in the final ZIP filename and script log filename.
# ============================================================

$TargetHostName = "CEXDCWDC1AP93"

# Example:
# $TargetHostName = "CEXDCWDC1AP93"

# ============================================================
# Source Paths
# ============================================================

$SourceOnlineLogPath = "O:\Log\Online"
$SourceArchiveLogPath = "O:\ArchivedLog"

# ============================================================
# Destination Paths
# ============================================================

# Final destination for the generated ZIP file.
$DestinationZipPath = "O:\Batch\dcs_enq_log_extracter"

# If empty, the script skips backing up the final ZIP file.
$BackupPath = "O:\Batch\dcs_enq_log_extracter\backup"

# ============================================================
# Processing Paths
# ============================================================

# Temporary working directory for collected logs during processing.
$ProcessingWorkPath = "O:\Batch\dcs_enq_log_extracter\work"

# If empty, defaults to:
#     ProcessingWorkPath\log
$LogPath = "O:\Batch\dcs_enq_log_extracter\log"
