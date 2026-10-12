# ==========================================================================
# Settings Modal Layout & Pinned Footer Verification Test
# ==========================================================================
$ErrorActionPreference = "Stop"

$html = [System.IO.File]::ReadAllText("index.html", [System.Text.Encoding]::UTF8)
$css = [System.IO.File]::ReadAllText("css\mobile.css", [System.Text.Encoding]::UTF8)

Write-Host "--- [1. Settings Modal Order & Structure Verification] ---" -ForegroundColor Yellow

$idxModal = $html.IndexOf('id="modal-settings"')
$idxBody = $html.IndexOf('class="modal-settings-body"', $idxModal)
$idxTheme = $html.IndexOf('id="setting-mobile-theme"', $idxBody)
$idxProfile = $html.IndexOf('id="setting-device-profile"', $idxTheme)
$idxAutoAudio = $html.IndexOf('id="setting-auto-audio"', $idxProfile)
$idxForceRefresh = $html.IndexOf('App.forceRefresh()', $idxAutoAudio)
$idxWebhook = $html.IndexOf('id="setting-webhook-url"', $idxForceRefresh)
$idxCloseBody = $html.IndexOf('</div>', $idxWebhook)
$idxActions = $html.IndexOf('class="modal-actions-bar"', $idxCloseBody)

$allPassed = $true

function Assert-Step($desc, $cond) {
    if ($cond) {
        Write-Host " [PASS] $desc" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $desc" -ForegroundColor Red
        $script:allPassed = $false
    }
}

Assert-Step "modal-settings exists" ($idxModal -ge 0)
Assert-Step "modal-settings-body wraps content" ($idxBody -gt $idxModal)
Assert-Step "1: Visual theme is first" ($idxTheme -gt $idxBody)
Assert-Step "2: Device profile is second" ($idxProfile -gt $idxTheme)
Assert-Step "3: Auto audio checkbox is third" ($idxAutoAudio -gt $idxProfile)
Assert-Step "4: Force refresh is fourth" ($idxForceRefresh -gt $idxAutoAudio)
Assert-Step "5: Webhook URL is fifth" ($idxWebhook -gt $idxForceRefresh)
Assert-Step "6: Actions bar is after modal-settings-body" ($idxActions -gt $idxWebhook)

Write-Host "`n--- [2. CSS Pinned Footer Rules Verification] ---" -ForegroundColor Yellow

Assert-Step "CSS: #modal-settings .modal-sheet has overflow: hidden" ($css -match '#modal-settings\s+\.modal-sheet\s*\{[^}]*overflow:\s*hidden;')
Assert-Step "CSS: #modal-settings .modal-header has flex-shrink: 0" ($css -match '#modal-settings\s+\.modal-header\s*\{[^}]*flex-shrink:\s*0;')
Assert-Step "CSS: #modal-settings .modal-settings-body has flex & overflow-y" ($css -match '#modal-settings\s+\.modal-settings-body\s*\{[^}]*flex:\s*1\s+1\s+auto;[^}]*min-height:\s*0;[^}]*overflow-y:\s*auto;')
Assert-Step "CSS: #modal-settings .modal-actions-bar has flex-shrink: 0" ($css -match '#modal-settings\s+\.modal-actions-bar\s*\{[^}]*flex-shrink:\s*0;')

if ($allPassed) {
    Write-Host "`n[SUCCESS] All Settings Modal layout & style verifications PASSED!" -ForegroundColor Green
} else {
    Write-Host "`n[FAILURE] One or more checks FAILED!" -ForegroundColor Red
    exit 1
}
