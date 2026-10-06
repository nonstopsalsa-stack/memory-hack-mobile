# tests/test_v150_profile_sync.ps1
$ErrorActionPreference = "Stop"

Write-Host "=== MEMORY HACK Mobile: v1.5.0 Profile Sync & Version Consistency Test ===" -ForegroundColor Cyan

$baseDir = "C:\Users\nonst\recover\obsidian folder\006_AI_Workspace\anki-mobile"
$htmlPath = Join-Path $baseDir "index.html"
$appPath = Join-Path $baseDir "js\app.js"
$syncPath = Join-Path $baseDir "js\sync.js"
$configPath = Join-Path $baseDir "js\config.js"
$studyPath = Join-Path $baseDir "js\study.js"
$swPath = Join-Path $baseDir "service-worker.js"

$passed = 0
$failed = 0

function Assert-Test($condition, $name) {
    if ($condition) {
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

# 1. Profile selector UI in index.html
Assert-Test ($html.Contains('id="setting-device-profile"')) "index.html: contains profile selector dropdown"
Assert-Test ($html.Contains('value="father"')) "index.html: contains father (哲生) option"
Assert-Test ($html.Contains('value="son"')) "index.html: contains son option"
Assert-Test ($html.Contains('value="daughter"')) "index.html: contains daughter option"
Assert-Test ($html.Contains('value="mother"')) "index.html: contains mother option"

# 2. Profile persistence in app.js
Assert-Test ($app.Contains("Storage.saveSetting('deviceProfile'")) "app.js: saves deviceProfile to Storage"
Assert-Test ($app.Contains("Storage.getSetting('deviceProfile'")) "app.js: loads deviceProfile from Storage"

# 3. Profile filtering in sync.js
Assert-Test ($sync.Contains("Storage.getSetting('deviceProfile'")) "sync.js: retrieves deviceProfile for filtering"
Assert-Test ($sync.Contains("allowedProjectIds")) "sync.js: builds allowedProjectIds set"
Assert-Test ($sync.Contains("dist.targetProfiles.includes(deviceProfile)")) "sync.js: checks targetProfiles for user match"
Assert-Test ($sync.Contains("allowedProjectIds.has(pId)")) "sync.js: filters remoteCards by allowedProjectIds"

# 4. Version & Cache-busting consistency (v1.5.0)
Assert-Test ($html.Contains('<span class="brand-ver-badge">v1.5.0</span>')) "index.html: Brand badge is v1.5.0"
Assert-Test ($html.Contains('<span class="modal-subtitle">MEMORY HACK Mobile v1.5.0</span>')) "index.html: Modal subtitle is v1.5.0"
Assert-Test ($html.Contains('css/mobile.css?v=1.5.0')) "index.html: CSS cache buster is ?v=1.5.0"
Assert-Test ($html.Contains('js/sync.js?v=1.5.0')) "index.html: sync.js cache buster is ?v=1.5.0"
Assert-Test ($config.Contains('version: "1.5.0-mobile"')) "config.js: version is 1.5.0-mobile"
Assert-Test ($study.Contains("version: '1.5.0-mobile'")) "study.js: version is 1.5.0-mobile"
Assert-Test ($app.Contains("MEMORY HACK Mobile v1.5.0 Initializing...")) "app.js: init log is v1.5.0"
Assert-Test ($sw.Contains("const CACHE_NAME = 'memory-hack-mobile-v1.5.0';")) "service-worker.js: CACHE_NAME is v1.5.0"
Assert-Test ($sw.Contains("'./css/mobile.css?v=1.5.0'")) "service-worker.js: mobile.css cache asset is ?v=1.5.0"

# 5. Mojibake guard
$mojibakePattern = '[\uFFFD\u309F\u30FF]'
Assert-Test (-not ($html -match $mojibakePattern)) "index.html: No mojibake detected"
Assert-Test (-not ($app -match $mojibakePattern)) "app.js: No mojibake detected"
Assert-Test (-not ($sync -match $mojibakePattern)) "sync.js: No mojibake detected"

Write-Host "`nTest Result: Passed: $passed / Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

if ($failed -gt 0) {
    exit 1
}
