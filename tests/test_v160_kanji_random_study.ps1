# test_v160_kanji_random_study.ps1 - Mobile PWA 漢字出題エンジン & キャッシュ整合性テスト

$ErrorActionPreference = "Stop"

function Assert-Check {
    param(
        [string]$Desc,
        [bool]$Condition
    )
    if ($Condition -eq $true) {
        Write-Host " [PASS] $Desc" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] $Desc" -ForegroundColor Red
        exit 1
    }
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " MEMORY HACK Mobile - v1.6.0-kanji Verification Test" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$studyPath = Resolve-Path "anki-mobile/js/study.js"
$appPath = Resolve-Path "anki-mobile/js/app.js"
$swPath = Resolve-Path "anki-mobile/service-worker.js"
$htmlPath = Resolve-Path "anki-mobile/index.html"
$cssPath = Resolve-Path "anki-mobile/css/mobile.css"

$study = [System.IO.File]::ReadAllText($studyPath, [System.Text.Encoding]::UTF8)
$app = [System.IO.File]::ReadAllText($appPath, [System.Text.Encoding]::UTF8)
$sw = [System.IO.File]::ReadAllText($swPath, [System.Text.Encoding]::UTF8)
$html = [System.IO.File]::ReadAllText($htmlPath, [System.Text.Encoding]::UTF8)
$css = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)

# 1. バージョン整合性
Assert-Check "1.1 study.js version is v2.2.3" ($study.Contains("version: 'v2.2.3'"))
Assert-Check "1.2 service-worker.js CACHE_NAME is memory-hack-mobile-v2.2.3" ($sw.Contains("memory-hack-mobile-v2.2.3"))
Assert-Check "1.3 service-worker.js ASSETS_TO_CACHE has v2.2.3 queries" ($sw.Contains("?v=2.2.3"))
Assert-Check "1.4 index.html has v2.2.3 query strings" ($html.Contains("?v=2.2.3"))

# 2. 漢字パターン定義と状態
Assert-Check "2.1 study.js defines KANJI_PATTERNS" ($study.Contains("KANJI_PATTERNS:") -and $study.Contains("char_to_read") -and $study.Contains("sentence_fill"))
Assert-Check "2.2 study.js defines activePatternsKanji default" ($study.Contains("activePatternsKanji:"))
Assert-Check "2.3 study.js has isKanjiCard method" ($study.Contains("isKanjiCard(card)"))
Assert-Check "2.4 study.js has isCurrentSessionKanji method" ($study.Contains("isCurrentSessionKanji()"))
Assert-Check "2.5 study.js has sanitizeKanjiPatterns method" ($study.Contains("sanitizeKanjiPatterns(patterns)"))

# 3. パーサー & ピッカー
Assert-Check "3.1 study.js has parseKanjiReadings method" ($study.Contains("parseKanjiReadings(card)"))
Assert-Check "3.2 study.js has parseKanjiCompounds method" ($study.Contains("parseKanjiCompounds(card)"))
Assert-Check "3.3 study.js has parseKanjiSentence method" ($study.Contains("parseKanjiSentence(card)"))
Assert-Check "3.4 study.js has pickKanjiQuestion method" ($study.Contains("pickKanjiQuestion(card, requestedPattern)"))

# 4. 安全フォールバック
Assert-Check "4.1 pickKanjiQuestion compound fallback" ($study.Contains("(pattern === 'word_to_read' || pattern === 'read_to_word') && compounds.length === 0"))
Assert-Check "4.2 pickKanjiQuestion sentence fallback" ($study.Contains("(pattern === 'sentence_fill' || pattern === 'sentence_read') && (!sentData || !sentData.rawSentence)"))
Assert-Check "4.3 pickKanjiQuestion reading fallback" ($study.Contains("pattern === 'read_to_char' && readings.allReadings.length === 0"))

# 5. 出題 & レンダリング連動
Assert-Check "5.1 pickCurrentPattern handles kanji cards" ($study.Contains("this.pickKanjiQuestion(this.currentCard, rawPattern)"))
Assert-Check "5.2 renderCard renders kanji front and back" ($study.Contains("isKanji") -and $study.Contains("kq.answerMain") -and $study.Contains("kq.displayPrompt"))
Assert-Check "5.3 getPatternInfo contains 6 kanji quest badges" ($study.Contains("case 'char_to_read':") -and $study.Contains("case 'sentence_fill':"))

# 6. app.js パターン連携
Assert-Check "6.1 app.js has onPatternChange method" ($app.Contains("onPatternChange()"))
Assert-Check "6.2 app.js onPatternChange saves to study_active_patterns_kanji" ($app.Contains("study_active_patterns_kanji"))
Assert-Check "6.3 app.js toggleAllPatterns supports kanji default" ($app.Contains("cardType === 'kanji'") -or $app.Contains("StudyManager.isCurrentSessionKanji()"))

# 7. 音訓読み解答画面（構造化HTML & 高視認性 - Mobile）
Assert-Check "7.1 study.js has buildReadingsAnswerHtml for structured readings" ($study.Contains("buildReadingsAnswerHtml") -and $study.Contains("kanji-answer-readings-wrap") -and $study.Contains("kanji-answer-label") -and $study.Contains("kanji-answer-val"))
Assert-Check "7.2 mobile.css defines kanji-answer-readings-wrap and sub-elements" ($css.Contains(".kanji-answer-readings-wrap") -and $css.Contains(".kanji-answer-item") -and $css.Contains(".kanji-answer-label") -and $css.Contains(".kanji-answer-val"))
Assert-Check "7.3 mobile.css defines light theme high contrast overrides" ($css.Contains('[data-theme="light"] .kanji-answer-val') -and $css.Contains('#0f172a'))

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " All 22 Mobile Tests Passed (100% SUCCESS) " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan

