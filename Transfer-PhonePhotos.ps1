# Transfer-PhonePhotos.ps1
# Copies NEW photos/videos from Galaxy S20+ Camera to D:\FOTKI\SD 2026
# Skips files already present in D:\FOTKI (matched by base name, no extension)
param(
    [switch]$DryRun,
    [switch]$DeleteAfter
)

$ErrorActionPreference = "Stop"

$FotkiRoot   = "D:\FOTKI"
$DestPhotos  = "D:\FOTKI\SD 2026\Photos"
$DestVideos  = "D:\FOTKI\SD 2026\Videos"
$FileTimeout = 120   # seconds per file before warning

function Write-Step($n,$msg){ Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-OK($msg)     { Write-Host "    $msg"   -ForegroundColor Green  }
function Write-Warn($msg)   { Write-Host "    $msg"   -ForegroundColor Yellow }
function Write-Err($msg)    { Write-Host "    $msg"   -ForegroundColor Red    }

# ----------------------------------------------------------------
# 1. Index existing FOTKI files by BaseName (no extension)
#    Samsung camera produces unique timestamp names; matching by
#    base name handles extension differences (jpg vs HEIC, etc.)
# ----------------------------------------------------------------
Write-Step "1/5" "Indexing existing files in D:\FOTKI (excluding SD 2026 staging)..."
$existingNames = @{}
Get-ChildItem $FotkiRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notlike "*\SD 2026\*" } |
    ForEach-Object { $existingNames[$_.BaseName] = $true }
Write-OK "Found $($existingNames.Count) existing files"

# ----------------------------------------------------------------
# 2. Connect to phone
# ----------------------------------------------------------------
Write-Step "2/5" "Connecting to Galaxy S20+..."
$shell         = New-Object -ComObject Shell.Application
$computerNS    = $shell.NameSpace(17)
$phoneItem     = $computerNS.Items() | Where-Object { $_.Name -like "*Galaxy*" }
if (-not $phoneItem) {
    Write-Err "Galaxy phone not found! Make sure USB is connected and MTP mode is active."
    exit 1
}
$internalFolder = ($shell.NameSpace($phoneItem.Path).Items() |
    Where-Object { $_.Name -like "*Internal*" }).GetFolder()
$dcimFolder     = ($internalFolder.Items() |
    Where-Object { $_.Name -eq "DCIM" }).GetFolder()
$cameraFolder   = ($dcimFolder.Items() |
    Where-Object { $_.Name -eq "Camera" }).GetFolder()
Write-OK "Connected: Galaxy S20+ > Internal storage > DCIM > Camera"

# ----------------------------------------------------------------
# 3. Scan and classify files
#    Shell COM strips extensions from MTP display names.
#    Column 1 of GetDetailsOf returns type like "JPG File" / "MP4 File"
# ----------------------------------------------------------------
Write-Step "3/5" "Scanning Camera folder for new vs duplicate files..."

$toTransferPhotos = [System.Collections.ArrayList]@()
$toTransferVideos = [System.Collections.ArrayList]@()
$dupCount         = 0

foreach ($item in $cameraFolder.Items()) {
    if ($item.IsFolder) { continue }
    $baseName = $item.Name   # Shell COM returns base name without extension
    $fileType = $cameraFolder.GetDetailsOf($item, 1)   # e.g. "JPG File", "MP4 File"

    if ($existingNames.ContainsKey($baseName)) {
        $dupCount++
    } else {
        if ($fileType -match "MP4|MOV|AVI|MKV|3GP|M4V|Video") {
            [void]$toTransferVideos.Add($item)
        } else {
            [void]$toTransferPhotos.Add($item)
        }
    }
}

$totalNew = $toTransferPhotos.Count + $toTransferVideos.Count
$totalOnPhone = $totalNew + $dupCount
Write-OK "Total files in Camera        : $totalOnPhone"
Write-Warn "Already in FOTKI (will skip) : $dupCount"
Write-OK "New photos to copy           : $($toTransferPhotos.Count)"
Write-OK "New videos to copy           : $($toTransferVideos.Count)"

if ($totalNew -eq 0) {
    Write-Host "`nNothing new to copy - all files are already in D:\FOTKI." -ForegroundColor Green
    exit 0
}

