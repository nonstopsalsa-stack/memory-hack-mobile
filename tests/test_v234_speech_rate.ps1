# ==========================================================================
# MEMORY HACK Mobile v2.3.4: Speech Rate Control & Storage Verification Test
# 
# Verification Coverage:
# 1. UI Structure: Slider (#setting-tts-rate) and value label (#setting-tts-rate-val)
# 2. JS Code Logic: App.init(), bindEvents(), openSettingsModal(), saveSettings()
# 3. Audio & Storage Integration: AudioManager.rate & Storage persistence
# 4. Service Worker & Version v2.3.4 Static Integrity
# 5. Headless Chrome/Edge Real DOM & Interactive Event Flow
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
Write-Host " MEMORY HACK Mobile v2.3.4: Speech Rate Control Verification Test         " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

$mobileDir = if (Test-Path (Join-Path $PSScriptRoot "..\css\mobile.css")) { (Resolve-Path "$PSScriptRoot\..").Path } else { (Resolve-Path ".").Path }
$htmlPath = Join-Path $mobileDir "index.html"
$appJsPath = Join-Path $mobileDir "js\app.js"
$audioJsPath = Join-Path $mobileDir "js\audio.js"
$storageJsPath = Join-Path $mobileDir "js\storage.js"
$swPath = Join-Path $mobileDir "service-worker.js"
$configPath = Join-Path $mobileDir "js\config.js"

$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$appJs = [System.IO.File]::ReadAllText($appJsPath, [System.Text.Encoding]::UTF8)
$audioJs = [System.IO.File]::ReadAllText($audioJsPath, [System.Text.Encoding]::UTF8)
$storageJs = [System.IO.File]::ReadAllText($storageJsPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)
$config = [System.IO.File]::ReadAllText($configPath, [System.Text.Encoding]::UTF8)

# -------------------------------------------------------------
# Phase 1: Static HTML & UI Structure Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 1: Static HTML & UI Structure Verification] ---" -ForegroundColor Yellow

$hasSlider = $html -match '<input\s+type="range"\s+id="setting-tts-rate"'
Assert-Check "1.1 index.html contains input range #setting-tts-rate" $hasSlider

$hasSliderAttrs = $html -match 'id="setting-tts-rate"[^>]*min="0\.6"[^>]*max="1\.4"[^>]*step="0\.05"' -or $html -match 'min="0\.6"[^>]*max="1\.4"[^>]*step="0\.05"[^>]*id="setting-tts-rate"'
Assert-Check "1.2 Slider has min='0.6', max='1.4', step='0.05'" $hasSliderAttrs

$hasValLabel = $html.Contains('id="setting-tts-rate-val"')
Assert-Check "1.3 index.html contains label #setting-tts-rate-val" $hasValLabel

$idxAutoAudio = $html.IndexOf('id="setting-auto-audio"')
$idxSlider = $html.IndexOf('id="setting-tts-rate"')
$idxVal = $html.IndexOf('id="setting-tts-rate-val"')
$idxRefresh = $html.IndexOf('App.forceRefresh()')
$orderOk = ($idxAutoAudio -gt 0) -and ($idxSlider -gt $idxAutoAudio) -and ($idxRefresh -gt $idxSlider)
Assert-Check "1.4 Slider is positioned in audio block (after auto-audio, before refresh)" $orderOk

# -------------------------------------------------------------
# Phase 2: Static JS Code & Architecture Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 2: Static JS Code & Architecture Verification] ---" -ForegroundColor Yellow

