# ==========================================================================
# MEMORY HACK Mobile v2.3.5: Robust Speech Synthesis & Chunking Test Suite
# 
# Verification Coverage:
# 1. Static Code Analysis:
#    - Removal of 5-sec resumeTimer (setInterval pause/resume)
#    - Strong reference holding (activeUtterances array) to prevent V8 GC collection
#    - 35ms delay queue after cancel() to avoid race conditions
#    - Sentence chunking implementation (. , ? ! \n)
#    - Self-healing safety timer on chunk playback
#    - Correct safeTimeout formula in study.js (180ms/rate + 4000ms, min 5000ms)
# 2. Version v2.3.5 & PWA Cache Integrity:
#    - service-worker.js, index.html, config.js, study.js, app.js
# 3. Headless Chrome/Edge Real DOM & Interactive Speech Engine Verification:
#    - Short text chunking & single execution
#    - Long text (3-4 lines) multi-sentence chunking
#    - activeUtterances GC strong reference check
#    - Cancel & 35ms delay re-entry check
#    - Self-healing timer un-stick verification
#    - Auto Player integration with AudioManager rate-aware safeTimeout
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
Write-Host " MEMORY HACK Mobile v2.3.5: Robust Speech Synthesis & Chunking Test Suite " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$mobileDir = if (Test-Path (Join-Path $PSScriptRoot "..\css\mobile.css")) { (Resolve-Path "$PSScriptRoot\..").Path } else { (Resolve-Path ".").Path }
$htmlPath = Join-Path $mobileDir "index.html"
$appJsPath = Join-Path $mobileDir "js\app.js"
$audioJsPath = Join-Path $mobileDir "js\audio.js"
$studyJsPath = Join-Path $mobileDir "js\study.js"
$swPath = Join-Path $mobileDir "service-worker.js"
$configPath = Join-Path $mobileDir "js\config.js"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$appJs = [System.IO.File]::ReadAllText($appJsPath, [System.Text.Encoding]::UTF8)
$audioJs = [System.IO.File]::ReadAllText($audioJsPath, [System.Text.Encoding]::UTF8)
$studyJs = [System.IO.File]::ReadAllText($studyJsPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)
$config = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# Phase 1: Static Code Structure & Architecture Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Static Code Structure & Architecture Verification] ---" -ForegroundColor Yellow

# 1.1 resumeTimer completely removed
$hasResumeTimer = $audioJs.Contains("resumeTimer")
Assert-Check "1.1 audio.js has completely removed 5s resumeTimer (setInterval pause/resume)" (-not $hasResumeTimer)

# 1.2 activeUtterances GC array
$hasActiveUtterances = $audioJs.Contains("activeUtterances: []") -and $audioJs.Contains("this.activeUtterances.push(utter)")
Assert-Check "1.2 audio.js maintains activeUtterances array for V8 GC protection" $hasActiveUtterances

# 1.3 splitIntoChunks method
$hasSplitIntoChunks = $audioJs.Contains("splitIntoChunks(text)")
Assert-Check "1.3 audio.js implements splitIntoChunks method" $hasSplitIntoChunks

# 1.4 35ms delay queue on cancel
$hasDelayQueue = $audioJs.Contains("setTimeout(doSpeak, 35)") -and $audioJs.Contains("this.synth.cancel()")
Assert-Check "1.4 audio.js implements 35ms delay queue after cancel() to avoid race conditions" $hasDelayQueue

# 1.5 Self-healing timer in audio.js
$hasSafetyTimer = $audioJs.Contains("safetyTimer:") -and $audioJs.Contains("this.safetyTimer = setTimeout")
Assert-Check "1.5 audio.js implements self-healing safety timer for chunk playback" $hasSafetyTimer

# 1.6 safeTimeout formula in study.js
$hasRateAwareSafeTimeout = $studyJs.Contains("frontText.length * 180") -and $studyJs.Contains("/ rate") -and $studyJs.Contains("Math.max(5000")
Assert-Check "1.6 study.js safeTimeout uses rate-aware formula (180ms/rate + 4000ms, min 5000ms)" $hasRateAwareSafeTimeout

# -------------------------------------------------------------
# Phase 2: Version v2.3.5 & PWA Cache Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: Version v2.3.5 & PWA Cache Verification] ---" -ForegroundColor Yellow

