$ErrorActionPreference = "Stop"

Write-Host "=== MEMORY HACK Mobile: v1.5.2 Sync Timeout & Cache Prevention Test ==="

$baseDir = "C:\Users\nonst\recover\obsidian folder\006_AI_Workspace\anki-mobile"
$htmlPath = Join-Path $baseDir "index.html"
$appPath = Join-Path $baseDir "js\app.js"
$syncPath = Join-Path $baseDir "js\sync.js"
$configPath = Join-Path $baseDir "js\config.js"
$studyPath = Join-Path $baseDir "js\study.js"
$swPath = Join-Path $baseDir "service-worker.js"

$passed = 0
$failed = 0

function Check-Assert([bool]$cond, [string]$name) {
    if ($cond) {
        Write-Host "  [PASS] $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $name" -ForegroundColor Red
        $script:failed++
    }
}

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$app = [System.IO.File]::ReadAllText($appPath, [System.Text.Encoding]::UTF8)
$sync = [System.IO.File]::ReadAllText($syncPath, [System.Text.Encoding]::UTF8)
$config = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)

# 1. Version consistency (v1.5.2)
Check-Assert ($html.IndexOf('<span class="brand-ver-badge">v1.5.2</span>') -ge 0) "index.html: Brand badge is v1.5.2"
Check-Assert ($html.IndexOf('<span class="modal-subtitle">MEMORY HACK Mobile v1.5.2</span>') -ge 0) "index.html: Modal subtitle is v1.5.2"
Check-Assert ($html.IndexOf('css/mobile.css?v=1.5.2') -ge 0) "index.html: CSS buster is ?v=1.5.2"
Check-Assert ($html.IndexOf('js/sync.js?v=1.5.2') -ge 0) "index.html: sync.js buster is ?v=1.5.2"
Check-Assert ($config.IndexOf('version: "1.5.2-mobile"') -ge 0) "config.js: version is 1.5.2-mobile"
Check-Assert ($study.IndexOf("version: '1.5.2-mobile'") -ge 0) "study.js: version is 1.5.2-mobile"
Check-Assert ($app.IndexOf("MEMORY HACK Mobile v1.5.2 Initializing...") -ge 0) "app.js: init log is v1.5.2"
Check-Assert ($sw.IndexOf("const CACHE_NAME = 'memory-hack-mobile-v1.5.2';") -ge 0) "service-worker.js: CACHE_NAME is v1.5.2"
Check-Assert ($sw.IndexOf("'./css/mobile.css?v=1.5.2'") -ge 0) "service-worker.js: asset cache is ?v=1.5.2"

# 2. Cache Prevention in index.html
Check-Assert ($html.IndexOf('http-equiv="Cache-Control"') -ge 0) "index.html: contains Cache-Control meta"
Check-Assert ($html.IndexOf('http-equiv="Pragma"') -ge 0) "index.html: contains Pragma meta"
Check-Assert ($html.IndexOf('http-equiv="Expires"') -ge 0) "index.html: contains Expires meta"

# 3. JSONP Timeout Expansion (35s)
Check-Assert ($sync.IndexOf('35000') -ge 0) "sync.js: timer is 35000ms (35s)"
Check-Assert ($sync -match '35\u79d2') "sync.js: contains 35s timeout message"

# 4. SW Registration with updateViaCache: 'none' and reg.update()
Check-Assert ($app.IndexOf("updateViaCache: 'none'") -ge 0) "app.js: contains updateViaCache: 'none'"
Check-Assert ($app.IndexOf("reg.update()") -ge 0) "app.js: calls reg.update() on startup"

Write-Host ""
Write-Host "Results: $passed Passed, $failed Failed"
if ($failed -gt 0) { exit 1 }
