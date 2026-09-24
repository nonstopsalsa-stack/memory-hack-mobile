@echo off
chcp 65001 >nul
cd /d "C:\Users\nonst\recover\obsidian folder\006_AI_Workspace\anki-mobile"
echo =========================================================================
echo    MEMORY HACK Mobile - GitHub 自動送信ツール (v1.2.2)
echo =========================================================================
echo.
echo [1/3] 変更されたファイルを収集しています...
git add -A
echo.
echo [2/3] 更新内容を記録しています...
git commit -m "feat(mobile): update themes (Roblox/Light/Dark) and bump to v1.2.2"
echo.
echo [3/3] GitHub に最新コードを送信しています...
git push origin main
echo.
if %errorlevel% equ 0 (
    echo =========================================================================
    echo  [成功] GitHubへの送信が正常に完了しました！
    echo.
    echo  約1〜2分後に GitHub Pages が自動更新されます。
    echo  スマホの MEMORY HACK Mobile を開き、設定画面の
    echo  『🗑️ キャッシュを全消去して最新版を取得』をタップしてください。
    echo =========================================================================
) else (
    echo =========================================================================
    echo  [エラー] GitHubへの送信に失敗しました。詳細は上記のエラーを確認してください。
    echo =========================================================================
)
echo.
pause
