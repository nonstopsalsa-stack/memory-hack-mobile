# test_v227_muichiro_visibility_and_scroll.ps1
# MEMORY HACK Mobile: Muichiro Theme Visibility, Kanji Whiteout Fix & Card Scroll Guard Verification

$ErrorActionPreference = "Stop"

$passed = 0
$failed = 0

function Assert-Check {
    param(
        [string]$Desc,
        [bool]$Condition,
        [string]$Detail = ""
    )
    if ($Condition -eq $true) {
        Write-Host " [PASS] $Desc" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host " [FAIL] $Desc" -ForegroundColor Red
        if ($Detail) {
            Write-Host "        Detail: $Detail" -ForegroundColor DarkRed
        }
        $script:failed++
    }
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " MEMORY HACK Mobile: Muichiro Theme Visibility & Card Scroll Test         " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$mobileDir = if (Test-Path (Join-Path $PSScriptRoot "..\css\mobile.css")) { (Resolve-Path "$PSScriptRoot\..").Path } else { (Resolve-Path ".").Path }
$cssPath = Join-Path $mobileDir "css\mobile.css"
$studyPath = Join-Path $mobileDir "js\study.js"
$htmlPath = Join-Path $mobileDir "index.html"

$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# Phase 1: 出題パターンモーダル & 階層ツリーモーダル視認性検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Pattern & Hierarchy Modal Visibility] ---" -ForegroundColor Yellow

$patternLabelColorVar = $css -match '\.pattern-label\s*\{[^}]*color:\s*var\(--color-text-main\)' -or $css -match '\.pattern-label\s*\{[^}]*color:\s*inherit'
Assert-Check "1.1 mobile.css .pattern-label color is variable or inherited (not hardcoded white #f1f5f9)" ($patternLabelColorVar)

$hasMuichiroPatternLabel = $css.Contains('[data-theme="muichiro"] .pattern-label')
Assert-Check "1.2 mobile.css defines [data-theme=`"muichiro`"] .pattern-label high contrast color" ($hasMuichiroPatternLabel)

$hasMuichiroTreeAll = $css -match '\[data-theme="muichiro"\]\s+\.hierarchy-tree-item\.all-item\s*\{[^}]*background:[^}]*border:'
Assert-Check "1.3 mobile.css defines Muichiro hierarchy-tree-item.all-item" ($hasMuichiroTreeAll)

$hasMuichiroTier1 = $css -match '\[data-theme="muichiro"\]\s+\.hierarchy-tier1-header\s*\{[^}]*background:\s*#ffffff[^}]*color:\s*#0f172a'
Assert-Check "1.4 mobile.css defines Muichiro hierarchy-tier1-header white background & slate text" ($hasMuichiroTier1)

$hasMuichiroTier1Active = $css -match '\[data-theme="muichiro"\]\s+\.hierarchy-tier1-header\.active\s*\{[^}]*border-left:\s*3px solid #0d9488'
Assert-Check "1.5 mobile.css defines Muichiro hierarchy-tier1-header.active mist green accent" ($hasMuichiroTier1Active)

$hasMuichiroName = $css -match '\[data-theme="muichiro"\]\s+\.hierarchy-name\s*\{[^}]*color:\s*#0f172a[^}]*font-weight:\s*700'
Assert-Check "1.6 mobile.css defines Muichiro hierarchy-name bold slate dark" ($hasMuichiroName)

$hasMuichiroTier2 = $css -match '\[data-theme="muichiro"\]\s+\.hierarchy-tier2-header\s*\{[^}]*background:\s*#ffffff[^}]*color:\s*#0f172a'
Assert-Check "1.7 mobile.css defines Muichiro hierarchy-tier2-header" ($hasMuichiroTier2)

$hasMuichiroTier3 = $css -match '\[data-theme="muichiro"\]\s+\.hierarchy-tier3-item\s*\{[^}]*background:\s*#ffffff[^}]*color:\s*#0f172a'
Assert-Check "1.8 mobile.css defines Muichiro hierarchy-tier3-item" ($hasMuichiroTier3)

$hasMuichiroSelectBtn = $css -match '\[data-theme="muichiro"\]\s+\.btn-tree-select\.selected'
Assert-Check "1.9 mobile.css defines Muichiro btn-tree-select.selected" ($hasMuichiroSelectBtn)

# -------------------------------------------------------------
# Phase 2: 漢字1文字・学習カード全般の白飛び解消検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: Kanji & Card Whiteout Prevention] ---" -ForegroundColor Yellow

# study.js pickKanjiQuestion 内のインラインスタイル排除チェック
$pickMethodMatch = $study -match 'pickKanjiQuestion\(card,\s*requestedPattern\)\s*\{([\s\S]*?)\n\s*isDrillMode:'
$pickMethodBody = if ($pickMethodMatch) { $Matches[1] } else { "" }

$noInlineF8InPick = -not ($pickMethodBody.Contains('color: #f8fafc'))
Assert-Check "2.1 study.js pickKanjiQuestion has NO hardcoded inline color: #f8fafc" ($noInlineF8InPick)

$noInlineRgbaBgInPick = -not ($pickMethodBody.Contains('background: rgba('))
Assert-Check "2.2 study.js pickKanjiQuestion has NO hardcoded inline background: rgba(...)" ($noInlineRgbaBgInPick)

$usesTargetKanjiHuge = $pickMethodBody.Contains('class="target-kanji-huge"')
Assert-Check "2.3 study.js pickKanjiQuestion uses .target-kanji-huge class" ($usesTargetKanjiHuge)

$usesKanjiSentenceBox = $pickMethodBody.Contains('class="kanji-sentence-box"')
Assert-Check "2.4 study.js pickKanjiQuestion uses .kanji-sentence-box class" ($usesKanjiSentenceBox)

$hasTargetKanjiHugeCss = $css.Contains('.target-kanji-huge') -and $css -match '\.target-kanji-huge\s*\{[^}]*font-size:[^}]*font-weight:'
Assert-Check "2.5 mobile.css defines .target-kanji-huge base styling" ($hasTargetKanjiHugeCss)

$hasKanjiSentenceBoxCss = $css.Contains('.kanji-sentence-box') -and $css -match '\.kanji-sentence-box\s*\{[^}]*font-size:[^}]*line-height:'
Assert-Check "2.6 mobile.css defines .kanji-sentence-box base styling" ($hasKanjiSentenceBoxCss)

$hasMuichiroKanjiHugeSlate = $css -match '\[data-theme="muichiro"\]\s+\.target-kanji-huge\s*\{[^}]*color:\s*#0f172a\s*!important'
Assert-Check "2.7 mobile.css [data-theme=`"muichiro`"] .target-kanji-huge uses dark slate #0f172a" ($hasMuichiroKanjiHugeSlate)

