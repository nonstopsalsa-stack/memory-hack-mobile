@echo off
cd /d "C:\Users\nonst\recover\obsidian folder\006_AI_Workspace\anki-mobile"
echo =========================================================================
echo    MEMORY HACK Mobile - GitHub Push (v1.1.1)
echo =========================================================================
echo.
echo [1/2] Sending latest code to GitHub repository...
git push origin main
echo.
if %errorlevel% equ 0 (
    echo =========================================================================
    echo  [SUCCESS] Push to GitHub completed successfully!
    echo  GitHub Pages will be updated in 1-2 minutes.
    echo  Please restart or refresh your smartphone PWA app.
    echo =========================================================================
) else (
    echo =========================================================================
    echo  [ERROR] Git push failed. Please see error details above.
    echo =========================================================================
)
echo.
pause
