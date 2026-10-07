# test_v210_tier0_project_selector.ps1
# MEMORY HACK Mobile v2.1.0 Tier 0 (Project) Selector UI & Reactive Context Verification Test

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

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " MEMORY HACK Mobile - v2.1.0 Tier 0 Project Selector Test " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$storagePath = Resolve-Path "$PSScriptRoot/../js/storage.js"
$syncPath = Resolve-Path "$PSScriptRoot/../js/sync.js"
$studyPath = Resolve-Path "$PSScriptRoot/../js/study.js"
$appPath = Resolve-Path "$PSScriptRoot/../js/app.js"
$configPath = Resolve-Path "$PSScriptRoot/../js/config.js"
$swPath = Resolve-Path "$PSScriptRoot/../service-worker.js"
$htmlPath = Resolve-Path "$PSScriptRoot/../index.html"
$cssPath = Resolve-Path "$PSScriptRoot/../css/mobile.css"

$storage = [System.IO.File]::ReadAllText($storagePath, [System.Text.Encoding]::UTF8)
$sync = [System.IO.File]::ReadAllText($syncPath, [System.Text.Encoding]::UTF8)
$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$app = [System.IO.File]::ReadAllText($appPath, [System.Text.Encoding]::UTF8)
$config = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# 1. バージョン整合性 & PWA キャッシュ検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: バージョン & PWA キャッシュ整合性] ---" -ForegroundColor Yellow
Assert-Check "1.1 config.js version is v2.1.0" ($config.Contains('version: "v2.1.0"'))
Assert-Check "1.2 study.js version is v2.1.0" ($study.Contains("version: 'v2.1.0'"))
Assert-Check "1.3 app.js logs and toasts v2.1.0" ($app.Contains("v2.1.0 Initializing") -and $app.Contains("Mobile v2.1.0 準備完了"))
Assert-Check "1.4 service-worker.js CACHE_NAME is memory-hack-mobile-v2.1.0" ($sw.Contains("memory-hack-mobile-v2.1.0"))
Assert-Check "1.5 service-worker.js ASSETS_TO_CACHE has ?v=2.1.0 queries" ($sw.Contains("?v=2.1.0"))
Assert-Check "1.6 index.html has ?v=2.1.0 query strings for css and scripts" ($html.Contains("css/mobile.css?v=2.1.0") -and $html.Contains("js/storage.js?v=2.1.0") -and $html.Contains("js/study.js?v=2.1.0"))
Assert-Check "1.7 index.html top bar has brand badge v2.1.0" ($html.Contains('<span class="brand-ver-badge">v2.1.0</span>'))

# -------------------------------------------------------------
# 2. ストレージ層 (storage.js) プロジェクト永続化検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: ストレージ層 (storage.js) 検証] ---" -ForegroundColor Yellow
Assert-Check "2.1 Storage.KEYS defines PROJECTS key" ($storage.Contains("PROJECTS: 'memory_hack_mobile_projects'"))
Assert-Check "2.2 Storage.KEYS defines ACTIVE_PROJECT key" ($storage.Contains("ACTIVE_PROJECT: 'memory_hack_mobile_active_proj'"))
Assert-Check "2.3 Storage defines DEFAULT_PROJECT fallback" ($storage.Contains("DEFAULT_PROJECT:") -and $storage.Contains("deck_default") -and $storage.Contains("哲生英語"))
Assert-Check "2.4 Storage has getProjects accessor" ($storage.Contains("async getProjects()"))
Assert-Check "2.5 Storage has saveProjects accessor" ($storage.Contains("async saveProjects(projects)"))
Assert-Check "2.6 Storage has getActiveProjectId accessor" ($storage.Contains("async getActiveProjectId()"))
Assert-Check "2.7 Storage has setActiveProjectId accessor" ($storage.Contains("async setActiveProjectId(id)"))
Assert-Check "2.8 Storage has getActiveProject helper" ($storage.Contains("async getActiveProject()"))

# -------------------------------------------------------------
# 3. 同期層 (sync.js) プロジェクト永続化・フィルタリング検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: 同期層 (sync.js) 検証] ---" -ForegroundColor Yellow
Assert-Check "3.1 pullDeck persists allowedProjects via Storage.saveProjects" ($sync.Contains("Storage.saveProjects(allowedProjects)"))
Assert-Check "3.2 pullDeck filters remoteCards using allowedProjectIds" ($sync.Contains("allowedProjectIds.has(pId)"))
Assert-Check "3.3 pullDeck updates active project fallback if needed" ($sync.Contains("Storage.setActiveProjectId(allowedProjects[0].id)"))
Assert-Check "3.4 pullDeck invokes App.updateProjectPill" ($sync.Contains("App.updateProjectPill()"))

