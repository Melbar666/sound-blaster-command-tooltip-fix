$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework

$Title = 'Sound Blaster Command - Tooltip Fix Verification'
$Target = 'C:\Program Files (x86)\Creative\Sound Blaster Command\Package\Hardcodet.Wpf.TaskbarNotification.dll'
$Backup = $Target + '.sticky-tooltip-fix.original.bak'

# Compatibility with pre-public builds of this fix that used the earlier backup name.
$LegacyBackup = $Target + '.original-1.0.5.0.bak'

$ExpectedOriginalHash = '4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E'
$ExpectedPatchedHash  = '72CDC5A4A5841158915D6B8ED414758E39B6C5A9871274BB90B2F23EC7FA4117'
$NL = [Environment]::NewLine

$LogDir = Join-Path $env:TEMP 'SoundBlasterCommand-TooltipFix'
$LogPath = Join-Path $LogDir 'verify.log'
$DisplayLogPath = '%TEMP%\SoundBlasterCommand-TooltipFix\verify.log'

function Write-Log([string]$Message) {
    try {
        if (-not (Test-Path -LiteralPath $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction Stop | Out-Null
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Add-Content -LiteralPath $LogPath -Value "$timestamp  $Message" -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Warning ("Diagnostic logging failed: " + $_.Exception.Message)
    }
}

function Get-Sha256([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $hashBytes = $sha.ComputeHash($stream)
        }
        finally {
            $sha.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }

    ([System.BitConverter]::ToString($hashBytes)).Replace('-', '')
}

function Show-Result([string]$Text, [string]$Icon = 'Information') {
    [System.Windows.MessageBox]::Show($Text, $Title, 'OK', $Icon) | Out-Null
}

Write-Log '=== Verification started ==='

try {
    if (-not (Test-Path -LiteralPath $Target)) {
        Write-Log 'Result: NOT VERIFIED - target DLL missing.'
        Show-Result ("NOT VERIFIED$NL$NL" + "The expected Sound Blaster Command DLL was not found.$NL$NL$Target$NL$NL" + "Diagnostic log:$NL$DisplayLogPath") 'Warning'
        exit 1
    }

    $targetHash = Get-Sha256 $Target
    Write-Log ("Target SHA-256: {0}" -f $targetHash)

    $assemblyVersion = 'unknown'
    try {
        $assemblyVersion = ([Reflection.AssemblyName]::GetAssemblyName($Target)).Version.ToString()
        Write-Log ("Assembly version: {0}" -f $assemblyVersion)
    }
    catch {
        Write-Log ("WARNING: Could not read assembly version: " + $_.Exception.Message)
    }

    $running = @(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue).Count -gt 0
    $runningText = if ($running) { 'Yes' } else { 'No' }
    Write-Log ("Sound Blaster Command running: {0}" -f $runningText)

    if ($targetHash -eq $ExpectedOriginalHash) {
        Write-Log 'Result: NOT INSTALLED - original DLL active.'
        Show-Result ("NOT INSTALLED$NL$NL" + "The original DLL is active.$NL$NL" + "Assembly version: $assemblyVersion$NL" + "SHA-256: $targetHash$NL" + "Sound Blaster Command running: $runningText$NL$NL" + "Diagnostic log:$NL$DisplayLogPath") 'Warning'
        exit 1
    }

    if ($targetHash -ne $ExpectedPatchedHash) {
        Write-Log 'Result: UNKNOWN BUILD.'
        Show-Result ("UNKNOWN BUILD$NL$NL" + "The installed DLL matches neither the supported original nor this fix.$NL$NL" + "Assembly version: $assemblyVersion$NL" + "SHA-256: $targetHash$NL$NL" + "Nothing was changed.$NL$NL" + "Diagnostic log:$NL$DisplayLogPath") 'Warning'
        exit 1
    }

    $backupPath = $null
    if (Test-Path -LiteralPath $Backup) {
        $backupPath = $Backup
        Write-Log 'Using current backup filename.'
    }
    elseif (Test-Path -LiteralPath $LegacyBackup) {
        $backupPath = $LegacyBackup
        Write-Log 'Using legacy backup filename.'
    }

    if (-not $backupPath) {
        Write-Log 'Result: PATCH FOUND, BACKUP MISSING.'
        Show-Result ("PATCH FOUND, BACKUP MISSING$NL$NL" + "The patched DLL is installed, but a verified local original backup was not found.$NL$NL" + "Patched SHA-256: $targetHash$NL$NL" + "Diagnostic log:$NL$DisplayLogPath") 'Warning'
        exit 1
    }

    $backupHash = Get-Sha256 $backupPath
    Write-Log ("Backup SHA-256: {0}" -f $backupHash)

    if ($backupHash -ne $ExpectedOriginalHash) {
        Write-Log 'Result: PATCH FOUND, BACKUP INVALID.'
        Show-Result ("PATCH FOUND, BACKUP INVALID$NL$NL" + "The patched DLL is installed, but the local backup is not the expected original file.$NL$NL" + "Backup SHA-256: $backupHash$NL$NL" + "Diagnostic log:$NL$DisplayLogPath") 'Warning'
        exit 1
    }

    Write-Log 'Result: SUCCESSFULLY VERIFIED.'
    Show-Result ("SUCCESSFULLY VERIFIED$NL$NL" + "The tooltip fix is correctly installed.$NL$NL" + "Assembly version: $assemblyVersion$NL" + "Patched SHA-256: $targetHash$NL" + "Original backup SHA-256: $backupHash$NL" + "Sound Blaster Command running: $runningText$NL$NL" + "Diagnostic log:$NL$DisplayLogPath")
    exit 0
}
catch {
    Write-Log ("Verification exception: " + $_.Exception.Message)
    Show-Result ("Verification failed.$NL$NL" + $_.Exception.Message + "$NL$NL" + "Diagnostic log:$NL$DisplayLogPath") 'Error'
    exit 2
}
