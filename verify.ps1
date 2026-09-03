$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework

$Title = 'Sound Blaster Command - Tooltip Fix Verification'
$Target = 'C:\Program Files (x86)\Creative\Sound Blaster Command\Package\Hardcodet.Wpf.TaskbarNotification.dll'
$Backup = $Target + '.sticky-tooltip-fix.original.bak'
$LegacyBackup = $Target + '.original-1.0.5.0.bak'

$ExpectedOriginalHash = '4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E'
$ExpectedPatchedHash  = '72CDC5A4A5841158915D6B8ED414758E39B6C5A9871274BB90B2F23EC7FA4117'

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Show-Result([string]$Text, [string]$Icon = 'Information') {
    [System.Windows.MessageBox]::Show($Text, $Title, 'OK', $Icon) | Out-Null
}

try {
    if (-not (Test-Path -LiteralPath $Target)) {
        Show-Result "NOT VERIFIED`n`nThe expected Sound Blaster Command DLL was not found.`n`n$Target" 'Warning'
        exit 1
    }

    $targetHash = Get-Sha256 $Target
    $assemblyVersion = 'unknown'

    try {
        $assemblyVersion = ([Reflection.AssemblyName]::GetAssemblyName($Target)).Version.ToString()
    } catch {}

    $running = @(Get-Process -Name 'Creative.SBCommand' -ErrorAction SilentlyContinue).Count -gt 0
    $runningText = if ($running) { 'Yes' } else { 'No' }

    if ($targetHash -eq $ExpectedOriginalHash) {
        Show-Result ("NOT INSTALLED`n`nThe original DLL is active.`n`nAssembly version: $assemblyVersion`nSHA-256: $targetHash`nSound Blaster Command running: $runningText") 'Warning'
        exit 1
    }

    if ($targetHash -ne $ExpectedPatchedHash) {
        Show-Result ("UNKNOWN BUILD`n`nThe installed DLL matches neither the supported original nor this fix.`n`nAssembly version: $assemblyVersion`nSHA-256: $targetHash`n`nNothing was changed.") 'Warning'
        exit 1
    }

    $backupPath = $null
    if (Test-Path -LiteralPath $Backup) {
        $backupPath = $Backup
    } elseif (Test-Path -LiteralPath $LegacyBackup) {
        $backupPath = $LegacyBackup
    }

    if (-not $backupPath) {
        Show-Result ("PATCH FOUND, BACKUP MISSING`n`nThe patched DLL is installed, but a verified local original backup was not found.`n`nPatched SHA-256: $targetHash") 'Warning'
        exit 1
    }

    $backupHash = Get-Sha256 $backupPath

    if ($backupHash -ne $ExpectedOriginalHash) {
        Show-Result ("PATCH FOUND, BACKUP INVALID`n`nThe patched DLL is installed, but the local backup is not the expected original file.`n`nBackup SHA-256: $backupHash") 'Warning'
        exit 1
    }

    Show-Result ("SUCCESSFULLY VERIFIED`n`nThe tooltip fix is correctly installed.`n`nAssembly version: $assemblyVersion`nPatched SHA-256: $targetHash`nOriginal backup SHA-256: $backupHash`nSound Blaster Command running: $runningText")
    exit 0
}
catch {
    Show-Result ("Verification failed.`n`n" + $_.Exception.Message) 'Error'
    exit 2
}
