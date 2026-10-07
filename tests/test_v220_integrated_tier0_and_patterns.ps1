# test_v220_integrated_tier0_and_patterns.ps1
# MEMORY HACK Mobile v2.2.0 Tier 0 Selector and 3-Way Pattern Separation Verification Test

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
Write-Host " MEMORY HACK Mobile v2.2.0: Tier 0 Selector & 3-Way Pattern Separation Test " -ForegroundColor Cyan
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
# Phase 1: Version and PWA Cache Integrity
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Version & PWA Cache Integrity] ---" -ForegroundColor Yellow
Assert-Check "1.1 config.js version is v2.2.0" ($config.Contains('version: "v2.2.0"'))
Assert-Check "1.2 study.js version is v2.2.0" ($study.Contains("version: 'v2.2.0'"))
Assert-Check "1.3 app.js logs v2.2.0 initialization" ($app.Contains("v2.2.0 Initializing") -and $app.Contains("Mobile v2.2.0"))
Assert-Check "1.4 service-worker.js CACHE_NAME is memory-hack-mobile-v2.2.0" ($sw.Contains("memory-hack-mobile-v2.2.0"))
Assert-Check "1.5 service-worker.js ASSETS_TO_CACHE has ?v=2.2.0 queries" ($sw.Contains("?v=2.2.0"))
Assert-Check "1.6 index.html has ?v=2.2.0 query strings for css and scripts" ($html.Contains("css/mobile.css?v=2.2.0") -and $html.Contains("js/study.js?v=2.2.0") -and $html.Contains("js/app.js?v=2.2.0"))
Assert-Check "1.7 index.html has brand-ver-badge v2.2.0" ($html.Contains('<span class="brand-ver-badge">v2.2.0</span>'))

# -------------------------------------------------------------
# Phase 2: 3-Way Pattern Separation (study.js & app.js)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: 3-Way Pattern Separation (study.js & app.js)] ---" -ForegroundColor Yellow
$p2_1 = $study.Contains("activePatternsLanguage:") -and $study.Contains("activePatternsUniversal:") -and $study.Contains("activePatternsKanji:")
Assert-Check "2.1 StudyManager defines activePatternsLanguage, activePatternsUniversal, activePatternsKanji" ($p2_1)

$p2_2 = $study.Contains("getCurrentCardType()") -and $study.Contains("cardType") -and $study.Contains("return 'kanji'") -and $study.Contains("return 'language'")
Assert-Check "2.2 StudyManager has getCurrentCardType returning language, kanji, or general" ($p2_2)

$p2_3 = $study.Contains("sanitizeLanguagePatterns(patterns)") -and $study.Contains("en_to_ja") -and $study.Contains("ja_to_en")
Assert-Check "2.3 StudyManager has sanitizeLanguagePatterns method" ($p2_3)

$p2_4 = $study.Contains("study_active_patterns_language") -and $study.Contains("sanitizeLanguagePatterns")
Assert-Check "2.4 StudyManager.init restores study_active_patterns_language" ($p2_4)

$p2_5 = $study.Contains("cardType = this.getCurrentCardType()") -and $study.Contains("activePatternsLanguage = this.sanitizeLanguagePatterns")
Assert-Check "2.5 StudyManager.switchProject sanitizes patterns via getCurrentCardType" ($p2_5)

$p2_6 = $study.Contains("getLanguagePatterns(cardLang)") -and $study.Contains("UNIVERSAL_PATTERNS") -and $study.Contains("KANJI_PATTERNS")
Assert-Check "2.6 StudyManager.renderPatternSelector supports 3-way pattern dictionaries" ($p2_6)

$p2_7 = $study.Contains("cardType === 'kanji'") -and $study.Contains("cardType === 'language'") -and $study.Contains("sanitizeLanguagePatterns")
Assert-Check "2.7 StudyManager.pickCurrentPattern branches into language, kanji, general" ($p2_7)

$p2_8 = $app.Contains("StudyManager.getCurrentCardType()") -and $app.Contains("study_active_patterns_language") -and $app.Contains("study_active_patterns_universal")
Assert-Check "2.8 App.onPatternChange and toggleAllPatterns handle 3-way card types" ($p2_8)

# -------------------------------------------------------------
# Phase 3: Tier 0 Selector in Hierarchy Modal (hierarchy.js & app.js)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: Tier 0 Selector in Hierarchy Modal] ---" -ForegroundColor Yellow
$p3_1 = $hierarchy.Contains("projectOptions")
Assert-Check "3.1 Hierarchy.renderTreeSheet accepts projectOptions parameter" ($p3_1)

$p3_2 = $hierarchy.Contains('class="hierarchy-tier0-section"') -and $hierarchy.Contains('class="hierarchy-tier0-pills"')
Assert-Check "3.2 Hierarchy.renderTreeSheet creates hierarchy-tier0-section at the top" ($p3_2)