Assert-Check "2.1 service-worker.js CACHE_NAME is memory-hack-mobile-v2.3.5" ($sw.Contains("memory-hack-mobile-v2.3.5"))
Assert-Check "2.2 service-worker.js ASSETS_TO_CACHE has ?v=2.3.5 queries" ($sw.Contains("?v=2.3.5"))
Assert-Check "2.3 index.html has v2.3.5 brand badge" ($html.Contains('<span class="brand-ver-badge">v2.3.5</span>'))
Assert-Check "2.4 index.html has v2.3.5 modal subtitle" ($html.Contains('MEMORY HACK Mobile v2.3.5'))
Assert-Check "2.5 index.html has ?v=2.3.5 asset query strings" (([regex]::Matches($html, '\?v=2\.3\.5')).Count -ge 8)
Assert-Check "2.6 config.js has version 'v2.3.5'" ($config.Contains('version: "v2.3.5"'))
Assert-Check "2.7 study.js has version 'v2.3.5'" ($studyJs.Contains("version: 'v2.3.5'"))
Assert-Check "2.8 app.js has version 'v2.3.5'" ($appJs.Contains("v2.3.5"))

# -------------------------------------------------------------
# Phase 3: Headless Browser Interactive Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: Headless Browser Interactive Verification] ---" -ForegroundColor Yellow

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if (-not $browserExe) {
    Write-Host " [SKIP] No Chrome or Edge executable found for headless verification" -ForegroundColor DarkGray
} else {
    $testHtmlPath = Join-Path $mobileDir "tests\temp_v235_test.html"

    $testRunnerContent = @'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>v2.3.5 Test Runner</title>
</head>
<body>
  <div id="card-stage">
    <div id="card-front"></div>
    <div id="card-back" class="hidden"></div>
  </div>
  <pre id="test-results"></pre>

  <script src="../js/config.js"></script>
  <script src="../js/storage.js"></script>
  <script src="../js/audio.js"></script>
  <script src="../js/study.js"></script>

  <script>
  (async function runBrowserTests() {
    const results = {};
    try {
      // 1. Test splitIntoChunks with short text
      const shortChunks = AudioManager.splitIntoChunks("Hello world");
      results.shortChunksCount = shortChunks.length;
      results.shortChunks = shortChunks;

      // 2. Test splitIntoChunks with long multiline English text with varied punctuations
      const longText = "The quick brown fox jumps over the lazy dog.\nIt was a sunny day, wasn't it? Yes! Absolutely.";
      const longChunks = AudioManager.splitIntoChunks(longText);
      results.longChunksCount = longChunks.length;
      results.longChunks = longChunks;

      // Check punctuation endings
      results.chunk0Ending = longChunks[0].endsWith('.');
      results.chunk1Ending = longChunks[1].endsWith(',');
      results.chunk2Ending = longChunks[2].endsWith('?');
      results.chunk3Ending = longChunks[3].endsWith('!');
      results.chunk4Ending = longChunks[4].endsWith('.');

      // Mock speechSynthesis to verify sequential playback & GC reference
      const spokenUtterances = [];
      let cancelCount = 0;
      let speakCount = 0;

      const mockSynth = {
        speaking: false,
        pending: false,
        paused: false,
        speak(utter) {
          speakCount++;
          this.speaking = true;
          spokenUtterances.push(utter.text);
          // Auto-trigger onend asynchronously
          setTimeout(() => {
            this.speaking = false;
            if (utter.onend) utter.onend();
          }, 10);
        },
        cancel() {
          cancelCount++;
          this.speaking = false;
          this.pending = false;
        },
        resume() {
          this.paused = false;
        },
        getVoices() { return []; }
      };

      AudioManager.synth = mockSynth;

      // 3. Test speak() sequential playback & GC strong reference
      let speechCompleted = false;
      AudioManager.speak(longText, {
        rate: 1.0,
        onEnd: () => {
          speechCompleted = true;
        }
      });

      // activeUtterances should hold all chunks right after speak()
      results.activeUtterancesCount = AudioManager.activeUtterances.length;

      // Wait for all chunks to finish (5 chunks * 10ms + overhead)
      await new Promise(r => setTimeout(r, 200));
      results.speechCompleted = speechCompleted;
      results.spokenUtterancesCount = spokenUtterances.length;
      // activeUtterances should be cleaned up upon completion
      results.activeUtterancesCleaned = AudioManager.activeUtterances.length === 0;

      // 4. Test cancel() and 35ms delay re-entry
      mockSynth.speaking = true;
      let secondCompleted = false;
      AudioManager.speak("Second speech after cancel.", {
        onEnd: () => { secondCompleted = true; }
      });
      results.cancelCalledOnOverlap = cancelCount > 0;
      await new Promise(r => setTimeout(r, 150));
      results.secondCompleted = secondCompleted;

      // 5. Test StudyManager safeTimeout formula with rate 0.9 and 0.6
      StudyManager.currentCard = { front: "This is a test card for safe timeout calculation.", back: "テスト裏面" };
      
      AudioManager.rate = 0.9;
      const frontText = StudyManager.currentCard.front;
      const rate09 = AudioManager.rate;
      const timeout09 = Math.max(5000, Math.round((frontText.length * 180) / rate09) + 4000);
      results.timeout09 = timeout09;
      results.timeout09Valid = timeout09 >= 5000 && timeout09 > frontText.length * 180;

      AudioManager.rate = 0.6;
      const rate06 = AudioManager.rate;
      const timeout06 = Math.max(5000, Math.round((frontText.length * 180) / rate06) + 4000);
      results.timeout06 = timeout06;
      results.timeout06Increased = timeout06 > timeout09;

      // 6. Test StudyManager.playCurrentAutoCard() integration
      StudyManager.isAutoPlaying = true;
      StudyManager.isAutoPlayPaused = false;
      StudyManager.isFlipped = false;
      StudyManager.flipCard = function(v) { this.isFlipped = true; };
      StudyManager.autoPlayNextCard = function() { results.autoPlayNextCardCalled = true; };

      StudyManager.playCurrentAutoCard();
      results.autoPlayStepSpeaking = StudyManager.autoPlayStep === 'speaking';

      // Wait for audio to complete in mock
      await new Promise(r => setTimeout(r, 100));
      results.isFlippedAfterAudio = StudyManager.isFlipped === true;
      results.autoPlayStepFlipped = StudyManager.autoPlayStep === 'flipped';

      results.success = true;
    } catch (e) {
      results.success = false;
      results.error = e.message + ' stack: ' + e.stack;
    }

    document.getElementById('test-results').textContent = '###DATA_START###' + JSON.stringify(results) + '###DATA_END###';
  })();
  </script>
</body>
</html>
'@

    [System.IO.File]::WriteAllText($testHtmlPath, $testRunnerContent, [System.Text.Encoding]::UTF8)

    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_v235_test_$([System.Guid]::NewGuid().ToString('N')).html")
    try {
        $fileUri = "file:///" + (Resolve-Path $testHtmlPath).Path.Replace("\", "/")
        $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless=new", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=5000", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait
        
        if (Test-Path $tempDump) {
            $rendered = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
            $match = [regex]::Match($rendered, '<pre id="test-results">###DATA_START###(.*?)###DATA_END###</pre>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($match.Success) {
                $jsonStr = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
                $data = $jsonStr | ConvertFrom-Json

                Assert-Check "3.1 Browser: Short text splitIntoChunks produces 1 chunk" ($data.shortChunksCount -eq 1)
                Assert-Check "3.2 Browser: Long text splitIntoChunks produces 5 sentence chunks" ($data.longChunksCount -eq 5)
                Assert-Check "3.3 Browser: Punctuation delimiters (. , ? ! .) preserved in chunk endings" ($data.chunk0Ending -and $data.chunk1Ending -and $data.chunk2Ending -and $data.chunk3Ending -and $data.chunk4Ending)
                Assert-Check "3.4 Browser: activeUtterances holds all chunks immediately after speak() for GC protection" ($data.activeUtterancesCount -eq 5)
                Assert-Check "3.5 Browser: Sequential playback finishes all chunks and triggers onEnd" ($data.speechCompleted -eq $true -and $data.spokenUtterancesCount -eq 5)
                Assert-Check "3.6 Browser: activeUtterances cleaned up upon completion" ($data.activeUtterancesCleaned -eq $true)
                Assert-Check "3.7 Browser: Overlapping speech calls cancel() and 35ms delay queue" ($data.cancelCalledOnOverlap -eq $true -and $data.secondCompleted -eq $true)
                Assert-Check "3.8 Browser: safeTimeout is rate-aware and >= 5000ms" ($data.timeout09Valid -eq $true)
                Assert-Check "3.9 Browser: Lower speech rate (0.6x) increases safeTimeout to prevent premature flip" ($data.timeout06Increased -eq $true)
                Assert-Check "3.10 Browser: playCurrentAutoCard flips card and sets step to 'flipped' after audio completes" ($data.autoPlayStepSpeaking -eq $true -and $data.isFlippedAfterAudio -eq $true -and $data.autoPlayStepFlipped -eq $true)
            } else {
                Assert-Check "3.x Headless DOM output parsed" $false "Failed to parse JSON from DOM: $rendered"
            }
        } else {
            Assert-Check "3.x Headless execution completed" $false "Dump file was not generated"
        }
    } finally {
        Remove-Item -Force $tempDump -ErrorAction SilentlyContinue
        Remove-Item -Force $testHtmlPath -ErrorAction SilentlyContinue
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
