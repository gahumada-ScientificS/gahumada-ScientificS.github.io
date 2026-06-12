# Transfer-WhatsApp.ps1
# Copies NEW WhatsApp Images & Videos from Galaxy S20+ to D:\FOTKI\SD 2026
# Skips duplicates already in D:\FOTKI (matched by base name)
param([switch]$DryRun)

$FotkiRoot   = "D:\FOTKI"
$DestImages  = "D:\FOTKI\SD 2026\WhatsApp Images"
$DestVideos  = "D:\FOTKI\SD 2026\WhatsApp Videos"
$FileTimeout = 180

function Write-Step($n,$msg){ Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-OK($msg)     { Write-Host "    $msg"   -ForegroundColor Green  }
function Write-Warn($msg)   { Write-Host "    $msg"   -ForegroundColor Yellow }

# 1. Index existing FOTKI files by BaseName
Write-Step "1/5" "Indexing existing files in D:\FOTKI..."
$existingNames = @{}
Get-ChildItem $FotkiRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notlike "*\SD 2026\WhatsApp*" } |
    ForEach-Object { $existingNames[$_.BaseName] = $true }
Write-OK "Found $($existingNames.Count) existing files"

# 2. Connect to phone and navigate to WhatsApp Media
Write-Step "2/5" "Connecting to WhatsApp Media on phone..."
$shell          = New-Object -ComObject Shell.Application
$computerNS     = $shell.NameSpace(17)
$phoneItem      = $computerNS.Items() | Where-Object { $_.Name -like "*Galaxy*" }
$internalFolder = ($shell.NameSpace($phoneItem.Path).Items() | Where-Object { $_.Name -like "*Internal*" }).GetFolder()
$androidFolder  = ($internalFolder.Items() | Where-Object { $_.Name -eq "Android" }).GetFolder()
$mediaFolder    = ($androidFolder.Items() | Where-Object { $_.Name -eq "media" }).GetFolder()
$waFolder       = ($mediaFolder.Items() | Where-Object { $_.Name -eq "com.whatsapp" }).GetFolder()
$waSubFolder    = ($waFolder.Items() | Where-Object { $_.Name -eq "WhatsApp" }).GetFolder()
$waMediaFolder  = ($waSubFolder.Items() | Where-Object { $_.Name -eq "Media" }).GetFolder()

$waImagesFolder = ($waMediaFolder.Items() | Where-Object { $_.Name -eq "WhatsApp Images" }).GetFolder()
$waVideosFolder = ($waMediaFolder.Items() | Where-Object { $_.Name -eq "WhatsApp Video" }).GetFolder()
Write-OK "Connected to WhatsApp Media"

# 3. Scan for new vs duplicate files
Write-Step "3/5" "Scanning for new vs duplicate files..."
$newImages = [System.Collections.ArrayList]@()
$newVideos = [System.Collections.ArrayList]@()
$dupCount  = 0

foreach ($item in $waImagesFolder.Items()) {
    if ($item.IsFolder) { continue }
    if ($existingNames.ContainsKey($item.Name)) { $dupCount++ }
    else { [void]$newImages.Add($item) }
}
foreach ($item in $waVideosFolder.Items()) {
    if ($item.IsFolder) { continue }
    if ($existingNames.ContainsKey($item.Name)) { $dupCount++ }
    else { [void]$newVideos.Add($item) }
}

$totalNew = $newImages.Count + $newVideos.Count
Write-OK "New WhatsApp Images to copy : $($newImages.Count)"
Write-OK "New WhatsApp Videos to copy : $($newVideos.Count)"
Write-Warn "Duplicates (already in FOTKI): $dupCount"

if ($totalNew -eq 0) {
    Write-Host "`nNothing new to copy." -ForegroundColor Green; exit 0
}
if ($DryRun) {
    Write-Warn "`n-DryRun: no files copied."; exit 0
}

# 4. Copy files
Write-Step "4/5" "Copying $totalNew files..."
$destImagesNS = $shell.NameSpace($DestImages)
$destVideosNS = $shell.NameSpace($DestVideos)

function Copy-MTPItem {
    param($item, $destFolder, $destNS)
    $existing = Get-ChildItem $destFolder -File -ErrorAction SilentlyContinue |
                Where-Object { $_.BaseName -eq $item.Name }
    if ($existing) { return "exists" }
    $destNS.CopyHere($item, 1556)
    $waited = 0
    do {
        Start-Sleep -Milliseconds 500
        $waited += 0.5
        $arrived = Get-ChildItem $destFolder -File -ErrorAction SilentlyContinue |
                   Where-Object { $_.BaseName -eq $item.Name }
    } while (-not $arrived -and $waited -lt $script:FileTimeout)
    if ($arrived) { return "ok" }
    return "timeout"
}

$copied = 0; $failed = 0; $i = 0
foreach ($item in $newImages) {
    $i++
    $r = Copy-MTPItem $item $DestImages $destImagesNS
    if ($r -eq "timeout") { $failed++; Write-Warn "TIMEOUT: $($item.Name)" } else { $copied++ }
    if ($i % 50 -eq 0) { Write-Host "    Images: $i / $($newImages.Count)..." }
}
Write-OK "Images done: $i processed"

$i = 0
foreach ($item in $newVideos) {
    $i++
    $r = Copy-MTPItem $item $DestVideos $destVideosNS
    if ($r -eq "timeout") { $failed++; Write-Warn "TIMEOUT: $($item.Name)" } else { $copied++ }
    if ($i % 25 -eq 0) { Write-Host "    Videos: $i / $($newVideos.Count)..." }
}
Write-OK "Videos done: $i processed"

# 5. Summary
Write-Step "5/5" "Summary"
$finalImages = (Get-ChildItem $DestImages -File -ErrorAction SilentlyContinue | Measure-Object).Count
$finalVideos = (Get-ChildItem $DestVideos -File -ErrorAction SilentlyContinue | Measure-Object).Count
Write-OK "WhatsApp Images copied : $finalImages"
Write-OK "WhatsApp Videos copied : $finalVideos"
if ($failed -gt 0) { Write-Warn "Timed out (not copied): $failed" }
Write-Host "`nDone!" -ForegroundColor Green