$hasMuichiroSentenceBox = $css -match '\[data-theme="muichiro"\]\s+\.kanji-sentence-box\s*\{[^}]*background:\s*#ffffff[^}]*color:\s*#0f172a'
Assert-Check "2.8 mobile.css [data-theme=`"muichiro`"] .kanji-sentence-box uses white background & slate text" ($hasMuichiroSentenceBox)

$hasMuichiroReadingsGrid = $css -match '\[data-theme="muichiro"\]\s+\.kanji-readings-grid\s*\{[^}]*background:\s*#ffffff[^}]*color:\s*#0f172a'
Assert-Check "2.9 mobile.css [data-theme=`"muichiro`"] .kanji-readings-grid uses white background & slate text" ($hasMuichiroReadingsGrid)

# -------------------------------------------------------------
# Phase 3: 縦長コンテンツのスクロール・上下見切れ解消検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: Card Body Overflow & Scroll Protection] ---" -ForegroundColor Yellow

$cardBodyFlexStart = $css -match '\.card-body\s*\{[^}]*justify-content:\s*flex-start'
Assert-Check "3.1 mobile.css .card-body uses justify-content: flex-start (no flex-center overflow)" ($cardBodyFlexStart)

$cardBodyMarginAuto = $css.Contains('.card-body > .card-prompt-container') -and $css.Contains('margin: auto 0')
Assert-Check "3.2 mobile.css centers short card content using margin: auto 0" ($cardBodyMarginAuto)

