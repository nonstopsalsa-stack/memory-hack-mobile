$ErrorActionPreference = "Stop"

Write-Host "=== MEMORY HACK Mobile: v1.5.1 Profile Sync Test ==="

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
        Write-Host "  [PASS] $name"
        $script:passed++
    } else {
        Write-Host "  [FAIL] $name"
        $script:failed++
    }
}

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$app = [System.IO.File]::ReadAllText($appPath, [System.Text.Encoding]::UTF8)
$sync = [System.IO.File]::ReadAllText($syncPath, [System.Text.Encoding]::UTF8)
$config = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)

# 1. 5 Profiles in index.html
Check-Assert ($html.IndexOf('id="setting-device-profile"') -ge 0) "index.html: contains profile selector dropdown"
Check-Assert ($html.IndexOf('value="father"') -ge 0) "index.html: contains father option"
Check-Assert ($html.IndexOf('value="son"') -ge 0) "index.html: contains son option"
Check-Assert ($html.IndexOf('value="daughter"') -ge 0) "index.html: contains daughter option"
Check-Assert ($html.IndexOf('value="mother"') -ge 0) "index.html: contains mother option"
Check-Assert ($html.IndexOf('value="guest"') -ge 0) "index.html: contains guest option"

# 2. Profile persistence in app.js
Check-Assert ($app.IndexOf("Storage.saveSetting('deviceProfile'") -ge 0) "app.js: saves deviceProfile"
Check-Assert ($app.IndexOf("Storage.getSetting('deviceProfile'") -ge 0) "app.js: loads deviceProfile"

# 3. Profile filtering in sync.js
Check-Assert ($sync.IndexOf("Storage.getSetting('deviceProfile'") -ge 0) "sync.js: retrieves deviceProfile"
Check-Assert ($sync.IndexOf("allowedProjectIds") -ge 0) "sync.js: builds allowedProjectIds"
Check-Assert ($sync.IndexOf("dist.targetProfiles.includes(deviceProfile)") -ge 0) "sync.js: checks targetProfiles"
Check-Assert ($sync.IndexOf("allowedProjectIds.has(pId)") -ge 0) "sync.js: filters remoteCards"

# 4. Version & Cache-busting consistency (v1.5.1)
Check-Assert ($html.IndexOf('<span class="brand-ver-badge">v1.5.1</span>') -ge 0) "index.html: Brand badge is v1.5.1"
Check-Assert ($html.IndexOf('<span class="modal-subtitle">MEMORY HACK Mobile v1.5.1</span>') -ge 0) "index.html: Modal subtitle is v1.5.1"
Check-Assert ($html.IndexOf('css/mobile.css?v=1.5.1') -ge 0) "index.html: CSS buster is ?v=1.5.1"
Check-Assert ($html.IndexOf('js/sync.js?v=1.5.1') -ge 0) "index.html: sync.js buster is ?v=1.5.1"
Check-Assert ($config.IndexOf('version: "1.5.1-mobile"') -ge 0) "config.js: version is 1.5.1-mobile"
Check-Assert ($study.IndexOf("version: '1.5.1-mobile'") -ge 0) "study.js: version is 1.5.1-mobile"
Check-Assert ($app.IndexOf("MEMORY HACK Mobile v1.5.1 Initializing...") -ge 0) "app.js: init log is v1.5.1"
Check-Assert ($sw.IndexOf("const CACHE_NAME = 'memory-hack-mobile-v1.5.1';") -ge 0) "service-worker.js: CACHE_NAME is v1.5.1"
Check-Assert ($sw.IndexOf("'./css/mobile.css?v=1.5.1'") -ge 0) "service-worker.js: asset cache is ?v=1.5.1"

# 5. Mojibake guard
Check-Assert (-not ($html -match '[\uFFFD]')) "index.html: No mojibake"
Check-Assert (-not ($app -match '[\uFFFD]')) "app.js: No mojibake"
Check-Assert (-not ($sync -match '[\uFFFD]')) "sync.js: No mojibake"

Write-Host "Total Passed: $passed, Failed: $failed"
if ($failed -gt 0) { exit 1 }