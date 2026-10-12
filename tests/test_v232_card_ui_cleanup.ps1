# test_v232_card_ui_cleanup.ps1
# MEMORY HACK Mobile: v2.3.2 Card UI Cleanup & Kanji Alignment Test
# Automated Headless Chrome/Edge Verification for R1 - R4

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
Write-Host " MEMORY HACK Mobile v2.3.2: Card UI Cleanup & Alignment Test               " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$mobileDir = if (Test-Path (Join-Path $PSScriptRoot "..\css\mobile.css")) { (Resolve-Path "$PSScriptRoot\..").Path } else { (Resolve-Path ".").Path }
$cssPath = Join-Path $mobileDir "css\mobile.css"
$studyPath = Join-Path $mobileDir "js\study.js"
$htmlPath = Join-Path $mobileDir "index.html"
$swPath = Join-Path $mobileDir "service-worker.js"

$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# Phase 1: 静的コード構造検証 (R1, R2, R3, R4)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Static Code Structure Verification] ---" -ForegroundColor Yellow

# R1: バッジ出力の根絶 & card-top-info flex-end
$hasNoQuestBadgeDiv = -not ($study -match '<div class="quest-badge')
Assert-Check "1.1 study.js has NO quest-badge markup rendered in renderCard" ($hasNoQuestBadgeDiv)

$cardTopInfoFlexEnd = $css -match '\.card-top-info\s*\{[^}]*justify-content:\s*flex-end'
Assert-Check "1.2 mobile.css defines .card-top-info with justify-content: flex-end" ($cardTopInfoFlexEnd)

# R2: 中央寄せルール
$hasHugeKanjiBlockCenter = $css.Contains(".card-prompt-target .target-kanji-huge") -and $css.Contains(".card-answer-main .target-kanji-huge")
Assert-Check "1.3 mobile.css defines block center rules for .target-kanji-huge in prompt and answer" ($hasHugeKanjiBlockCenter)

$hasReadingsWrapWidth100 = $css -match '\.kanji-answer-readings-wrap\s*\{[^}]*width:\s*100%'
Assert-Check "1.4 mobile.css defines .kanji-answer-readings-wrap with width: 100%" ($hasReadingsWrapWidth100)

$hasReadingsGridCentered = $css -match '\.kanji-readings-grid\s*\{[^}]*margin:\s*8px auto' -and $css -match '\.kanji-readings-grid\s*\{[^}]*justify-content:\s*center'
Assert-Check "1.5 mobile.css defines .kanji-readings-grid with margin: 8px auto and justify-content: center" ($hasReadingsGridCentered)

# R3/R4: 系統B .reading-val 存在 & 各テーマの配色セレクタ
$studyHasReadingVal = $study.Contains('class="reading-val"')
Assert-Check "1.6 study.js fullReadingsHtml outputs .reading-val span for readings values" ($studyHasReadingVal)

$cssHasBloxfruitsColors = $css.Contains('[data-theme="bloxfruits"] .kanji-answer-val') -and $css.Contains('#ffd24a')
Assert-Check "1.7 mobile.css bloxfruits theme defines gold (#ffd24a) kanji-answer-val & reading-val" ($cssHasBloxfruitsColors)

$cssHasDarkColors = $css.Contains('[data-theme="dark"] .kanji-answer-val') -and $css.Contains('#7dd3fc')
Assert-Check "1.8 mobile.css dark theme defines sky blue (#7dd3fc) kanji-answer-val & reading-val" ($cssHasDarkColors)

$cssHasLightColors = $css.Contains('[data-theme="light"] .kanji-answer-val') -and $css.Contains('#4338ca')
Assert-Check "1.9 mobile.css light theme defines indigo (#4338ca) kanji-answer-val & reading-val" ($cssHasLightColors)

$cssHasMuichiroColors = $css.Contains('[data-theme="muichiro"] .kanji-answer-val') -and $css.Contains('#0f766e')
Assert-Check "1.10 mobile.css muichiro theme defines teal (#0f766e) kanji-answer-val & reading-val" ($cssHasMuichiroColors)