$cardBodyMaxHeight = $css -match '\.card-body\s*\{[^}]*max-height:\s*calc\(100dvh\s*-\s*3[0-9]{2}px\)'
Assert-Check "3.3 mobile.css .card-body max-height protects bottom action bar (calc(100dvh - 350px))" ($cardBodyMaxHeight)

$touchStateHasMoved = $study.Contains('hasMoved: false') -and $study.Contains('lastMoveTime: 0')
Assert-Check "3.4 study.js touchState tracks movement & timestamp" ($touchStateHasMoved)

$studyTouchMoveThreshold = $study.Contains('Math.abs(deltaX) > 8 || Math.abs(deltaY) > 8')
Assert-Check "3.5 study.js touchmove listener detects minimal movement to guard tap" ($studyTouchMoveThreshold)

$studyFlipCardGuarded = $study.Contains('if (this.touchState.hasMoved || (this.touchState.lastMoveTime && Date.now() - this.touchState.lastMoveTime < 350))')
Assert-Check "3.6 study.js flipCard guards against accidental flip during touch drag" ($studyFlipCardGuarded)

$studyCardOnClickGuarded = $study.Contains('onclick="StudyManager.flipCard(false);"')
Assert-Check "3.7 study.js study-card element calls flipCard(false) through touch guard" ($studyCardOnClickGuarded)

$studyBtnFlipBypass = $study.Contains('onclick="StudyManager.flipCard(true);"')
Assert-Check "3.8 study.js bottom bar FLIP button calls flipCard(true) to bypass touch guard" ($studyBtnFlipBypass)

# -------------------------------------------------------------
# Phase 4: 他テーマ（light, bloxfruits, dark）非破壊検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 4: Multi-Theme Non-Regression Verification] ---" -ForegroundColor Yellow

