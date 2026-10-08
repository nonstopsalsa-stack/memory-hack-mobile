# test_theme_switch_browser.ps1
# Verify live theme application and computed CSS properties via headless browser

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

$browserExe = $null
if (Test-Path "C:\Program Files\Google\Chrome\Application\chrome.exe") {
    $browserExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
} elseif (Test-Path "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") {
    $browserExe = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
}

if (-not $browserExe) {
    Write-Host "Browser not found, skipping."
    exit 0
}

Write-Host "==========================================================================" -ForegroundColor Cyan
Write-Host " Live Headless Browser Theme Switching & Visual Integrity Verification    " -ForegroundColor Cyan
Write-Host "==========================================================================" -ForegroundColor Cyan

# Create a temporary test runner HTML that sets each theme and verifies DOM & styles
$runnerHtmlPath = [System.IO.Path]::Combine("$PSScriptRoot", "temp_theme_verify.html")

$runnerContent = @'
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <link rel="stylesheet" href="../css/mobile.css">
</head>
<body data-theme="muichiro">
  <div id="app-container">
    <header class="top-bar">
      <div class="brand-section">
        <span class="brand-logo" id="brand-logo">
          <span class="logo-sword">⚔️</span>
          <svg class="logo-intellect" viewBox="0 0 24 24"><rect width="10" height="10"/></svg>
          <img class="logo-muichiro" src="../assets/muichiro_avatar.png" alt="時透無一郎">
        </span>
        <span class="brand-title">MEMORY HACK</span>
      </div>
    </header>
    <div class="control-strip">
      <button class="deck-chip-btn"><span class="deck-trigger-proj">Proj</span></button>
    </div>
    <div class="study-card">
      <div class="card-prompt-text en">Test Prompt</div>
      <div class="card-answer-main en">Test Answer</div>
      <div class="kanji-answer-val">漢字</div>
    </div>
    <footer class="bottom-bar">
      <button class="btn-action btn-flip"><span class="action-icon">👀</span>FLIP</button>
    </footer>
  </div>
  <script>
    window.addEventListener('DOMContentLoaded', () => {
      const results = {};
      const logoM = document.querySelector('.logo-muichiro');
      const logoS = document.querySelector('.logo-sword');
      const logoI = document.querySelector('.logo-intellect');
      const topBar = document.querySelector('.top-bar');
      const card = document.querySelector('.study-card');
      const flipBtn = document.querySelector('.btn-action.btn-flip');

      const sLogoM = window.getComputedStyle(logoM);
      const sLogoS = window.getComputedStyle(logoS);
      const sLogoI = window.getComputedStyle(logoI);
      const sTopBar = window.getComputedStyle(topBar);
      const sCard = window.getComputedStyle(card);
      const sFlipBtn = window.getComputedStyle(flipBtn);

      results.muichiro = {
        logoM_display: sLogoM.display,
        logoS_display: sLogoS.display,
        logoI_display: sLogoI.display,
        logoM_width: sLogoM.width,
        logoM_borderRadius: sLogoM.borderRadius,
        topBar_bg: sTopBar.backgroundColor,
        card_border: sCard.borderTopWidth + ' ' + sCard.borderTopColor,
        card_bg: sCard.backgroundColor
      };

      // Test BloxFruits theme
      document.documentElement.setAttribute('data-theme', 'bloxfruits');
      document.body.setAttribute('data-theme', 'bloxfruits');
      results.bloxfruits = {
        logoM_display: window.getComputedStyle(logoM).display,
        logoS_display: window.getComputedStyle(logoS).display
      };

      // Test Light theme
      document.documentElement.setAttribute('data-theme', 'light');
      document.body.setAttribute('data-theme', 'light');
      results.light = {
        logoM_display: window.getComputedStyle(logoM).display,
        logoS_display: window.getComputedStyle(logoS).display,
        logoI_display: window.getComputedStyle(logoI).display
      };

      // Test Dark theme
      document.documentElement.setAttribute('data-theme', 'dark');
      document.body.setAttribute('data-theme', 'dark');
      results.dark = {
        logoM_display: window.getComputedStyle(logoM).display,
        logoS_display: window.getComputedStyle(logoS).display,
        logoI_display: window.getComputedStyle(logoI).display
      };

      const out = document.createElement('pre');
      out.id = 'theme-results';
      out.textContent = JSON.stringify(results);
      document.body.appendChild(out);
    });
  </script>
