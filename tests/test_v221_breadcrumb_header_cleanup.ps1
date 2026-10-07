# test_v221_breadcrumb_header_cleanup.ps1
# MEMORY HACK Mobile v2.2.1 Header Cleanup and Breadcrumb Deck Selector Test

$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-Check {
    param(
        [string]$name,
        [bool]$condition
    )
    if ($condition) {
        Write-Host " [PASS] $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host " [FAIL] $name" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " MEMORY HACK Mobile v2.2.1: Header Cleanup & Breadcrumb Integration Test  " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$storagePath = Resolve-Path "$PSScriptRoot/../js/storage.js"
$studyPath = Resolve-Path "$PSScriptRoot/../js/study.js"
$appPath = Resolve-Path "$PSScriptRoot/../js/app.js"
$hierarchyPath = Resolve-Path "$PSScriptRoot/../js/hierarchy.js"
$configPath = Resolve-Path "$PSScriptRoot/../js/config.js"
$swPath = Resolve-Path "$PSScriptRoot/../service-worker.js"
$htmlPath = Resolve-Path "$PSScriptRoot/../index.html"
$cssPath = Resolve-Path "$PSScriptRoot/../css/mobile.css"

$storage = [System.IO.File]::ReadAllText($storagePath, [System.Text.Encoding]::UTF8)
$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$app = [System.IO.File]::ReadAllText($appPath, [System.Text.Encoding]::UTF8)
$hierarchy = [System.IO.File]::ReadAllText($hierarchyPath, [System.Text.Encoding]::UTF8)
$config = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# Phase 1: Version and PWA Cache Integrity (v2.2.1)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Version & PWA Cache Integrity (v2.2.1)] ---" -ForegroundColor Yellow
Assert-Check "1.1 config.js version is v2.2.1" ($config.Contains('version: "v2.2.1"'))
Assert-Check "1.2 study.js version is v2.2.1" ($study.Contains("version: 'v2.2.1'"))
Assert-Check "1.3 app.js logs v2.2.1 initialization and toast" ($app.Contains("v2.2.1 Initializing") -and $app.Contains("Mobile v2.2.1"))
Assert-Check "1.4 service-worker.js CACHE_NAME is memory-hack-mobile-v2.2.1" ($sw.Contains("memory-hack-mobile-v2.2.1"))
Assert-Check "1.5 service-worker.js ASSETS_TO_CACHE has ?v=2.2.1 queries" ($sw.Contains("?v=2.2.1"))
Assert-Check "1.6 index.html has ?v=2.2.1 query strings for css and scripts" ($html.Contains("css/mobile.css?v=2.2.1") -and $html.Contains("js/study.js?v=2.2.1") -and $html.Contains("js/app.js?v=2.2.1"))
Assert-Check "1.7 index.html has brand-ver-badge v2.2.1 and modal-settings v2.2.1" ($html.Contains('<span class="brand-ver-badge">v2.2.1</span>') -and $html.Contains('MEMORY HACK Mobile v2.2.1'))

# -------------------------------------------------------------
# Phase 2: Top-Bar Cleanup & Sync Button Anti-Shrink
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: Top-Bar Cleanup & Sync Button Anti-Shrink] ---" -ForegroundColor Yellow
$p2_1 = -not ($html.Contains('id="btn-project-trigger"'))
Assert-Check "2.1 index.html top-bar removed duplicate #btn-project-trigger" ($p2_1)

$p2_2 = $css.Contains("flex-shrink: 0") -and $css.Contains("white-space: nowrap")
Assert-Check "2.2 mobile.css sync-btn prevents shrinking and line breaks" ($p2_2)

$p2_3 = $html.Contains('id="btn-sync"') -and $html.Contains('id="sync-status-badge"') -and $html.Contains('id="sync-status-label"')
Assert-Check "2.3 index.html retains sync button elements" ($p2_3)

# -------------------------------------------------------------
# Phase 3: Breadcrumb Integration (Project + Deck)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: Breadcrumb Integration (Project + Deck)] ---" -ForegroundColor Yellow
$p3_1 = $study.Contains("deck-trigger-proj") -and $study.Contains("deck-trigger-sep") -and $study.Contains("deck-trigger-deck")
Assert-Check "3.1 study.js updateDeckTriggerButton renders breadcrumb HTML" ($p3_1)

$p3_2 = $css.Contains(".deck-trigger-proj") -and $css.Contains(".deck-trigger-sep") -and $css.Contains(".deck-trigger-deck")
Assert-Check "3.2 mobile.css defines breadcrumb classes" ($p3_2)

$p3_3 = $css.Contains('[data-theme="light"] .deck-trigger-proj') -and $css.Contains('[data-theme="bloxfruits"] .deck-trigger-proj') -and $css.Contains('[data-theme="muichiro"] .deck-trigger-proj')
Assert-Check "3.3 mobile.css defines theme overrides for deck-trigger-proj (light, bloxfruits, muichiro)" ($p3_3)

$p3_4 = $app.Contains("StudyManager.updateDeckTriggerButton")
Assert-Check "3.4 app.js updateProjectPill notifies StudyManager to update deck trigger" ($p3_4)

# -------------------------------------------------------------
# Phase 4: Headless Browser DOM Rendering Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 4: Headless Browser DOM Rendering Verification] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if ($browserExe) {
    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_v221_dump_$([System.Guid]::NewGuid().ToString('N')).html")
    try {
        $fileUri = "file:///" + (Resolve-Path "$htmlPath").Path.Replace("\", "/")
        $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait
        
        if (Test-Path $tempDump) {
            $domText = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
            Assert-Check "4.1 Headless browser rendered DOM successfully" ($domText.Length -gt 1000)
            $p4_2 = -not ($domText.Contains('id="btn-project-trigger"'))
            Assert-Check "4.2 Headless DOM confirms no duplicate btn-project-trigger in top bar" ($p4_2)
            $p4_3 = $domText.Contains('<span class="brand-ver-badge">v2.2.1</span>')
            Assert-Check "4.3 Headless DOM contains updated v2.2.1 brand badge" ($p4_3)
            $p4_4 = $domText.Contains('id="btn-sync"') -and $domText.Contains('id="btn-deck-trigger"')
            Assert-Check "4.4 Headless DOM contains sync and deck-trigger buttons" ($p4_4)
        } else {
            Assert-Check "4.1 Headless browser DOM dump generated" $false
        }
    } finally {
        if (Test-Path $tempDump) { Remove-Item -Force $tempDump }
    }
} else {
    Write-Host " [SKIP] Headless browser not found, skipping Phase 4" -ForegroundColor Gray
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESULT: $passed Passed / $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