$openBraces = ($css.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$closeBraces = ($css.ToCharArray() | Where-Object { $_ -eq '}' }).Count
Assert-Check "4.1 mobile.css braces balance check ($openBraces vs $closeBraces)" ($openBraces -eq $closeBraces)

$lightThemeIntact = $css.Contains('[data-theme="light"] .study-card') -and
                    $css.Contains('[data-theme="light"] .target-kanji-huge') -and
                    $css.Contains('[data-theme="light"] .hierarchy-tier1-group')
Assert-Check "4.2 light theme hierarchy & kanji rules intact" ($lightThemeIntact)

$bloxfruitsThemeIntact = $css.Contains('[data-theme="bloxfruits"] .hierarchy-tier0-section') -and
                         $css.Contains('[data-theme="bloxfruits"] .kanji-answer-val') -and
                         $css.Contains('[data-theme="bloxfruits"] .brand-logo .logo-sword')
Assert-Check "4.3 bloxfruits theme rules intact" ($bloxfruitsThemeIntact)

$darkThemeIntact = $css.Contains('[data-theme="dark"] .kanji-answer-val')
Assert-Check "4.4 dark theme rules intact" ($darkThemeIntact)

# -------------------------------------------------------------
# Phase 5: ヘッドレスブラウザによる Computed Styles 検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 5: Headless Browser Computed Style Verification] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if ($browserExe) {
    $testHtmlPath = Join-Path $mobileDir "tests\temp_muichiro_computed_test.html"
    $htmlContent = @"
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <link rel="stylesheet" href="../css/mobile.css">
</head>
<body data-theme="muichiro">
  <div id="app-container">
    <div class="pattern-item">
      <span class="pattern-label">テスト出題パターン</span>
    </div>
    <div class="hierarchy-tier1-group open">
      <div class="hierarchy-tier1-header">
        <span class="hierarchy-name">テストジャンル</span>
      </div>
    </div>
    <div class="study-card">
      <div class="card-body">
        <div class="card-prompt-container">
          <span class="target-kanji-huge">漢</span>
          <div class="kanji-sentence-box">例文テスト</div>
        </div>
      </div>
    </div>
  </div>
  <script>
    window.addEventListener('DOMContentLoaded', () => {
      const pLabel = document.querySelector('.pattern-label');
      const t1Header = document.querySelector('.hierarchy-tier1-header');
      const hName = document.querySelector('.hierarchy-name');
      const kanjiHuge = document.querySelector('.target-kanji-huge');
      const cardBody = document.querySelector('.card-body');

      const res = {
        patternLabel_color: window.getComputedStyle(pLabel).color,
        t1Header_bg: window.getComputedStyle(t1Header).backgroundColor,
        t1Header_color: window.getComputedStyle(t1Header).color,
        hName_color: window.getComputedStyle(hName).color,
        kanjiHuge_color: window.getComputedStyle(kanjiHuge).color,
        cardBody_justify: window.getComputedStyle(cardBody).justifyContent
      };
      
      const out = document.createElement('div');
      out.id = 'computed-results';
      out.textContent = JSON.stringify(res);
      document.body.appendChild(out);
    });
  </script>
</body>
</html>
"@
    [System.IO.File]::WriteAllText($testHtmlPath, $htmlContent, [System.Text.Encoding]::UTF8)

    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_muichiro_dom_$([System.Guid]::NewGuid().ToString('N')).html")
    try {
        $fileUri = "file:///" + (Resolve-Path $testHtmlPath).Path.Replace("\", "/")
        $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait

        if (Test-Path $tempDump) {
            $rendered = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
            $match = [regex]::Match($rendered, '<div id="computed-results">(.*?)</div>')
            if ($match.Success) {
                $jsonStr = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
                $data = $jsonStr | ConvertFrom-Json

                # rgb(19, 78, 74) is #134e4a
                Assert-Check "5.1 Muichiro .pattern-label computed color is dark teal (rgb(19, 78, 74))" ($data.patternLabel_color -eq "rgb(19, 78, 74)")
                # rgb(255, 255, 255)
                Assert-Check "5.2 Muichiro .hierarchy-tier1-header computed bg is white (rgb(255, 255, 255))" ($data.t1Header_bg -eq "rgb(255, 255, 255)")
                # rgb(15, 23, 42) is #0f172a
                Assert-Check "5.3 Muichiro .hierarchy-name computed color is dark slate (rgb(15, 23, 42))" ($data.hName_color -eq "rgb(15, 23, 42)")
                # rgb(15, 23, 42) is #0f172a
                Assert-Check "5.4 Muichiro .target-kanji-huge computed color is dark slate (rgb(15, 23, 42))" ($data.kanjiHuge_color -eq "rgb(15, 23, 42)")
                # flex-start
                Assert-Check "5.5 .card-body computed justify-content is flex-start" ($data.cardBody_justify -eq "flex-start")
            } else {
                Assert-Check "5.1 Browser computed results extracted" $false "Failed to find #computed-results div"
            }
            Remove-Item -Force $tempDump -ErrorAction SilentlyContinue
        } else {
            Assert-Check "5.1 Headless browser dump" $false "Dump file not created"
        }
    } finally {
        Remove-Item -Force $testHtmlPath -ErrorAction SilentlyContinue
    }
} else {
    Write-Host " [SKIP] No Chrome or Edge found for headless verification" -ForegroundColor DarkGray
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESULT: $passed Passed / $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
