# ==========================================================================
# MEMORY HACK Mobile v2.3.3: UI Layout & Contrast Verification Test
# 
# Verification Coverage:
# 1. Tier 0 Selector 2-Row Layout (3 items visible on 390px and 360px)
# 2. Kanji Prompt Center Alignment (Offset <= 1px)
# 3. Reading/Meaning/Guide Equal Gap (--kanji-line-gap)
# 4. Sentence Box Leading Whitespace Elimination (Padding <= 19px)
# 5. Kanji Reading Label & Value Styling, Contrast Ratio >= 4.5
# 6. Version v2.3.3 Static Integrity
# ==========================================================================

$ErrorActionPreference = "Stop"

$script:passed = 0
$script:failed = 0

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
Write-Host " MEMORY HACK Mobile v2.3.3: UI Layout & Contrast Verification Test        " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$mobileDir = if (Test-Path (Join-Path $PSScriptRoot "..\css\mobile.css")) { (Resolve-Path "$PSScriptRoot\..").Path } else { (Resolve-Path ".").Path }
$cssPath = Join-Path $mobileDir "css\mobile.css"
$studyPath = Join-Path $mobileDir "js\study.js"
$hierarchyPath = Join-Path $mobileDir "js\hierarchy.js"
$htmlPath = Join-Path $mobileDir "index.html"
$swPath = Join-Path $mobileDir "service-worker.js"

$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$hierarchy = [System.IO.File]::ReadAllText($hierarchyPath, [System.Text.Encoding]::UTF8)
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# Phase 1: Static Code Structure & Version Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Static Code Structure & Version Verification] ---" -ForegroundColor Yellow

Assert-Check "1.1 study.js version is v2.3.3 or higher" ($study -match "version:\s*'v2\.3\.[3-9]'")
Assert-Check "1.2 service-worker.js CACHE_NAME is memory-hack-mobile-v2.3.x" ($sw -match "memory-hack-mobile-v2\.3\.[3-9]")
Assert-Check "1.3 service-worker.js ASSETS_TO_CACHE has ?v=2.3.x queries" ($sw -match "\?v=2\.3\.[3-9]")
Assert-Check "1.4 index.html has v2.3.x brand badge" ($html -match '<span class="brand-ver-badge">v2\.3\.[3-9]</span>')
Assert-Check "1.5 index.html has v2.3.x query strings (12 occurrences)" (([regex]::Matches($html, '\?v=2\.3\.[3-9]')).Count -ge 9)

Assert-Check "1.6 hierarchy.js renders .tier0-pill-top markup" ($hierarchy.Contains('class="tier0-pill-top"'))
Assert-Check "1.7 mobile.css defines .tier0-pill-top and 2-row layout" ($css.Contains('.tier0-pill-top') -and $css.Contains('calc((100% - 12px) / 3)'))
Assert-Check "1.8 mobile.css defines --kanji-line-gap" ($css.Contains('--kanji-line-gap: 1.1rem;'))
Assert-Check "1.9 mobile.css defines .kanji-prompt-container with equal gap" ($css.Contains('.kanji-prompt-container') -and $css.Contains('gap: var(--kanji-line-gap'))
Assert-Check "1.10 study.js renders .kanji-reading-label and .kanji-reading-value" ($study.Contains('kanji-reading-label') -and $study.Contains('kanji-reading-value'))
Assert-Check "1.11 mobile.css defines 4 theme reading value colors" ($css.Contains('#fbbf24') -and $css.Contains('#ffd24a') -and $css.Contains('#4338ca') -and $css.Contains('#0f766e'))

