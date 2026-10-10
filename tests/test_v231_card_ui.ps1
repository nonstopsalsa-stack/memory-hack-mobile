# test_v231_card_ui.ps1
# MEMORY HACK Mobile: v2.3.1 Card UI Micro-Adjustments & Alignment Test
# T1-T10 Automated Verification via Headless Chrome

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
Write-Host " MEMORY HACK Mobile v2.3.1: Card UI Micro-Adjustments Test (T1 - T10)      " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$mobileDir = if (Test-Path (Join-Path $PSScriptRoot "..\css\mobile.css")) { (Resolve-Path "$PSScriptRoot\..").Path } else { (Resolve-Path ".").Path }
$cssPath = Join-Path $mobileDir "css\mobile.css"
$studyPath = Join-Path $mobileDir "js\study.js"
$configPath = Join-Path $mobileDir "js\config.js"

$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$config = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# Phase 1: 静的コード構造 & ヘルパーメソッド検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Code Structure & Helpers in study.js] ---" -ForegroundColor Yellow

$hasIsSentenceCard = $study.Contains("isSentenceCard(card)")
Assert-Check "1.1 StudyManager defines isSentenceCard" ($hasIsSentenceCard)

$hasGetAlignClass = $study.Contains("getAlignClass(card, displayText)")
Assert-Check "1.2 StudyManager defines getAlignClass" ($hasGetAlignClass)

$hasGetGuideLangName = $study.Contains("getGuideLangName(card)")
Assert-Check "1.3 StudyManager defines getGuideLangName" ($hasGetGuideLangName)

$hasBuildGuideHtml = $study.Contains("buildGuideHtml(label)")
Assert-Check "1.4 StudyManager defines buildGuideHtml" ($hasBuildGuideHtml)

$hasBuildSpeakerRow = $study.Contains("buildSpeakerRow(align)")
Assert-Check "1.5 StudyManager defines buildSpeakerRow" ($hasBuildSpeakerRow)

$cssDefinesAlignLeft = $css.Contains(".card-prompt-text.align-left") -and $css.Contains(".card-answer-main.align-left")
Assert-Check "1.6 mobile.css defines .align-left override rules" ($cssDefinesAlignLeft)

$cssDefinesAlignCenter = $css.Contains(".card-prompt-text.align-center") -and $css.Contains(".card-answer-main.align-center")
Assert-Check "1.7 mobile.css defines .align-center override rules" ($cssDefinesAlignCenter)

$cssDefinesSpeakerRow = $css.Contains(".speaker-row")
Assert-Check "1.8 mobile.css defines .speaker-row rules" ($cssDefinesSpeakerRow)

