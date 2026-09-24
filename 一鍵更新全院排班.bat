@echo off
title CHHW OPD Schedule Updater
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& { [Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '%~dp0scripts\update_schedule.ps1' }"
pause
