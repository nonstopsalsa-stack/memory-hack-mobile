@echo off
chcp 65001 >nul
title MEMORY HACK Mobile - Local Test Server

echo =========================================================================
echo    MEMORY HACK MOBILE - ローカル開発・実機テスト用サーバー
echo =========================================================================
echo.

powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0server.ps1"

pause
