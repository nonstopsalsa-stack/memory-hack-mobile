# tests/test_light_theme_hierarchy.ps1
$ErrorActionPreference = "Stop"

Write-Host "=== MEMORY HACK Mobile: Light Theme Hierarchy Tree CSS Test ===" -ForegroundColor Cyan

$baseDir = "C:\Users\nonst\recover\obsidian folder\006_AI_Workspace\anki-mobile"
$cssFile = Join-Path $baseDir "css\mobile.css"

$passed = 0
$failed = 0

function Assert-Test($condition, $name) {
    if ($condition) {
        Write-Host "  [PASS] $name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $name" -ForegroundColor Red
        $script:failed++
    }
}

$cssContent = [System.IO.File]::ReadAllText($cssFile, [System.Text.Encoding]::UTF8)

# 1. 括弧のバランスチェック
$openBraces = ($cssContent.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$closeBraces = ($cssContent.ToCharArray() | Where-Object { $_ -eq '}' }).Count
Assert-Test ($openBraces -eq $closeBraces) "CSS syntax: Braces balance ($openBraces vs $closeBraces)"

# 2. 全てのスタイル要件チェック
$checks = @(
    @{
        Name = "hierarchy-tree-item.all-item background gradient & border"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tree-item\.all-item\s*\{[^}]*background:\s*linear-gradient\(135deg,\s*#eef2ff\s*0%,\s*#ffffff\s*100%\)[^}]*border:\s*1px solid #c7d2fe'
    },
    @{
        Name = "hierarchy-tier1-group background & border"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier1-group\s*\{[^}]*background:\s*#ffffff[^}]*border:\s*1px solid #e2e8f0'
    },
    @{
        Name = "hierarchy-tier1-group.open border-color"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier1-group\.open\s*\{[^}]*border-color:\s*#a5b4fc'
    },
    @{
        Name = "hierarchy-tier1-header background & color"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier1-header\s*\{[^}]*background:\s*#ffffff[^}]*color:\s*#0b132b'
    },
    @{
        Name = "hierarchy-tier1-header.active background & border-left"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier1-header\.active\s*\{[^}]*background:\s*#eef2ff[^}]*border-left:\s*3px solid #6366f1'
    },
    @{
        Name = "accordion-arrow color"
        Pattern = '\[data-theme="light"\]\s+\.accordion-arrow\s*\{[^}]*color:\s*#64748b'
    },
    @{
        Name = "hierarchy-name color & font-weight"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-name\s*\{[^}]*color:\s*#0b132b[^}]*font-weight:\s*700'
    },
    @{
        Name = "hierarchy-count-badge background, color & border"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-count-badge\s*\{[^}]*background:\s*#e0e7ff[^}]*color:\s*#4338ca[^}]*border:\s*1px solid #c7d2fe'
    },
    @{
        Name = "btn-tree-select, btn-tier-select background, border & color"
        Pattern = '\[data-theme="light"\]\s+\.btn-tree-select,\s*\[data-theme="light"\]\s+\.btn-tier-select\s*\{[^}]*background:\s*#f1f5f9[^}]*border:\s*1px solid #cbd5e1[^}]*color:\s*#1e293b'
    },
    @{
        Name = "btn-tree-select.selected, btn-tier-select.selected background, color & border-color"
        Pattern = '\[data-theme="light"\]\s+\.btn-tree-select\.selected,\s*\[data-theme="light"\]\s+\.btn-tier-select\.selected\s*\{[^}]*background:\s*#6366f1[^}]*color:\s*#ffffff[^}]*border-color:\s*#6366f1'
    },
    @{
        Name = "hierarchy-tier2-container background & border-top"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier2-container\s*\{[^}]*background:\s*#f8fafc[^}]*border-top:\s*1px solid #e2e8f0'
    },
    @{
        Name = "hierarchy-tier2-header background, color & border"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier2-header\s*\{[^}]*background:\s*#ffffff[^}]*color:\s*#0b132b[^}]*border:\s*1px solid #e2e8f0'
    },
    @{
        Name = "hierarchy-tier2-header.active background & border-left"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier2-header\.active\s*\{[^}]*background:\s*#eef2ff[^}]*border-left:\s*3px solid #4f46e5'
    },
    @{
        Name = "hierarchy-tier3-item background, color & border"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier3-item\s*\{[^}]*background:\s*#ffffff[^}]*color:\s*#0b132b[^}]*border:\s*1px solid #e2e8f0'
    },
    @{
        Name = "hierarchy-tier3-item.active background & border-left"
        Pattern = '\[data-theme="light"\]\s+\.hierarchy-tier3-item\.active\s*\{[^}]*background:\s*#eef2ff[^}]*border-left:\s*2px solid #6366f1'
    }
)

foreach ($c in $checks) {
    Assert-Test ($cssContent -match $c.Pattern) $c.Name
}

# 3. [data-theme="light"] scope check (ensure no leaky unscoped rules)
$lines = $cssContent -split "`r?`n"
$insideTreeBlock = $false
$allScoped = $true
$testedSelectors = 0

foreach ($line in $lines) {
    if ($line.Contains('[data-theme="light"] .hierarchy-tree-item.all-item {')) {
        $insideTreeBlock = $true
    }
    if ($insideTreeBlock -and $line.Contains(".pwa-banner")) {
        $insideTreeBlock = $false
        break
    }
    if ($insideTreeBlock -and $line.Contains("{") -and -not $line.Trim().StartsWith("/*")) {
        $selectorPart = ($line -split "\{")[0]
        $selectors = $selectorPart -split ","
        foreach ($sel in $selectors) {
            $trimmed = $sel.Trim()
            if ($trimmed -ne "") {
                $testedSelectors++
                if (-not $trimmed.StartsWith('[data-theme="light"]')) {
                    Write-Host "  Unscoped selector found: $trimmed" -ForegroundColor Red
                    $allScoped = $false
                }
            }
        }
    }
}

Assert-Test ($allScoped -and ($testedSelectors -gt 0)) "All new hierarchy selectors ($testedSelectors found) are scoped under [data-theme=`"light`"]"

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "PASS: $passed" -ForegroundColor Green
Write-Host "FAIL: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })

if ($failed -eq 0) {
    Write-Host "`nAll tests PASSED 100% successfully!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`nSome tests failed." -ForegroundColor Red
    exit 1
}
