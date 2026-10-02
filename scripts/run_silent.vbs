' CHHW Schedule Silent Auto-Sync
WScript.Sleep 30000

Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
projectDir = fso.GetParentFolderName(scriptDir)
ps1Path = fso.BuildPath(scriptDir, "update_schedule.ps1")

Set WshShell = CreateObject("WScript.Shell")
WshShell.CurrentDirectory = projectDir
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & ps1Path & """"
WshShell.Run cmd, 0, False