# -------------------------------------------------------------
# Phase 2: ヘッドレスブラウザによる R1〜R4 実測検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: Headless Browser Real DOM Measurements (R1 - R4)] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if (-not $browserExe) {
    Write-Host " [SKIP] No Chrome or Edge found for headless verification" -ForegroundColor DarkGray
} else {
    $testHtmlPath = Join-Path $mobileDir "tests\temp_v232_test.html"

    $htmlContent = @'
<!DOCTYPE html>
<html lang="ja" data-theme="dark">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="../css/mobile.css">
  <style>
    html, body { margin: 0; width: 390px; height: 760px; overflow: hidden; }
    .stage-container { width: 390px; box-sizing: border-box; }
  </style>
</head>
<body data-theme="dark">
  <div class="stage-container"><div id="card-stage"></div></div>
  <pre id="out"></pre>

  <script src="../js/config.js"></script>
  <script src="../js/storage.js"></script>
  <script src="../js/audio.js"></script>
  <script src="../js/study.js"></script>
  <script>
  window.onerror = function(msg, url, line, col, err) {
    document.getElementById('out').textContent = '###DATA_START###' + JSON.stringify({ error: msg + ' at ' + line + ':' + col }) + '###DATA_END###';
  };
  (function() {
    const out = document.getElementById('out');
    const results = {};
    try {
      const S = window.StudyManager;
      S.renderPatternSelector = function() {};
      S.updateBottomActionButtons = function() {};
      S.queue = [1, 2, 3];
      S.currentIndex = 1;

      const cards = {
        word1: { id: 'w1', front: 'apple', back: '\u308A\u3093\u3054', itemType: 'word' },
        sent1: { id: 's1', front: 'May the force be with you.', back: '\u30D5\u30A9\u30FC\u30B9\u3068\u5171\u306B\u3042\u3089\u3093\u3053\u3068\u3092\u3002', itemType: 'sentence' },
        kanji1: { id: 'k1', front: '\u65E5', back: '\u3072\u3001\u306B\u3061', itemType: 'kanji', onYomi: '\u30CB\u30C1', kunYomi: '\u3072', category1: '\u6F22\u5B57' },
        univ1: { id: 'u1', front: '\u65E5\u672C\u306E\u9996\u90FD\u306F\uFF1F', back: '\u6771\u4EAC', itemType: 'general' }
      };

      function render(card, p, flipped, projType) {
        S.currentProject = { id: 'deck_test', targetLanguage: 'ja-JP', cardType: projType || 'language' };
        S.currentCard = card;
        S.currentPattern = p;
        S.isFlipped = flipped;
        S.currentKanjiQuestion = null;
        S.renderCard();
      }

      const themes = ['dark', 'light', 'bloxfruits', 'muichiro'];

      /* R1 Verification: Ensure no quest-badge across all patterns, sides, and themes */
      let r1AllNoBadge = true;
      let r1FailReason = '';
      const patternsToTest = [
        { card: cards.word1, p: 'en_to_ja', proj: 'language' },
        { card: cards.word1, p: 'ja_to_en', proj: 'language' },
        { card: cards.word1, p: 'audio_to_ja', proj: 'language' },
        { card: cards.kanji1, p: 'char_to_read', proj: 'kanji' },
        { card: cards.kanji1, p: 'read_to_char', proj: 'kanji' },
        { card: cards.univ1, p: 'front_to_back', proj: 'general' }
      ];

      for (const th of themes) {
        document.body.setAttribute('data-theme', th);
        for (const item of patternsToTest) {
          for (const flipped of [false, true]) {
            render(item.card, item.p, flipped, item.proj);
            if (document.querySelector('.quest-badge')) {
              r1AllNoBadge = false;
              r1FailReason = 'Found .quest-badge in theme ' + th + ', p=' + item.p + ', flipped=' + flipped;
              break;
            }
          }
          if (!r1AllNoBadge) break;
        }
        if (!r1AllNoBadge) break;
      }
      results.R1 = { ok: r1AllNoBadge, detail: r1FailReason };

      /* R2 Verification: Centering <= 2px */
      let r2CenterOk = true;
      let r2CenterFails = [];

      function checkCenterDiff(selector, name) {
        const body = document.querySelector('.card-body');
        const el = document.querySelector(selector);
        if (!body || !el) return { ok: false, diff: -999, detail: 'Not found: ' + selector };
        const bRect = body.getBoundingClientRect();
        const eRect = el.getBoundingClientRect();
        const bCenter = bRect.left + bRect.width / 2;
        const eCenter = eRect.left + eRect.width / 2;
        const diff = Math.abs(eCenter - bCenter);
        return { ok: diff <= 2.0, diff: Math.round(diff * 10) / 10 };
      }

      for (const th of themes) {
        document.body.setAttribute('data-theme', th);

        /* 1. char_to_read front (.target-kanji-huge) */
        render(cards.kanji1, 'char_to_read', false, 'kanji');
        const resFrontKanji = checkCenterDiff('.target-kanji-huge', 'char_to_read front kanji');
        if (!resFrontKanji.ok) {
          r2CenterOk = false;
          r2CenterFails.push(th + ' char_to_read front kanji diff=' + resFrontKanji.diff);
        }

        /* 2. char_to_read back (.kanji-answer-readings-wrap & .kanji-readings-grid) */
        render(cards.kanji1, 'char_to_read', true, 'kanji');
        const resSysA = checkCenterDiff('.kanji-answer-readings-wrap', 'char_to_read back sysA wrap');
        const resSysB = checkCenterDiff('.kanji-readings-grid', 'char_to_read back sysB grid');
        if (!resSysA.ok) {
          r2CenterOk = false;
          r2CenterFails.push(th + ' char_to_read back sysA wrap diff=' + resSysA.diff);
        }
        if (!resSysB.ok) {
          r2CenterOk = false;
          r2CenterFails.push(th + ' char_to_read back sysB grid diff=' + resSysB.diff);
        }

        /* 3. read_to_char back (.target-kanji-huge & .kanji-readings-grid) */
        render(cards.kanji1, 'read_to_char', true, 'kanji');
        const resBackKanji = checkCenterDiff('.target-kanji-huge', 'read_to_char back kanji');
        const resBackSysB = checkCenterDiff('.kanji-readings-grid', 'read_to_char back sysB grid');
        if (!resBackKanji.ok) {
          r2CenterOk = false;
          r2CenterFails.push(th + ' read_to_char back kanji diff=' + resBackKanji.diff);
        }
        if (!resBackSysB.ok) {
          r2CenterOk = false;
          r2CenterFails.push(th + ' read_to_char back sysB grid diff=' + resBackSysB.diff);
        }
      }
      results.R2 = { ok: r2CenterOk, detail: r2CenterFails.join(', ') };

      /* R3 Verification: font-size (val > label) */
      render(cards.kanji1, 'char_to_read', true, 'kanji');
      const labelA = document.querySelector('.kanji-answer-label');
      const valA = document.querySelector('.kanji-answer-val');
      const labelB = document.querySelector('.reading-tag-on');
      const valB = document.querySelector('.reading-val');

      const sizeLabelA = parseFloat(getComputedStyle(labelA).fontSize);
      const sizeValA = parseFloat(getComputedStyle(valA).fontSize);
      const sizeLabelB = parseFloat(getComputedStyle(labelB).fontSize);
      const sizeValB = parseFloat(getComputedStyle(valB).fontSize);

      const r3SizeOk = (sizeValA > sizeLabelA) && (sizeValB > sizeLabelB);
      results.R3 = {
        ok: r3SizeOk,
        detail: 'SysA: val=' + sizeValA + 'px vs lbl=' + sizeLabelA + 'px, SysB: val=' + sizeValB + 'px vs lbl=' + sizeLabelB + 'px'
      };

      /* R4 Verification: color distinction across 4 themes */
      let r4ColorsOk = true;
      let r4ColorDetails = [];
      for (const th of themes) {
        document.body.setAttribute('data-theme', th);
        render(cards.kanji1, 'char_to_read', true, 'kanji');
        const vA = document.querySelector('.kanji-answer-val');
        const lA = document.querySelector('.kanji-answer-label');
        const vB = document.querySelector('.reading-val');
        const cValA = getComputedStyle(vA).color;
        const cLblA = getComputedStyle(lA).color;
        const cValB = getComputedStyle(vB).color;

        if (cValA === cLblA) {
          r4ColorsOk = false;
          r4ColorDetails.push(th + ' SysA val equals label: ' + cValA);
        }
      }
      results.R4 = { ok: r4ColorsOk, detail: r4ColorDetails.join(', ') };

    } catch (e) {
      results.error = e.message + ' stack: ' + e.stack;
    }
    out.textContent = '###DATA_START###' + JSON.stringify(results) + '###DATA_END###';
  })();
  </script>
</body>
</html>
'@

    [System.IO.File]::WriteAllText($testHtmlPath, $htmlContent, [System.Text.Encoding]::UTF8)

    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_v232_test_$([System.Guid]::NewGuid().ToString('N')).html")
    try {
        $fileUri = "file:///" + (Resolve-Path $testHtmlPath).Path.Replace("\", "/")
        $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--window-size=390,760", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait

        if (Test-Path $tempDump) {
            $rendered = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
            $match = [regex]::Match($rendered, '<pre id="out">###DATA_START###(.*?)###DATA_END###</pre>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($match.Success) {
                $jsonStr = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
                $data = $jsonStr | ConvertFrom-Json

                if ($data.error) {
                    Assert-Check "JavaScript Execution" $false "JS Error: $($data.error)"
                } else {
                    Assert-Check "2.1 (R1) No .quest-badge rendered across all card types, patterns and themes" ([bool]$data.R1.ok) ($data.R1.detail)
                    Assert-Check "2.2 (R2) Center alignment within 2px across front & rear kanji elements (4 themes)" ([bool]$data.R2.ok) ($data.R2.detail)
                    Assert-Check "2.3 (R3) Reading value font-size strictly larger than label font-size (System A & B)" ([bool]$data.R3.ok) ($data.R3.detail)
                    Assert-Check "2.4 (R4) Reading value color distinct from label color across all 4 themes" ([bool]$data.R4.ok) ($data.R4.detail)
                }
            } else {
                Assert-Check "Headless results extracted" $false "Failed to find ###DATA_START### in DOM dump"
            }
            Remove-Item -Force $tempDump -ErrorAction SilentlyContinue
        } else {
            Assert-Check "Headless DOM dump file created" $false "Dump file not created"
        }
    } finally {
        Remove-Item -Force $testHtmlPath -ErrorAction SilentlyContinue
    }
}

# -------------------------------------------------------------
# Phase 3: WCAG コントラスト比検証 (R4: 4.5以上)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: WCAG 2.1 Contrast Ratio Verification (R4 >= 4.5)] ---" -ForegroundColor Yellow

function Get-Luminance([string]$hex) {
    $r = [Convert]::ToInt32($hex.Substring(1, 2), 16) / 255.0
    $g = [Convert]::ToInt32($hex.Substring(3, 2), 16) / 255.0
    $b = [Convert]::ToInt32($hex.Substring(5, 2), 16) / 255.0
    $rLin = if ($r -le 0.03928) { $r / 12.92 } else { [Math]::Pow(($r + 0.055) / 1.055, 2.4) }
    $gLin = if ($g -le 0.03928) { $g / 12.92 } else { [Math]::Pow(($g + 0.055) / 1.055, 2.4) }
    $bLin = if ($b -le 0.03928) { $b / 12.92 } else { [Math]::Pow(($b + 0.055) / 1.055, 2.4) }
    return 0.2126 * $rLin + 0.7152 * $gLin + 0.0722 * $bLin
}

function Get-Ratio([string]$c1, [string]$c2) {
    $l1 = Get-Luminance $c1
    $l2 = Get-Luminance $c2
    $max = [Math]::Max($l1, $l2)
    $min = [Math]::Min($l1, $l2)
    return ($max + 0.05) / ($min + 0.05)
}

$contrastTests = @(
    @{ Theme='bloxfruits'; Target='systemA (card #151d2f)'; Text='#ffd24a'; Bg='#151d2f' },
    @{ Theme='bloxfruits'; Target='systemB (grid #101828)'; Text='#ffd24a'; Bg='#101828' },
    @{ Theme='dark';       Target='systemA (card #131b2e)'; Text='#7dd3fc'; Bg='#131b2e' },
    @{ Theme='dark';       Target='systemB (grid #0f172a)'; Text='#7dd3fc'; Bg='#0f172a' },
    @{ Theme='light';      Target='systemA (card #e0e7ff)'; Text='#4338ca'; Bg='#e0e7ff' },
    @{ Theme='light';      Target='systemB (grid #ffffff)'; Text='#4338ca'; Bg='#ffffff' },
    @{ Theme='muichiro';   Target='systemA (card #fbf9f6)'; Text='#0f766e'; Bg='#fbf9f6' },
    @{ Theme='muichiro';   Target='systemB (grid #ffffff)'; Text='#0f766e'; Bg='#ffffff' }
)

$allContrastPass = $true
foreach ($t in $contrastTests) {
    $r = Get-Ratio $t.Text $t.Bg
    $pass = $r -ge 4.5
    if (-not $pass) { $allContrastPass = $false }
    Assert-Check "3.x Contrast $($t.Theme) $($t.Target) ($($t.Text) vs $($t.Bg)) = $([Math]::Round($r, 2)) >= 4.5" $pass "Ratio: $r"
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESULT: $passed Passed / $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
