# test_v170_universal_flashcard.ps1
# MEMORY HACK Mobile v1.7.0-universal Flashcard Renewal Verification Test

$passed = 0
$failed = 0

function Assert-Check($name, $condition) {
    if ($condition) {
        Write-Host " [PASS] $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host " [FAIL] $name" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " MEMORY HACK Mobile - v1.7.0-universal Verification Test" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$studyPath = Resolve-Path "$PSScriptRoot/../js/study.js"
$appPath = Resolve-Path "$PSScriptRoot/../js/app.js"
$swPath = Resolve-Path "$PSScriptRoot/../service-worker.js"
$htmlPath = Resolve-Path "$PSScriptRoot/../index.html"
$cssPath = Resolve-Path "$PSScriptRoot/../css/mobile.css"

$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$app = [System.IO.File]::ReadAllText($appPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)

# 1. バージョン整合性
Assert-Check "1.1 study.js version is 1.7.0-universal" ($study.Contains("version: '1.7.0-universal'"))
Assert-Check "1.2 service-worker.js CACHE_NAME is memory-hack-mobile-v1.7.0-universal" ($sw.Contains("memory-hack-mobile-v1.7.0-universal"))
Assert-Check "1.3 service-worker.js ASSETS_TO_CACHE has v1.7.0-universal queries" ($sw.Contains("?v=1.7.0-universal"))
Assert-Check "1.4 index.html has v1.7.0-universal query strings" ($html.Contains("?v=1.7.0-universal"))

# 2. 汎用2本柱 & 漢字6本柱の共存
Assert-Check "2.1 study.js defines UNIVERSAL_PATTERNS" ($study.Contains("UNIVERSAL_PATTERNS:") -and $study.Contains("front_to_back") -and $study.Contains("back_to_front"))
Assert-Check "2.2 study.js defines KANJI_PATTERNS" ($study.Contains("KANJI_PATTERNS:") -and $study.Contains("char_to_read") -and $study.Contains("sentence_fill"))
Assert-Check "2.3 study.js has getFontScaleClass for dynamic typography" ($study.Contains("getFontScaleClass(text)"))
Assert-Check "2.4 study.js has renderImageHtml with lightbox zoom" ($study.Contains("renderImageHtml(") -and $study.Contains("StudyManager.openLightbox"))
Assert-Check "2.5 study.js has openLightbox and closeLightbox" ($study.Contains("openLightbox(src)") -and $study.Contains("closeLightbox()"))

# 3. HTML & CSS 構造
Assert-Check "3.1 index.html contains image-lightbox-modal" ($html.Contains('id="image-lightbox-modal"'))
Assert-Check "3.2 PC index.html hides study-item-type select" ((Get-Content "$PSScriptRoot/../../anki-pc/index.html" -Raw).Contains('class="custom-dropdown-container hidden" id="study-item-type-container"'))
Assert-Check "3.3 mobile.css defines dynamic font scales" ($css.Contains(".text-hero") -and $css.Contains(".text-large") -and $css.Contains(".text-medium") -and $css.Contains(".text-content"))
Assert-Check "3.4 mobile.css defines lightbox styles" ($css.Contains(".image-lightbox-modal") -and $css.Contains(".lightbox-content-wrap"))
Assert-Check "3.5 mobile.css defines universal guide style" ($css.Contains(".guide-universal"))

$statusColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host "----------------------------------------------------------"
Write-Host "Mobile v1.7.0 Verification: Passed=$passed, Failed=$failed" -ForegroundColor $statusColor

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
