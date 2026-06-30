# Get-DcsEnqLogs

PowerShell script for collecting DCS ACCESS log files for a configured date
range, cleaning them, and packaging them into one DCS ENQ ZIP file.

## What it does

- Reads `DCS_ACCESS_yyyyMMdd.log` files for the configured date range.
- Uses online log folders for the current and previous month.
- Uses archived monthly ZIP files for older dates.
- Keeps only log lines that start with `yyyy-MM-dd HH:mm:ss`.
- Removes lines where the username column contains `uat`, case-insensitive.
- Creates one final ZIP file named:

```text
DCS_ENQ_StartDate_to_EndDate_HOSTNAME_TIMESTAMP.zip
```

Collected log files keep their original `DCS_ACCESS_yyyyMMdd.log` names inside
the ZIP. Only the final ZIP file uses the `DCS_ENQ` name.

## Files

| File | Purpose |
| --- | --- |
| `Get-DcsEnqLogs.ps1` | Main extraction script |
| `config.ps1` | Runtime configuration |

## Requirements

- Windows PowerShell 5.1
- Access to the configured source paths, destination path, work path, log path,
  and optional backup path

## Configure

Edit `config.ps1`.

### Run control

Leave either date empty to skip processing. After a successful ZIP is created,
the script clears both values automatically.

```powershell
$ExtractionStartDate = ""
$ExtractionEndDate = ""
```

Example:

```powershell
$ExtractionStartDate = "2026-03-01"
$ExtractionEndDate   = "2026-06-04"
```

### Identity

Used in the final ZIP filename. If empty, the script uses
`$env:COMPUTERNAME`.

```powershell
$TargetHostName = "CEXDCWDC1AP93"
```

### Source paths

```powershell
$SourceOnlineLogPath = "O:\Log\Online"
$SourceArchiveLogPath = "O:\ArchivedLog"
```

Expected online source file:

```text
SourceOnlineLogPath\yyyyMMdd\DCS_ACCESS_yyyyMMdd.log
```

Expected archive ZIP pattern:

```text
SourceArchiveLogPath\Log*OnlineyyyyMM.zip
```

Expected entry inside archive ZIP:

```text
yyyyMMdd\DCS_ACCESS_yyyyMMdd.log
```

### Destination and processing paths

```powershell
$DestinationZipPath = "O:\Batch\dcs_enq_log_extracter"
$BackupPath = "O:\Batch\dcs_enq_log_extracter\backup"
$ProcessingWorkPath = "O:\Batch\dcs_enq_log_extracter\work"
$LogPath = "O:\Batch\dcs_enq_log_extracter\log"
```

| Config | Purpose |
| --- | --- |
| `$DestinationZipPath` | Final ZIP destination |
| `$BackupPath` | Optional backup copy of the final ZIP; empty disables backup |
| `$ProcessingWorkPath` | Temporary working directory |
| `$LogPath` | Script execution logs |

If `$LogPath` is empty, logs are written to:

```text
ProcessingWorkPath\log
```

## Output layout

Example default layout:

```text
O:\Batch\dcs_enq_log_extracter\
├── DCS_ENQ_20260301_to_20260604_CEXDCWDC1AP93_20260630_083000.zip
├── backup\
│   └── DCS_ENQ_20260301_to_20260604_CEXDCWDC1AP93_20260630_083000.zip
├── work\
└── log\
    └── 20260630.log
```

## Log cleaning

The script keeps only lines that start with this timestamp format:

```text
yyyy-MM-dd HH:mm:ss
```

It also removes lines where the username column contains `uat`,
case-insensitive.

Example removed line:

```text
2026-06-04 15:39:56,061 [9] [10.12.187.33] [5ba5bc31040e4ee6ad98d1da7f62065f] [cpuat37] [FLP019] [FLP019S02] DEBUG [(null)] -
```

In this format, the username is the fourth bracket-enclosed field after the
timestamp. `cpuat37` contains `uat`, so the line is removed.

## Run

From the folder containing both files:

```powershell
.\Get-DcsEnqLogs.ps1
```

The script is designed for daily scheduled execution. If either extraction date
is empty, it logs that processing was skipped and exits successfully.

## Version

Current version: `1.1.0`