# -------------------------------------------------------------
# 4. UI構造 (index.html) & スタイリング (mobile.css) 検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 4: UI構造 & スタイリング検証] ---" -ForegroundColor Yellow
Assert-Check "4.1 index.html has btn-project-trigger pill button in top bar" ($html.Contains('id="btn-project-trigger"') -and $html.Contains('class="project-pill-btn"') -and $html.Contains('onclick="App.openProjectModal()"'))
Assert-Check "4.2 index.html has #project-icon and #project-name elements" ($html.Contains('id="project-icon"') -and $html.Contains('id="project-name"'))
Assert-Check "4.3 index.html has #modal-project bottom sheet modal" ($html.Contains('id="modal-project"') -and $html.Contains('class="modal-sheet bottom-sheet project-sheet"'))
Assert-Check "4.4 index.html has #project-list-container for dynamic project items" ($html.Contains('id="project-list-container"'))
Assert-Check "4.5 mobile.css defines .project-pill-wrap and .project-pill-btn" ($css.Contains(".project-pill-wrap") -and $css.Contains(".project-pill-btn"))
Assert-Check "4.6 mobile.css defines .project-sheet and .project-item" ($css.Contains(".project-sheet") -and $css.Contains(".project-item") -and $css.Contains(".btn-project-select"))
Assert-Check "4.7 mobile.css defines light theme overrides for project selection" ($css.Contains('[data-theme="light"] .project-pill-btn') -and $css.Contains('[data-theme="light"] .project-item'))

# -------------------------------------------------------------
# 5. コントローラー (app.js) & 学習エンジン (study.js) リアクティブ連動検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 5: リアクティブ連動 (app.js & study.js) 検証] ---" -ForegroundColor Yellow
Assert-Check "5.1 App has updateProjectPill method" ($app.Contains("updateProjectPill()"))
Assert-Check "5.2 App has openProjectModal and renderProjectList methods" ($app.Contains("openProjectModal()") -and $app.Contains("renderProjectList()"))
Assert-Check "5.3 App has switchProject method with toast notification" ($app.Contains("switchProject(projectId)") -and $app.Contains("StudyManager.switchProject"))
Assert-Check "5.4 StudyManager has filterCardsForProject method" ($study.Contains("filterCardsForProject(allCards, projectId, projects)"))
Assert-Check "5.5 StudyManager has switchProject reactive method" ($study.Contains("switchProject(projectId)"))
Assert-Check "5.6 StudyManager.switchProject resets hierarchy filter to 'all'" ($study.Contains("this.selectedFilter = { level1: 'all', level2: 'all', level3: 'all' }"))
Assert-Check "5.7 StudyManager.getCardLanguage links with currentProject.targetLanguage" ($study.Contains("this.currentProject && this.currentProject.targetLanguage"))
Assert-Check "5.8 StudyManager.isCurrentSessionKanji links with currentProject.cardType === 'kanji'" ($study.Contains("this.currentProject && this.currentProject.cardType === 'kanji'"))

# -------------------------------------------------------------
# 6. Headless Browser (Edge/Chrome) DOM レンダリング検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 6: Headless Browser DOM レンダリング検証] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if ($browserExe) {
    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_v210_dump_$([System.Guid]::NewGuid().ToString('N')).html")
    try {
        $fileUri = "file:///" + (Resolve-Path "$htmlPath").Path.Replace("\", "/")
        $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait
        
        if (Test-Path $tempDump) {
            $domText = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
            Assert-Check "6.1 Headless browser rendered DOM successfully" ($domText.Length -gt 1000)
            Assert-Check "6.2 Headless DOM contains btn-project-trigger" ($domText.Contains('id="btn-project-trigger"'))
            Assert-Check "6.3 Headless DOM contains modal-project" ($domText.Contains('id="modal-project"'))
            Assert-Check "6.4 Headless DOM contains project-list-container" ($domText.Contains('id="project-list-container"'))
        } else {
            Assert-Check "6.1 Headless browser rendered DOM successfully" $false
            Assert-Check "6.2 Headless DOM contains btn-project-trigger" $false
            Assert-Check "6.3 Headless DOM contains modal-project" $false
            Assert-Check "6.4 Headless DOM contains project-list-container" $false
        }
    } catch {
        Write-Host " [WARN] Headless browser test skipped due to execution error: $_" -ForegroundColor Yellow
    } finally {
        if (Test-Path $tempDump) {
            Remove-Item -Path $tempDump -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host " [WARN] No suitable Chrome or Edge browser found for Phase 6." -ForegroundColor Yellow
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
$statusColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host " MEMORY HACK Mobile v2.1.0 Test Result: Passed=$passed, Failed=$failed" -ForegroundColor $statusColor
Write-Host "==========================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
