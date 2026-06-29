<#
.SYNOPSIS
    Configuration file for Get-DcsEnqLogs.ps1

.DESCRIPTION
    This file contains all configurable values for Get-DcsEnqLogs.ps1.

    The script is designed to run daily.

    If StartDate or EndDate is empty, the script will skip processing.

    If both StartDate and EndDate contain valid dates, the script will collect
    DCS ENQ logs for the inclusive date range.

    After the final ZIP file is generated successfully and the temporary working
    folder is removed successfully, the script will automatically clear
    StartDate and EndDate.

.DATE FORMAT
    Recommended date format:
        yyyy-MM-dd

.EXAMPLE
    To enable log extraction, set:
$StartDate = ""
$EndDate = ""

    After successful ZIP generation, the script will reset them to:
$StartDate = ""
$EndDate = ""

.NOTES
    If HostName is empty, the script uses the local computer name.

    If ScriptLogRoot is empty, the script writes execution logs to:
        OutputRoot\log

    If BkRoot is empty, the script skips backing up the final ZIP file.
#>

# ============================================================
# Date Range
# Leave empty to skip processing.
# The script clears these values after successful ZIP creation.
# ============================================================
$StartDate = ""
$EndDate = ""

# Example:
# $StartDate = "2026-03-01"
# $EndDate   = "2026-06-04"

# ============================================================
# Host Name
# If empty, the script uses $env:COMPUTERNAME.
# This value is used in the final ZIP filename and script log filename.
# ============================================================

$HostName = "CEXDCWDC1AP93"

# Example:
# $HostName = "CEXDCWDC1AP93"

# ============================================================
# Source Paths
# ============================================================

$OnlineLogRoot = "O:\Log\Online"
$ArchivedLogRoot = "O:\ArchivedLog"

# ============================================================
# Output Paths
# ============================================================

$OutputRoot = "O:\Batch\dcs_enq_log_extracter"

# If empty, defaults to:
#     OutputRoot\log
$ScriptLogRoot = "O:\Batch\dcs_enq_log_extracter"

# If empty, the script skips backing up the final ZIP file.
$BkRoot = "O:\Batch\dcs_enq_log_extracter\bk"