$initRateLoad = $appJs -match "Storage\.getSetting\(['`"]tts_rate['`"],\s*0\.9\)" -and $appJs.Contains("AudioManager.rate")
Assert-Check "2.1 app.js init() loads tts_rate with default 0.9 and sets AudioManager.rate" $initRateLoad

$bindInputEvt = $appJs.Contains("setting-tts-rate") -and $appJs.Contains("setting-tts-rate-val") -and $appJs -match "addEventListener\(['`"]input['`"]"
Assert-Check "2.2 app.js bindEvents() listens for input on slider and updates label" $bindInputEvt

$openModalReflect = $appJs -match '(?s)openSettingsModal\s*\(\).*?setting-tts-rate'
Assert-Check "2.3 app.js openSettingsModal() reflects rate to slider and label" $openModalReflect

$saveSettingsPersist = $appJs -match '(?s)saveSettings\s*\(\).*?saveSetting\([''"]tts_rate[''"]'
Assert-Check "2.4 app.js saveSettings() saves tts_rate and updates AudioManager.rate" $saveSettingsPersist

$audioManagerRateProp = $audioJs -match "rate:\s*0\.9" -and $audioJs.Contains("utter.rate = options.rate || this.rate")
Assert-Check "2.5 audio.js supports AudioManager.rate in speak()" $audioManagerRateProp

# -------------------------------------------------------------
# Phase 3: Version v2.3.4 & PWA Cache Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 3: Version v2.3.4 & PWA Cache Verification] ---" -ForegroundColor Yellow

Assert-Check "3.1 service-worker.js CACHE_NAME is memory-hack-mobile-v2.3.4" ($sw.Contains("memory-hack-mobile-v2.3.4"))
Assert-Check "3.2 service-worker.js ASSETS_TO_CACHE has ?v=2.3.4 queries" ($sw.Contains("?v=2.3.4"))
Assert-Check "3.3 index.html has v2.3.4 brand badge" ($html.Contains('<span class="brand-ver-badge">v2.3.4</span>'))
Assert-Check "3.4 index.html has v2.3.4 modal subtitle" ($html.Contains('MEMORY HACK Mobile v2.3.4'))
Assert-Check "3.5 index.html has ?v=2.3.4 asset query strings" (([regex]::Matches($html, '\?v=2\.3\.4')).Count -ge 8)
Assert-Check "3.6 config.js has version 'v2.3.4'" ($config.Contains('version: "v2.3.4"'))

# -------------------------------------------------------------
# Phase 4: Headless Browser Interactive Verification
# -------------------------------------------------------------
Write-Host "`n--- [Phase 4: Headless Browser Interactive Verification] ---" -ForegroundColor Yellow

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
    $testHtmlPath = Join-Path $mobileDir "tests\temp_v234_test.html"

    $testRunnerContent = @'
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>v2.3.4 Test Runner</title>
</head>
<body>
  <!-- Settings Modal UI Shell -->
  <div id="modal-settings" class="hidden">
    <select id="setting-mobile-theme"><option value="light">light</option></select>
    <select id="setting-device-profile"><option value="all">all</option></select>
    <input type="checkbox" id="setting-auto-audio" checked />
    <span id="setting-tts-rate-val">0.90x</span>
    <input type="range" id="setting-tts-rate" min="0.6" max="1.4" step="0.05" value="0.9" />
    <input type="url" id="setting-webhook-url" value="" />
  </div>
  <pre id="test-results"></pre>

  <script src="../js/config.js"></script>
  <script src="../js/storage.js"></script>
  <script src="../js/audio.js"></script>
  <script>
    // Mock StudyManager & SyncManager to isolate App & Audio & Storage tests
    window.StudyManager = { autoPlayAudio: true, init: async () => {} };
    window.SyncManager = { syncUrl: '', init: async () => {} };
  </script>
  <script src="../js/app.js"></script>

  <script>
  (async function runBrowserTests() {
    const results = {};
    try {
      // 1. Initial State: App.init() with default (no storage item)
      localStorage.removeItem('memory_hack_mobile_settings');
      await App.init();
      results.initialRate = AudioManager.rate;

      // 2. Open Settings Modal: verify UI reflects initial rate
      await App.openSettingsModal();
      const slider = document.getElementById('setting-tts-rate');
      const valLabel = document.getElementById('setting-tts-rate-val');
      results.sliderValueAtOpen = parseFloat(slider.value);
      results.labelAtOpen = valLabel.textContent.trim();

      // 3. User Interaction: Change slider to 1.15 and fire input event
      slider.value = '1.15';
      slider.dispatchEvent(new Event('input', { bubbles: true }));
      results.labelAfterInput = valLabel.textContent.trim();

      // 4. Save Settings: verify AudioManager.rate & Storage persistence
      await App.saveSettings();
      results.rateAfterSave = AudioManager.rate;
      const savedRateInStorage = await Storage.getSetting('tts_rate');
      results.storageAfterSave = savedRateInStorage;

      // 5. Subsequent Open: verify values are re-read and reflected accurately
      slider.value = '0.6'; // dirty the UI
      valLabel.textContent = '0.60x';
      await App.openSettingsModal();
      results.sliderValueAtSecondOpen = parseFloat(slider.value);
      results.labelAtSecondOpen = valLabel.textContent.trim();

      // 6. Test App.init() reload scenario with saved rate 1.15
      AudioManager.rate = 0.5; // dirty in-memory rate
      await App.init();
      results.rateAfterReinit = AudioManager.rate;

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

    $tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_v234_test_$([System.Guid]::NewGuid().ToString('N')).html")
    try {
        $fileUri = "file:///" + (Resolve-Path $testHtmlPath).Path.Replace("\", "/")
        $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=4000", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait
        
        if (Test-Path $tempDump) {
            $rendered = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
            $match = [regex]::Match($rendered, '<pre id="test-results">###DATA_START###(.*?)###DATA_END###</pre>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($match.Success) {
                $jsonStr = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
                $data = $jsonStr | ConvertFrom-Json

                Assert-Check "4.1 Browser: Initial AudioManager.rate is 0.9" ($data.initialRate -eq 0.9)
                Assert-Check "4.2 Browser: openSettingsModal sets slider to 0.9 and label to '0.90x'" ($data.sliderValueAtOpen -eq 0.9 -and $data.labelAtOpen -eq "0.90x")
                Assert-Check "4.3 Browser: input event updates label to '1.15x' in real-time" ($data.labelAfterInput -eq "1.15x")
                Assert-Check "4.4 Browser: saveSettings updates AudioManager.rate to 1.15" ($data.rateAfterSave -eq 1.15)
                Assert-Check "4.5 Browser: saveSettings persists tts_rate 1.15 in Storage" ($data.storageAfterSave -eq 1.15)
                Assert-Check "4.6 Browser: Re-opening modal retains slider 1.15 & label '1.15x'" ($data.sliderValueAtSecondOpen -eq 1.15 -and $data.labelAtSecondOpen -eq "1.15x")
                Assert-Check "4.7 Browser: Subsequent App.init() restores saved rate 1.15" ($data.rateAfterReinit -eq 1.15)
            } else {
                Assert-Check "4.x Headless DOM output parsed" $false "Failed to parse JSON from DOM: $rendered"
            }
        } else {
            Assert-Check "4.x Headless execution completed" $false "Dump file was not generated"
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
