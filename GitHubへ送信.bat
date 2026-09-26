@echo off
chcp 65001 > nul
setlocal

set SRC=C:\Users\nonst\Desktop\MEMORY HACK Mobile (アップロード用)
set REPO=C:\Users\nonst\recover\obsidian folder\006_AI_Workspace\anki-mobile

echo =========================================================================
echo    MEMORY HACK Mobile - Sync ^& GitHub Push
echo =========================================================================
echo.
echo [1/3] Syncing files from upload folder to git repository...
echo   FROM: %SRC%
echo   TO  : %REPO%
echo.

REM ── index.html / manifest.json / service-worker.js ──
copy /Y "%SRC%\index.html"          "%REPO%\index.html"          > nul
copy /Y "%SRC%\manifest.json"       "%REPO%\manifest.json"       > nul
copy /Y "%SRC%\service-worker.js"   "%REPO%\service-worker.js"   > nul

REM ── assets ──
if not exist "%REPO%\assets" mkdir "%REPO%\assets"
copy /Y "%SRC%\assets\icon.png"      "%REPO%\assets\icon.png"      > nul
copy /Y "%SRC%\assets\icon.ico"      "%REPO%\assets\icon.ico"      > nul

REM ── css ──
copy /Y "%SRC%\css\mobile.css"      "%REPO%\css\mobile.css"      > nul

REM ── js ──
copy /Y "%SRC%\js\app.js"           "%REPO%\js\app.js"           > nul
copy /Y "%SRC%\js\audio.js"         "%REPO%\js\audio.js"         > nul
copy /Y "%SRC%\js\config.js"        "%REPO%\js\config.js"        > nul
copy /Y "%SRC%\js\hierarchy.js"     "%REPO%\js\hierarchy.js"     > nul
copy /Y "%SRC%\js\srs.js"           "%REPO%\js\srs.js"           > nul
copy /Y "%SRC%\js\storage.js"       "%REPO%\js\storage.js"       > nul
copy /Y "%SRC%\js\study.js"         "%REPO%\js\study.js"         > nul
copy /Y "%SRC%\js\sync.js"          "%REPO%\js\sync.js"          > nul

echo [1/3] Sync complete.
echo.

REM ── Git commit & push ──
cd /d "%REPO%"

echo [2/3] Staging changes...
git add -A
git status

echo.
echo [3/3] Committing and pushing to GitHub...
git commit -m "deploy: sync from upload folder and push"
git push origin main

echo.
if %errorlevel% equ 0 (
    echo =========================================================================
    echo  [SUCCESS] Push to GitHub completed!
    echo  GitHub Pages will update in 1-2 minutes.
    echo  On smartphone: Settings -^> Clear cache -^> Reload
    echo =========================================================================
) else (
    echo =========================================================================
    echo  [INFO] Nothing new to push, or push succeeded.
    echo =========================================================================
)
echo.
pause
