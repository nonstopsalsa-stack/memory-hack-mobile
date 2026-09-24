# tests/test_mobile_v123.ps1
$ErrorActionPreference = "Stop"

Write-Host "=== MEMORY HACK Mobile v1.2.3 Test Suite ===" -ForegroundColor Cyan

$baseDir = "C:\Users\nonst\recover\obsidian folder\006_AI_Workspace\anki-mobile"
$htmlFile = Join-Path $baseDir "index.html"
$appJsFile = Join-Path $baseDir "js\app.js"
$configJsFile = Join-Path $baseDir "js\config.js"
$swFile = Join-Path $baseDir "service-worker.js"

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

# 1. index.html version and query check
$htmlContent = [System.IO.File]::ReadAllText($htmlFile, [System.Text.Encoding]::UTF8)
Assert-Test ($htmlContent.Contains('<span class="brand-ver-badge">v1.2.3</span>')) "index.html: Brand badge is v1.2.3"
Assert-Test ($htmlContent.Contains('<span class="modal-subtitle">MEMORY HACK Mobile v1.2.3-mobile</span>')) "index.html: Modal subtitle is v1.2.3-mobile"
Assert-Test ($htmlContent.Contains('<link rel="stylesheet" href="css/mobile.css?v=1.2.3">')) "index.html: mobile.css query is ?v=1.2.3"

$scripts = @("config.js", "storage.js", "srs.js", "hierarchy.js", "audio.js", "sync.js", "study.js", "app.js")
foreach ($s in $scripts) {
    $expectedTag = '<script src="js/' + $s + '?v=1.2.3"></script>'
    Assert-Test ($htmlContent.Contains($expectedTag)) "index.html: js/$s query is ?v=1.2.3"
}

# 2. config.js version check
$configContent = [System.IO.File]::ReadAllText($configJsFile, [System.Text.Encoding]::UTF8)
Assert-Test ($configContent -match 'version:\s*"1\.2\.3-mobile"') "config.js: version is 1.2.3-mobile"

# 3. service-worker.js check
$swContent = [System.IO.File]::ReadAllText($swFile, [System.Text.Encoding]::UTF8)
Assert-Test ($swContent -match "CACHE_NAME\s*=\s*'memory-hack-mobile-v1\.2\.3'") "service-worker.js: CACHE_NAME is memory-hack-mobile-v1.2.3"
foreach ($s in $scripts) {
    $expectedAsset = "./js/" + $s + "?v=1.2.3"
    Assert-Test ($swContent.Contains($expectedAsset)) "service-worker.js: $expectedAsset is in cache"
}
Assert-Test ($swContent.Contains("./css/mobile.css?v=1.2.3")) "service-worker.js: ./css/mobile.css?v=1.2.3 is in cache"

# 4. app.js applyTheme method check
$appJsContent = [System.IO.File]::ReadAllText($appJsFile, [System.Text.Encoding]::UTF8)
Assert-Test ($appJsContent -match 'applyTheme\s*\(\s*theme\s*,\s*save\s*=\s*true\s*\)') "app.js: applyTheme(theme, save = true) is defined"
Assert-Test ($appJsContent.Contains("document.documentElement.setAttribute('data-theme', theme)")) "app.js: applyTheme sets data-theme attribute"
Assert-Test ($appJsContent.Contains("localStorage.setItem('anki_mobile_theme', theme)")) "app.js: applyTheme stores theme in localStorage"
Assert-Test ($appJsContent.Contains('document.querySelector(''meta[name="theme-color"]'')')) "app.js: applyTheme updates meta theme-color"

# 5. app.js init() try-catch protection check
Assert-Test ($appJsContent -match 'try\s*\{\s*const savedTheme = localStorage\.getItem\(''anki_mobile_theme''\)') "app.js: Theme init is protected by try-catch"
Assert-Test ($appJsContent -match 'try\s*\{\s*if\s*\(typeof AudioManager !== ''undefined''\)') "app.js: Manager init is protected by try-catch"

# 6. Syntax / Brackets Balance Check
$jsFiles = @($appJsFile, $configJsFile, $swFile)
foreach ($jf in $jsFiles) {
    $content = [System.IO.File]::ReadAllText($jf, [System.Text.Encoding]::UTF8)
    $fileName = Split-Path -Leaf $jf
    
    $openBraces = ($content.ToCharArray() | Where-Object { $_ -eq '{' }).Count
    $closeBraces = ($content.ToCharArray() | Where-Object { $_ -eq '}' }).Count
    Assert-Test ($openBraces -eq $closeBraces) "Syntax: $fileName curly braces balance ($openBraces vs $closeBraces)"
    
    $openParens = ($content.ToCharArray() | Where-Object { $_ -eq '(' }).Count
    $closeParens = ($content.ToCharArray() | Where-Object { $_ -eq ')' }).Count
    Assert-Test ($openParens -eq $closeParens) "Syntax: $fileName parentheses balance ($openParens vs $closeParens)"
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "PASS: $passed" -ForegroundColor Green
Write-Host "FAIL: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

if ($failed -eq 0) {
    Write-Host "`nAll tests PASSED 100% successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed." -ForegroundColor Red
    exit 1
}
