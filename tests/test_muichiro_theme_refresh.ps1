# test_muichiro_theme_refresh.ps1
# MEMORY HACK Mobile: Muichiro Theme Visual Refresh & Icon Placement Verification Test

$ErrorActionPreference = "Stop"
$passed = 0
$failed = 0

function Assert-Check {
    param(
        [string]$name,
        [bool]$condition,
        [string]$detail = ""
    )
    if ($condition) {
        Write-Host " [PASS] $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host " [FAIL] $name $detail" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " MEMORY HACK Mobile: Muichiro (Mist Hashira) Theme & Icon Refresh Test    " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$mobileDir = Resolve-Path "$PSScriptRoot/.."
$htmlPath = Join-Path $mobileDir "index.html"
$cssPath = Join-Path $mobileDir "css\mobile.css"
$appPath = Join-Path $mobileDir "js\app.js"
$avatarPath = Join-Path $mobileDir "assets\muichiro_avatar.png"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
$app = [System.IO.File]::ReadAllText($appPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# Phase 1: Asset Placement Verification (assets/muichiro_avatar.png)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Asset Placement Verification] ---" -ForegroundColor Yellow
$avatarExists = Test-Path $avatarPath
$avatarSize = if ($avatarExists) { (Get-Item $avatarPath).Length } else { 0 }
Assert-Check "1.1 muichiro_avatar.png exists in anki-mobile/assets" ($avatarExists)
Assert-Check "1.2 muichiro_avatar.png size is valid (> 10KB)" ($avatarSize -gt 10000)

# -------------------------------------------------------------
# Phase 2: HTML Structure Verification (#brand-logo & avatar)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: HTML Structure Verification] ---" -ForegroundColor Yellow
$hasAvatarElement = $html.Contains('class="logo-muichiro"') -and $html.Contains('src="assets/muichiro_avatar.png"')
Assert-Check "2.1 index.html contains .logo-muichiro with assets/muichiro_avatar.png" ($hasAvatarElement)

$brandLogoSlice = if ($html -match 'id="brand-logo"[\s\S]*?<span class="brand-title">') { $Matches[0] } else { "" }
$isInsideBrandLogo = $brandLogoSlice.Contains('logo-muichiro')
Assert-Check "2.2 .logo-muichiro is strictly inside #brand-logo span" ($isInsideBrandLogo)

# -------------------------------------------------------------
# Phase 3: PWA Dynamic Theme Color (app.js applyTheme)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: PWA Theme-Color Verification] ---" -ForegroundColor Yellow
$pwaMuichiroMatch = $app -match "theme === 'muichiro'\)\s*\{\s*metaTheme\.setAttribute\('content',\s*'#a7f3d0'\);"
Assert-Check "3.1 app.js applyTheme sets theme-color to #a7f3d0 for muichiro theme" ($pwaMuichiroMatch)

# -------------------------------------------------------------
# Phase 4: CSS Theme Styling Verification (mobile.css)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 4: CSS Theme Styling Verification] ---" -ForegroundColor Yellow

# 4.1 Background: PC-compliant mint gradient + mist cloud radial backdrops
$hasMintGradient = $css.Contains("linear-gradient(135deg, #a7f3d0 0%, #6ee7b7 35%, #5eead4 70%, #99f6e4 100%)")
Assert-Check "4.1 mobile.css defines PC-compliant mint gradient background for muichiro" ($hasMintGradient)

$hasMistClouds = $css.Contains('[data-theme="muichiro"] body::before') -and $css.Contains('radial-gradient(circle at 8% 22%')
Assert-Check "4.2 mobile.css defines mist clouds radial-gradient decorative backdrop" ($hasMistClouds)

# 4.2 Top Bar: Deep green teal (#133b46)
$hasTealTopBar = $css -match '\[data-theme="muichiro"\]\s+\.top-bar\s*\{[^}]*background:\s*#133b46'
Assert-Check "4.3 mobile.css top-bar uses deep green teal (#133b46)" ($hasTealTopBar)

# 4.3 Brand Logo controls
$hasBaseLogoHidden = $css.Contains('.brand-logo .logo-muichiro') -and $css -match '\.brand-logo\s+\.logo-muichiro\s*\{[^}]*display:\s*none'
Assert-Check "4.4 mobile.css sets default display:none for .logo-muichiro" ($hasBaseLogoHidden)

$hasMuichiroLogoVisible = $css -match '\[data-theme="muichiro"\]\s+\.brand-logo\s+\.logo-muichiro\s*\{[^}]*display:\s*inline-block\s*!important' -and
                          $css -match 'width:\s*28px' -and
                          $css -match 'border:\s*2px solid #2dd4bf'
Assert-Check "4.5 mobile.css renders 28x28px circular turquoise-bordered logo-muichiro on muichiro theme" ($hasMuichiroLogoVisible)

$hasSwordsIntellectHidden = $css -match '\[data-theme="muichiro"\]\s+\.brand-logo\s+\.logo-sword\s*\{[^}]*display:\s*none\s*!important' -and
                            $css -match '\[data-theme="muichiro"\]\s+\.brand-logo\s+\.logo-intellect\s*\{[^}]*display:\s*none\s*!important'
Assert-Check "4.6 mobile.css hides sword and intellect logo when muichiro theme is active" ($hasSwordsIntellectHidden)

# 4.4 Card body: Kinari (#faf8f5) + wood frame border (2.5px solid #8b5a2b)
$hasWoodCardFrame = $css -match '\[data-theme="muichiro"\]\s+\.study-card,\s*\[data-theme="muichiro"\]\s+\.flashcard-card\s*\{[^}]*background:\s*#faf8f5[^}]*border:\s*2\.5px solid #8b5a2b'
Assert-Check "4.7 mobile.css card uses kinari background (#faf8f5) and wood frame border (2.5px solid #8b5a2b)" ($hasWoodCardFrame)

# 4.5 Text visibility: Prompt, answer, and kanji drill text use high-contrast slate dark (#0f172a)
$hasCardPromptSlate = $css -match '\[data-theme="muichiro"\]\s+\.card-prompt-text[^\{]*\{[^}]*color:\s*#0f172a\s*!important'
Assert-Check "4.8 mobile.css prompt text uses high-contrast slate dark (#0f172a)" ($hasCardPromptSlate)

$hasCardAnswerSlate = $css -match '\[data-theme="muichiro"\]\s+\.card-answer-main[^\{]*\{[^}]*color:\s*#0f172a\s*!important'
Assert-Check "4.9 mobile.css answer text uses high-contrast slate dark (#0f172a)" ($hasCardAnswerSlate)

$hasKanjiValSlate = $css -match '\[data-theme="muichiro"\]\s+\.kanji-answer-val\s*\{[^}]*color:\s*#0f172a\s*!important'
Assert-Check "4.10 mobile.css kanji-answer-val uses high-contrast slate dark (#0f172a)" ($hasKanjiValSlate)

# 4.6 Control strip: White chip background + turquoise border (#14b8a6)
$hasChipsTurquoise = $css -match '\[data-theme="muichiro"\]\s+\.deck-chip-btn[^\{]*\{[^}]*background:\s*#ffffff[^}]*border:\s*1\.5px solid #14b8a6'
Assert-Check "4.11 mobile.css control strip chips use white background and turquoise border (#14b8a6)" ($hasChipsTurquoise)

# 4.7 Action buttons: FLIP button uses vibrant mist green (#0d9488 to #14b8a6)
$hasFlipMistGreen = $css -match '\[data-theme="muichiro"\]\s+\.btn-action\.btn-flip[^\{]*\{[^}]*background:\s*linear-gradient\(135deg,\s*#0d9488\s*0%,\s*#14b8a6\s*100%\)'
Assert-Check "4.12 mobile.css FLIP button uses vibrant mist green gradient (#0d9488 to #14b8a6)" ($hasFlipMistGreen)

# -------------------------------------------------------------
# Phase 5: Other Themes Intact Verification (light, dark, bloxfruits)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 5: Other Themes Non-Regression Verification] ---" -ForegroundColor Yellow

$lightThemeIntact = $css.Contains('[data-theme="light"] html') -and
                    $css.Contains('[data-theme="light"] .btn-action.btn-flip') -and
                    $css.Contains('[data-theme="light"] .kanji-answer-val')
Assert-Check "5.1 light theme rules intact in mobile.css" ($lightThemeIntact)

$darkThemeIntact = $css.Contains('[data-theme="dark"] .brand-title') -and
                   $css.Contains('[data-theme="dark"] .brand-logo .logo-intellect') -and
                   $css.Contains('[data-theme="dark"] .kanji-answer-val')
Assert-Check "5.2 dark theme rules intact in mobile.css" ($darkThemeIntact)

$bloxfruitsThemeIntact = $css.Contains('[data-theme="bloxfruits"] .hierarchy-tier0-section') -and
                         $css.Contains('[data-theme="bloxfruits"] .kanji-answer-val') -and
                         $css.Contains('[data-theme="bloxfruits"] .brand-logo .logo-sword')
Assert-Check "5.3 bloxfruits theme rules intact in mobile.css" ($bloxfruitsThemeIntact)

# -------------------------------------------------------------
# Phase 6: Headless Browser DOM Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 6: Headless Browser DOM Verification] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if ($browserExe) {
    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_muichiro_dump_$([System.Guid]::NewGuid().ToString('N')).html")
    try {
        $fileUri = "file:///" + (Resolve-Path "$htmlPath").Path.Replace("\", "/")
        $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait
        
        if (Test-Path $tempDump) {
            $rendered = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
            Assert-Check "6.1 Headless browser rendered DOM successfully" ($rendered.Length -gt 1000)
            Assert-Check "6.2 Headless DOM contains .logo-muichiro avatar element" ($rendered.Contains('logo-muichiro'))
            Assert-Check "6.3 Headless DOM contains avatar source assets/muichiro_avatar.png" ($rendered.Contains('assets/muichiro_avatar.png'))
            Remove-Item -Force $tempDump -ErrorAction SilentlyContinue
        } else {
            Assert-Check "6.1 Headless browser DOM dump creation" $false "Dump file not created"
        }
    } catch {
        Assert-Check "6.1 Headless browser execution failed" $false $_.Exception.Message
    }
} else {
    Write-Host " [SKIP] No Chrome or Edge found for headless DOM dump" -ForegroundColor DarkGray
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESULT: $passed Passed / $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