if ($DryRun) {
    Write-Warn "`n-DryRun flag: no files were copied."
    exit 0
}

# ----------------------------------------------------------------
# 4. Copy files, waiting for each to appear at destination
# ----------------------------------------------------------------
Write-Step "4/5" "Copying $totalNew files from phone to D:\FOTKI\SD 2026..."

$destPhotosNS = $shell.NameSpace($DestPhotos)
$destVideosNS = $shell.NameSpace($DestVideos)

function Copy-MTPItem {
    param($item, $destFolder, $destNS)
    $baseName = $item.Name

    # Check if already copied (resume support)
    $existing = Get-ChildItem $destFolder -File -ErrorAction SilentlyContinue |
                Where-Object { $_.BaseName -eq $baseName }
    if ($existing) { return "exists" }

    $destNS.CopyHere($item, 1556)   # 4+16+512+1024 = suppress all dialogs

    $waited = 0
    do {
        Start-Sleep -Milliseconds 500
        $waited += 0.5
        $arrived = Get-ChildItem $destFolder -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.BaseName -eq $baseName }
    } while (-not $arrived -and $waited -lt $script:FileTimeout)

    if ($arrived) { return "ok" }
    return "timeout"
}

$copied = 0; $failed = 0; $i = 0

# Photos
foreach ($item in $toTransferPhotos) {
    $i++
    $r = Copy-MTPItem $item $DestPhotos $destPhotosNS
    if ($r -eq "timeout") { $failed++; Write-Warn "TIMEOUT: $($item.Name)" }
    else                   { $copied++ }
    if ($i % 25 -eq 0)    { Write-Host "    Photos: $i / $($toTransferPhotos.Count)..." }
}
Write-OK "Photos done: $i processed"

# Videos
$i = 0
foreach ($item in $toTransferVideos) {
    $i++
    $r = Copy-MTPItem $item $DestVideos $destVideosNS
    if ($r -eq "timeout") { $failed++; Write-Warn "TIMEOUT: $($item.Name)" }
    else                   { $copied++ }
    if ($i % 5 -eq 0)     { Write-Host "    Videos: $i / $($toTransferVideos.Count)..." }
}
Write-OK "Videos done: $i processed"

# ----------------------------------------------------------------
# 5. Summary
# ----------------------------------------------------------------
Write-Step "5/5" "Summary"
$finalPhotos = (Get-ChildItem $DestPhotos -File -ErrorAction SilentlyContinue | Measure-Object).Count
$finalVideos = (Get-ChildItem $DestVideos -File -ErrorAction SilentlyContinue | Measure-Object).Count
Write-OK "Photos in SD 2026\Photos : $finalPhotos"
Write-OK "Videos in SD 2026\Videos : $finalVideos"
if ($failed -gt 0) { Write-Warn "Files that timed out (not copied): $failed" }

# ----------------------------------------------------------------
# Optional: delete copied files from phone
# ----------------------------------------------------------------
if ($DeleteAfter -and $failed -eq 0) {
    Write-Host "`n[DELETE] Removing transferred files from phone..." -ForegroundColor Magenta
    $deleted = 0
    $allTransferred = @($toTransferPhotos) + @($toTransferVideos)
    foreach ($item in $allTransferred) {
        $baseName  = $item.Name
        $destPhoto = Get-ChildItem $DestPhotos -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.BaseName -eq $baseName }
        $destVideo = Get-ChildItem $DestVideos -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.BaseName -eq $baseName }
        if ($destPhoto -or $destVideo) {
            $item.InvokeVerb("delete")
            $deleted++
            if ($deleted % 50 -eq 0) { Write-Host "    Deleted $deleted files from phone..." }
        }
    }
    Write-OK "Deleted $deleted files from phone"
    Write-Warn "Remaining on phone (duplicates already in FOTKI): $dupCount"
} elseif ($DeleteAfter -and $failed -gt 0) {
    Write-Warn "Skipping phone deletion - $failed files failed to copy. Fix issues and re-run with -DeleteAfter."
} else {
    Write-Host ""
    Write-Host "To delete the copied files from phone, re-run with:" -ForegroundColor Yellow
    Write-Host "   .\Transfer-PhonePhotos.ps1 -DeleteAfter" -ForegroundColor White
}

Write-Host "`nDone!" -ForegroundColor Green
