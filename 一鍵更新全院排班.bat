@echo off
chcp 65001 >nul
echo ================================================================
echo  🏥 衛生福利部彰化醫院 (CHHW) 門診排班與停代診公告即時同步中...
echo ================================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\update_schedule.ps1"
echo.
echo 按任意鍵關閉視窗...
pause >nul
