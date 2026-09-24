' 衛生福利部彰化醫院 (CHHW) 門診排班背景無聲自動同步程式
' 開機後等待 30 秒 (待網路就緒)，在背景 100% 靜默執行，不彈出任何黑底視窗
WScript.Sleep 30000

Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = "C:\Users\X4715G\Desktop\Antigravity 專案\門診時段交叉查詢與醫師代碼查詢系統"
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\Users\X4715G\Desktop\Antigravity 專案\門診時段交叉查詢與醫師代碼查詢系統\scripts\update_schedule.ps1"""
WshShell.Run cmd, 0, False