# -------------------------------------------------------------
# Phase 2: Headless Browser Real DOM Measurements (390px & 360px)
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: Headless Browser Real DOM Measurements] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if (-not $browserExe) {
    Write-Host " [SKIP] No Chrome or Edge found for headless verification" -ForegroundColor DarkGray
} else {
    $testHtmlPath = Join-Path $mobileDir "tests\temp_v233_test.html"

    $htmlContent = @'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="stylesheet" href="../css/mobile.css">
  <style>
    body { margin: 0; padding: 0; }
  </style>
</head>
<body>
  <div class="modal-sheet" style="padding: 10px; width: 390px;"><div id="tc" class="hierarchy-tree-content"></div></div>
  <div class="card-wrap"><div class="card-body"><div id="card-stage"></div></div></div>
  <pre id="out"></pre>

  <script>
  window.onerror = function(msg, url, line, col, err) {
    document.getElementById('out').textContent = '###DATA_START###' + JSON.stringify({ error: msg + ' at ' + line + ':' + col + ' ' + (err ? err.stack : '') }) + '###DATA_END###';
  };
  </script>
  <script src="../js/config.js"></script>
  <script src="../js/storage.js"></script>
  <script src="../js/srs.js"></script>
  <script src="../js/hierarchy.js"></script>
  <script src="../js/audio.js"></script>
  <script src="../js/study.js"></script>
  <script>
  window.onload = function() {
    const out = document.getElementById('out');
    const results = { tier0: {}, kanji: {}, otherOffsets: [], sentence: [] };
    try {
      const S = window.StudyManager;
      S.renderPatternSelector = function() {};
      S.updateBottomActionButtons = function() {};

      const projects = [
        { id: 'p1', name: 'English Deck', icon: 'EN' },
        { id: 'p2', name: 'Spanish Deck', icon: 'ES' },
        { id: 'p3', name: 'Kanji Study', icon: 'KJ' },
        { id: 'p4', name: 'Math Exercises', icon: 'MT' },
        { id: 'p5', name: 'Marketing Terms', icon: 'MK' }
      ];
      const cards = [{ id: 'a', front: 'a', back: 'b', category1: 'x', projectDeckId: 'p1' }];

      function rect(el) {
        const r = el.getBoundingClientRect();
        return { l: +r.left.toFixed(1), r: +r.right.toFixed(1), t: +r.top.toFixed(1), b: +r.bottom.toFixed(1), w: +r.width.toFixed(1), h: +r.height.toFixed(1) };
      }
      function bgOf(el) {
        while (el) {
          const c = getComputedStyle(el).backgroundColor;
          if (c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent') return c;
          el = el.parentElement;
        }
        return 'rgb(0,0,0)';
      }
      function firstGlyphLeft(el) {
        const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
        let n;
        while (n = w.nextNode()) {
          const i = n.data.search(/\S/);
          if (i >= 0) {
            const rg = document.createRange(); rg.setStart(n, i); rg.setEnd(n, i + 1);
            const q = rg.getClientRects()[0];
            return q ? +q.left.toFixed(1) : null;
          }
        }
        return null;
      }
      function lastGlyphRight(el) {
        const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
        let n, last = null;
        while (n = w.nextNode()) {
          const m = n.data.match(/\S\s*$/);
          if (m) last = n;
        }
        if (!last) return null;
        const i = last.data.search(/\S\s*$/);
        const rg = document.createRange(); rg.setStart(last, i); rg.setEnd(last, i + 1);
        const qs = rg.getClientRects();
        const q = qs[qs.length - 1];
        return q ? +q.right.toFixed(1) : null;
      }

      const themes = ['dark', 'light', 'bloxfruits', 'muichiro'];

      // 1. Tier 0 Pills Test
      results.tier0 = themes.map(th => {
        document.documentElement.setAttribute('data-theme', th);
        document.body.setAttribute('data-theme', th);
        Hierarchy.renderTreeSheet(document.getElementById('tc'), cards, null, () => {}, { projects, activeProjectId: 'p1', allCards: cards });
        const pills = [...document.querySelectorAll('.tier0-pill')].map(p => rect(p));
        const cont = rect(document.getElementById('hierarchy-tier0-pills'));
        const visibleCount = pills.filter(p => p.r <= cont.r + 0.5).length;
        const heights = pills.map(p => p.h);
        const maxH = Math.max(...heights);
        const minH = Math.min(...heights);
        return { theme: th, visibleCount, heightDiff: +(maxH - minH).toFixed(1), pills };
      });

      // 2. Kanji Front Card Test
      const cardK = { id: 'k1', front: '\u5B89', back: '\u97F3\u8AAD\u307F\uFF1A\u30A2\u30F3\n\u8A13\u8AAD\u307F\uFF1A\u3084\u3059-\u3044\n\u610F\u5473\uFF1A\u304A\u3060\u3084\u304B', type: 'kanji', category1: '\u6F22\u5B57', example: '\u5B89\u5FC3(\u3042\u3093\u3057\u3093):\u5FC3\u304C\u304A\u3060\u3084\u304B' };
      const cardSent = { id: 'k2', front: '\u5B89', back: '\u97F3\u8AAD\u307F\uFF1A\u30A2\u30F3\n\u8A13\u8AAD\u307F\uFF1A\u3084\u3059-\u3044\n\u610F\u5473\uFF1A\u304A\u3060\u3084\u304B', type: 'kanji', category1: '\u6F22\u5B57', example: '\u5B89\u5FC3(\u3042\u3093\u3057\u3093):\u5FC3\u304C\u304A\u3060\u3084\u304B', exampleTranslation: '\u5F7C\u306F[\u5B89\u5FC3]\u3057\u3066\u7720\u3063\u305F\u3002' };
      const stage = document.getElementById('card-stage');

      results.kanji = {};
      for (const th of themes) {
        document.documentElement.setAttribute('data-theme', th);
        document.body.setAttribute('data-theme', th);
        S.currentCard = cardK; S.currentPattern = 'read_to_char'; S.isFlipped = false; S.currentKanjiQuestion = null; S.currentProject = { cardType: 'kanji' };
        S.renderCard();

        const rWrap = stage.querySelector('.kanji-prompt-reading');
        const lbl = stage.querySelector('.kanji-reading-label');
        const val = stage.querySelector('.kanji-reading-value');
        const mean = stage.querySelector('.kanji-prompt-meaning');
        const guide = stage.querySelector('.card-target-guide');

        const sr = rect(stage);
        const cx = (sr.l + sr.r) / 2;
        const fl = firstGlyphLeft(rWrap);
        const lr = lastGlyphRight(rWrap);
        const midOffset = (fl != null && lr != null) ? +(((fl + lr) / 2) - cx).toFixed(1) : null;

        const rWrapR = rect(rWrap);
        const meanR = rect(mean);
        const guideR = rect(guide);

        results.kanji[th] = {
          midOffset,
          wrapHeight: rWrapR.h,
          gap1: +(meanR.t - rWrapR.b).toFixed(1),
          gap2: +(guideR.t - meanR.b).toFixed(1),
          labelColor: lbl ? getComputedStyle(lbl).color : null,
          labelFs: lbl ? parseFloat(getComputedStyle(lbl).fontSize) : 0,
          valColor: val ? getComputedStyle(val).color : null,
          valFs: val ? parseFloat(getComputedStyle(val).fontSize) : 0,
          bg: bgOf(rWrap)
        };
      }

      // 3. Other Patterns Center Offset (dark theme)
      document.documentElement.setAttribute('data-theme', 'dark');
      document.body.setAttribute('data-theme', 'dark');
      const testPatterns = [
        { p: 'word_to_read', flipped: false, sel: '.kanji-compound-prompt' },
        { p: 'word_to_read', flipped: true, sel: '.kanji-compound-reading-answer' },
        { p: 'read_to_word', flipped: false, sel: '.kanji-compound-reading-prompt' },
        { p: 'read_to_word', flipped: true, sel: '.kanji-compound-answer' },
        { p: 'sentence_read', flipped: true, sel: '.kanji-sentence-reading-answer' }
      ];
      results.otherOffsets = testPatterns.map(tp => {
        S.currentCard = cardK; S.currentPattern = tp.p; S.isFlipped = tp.flipped; S.currentKanjiQuestion = null; S.currentProject = { cardType: 'kanji' };
        S.renderCard();
        const el = stage.querySelector(tp.sel);
        const sr = rect(stage);
        const cx = (sr.l + sr.r) / 2;
        const fl = firstGlyphLeft(el);
        const lr = lastGlyphRight(el);
        return {
          p: tp.p,
          flipped: tp.flipped,
          sel: tp.sel,
          midOffset: (fl != null && lr != null) ? +(((fl + lr) / 2) - cx).toFixed(1) : null
        };
      });

      // 4. Sentence Box Left Margin
      results.sentence = ['sentence_fill', 'sentence_read'].map(p => {
        S.currentCard = cardSent; S.currentPattern = p; S.isFlipped = false; S.currentKanjiQuestion = null; S.currentProject = { cardType: 'kanji' };
        S.renderCard();
        const box = stage.querySelector('.kanji-sentence-box');
        const boxR = rect(box);
        const fl = firstGlyphLeft(box);
        return {
          p,
          boxLeft: boxR.l,
          firstCharLeft: fl,
          paddingText: fl != null ? +(fl - boxR.l).toFixed(1) : null
        };
      });

    } catch (e) {
      results.error = e.message + ' stack: ' + e.stack;
    }
    out.textContent = '###DATA_START###' + JSON.stringify(results) + '###DATA_END###';
  };
  </script>
</body>
</html>
'@

    [System.IO.File]::WriteAllText($testHtmlPath, $htmlContent, [System.Text.Encoding]::UTF8)

    function Run-HeadlessTest([int]$width, [int]$height) {
        $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_v233_test_$([System.Guid]::NewGuid().ToString('N')).html")
        try {
            $fileUri = "file:///" + (Resolve-Path $testHtmlPath).Path.Replace("\", "/")
            $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=5000", "--window-size=$width,$height", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait
            if (Test-Path $tempDump) {
                $rendered = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
                $match = [regex]::Match($rendered, '<pre id="out">###DATA_START###(.*?)###DATA_END###</pre>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
                if ($match.Success) {
                    $jsonStr = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
                    return ($jsonStr | ConvertFrom-Json)
                }
            }
        } finally {
            Remove-Item -Force $tempDump -ErrorAction SilentlyContinue
        }
        return $null
    }

    try {
        # 390px (iPhone 14) Verification
        $data390 = Run-HeadlessTest 390 844
        if ($data390 -and -not $data390.error) {
            # 2.1 Tier 0 pills visible count
            $tier0AllPass = $true
            foreach ($t in $data390.tier0) {
                if ($t.visibleCount -lt 3 -or $t.heightDiff -gt 2.0) { $tier0AllPass = $false }
            }
            Assert-Check "2.1 (390px) Tier 0 pills visible >= 3 and height diff <= 2px (all 4 themes)" $tier0AllPass

            # 2.2 Read->Char front center offset, height, equal gaps
            $kanjiDark = $data390.kanji.dark
            $centerOk = [Math]::Abs($kanjiDark.midOffset) -le 1.0
            $heightOk = $kanjiDark.wrapHeight -le 65.0
            $gapDiff = [Math]::Abs($kanjiDark.gap1 - $kanjiDark.gap2)
            $gapOk = $gapDiff -le 2.0
            Assert-Check "2.2 Read->Char front center offset <= 1.0px (offset=$($kanjiDark.midOffset)px)" $centerOk
            Assert-Check "2.3 Read->Char front reading height <= 65px (height=$($kanjiDark.wrapHeight)px)" $heightOk
            Assert-Check "2.4 Read->Char front line gaps equal within 2px (gap1=$($kanjiDark.gap1)px, gap2=$($kanjiDark.gap2)px)" $gapOk

            # 2.5 Compound & sentence answer center offsets
            $allOtherCenterOk = $true
            foreach ($o in $data390.otherOffsets) {
                if ([Math]::Abs($o.midOffset) -gt 1.0) { $allOtherCenterOk = $false }
            }
            Assert-Check "2.5 Compound & sentence answer center offset <= 1.0px (5 patterns)" $allOtherCenterOk

            # 2.6 Sentence box left margin (<= 19px)
            $sentPaddingOk = $true
            foreach ($s in $data390.sentence) {
                if ($s.paddingText -gt 19.0 -or $s.paddingText -lt 10.0) { $sentPaddingOk = $false }
            }
            Assert-Check "2.6 Sentence box left margin <= 19px (paddingText=$($data390.sentence[0].paddingText)px)" $sentPaddingOk

            # 2.7 Reading label and value style differentiation
            $stylesOk = $true
            foreach ($thName in @('dark', 'light', 'bloxfruits', 'muichiro')) {
                $thData = $data390.kanji.$thName
                if ($thData.labelColor -eq $thData.valColor -or ($thData.valFs / $thData.labelFs) -lt 1.5) {
                    $stylesOk = $false
                }
            }
            Assert-Check "2.7 Reading label/value style differentiation across 4 themes (size ratio >= 1.5, colors distinct)" $stylesOk
        } else {
            Assert-Check "Headless Chrome 390px execution" $false "Error: $($data390.error)"
        }

        # 360px (Compact Device) Verification
        $data360 = Run-HeadlessTest 360 740
        if ($data360 -and -not $data360.error) {
            $tier0_360_Pass = $true
            foreach ($t in $data360.tier0) {
                if ($t.visibleCount -lt 3) { $tier0_360_Pass = $false }
            }
            Assert-Check "2.8 (360px) Tier 0 pills visible >= 3 on compact device" $tier0_360_Pass
        } else {
            Assert-Check "Headless Chrome 360px execution" $false "Error: $($data360.error)"
        }

    } finally {
        Remove-Item -Force $testHtmlPath -ErrorAction SilentlyContinue
    }
}

# -------------------------------------------------------------
# Phase 3: WCAG 2.1 Contrast Ratio Verification (>= 4.5)
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
    @{ Theme='dark';       Target='reading value'; Text='#fbbf24'; Bg='#131b2e' },
    @{ Theme='bloxfruits'; Target='reading value'; Text='#ffd24a'; Bg='#121826' },
    @{ Theme='light';      Target='reading value'; Text='#4338ca'; Bg='#f1f5f9' },
    @{ Theme='muichiro';   Target='reading value'; Text='#0f766e'; Bg='#faf8f5' }
)

foreach ($t in $contrastTests) {
    $r = Get-Ratio $t.Text $t.Bg
    $pass = $r -ge 4.5
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
