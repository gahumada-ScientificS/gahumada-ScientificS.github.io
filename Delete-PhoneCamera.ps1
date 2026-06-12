# Delete-PhoneCamera.ps1
# Deletes ALL files from Galaxy S20+ DCIM\Camera folder
# Favorites and all other folders are NOT touched

$ErrorActionPreference = "Continue"

function Write-Step($n,$msg){ Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Write-OK($msg)     { Write-Host "    $msg"   -ForegroundColor Green  }
function Write-Warn($msg)   { Write-Host "    $msg"   -ForegroundColor Yellow }

Write-Step "1/3" "Connecting to Galaxy S20+..."
$shell = New-Object -ComObject Shell.Application
$computerNS = $shell.NameSpace(17)
$phoneItem = $computerNS.Items() | Where-Object { $_.Name -like "*Galaxy*" }
if (-not $phoneItem) {
    Write-Host "Galaxy phone not found!" -ForegroundColor Red; exit 1
}
$internalFolder = ($shell.NameSpace($phoneItem.Path).Items() |
    Where-Object { $_.Name -like "*Internal*" }).GetFolder()
$dcimFolder = ($internalFolder.Items() |
    Where-Object { $_.Name -eq "DCIM" }).GetFolder()
$cameraFolder = ($dcimFolder.Items() |
    Where-Object { $_.Name -eq "Camera" }).GetFolder()
Write-OK "Connected to DCIM\Camera"

Write-Step "2/3" "Counting files to delete..."
$allFiles = $cameraFolder.Items() | Where-Object { -not $_.IsFolder }
$total = ($allFiles | Measure-Object).Count
Write-OK "Files to delete: $total"

Write-Step "3/3" "Deleting all $total files from phone Camera folder..."
$deleted = 0
foreach ($item in $allFiles) {
    $item.InvokeVerb("delete")
    $deleted++
    if ($deleted % 100 -eq 0) {
        Write-Host "    Deleted $deleted / $total..."
    }
}

Write-OK "Deleted $deleted files from DCIM\Camera"
Write-Warn "Favorites, Baby Pics, Ważne and all other folders were NOT touched."
Write-Host "`nDone!" -ForegroundColor Green