# -------------------------------------------------------------
# Phase 2: ヘッドレスブラウザによる T1〜T9 レンダリング・座標実測検証
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: Headless Chrome T1 - T9 Real DOM Measurements] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if (-not $browserExe) {
    Write-Host " [SKIP] No Chrome or Edge found for headless verification" -ForegroundColor DarkGray
} else {
    $testHtmlPath = Join-Path $mobileDir "tests\temp_v231_ui_test.html"

    # Single-quote heredoc @' ... '@ prevents PowerShell variable expansion in JS code!
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
  (function() {
    const out = document.getElementById('out');
    const results = {};
    try {
      const S = window.StudyManager;
      S.renderPatternSelector = function() {};
      S.updateBottomActionButtons = function() {};
      S.currentProject = { id: 'deck_default', targetLanguage: 'en-US', cardType: 'language' };
      S.queue = [1, 2, 3];
      S.currentIndex = 1;

      const cards = {
        word1: { id: 'w1', front: 'apple', back: 'りんご', itemType: 'word' },
        phrase1: { id: 'p1', front: 'participate in', back: '参加する', itemType: 'phrase' },
        sent1: { id: 's1', front: 'May the force be with you.', back: 'フォースと共にあらんことを。', itemType: 'sentence' },
        sent2: { id: 's2', front: 'The quick brown fox jumps over the lazy dog and runs away into the forest.', back: '素早い茶色のキツネが怠惰な犬を飛び越えて森へと走り去ります。' },
        sent3: { id: 's3', front: 'Knowledge is power, but enthusiasm pulls the switch. When you have a dream that you cannot let go of, trust your instincts and pursue it.', back: '知識は力ですが、熱意がスイッチを入れます。手放せない夢があるなら、直感を信じてそれを追い求めてください。' },
        kanji1: { id: 'k1', front: '日', back: 'ひ、にち', itemType: 'kanji', onYomi: 'ニチ', kunYomi: 'ひ' },
        univ1: { id: 'u1', front: '日本の首都は？', back: '東京', itemType: 'general' }
      };

      const patterns = ['en_to_ja', 'ja_to_en', 'audio_to_ja', 'audio_to_en', 'ja_to_audio', 'en_to_audio'];

      function render(card, p, flipped) {
        S.currentCard = card;
        S.currentPattern = p;
        S.isFlipped = flipped;
        S.renderCard();
      }

      function textNodesOf(el) {
        const w = document.createTreeWalker(el, NodeFilter.SHOW_TEXT, {
          acceptNode(n) {
            if (!n.nodeValue.trim()) return NodeFilter.FILTER_REJECT;
            if (n.parentElement.closest('button')) return NodeFilter.FILTER_REJECT;
            return NodeFilter.FILTER_ACCEPT;
          }
        });
        const arr = [];
        let n;
        while ((n = w.nextNode())) arr.push(n);
        return arr;
      }

      function leadWs(el) {
        const t = textNodesOf(el)[0];
        if (!t) return 0;
        const m = t.nodeValue.match(/^\s*/)[0];
        return m.length;
      }

      function getLines(el, base) {
        const byTop = {};
        textNodesOf(el).forEach(t => {
          const v = t.nodeValue;
          for (let i = 0; i < v.length; i++) {
            if (/\s/.test(v[i])) continue;
            const r = document.createRange();
            r.setStart(t, i);
            r.setEnd(t, i + 1);
            const x = r.getBoundingClientRect();
            if (!x.width) continue;
            const k = Math.round(x.top / 6);
            const o = (byTop[k] = byTop[k] || { l: 1e9, r: -1e9 });
            o.l = Math.min(o.l, x.left);
            o.r = Math.max(o.r, x.right);
          }
        });
        return Object.keys(byTop).sort((a, b) => a - b).map(k => ({
          l: Math.round(byTop[k].l - base.left),
          r: Math.round(base.right - byTop[k].r)
        }));
      }

      // T1: 全パターン×表裏で先頭空白なし
      let t1Ok = true;
      let t1Fail = '';
      for (let p of patterns) {
        for (let flipped of [false, true]) {
          render(cards.sent1, p, flipped);
          const txt = document.querySelector('.card-prompt-text, .card-answer-main');
          if (txt && leadWs(txt) > 0) {
            t1Ok = false;
            t1Fail = 'Pattern ' + p + ', flipped=' + flipped + ' has leadWs=' + leadWs(txt);
            break;
          }
        }
        if (!t1Ok) break;
      }
      results.T1 = { ok: t1Ok, detail: t1Fail };

      // T2: 文章カード（3種）全行の左端一致 (±3.5px)
      let t2Ok = true;
      let t2Fail = '';
      const testSentences = [cards.sent1, cards.sent2, cards.sent3];
      for (let sc of testSentences) {
        // 表面 (en_to_ja, ja_to_en, ja_to_audio, en_to_audio)
        for (let p of ['en_to_ja', 'ja_to_en', 'ja_to_audio', 'en_to_audio']) {
          render(sc, p, false);
          const body = document.querySelector('.card-body');
          const txt = body.querySelector('.card-prompt-text');
          if (txt) {
            const lns = getLines(txt, body.getBoundingClientRect());
            if (lns.length > 1) {
              const minL = Math.min(...lns.map(x => x.l));
              const maxL = Math.max(...lns.map(x => x.l));
              if (maxL - minL > 3.5) {
                t2Ok = false;
                t2Fail = 'Front sent ' + sc.id + ' ' + p + ' left diff=' + (maxL - minL) + ' lines=' + JSON.stringify(lns);
                break;
              }
            }
          }
        }
        if (!t2Ok) break;

        // 裏面 (全6パターン)
        for (let p of patterns) {
          render(sc, p, true);
          const body = document.querySelector('.card-body');
          const txt = body.querySelector('.card-answer-main');
          if (txt) {
            const lns = getLines(txt, body.getBoundingClientRect());
            if (lns.length > 1) {
              const minL = Math.min(...lns.map(x => x.l));
              const maxL = Math.max(...lns.map(x => x.l));
              if (maxL - minL > 3.5) {
                t2Ok = false;
                t2Fail = 'Rear sent ' + sc.id + ' ' + p + ' left diff=' + (maxL - minL) + ' lines=' + JSON.stringify(lns);
                break;
              }
            }
          }
        }
        if (!t2Ok) break;
      }
      results.T2 = { ok: t2Ok, detail: t2Fail };

      // T3: 単語カード 各行の中央寄せ (apple)
      render(cards.word1, 'en_to_ja', false);
      const wf = document.querySelector('.card-prompt-text');
      const wfAlign = getComputedStyle(wf).textAlign;
      render(cards.word1, 'en_to_ja', true);
      const wb = document.querySelector('.card-answer-main');
      const wbAlign = getComputedStyle(wb).textAlign;
      results.T3 = {
        ok: (wfAlign === 'center' && wbAlign === 'center'),
        detail: 'front=' + wfAlign + ', back=' + wbAlign
      };

      // T4: 英→日表面 (May the force be with you.) でスクロール不要 & ガイド可視 (390x640)
      document.body.style.height = '640px';
      render(cards.sent1, 'en_to_ja', false);
      const bodyEl = document.querySelector('.card-body');
      const guideEl = document.querySelector('.card-target-guide');
      const bodyScrolls = bodyEl ? (bodyEl.scrollHeight <= bodyEl.clientHeight + 2) : false;
      const guideVis = (guideEl && bodyEl) ? (guideEl.getBoundingClientRect().bottom <= bodyEl.getBoundingClientRect().bottom + 5) : false;
      results.T4 = {
        ok: (bodyScrolls && guideVis),
        detail: 'scrollHeight=' + (bodyEl ? bodyEl.scrollHeight : 0) + ' clientHeight=' + (bodyEl ? bodyEl.clientHeight : 0) + ' guideVis=' + guideVis
      };
      document.body.style.height = '760px';

      // T5: ガイド文言
      const expectedGuides = {
        'en_to_ja': '🇯🇵 日本語訳',
        'ja_to_en': '英語で発音/作文を',
        'audio_to_ja': '🇯🇵 日本語訳',
        'audio_to_en': '英語で',
        'ja_to_audio': '英語で発音',
        'en_to_audio': '英語で発音'
      };
      let t5Ok = true;
      let t5Fail = '';
      for (let p in expectedGuides) {
        render(cards.word1, p, false);
        const gBox = document.querySelector('.card-target-box');
        if (!gBox || !gBox.textContent.includes(expectedGuides[p])) {
          t5Ok = false;
          t5Fail = p + ' guide expected "' + expectedGuides[p] + '", got "' + (gBox ? gBox.textContent : 'none') + '"';
          break;
        }
        if (p.startsWith('audio_')) {
          const audioBox = document.querySelector('.audio-prompt-box');
          const guide = document.querySelector('.card-target-guide');
          if (audioBox && guide && guide.getBoundingClientRect().top < audioBox.getBoundingClientRect().bottom - 2) {
            t5Ok = false;
            t5Fail = 'Guide is not below audio box in ' + p;
            break;
          }
        }
      }
      results.T5 = { ok: t5Ok, detail: t5Fail };

      // T6: 裏面発音ボタンは🔊のみ
      let t6Ok = true;
      let t6Fail = '';
      for (let p of patterns) {
        render(cards.word1, p, true);
        const btn = document.querySelector('.card-answer-block .speaker-btn');
        if (btn) {
          const text = btn.textContent.trim();
          if (text !== '🔊') {
            t6Ok = false;
            t6Fail = 'Pattern ' + p + ' rear speaker button text is "' + text + '"';
            break;
          }
        }
      }
      results.T6 = { ok: t6Ok, detail: t6Fail };

      // T7: 日→音・英→音の裏面は英文メイン＋日本語サブ
      let t7Ok = true;
      let t7Fail = '';
      for (let p of ['ja_to_audio', 'en_to_audio']) {
        render(cards.sent1, p, true);
        const main = document.querySelector('.card-answer-main');
        const sub = document.querySelector('.card-answer-sub');
        const btn = document.querySelector('.speaker-btn');
        if (!main || !main.textContent.includes(cards.sent1.front)) {
          t7Ok = false;
          t7Fail = p + ' rear main missing front English: ' + (main ? main.textContent : 'null');
          break;
        }
        if (!sub || !sub.textContent.includes(cards.sent1.back)) {
          t7Ok = false;
          t7Fail = p + ' rear sub missing back Japanese: ' + (sub ? sub.textContent : 'null');
          break;
        }
        if (!btn) {
          t7Ok = false;
          t7Fail = p + ' rear missing speaker button';
          break;
        }
      }
      results.T7 = { ok: t7Ok, detail: t7Fail };

      // T8: 4テーマ (dark, light, bloxfruits, muichiro) での text-align
      let t8Ok = true;
      let t8Fail = '';
      const themes = ['dark', 'light', 'bloxfruits', 'muichiro'];
      for (let th of themes) {
        document.body.setAttribute('data-theme', th);
        render(cards.sent1, 'en_to_ja', false);
        const sTa = getComputedStyle(document.querySelector('.card-prompt-text')).textAlign;
        render(cards.word1, 'en_to_ja', false);
        const wTa = getComputedStyle(document.querySelector('.card-prompt-text')).textAlign;
        if (sTa !== 'left' || wTa !== 'center') {
          t8Ok = false;
          t8Fail = 'Theme ' + th + ': sent align=' + sTa + ' word align=' + wTa;
          break;
        }
      }
      document.body.setAttribute('data-theme', 'dark');
      results.T8 = { ok: t8Ok, detail: t8Fail };

      // T9: 汎用・漢字の非回帰
      let t9Ok = true;
      let t9Fail = '';
      try {
        S.currentProject = { id: 'deck_kanji', targetLanguage: 'ja-JP', cardType: 'kanji' };
        render(cards.kanji1, 'read_to_char', false);
        if (!document.querySelector('.card-prompt-target')) {
          t9Ok = false;
          t9Fail = 'Kanji front missing prompt target';
        }
        render(cards.kanji1, 'read_to_char', true);
        if (!document.querySelector('.card-answer-main')) {
          t9Ok = false;
          t9Fail = 'Kanji rear missing answer main';
        }

        S.currentProject = { id: 'deck_univ', targetLanguage: 'ja-JP', cardType: 'general' };
        render(cards.univ1, 'front_to_back', false);
        if (!document.querySelector('.card-prompt-text')) {
          t9Ok = false;
          t9Fail = 'General front missing prompt text';
        }
        render(cards.univ1, 'front_to_back', true);
        if (!document.querySelector('.card-answer-main')) {
          t9Ok = false;
          t9Fail = 'General rear missing answer main';
        }
      } catch (e) {
        t9Ok = false;
        t9Fail = 'Exception during non-regression: ' + e.message;
      }
      results.T9 = { ok: t9Ok, detail: t9Fail };

    } catch (err) {
      results.error = err.message + ' stack: ' + err.stack;
    }

    out.textContent = '###DATA_START###' + JSON.stringify(results) + '###DATA_END###';
  })();
  </script>
</body>
</html>
'@
    [System.IO.File]::WriteAllText($testHtmlPath, $htmlContent, [System.Text.Encoding]::UTF8)

    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_v231_ui_$([System.Guid]::NewGuid().ToString('N')).html")
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
                    Assert-Check "T1: No leading whitespace across all patterns (front/rear)" ([bool]$data.T1.ok) ($data.T1.detail)
                    Assert-Check "T2: Sentence cards left edges aligned across all lines" ([bool]$data.T2.ok) ($data.T2.detail)
                    Assert-Check "T3: Word cards centered properly" ([bool]$data.T3.ok) ($data.T3.detail)
                    Assert-Check "T4: En->Ja front sentence has no overflow and guide is visible (390x640)" ([bool]$data.T4.ok) ($data.T4.detail)
                    Assert-Check "T5: Surface guides text correct across 6 patterns and below audio box" ([bool]$data.T5.ok) ($data.T5.detail)
                    Assert-Check "T6: Rear speaker button text is icon-only (speaker icon)" ([bool]$data.T6.ok) ($data.T6.detail)
                    Assert-Check "T7: Ja->Audio and En->Audio rear display English main + Japanese sub" ([bool]$data.T7.ok) ($data.T7.detail)
                    Assert-Check "T8: 4 visual themes (dark, light, bloxfruits, muichiro) text-align correct" ([bool]$data.T8.ok) ($data.T8.detail)
                    Assert-Check "T9: Non-regression for General flashcards & Kanji cards" ([bool]$data.T9.ok) ($data.T9.detail)
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
# Phase 3: T10 既存テストのベースライン一致確認
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: T10 Baseline Tests Consistency Verification] ---" -ForegroundColor Yellow

# Baseline PASS tests: run_test_auto_player_mobile.ps1, test_muichiro_theme_refresh.ps1, test_theme_switch_browser.ps1, test_v227_muichiro_visibility_and_scroll.ps1
$baselinePassTests = @(
    "run_test_auto_player_mobile.ps1",
    "test_muichiro_theme_refresh.ps1",
    "test_theme_switch_browser.ps1",
    "test_v227_muichiro_visibility_and_scroll.ps1"
)

foreach ($testFile in $baselinePassTests) {
    $fullPath = Join-Path $PSScriptRoot $testFile
    if (Test-Path $fullPath) {
        $out = & powershell -ExecutionPolicy Bypass -File $fullPath 2>&1
        $exitCode = $LASTEXITCODE
        Assert-Check "T10: Baseline test $testFile passes (ExitCode=0)" ($exitCode -eq 0) "ExitCode=$exitCode"
    }
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESULT: $passed Passed / $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