$p3_3 = $hierarchy.Contains('class="tier0-pill') -and $hierarchy.Contains('class="tier0-pill-icon"') -and $hierarchy.Contains('class="tier0-pill-count"')
Assert-Check "3.3 Hierarchy.renderTreeSheet creates tier0-pill elements with icon, name, count" ($p3_3)

$p3_4 = $hierarchy.Contains("data-project-id") -and $hierarchy.Contains("onProjectSelect")
Assert-Check "3.4 Hierarchy.renderTreeSheet binds onProjectSelect event to tier0-pill clicks" ($p3_4)

$p3_5 = $app.Contains("onProjectSelect: async (projId)") -and $app.Contains("StudyManager.switchProject(projId)") -and $app.Contains("openHierarchyModal")
Assert-Check "3.5 App.openHierarchyModal passes projectOptions and handles reactive switching" ($p3_5)

$p3_6 = $app.Contains("openProjectModal() {") -and $app.Contains("openHierarchyModal()")
Assert-Check "3.6 App.openProjectModal routes directly to openHierarchyModal" ($p3_6)

# -------------------------------------------------------------
# Phase 4: CSS Styling and 4 Themes (mobile.css)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 4: CSS Styling and 4 Themes (mobile.css)] ---" -ForegroundColor Yellow
$p4_1 = $css.Contains(".hierarchy-tier0-section") -and $css.Contains(".hierarchy-tier0-pills")
Assert-Check "4.1 mobile.css defines .hierarchy-tier0-section and .hierarchy-tier0-pills" ($p4_1)

$p4_2 = $css.Contains(".tier0-pill") -and $css.Contains(".tier0-pill.active")
Assert-Check "4.2 mobile.css defines .tier0-pill and .tier0-pill.active" ($p4_2)

$p4_3 = $css.Contains('[data-theme="light"] .hierarchy-tier0-section') -and $css.Contains('[data-theme="light"] .tier0-pill')
Assert-Check "4.3 mobile.css defines light theme overrides for tier0 strip" ($p4_3)

$p4_4 = $css.Contains('[data-theme="bloxfruits"] .hierarchy-tier0-section') -and $css.Contains('[data-theme="bloxfruits"] .tier0-pill.active')
Assert-Check "4.4 mobile.css defines bloxfruits (Roblox) theme overrides for tier0 strip" ($p4_4)

$p4_5 = $css.Contains('[data-theme="muichiro"] .hierarchy-tier0-section') -and $css.Contains('[data-theme="muichiro"] .tier0-pill.active')
Assert-Check "4.5 mobile.css defines muichiro (Kimetsu) theme overrides for tier0 strip" ($p4_5)

# -------------------------------------------------------------
# Phase 5: Headless Browser DOM Rendering Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 5: Headless Browser DOM Rendering Verification] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if ($browserExe) {
    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_v220_dump_$([System.Guid]::NewGuid().ToString('N')).html")
    try {
        $fileUri = "file:///" + (Resolve-Path "$htmlPath").Path.Replace("\", "/")
        $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait
        
        if (Test-Path $tempDump) {
            $domText = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
            Assert-Check "5.1 Headless browser rendered DOM successfully" ($domText.Length -gt 1000)
            $p5_2 = $domText.Contains('id="modal-hierarchy"') -and $domText.Contains('id="hierarchy-tree-container"')
            Assert-Check "5.2 Headless DOM contains modal-hierarchy and hierarchy-tree-container" ($p5_2)
            $p5_3 = $domText.Contains('<span class="brand-ver-badge">v2.2.0</span>')
            Assert-Check "5.3 Headless DOM contains updated v2.2.0 brand badge" ($p5_3)
            $p5_4 = $domText.Contains('js/study.js?v=2.2.0') -and $domText.Contains('js/hierarchy.js?v=2.2.0')
            Assert-Check "5.4 Headless DOM scripts are loaded with ?v=2.2.0 cache-buster" ($p5_4)
        } else {
            Assert-Check "5.1 Headless browser rendered DOM successfully" ($false)
            Assert-Check "5.2 Headless DOM contains modal-hierarchy and hierarchy-tree-container" ($false)
            Assert-Check "5.3 Headless DOM contains updated v2.2.0 brand badge" ($false)
            Assert-Check "5.4 Headless DOM scripts are loaded with ?v=2.2.0 cache-buster" ($false)
        }
    } catch {
        Write-Host " [WARN] Headless browser test skipped: $_" -ForegroundColor Yellow
    } finally {
        if (Test-Path $tempDump) {
            Remove-Item -Path $tempDump -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host " [WARN] No suitable browser found for Phase 5." -ForegroundColor Yellow
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
$statusColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host " MEMORY HACK Mobile v2.2.0 Test Result: Passed=$passed, Failed=$failed" -ForegroundColor $statusColor
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