</body>
</html>
'@

[System.IO.File]::WriteAllText($runnerHtmlPath, $runnerContent, (New-Object System.Text.UTF8Encoding $false))

$tempDump = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "mh_theme_runner_$([System.Guid]::NewGuid().ToString('N')).html")
try {
    $fileUri = "file:///" + (Resolve-Path $runnerHtmlPath).Path.Replace("\", "/")
    $proc = Start-Process -FilePath $browserExe -ArgumentList "--headless", "--disable-gpu", "--allow-file-access-from-files", "--dump-dom", "`"$fileUri`"" -RedirectStandardOutput $tempDump -NoNewWindow -PassThru -Wait
    
    if (Test-Path $tempDump) {
        $dom = [System.IO.File]::ReadAllText($tempDump, [System.Text.Encoding]::UTF8)
        if ($dom -match '<pre id="theme-results">([\s\S]*?)</pre>') {
            $jsonStr = $Matches[1]
            $res = ConvertFrom-Json $jsonStr
            
            # Check Muichiro Computed Styles
            Write-Host "`n--- [Muichiro Theme Computed Styles] ---" -ForegroundColor Yellow
            Assert-Check "Logo Muichiro is displayed (inline-block)" ($res.muichiro.logoM_display -eq "inline-block")
            Assert-Check "Logo Sword is hidden (none)" ($res.muichiro.logoS_display -eq "none")
            Assert-Check "Logo Intellect is hidden (none)" ($res.muichiro.logoI_display -eq "none")
            Assert-Check "Logo Muichiro size is 28px" ($res.muichiro.logoM_width -eq "28px")
            Assert-Check "Logo Muichiro is circular (50%)" ($res.muichiro.logoM_borderRadius -eq "50%")
            Assert-Check "Top bar is deep teal (rgb(19, 59, 70))" ($res.muichiro.topBar_bg -eq "rgb(19, 59, 70)")
            Assert-Check "Card background is kinari (rgb(250, 248, 245))" ($res.muichiro.card_bg -eq "rgb(250, 248, 245)")

            # Check BloxFruits Computed Styles
            Write-Host "`n--- [BloxFruits Theme Computed Styles] ---" -ForegroundColor Yellow
            Assert-Check "BloxFruits: Logo Muichiro is hidden (none)" ($res.bloxfruits.logoM_display -eq "none")
            Assert-Check "BloxFruits: Logo Sword is visible (not none)" ($res.bloxfruits.logoS_display -ne "none")

            # Check Light Theme Computed Styles
            Write-Host "`n--- [Light Theme Computed Styles] ---" -ForegroundColor Yellow
            Assert-Check "Light: Logo Muichiro is hidden (none)" ($res.light.logoM_display -eq "none")
            Assert-Check "Light: Logo Sword is hidden (none)" ($res.light.logoS_display -eq "none")
            Assert-Check "Light: Logo Intellect is visible (inline-flex)" ($res.light.logoI_display -eq "inline-flex")

            # Check Dark Theme Computed Styles
            Write-Host "`n--- [Dark Theme Computed Styles] ---" -ForegroundColor Yellow
            Assert-Check "Dark: Logo Muichiro is hidden (none)" ($res.dark.logoM_display -eq "none")
            Assert-Check "Dark: Logo Sword is hidden (none)" ($res.dark.logoS_display -eq "none")
            Assert-Check "Dark: Logo Intellect is visible (inline-flex)" ($res.dark.logoI_display -eq "inline-flex")
        } else {
            Write-Host "Could not find theme-results in DOM" -ForegroundColor Red
            $script:failed++
        }
    }
} finally {
    if (Test-Path $tempDump) { Remove-Item -Force $tempDump }
    if (Test-Path $runnerHtmlPath) { Remove-Item -Force $runnerHtmlPath }
}

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host " RESULT: $passed Passed / $failed Failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
Write-Host "==========================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    exit 1
} else {
    exit 0
}
