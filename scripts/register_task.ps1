$vbsPath = Join-Path $PSScriptRoot "run_silent.vbs"
$taskName = "CHHW_OPD_Schedule_Auto_Sync"

$action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$vbsPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -WakeToRun -StartWhenAvailable -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "CHHW OPD Schedule 30-min silent sync with WakeToRun" -Force | Out-Null

$task = Get-ScheduledTask -TaskName $taskName
Write-Host "TaskName: $($task.TaskName)"
Write-Host "State: $($task.State)"
Write-Host "WakeToRun: $($task.Settings.WakeToRun)"
Write-Host "Interval: $($task.Triggers[0].Repetition.Interval)"
Write-Host "Duration: $($task.Triggers[0].Repetition.Duration)"
Write-Host "SUCCESS: Windows Scheduled Task 100% configured!"
