$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$testHtml = "file:///" + (Join-Path $PSScriptRoot "test_auto_player_mode_mobile.html").Replace('\', '/')
$tempProfile = Join-Path $env:TEMP "browser_test_profile_$(Get-Random)"
New-Item -ItemType Directory -Path $tempProfile -Force | Out-Null
$outHtml = Join-Path $tempProfile "out.html"
$errLog = Join-Path $tempProfile "err.log"

$browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $browserExe)) {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "1. Running Headless Auto Player Mobile Verification" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

$proc = Start-Process -FilePath $browserExe -ArgumentList @(
    "--headless=new",
    "--disable-gpu",
    "--no-sandbox",
    "--virtual-time-budget=5000",
    "--user-data-dir=`"$tempProfile`"",
    "--dump-dom",
    "`"$testHtml`""
) -PassThru -NoNewWindow -RedirectStandardOutput $outHtml -RedirectStandardError $errLog

$timeout = 10
$sw = [System.Diagnostics.Stopwatch]::StartNew()
while (-not $proc.HasExited -and $sw.Elapsed.TotalSeconds -lt $timeout) {
    Start-Sleep -Milliseconds 200
}
if (-not $proc.HasExited) {
    $proc.Kill()
}
try { $proc.WaitForExit(1000) } catch {}
Start-Sleep -Milliseconds 300

$passed = 0
$failed = 0
if (Test-Path $outHtml) {
    $domText = ""
    for ($retry = 0; $retry -lt 5; $retry++) {
        try {
            $domText = [System.IO.File]::ReadAllText($outHtml, [System.Text.Encoding]::UTF8)
            break
        } catch {
            Start-Sleep -Milliseconds 200
        }
    }
    $logMatches = [System.Text.RegularExpressions.Regex]::Matches($domText, '<div class="log-item (pass|fail)">([^<]+)</div>')
    foreach ($m in $logMatches) {
        $status = $m.Groups[1].Value
        $line = $m.Groups[2].Value
        if ($status -eq "pass") {
            $passed++
            Write-Host "  $line" -ForegroundColor Green
        } else {
            $failed++
            Write-Host "  $line" -ForegroundColor Red
        }
    }
}
Remove-Item $tempProfile -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Mobile Test Results: $passed Passed, $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================" -ForegroundColor Cyan

if ($failed -gt 0 -or $passed -eq 0) {
    exit 1
}
exit 0
