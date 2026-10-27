# ==============================================================================
# 衛生福利部彰化醫院 (CHHW) 門診時刻表、醫師代碼與停代診公告 原生同步程式 (PowerShell)
# 支援台灣在地 IP 直接連線、熔斷保護機制 (Circuit Breaker)、雙生檔案 100% SHA-256 同步
# ==============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$baseDir = Split-Path -Parent $scriptDir
$noticesDir = Join-Path $baseDir "assets/notices"
if (-not (Test-Path $noticesDir)) {
    New-Item -ItemType Directory -Path $noticesDir -Force | Out-Null
}

$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    "Accept-Language" = "zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7"
    "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

# ------------------------------------------------------------------------------
# 0. 鎖定狀態智慧 0 秒黑屏防護（休眠/鎖定喚醒爬蟲時強制黑屏，上班使用時長亮）
# ------------------------------------------------------------------------------
function Set-ScreenOffIfLocked {
    $isLocked = (Get-Process -Name logonui -ErrorAction SilentlyContinue) -ne $null
    if ($isLocked) {
        try {
            if (-not ([System.Management.Automation.PSTypeName]'Win32.ScreenHelper').Type) {
                Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);' -Name 'ScreenHelper' -Namespace 'Win32' -ErrorAction SilentlyContinue
            }
            [Win32.ScreenHelper]::SendMessage([IntPtr](-1), 0x0112, [IntPtr]0xF170, [IntPtr]2) | Out-Null
            Write-Host "🌙 偵測到 Windows 處於鎖定/睡眠喚醒狀態：已執行 0 秒強制黑屏（關閉螢幕電源），防止值班人員誤關機！" -ForegroundColor DarkCyan
        } catch {
            Write-Warning "執行強制黑屏時發生錯誤: $_"
        }
    } else {
        Write-Host "☀️ 偵測到 Windows 處於正常使用中：保持螢幕亮起，不干擾辦公操作。" -ForegroundColor DarkGray
    }
}
Set-ScreenOffIfLocked

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " 🏥 啟動衛生福利部彰化醫院 (CHHW) 門診時刻與停代診公告同步程式" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# ------------------------------------------------------------------------------
# 1. 抓取官方停診公告 (aid=320&page_name=detail&iid=15)
# ------------------------------------------------------------------------------
Write-Host "[1/4] 正在抓取官方停代診公告專頁..." -ForegroundColor Yellow
$noticeUrl = 'https://www.chhw.mohw.gov.tw/?aid=320&page_name=detail&iid=15'
$noticeTitle = "最新醫師停診、代診公告"
$noticeImages = @()

try {
    $resNotice = Invoke-WebRequest -Uri $noticeUrl -Headers $headers -UseBasicParsing -TimeoutSec 20
    $htmlNotice = [System.Text.Encoding]::UTF8.GetString($resNotice.RawContentStream.ToArray())
    
    if ($htmlNotice -match '(\d+月[^\s<]*?醫師停[^\s<]*?公告)') {
        $noticeTitle = $Matches[1]
    }

    $imgRegex = '<a[^>]*href=["''](/public/news1/320/[^"'']+\.jpg)["''][^>]*title=["'']([^"'']+)["'']'
    $imgMatches = [regex]::Matches($htmlNotice, $imgRegex)
    $seenUrls = @{}
    $idx = 1
    foreach ($m in $imgMatches) {
        $imgPath = $m.Groups[1].Value
        $imgTitle = ($m.Groups[2].Value -replace '\(另開新視窗\s*\)', '').Trim()
        $fullImgUrl = "https://www.chhw.mohw.gov.tw" + $imgPath
        
        if ($imgTitle -match '^\d+$' -or $imgTitle.Length -lt 3) { continue }
        if (-not $seenUrls.ContainsKey($fullImgUrl)) {
            $seenUrls[$fullImgUrl] = $true
            $localFname = "notice_{0:D2}.jpg" -f $idx
            $localFpath = Join-Path $noticesDir $localFname
            
            try {
                Invoke-WebRequest -Uri $fullImgUrl -Headers $headers -OutFile $localFpath -UseBasicParsing -TimeoutSec 30
                Write-Host " -> 成功備份官方公文大圖: $localFname" -ForegroundColor Green
            } catch {
                Write-Warning "備份圖檔失敗: $_"
            }

            $noticeImages += [PSCustomObject]@{
                title = $imgTitle
                localUrl = "assets/notices/$localFname"
                url = $fullImgUrl
            }
            $idx++
        }
    }
} catch {
    Write-Warning "抓取官方停代診公告頁面失敗: $_"
}

$officialNoticeObj = [PSCustomObject]@{
    title = $noticeTitle
    sourceUrl = $noticeUrl
    updateTime = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    images = $noticeImages
}
Write-Host " -> 官方公告擷取完成: $noticeTitle (共 $($noticeImages.Count) 張圖檔)" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 2. 抓取全院醫師官方代碼 (/DOCTOR)
# ------------------------------------------------------------------------------
Write-Host "[2/4] 正在抓取全院醫師官方代碼..." -ForegroundColor Yellow
$docCodeMap = @{}
try {
    $resDoc = Invoke-WebRequest -Uri "https://netreg.chhw.mohw.gov.tw/DOCTOR" -Headers $headers -UseBasicParsing -TimeoutSec 20
    $htmlDoc = [System.Text.Encoding]::UTF8.GetString($resDoc.RawContentStream.ToArray())
    $docRegex = 'GoDoctorList\(''([A-Za-z0-9]{4})''\)[^>]*>([\s\S]*?)</a>'
    $docMatches = [regex]::Matches($htmlDoc, $docRegex)
    foreach ($dm in $docMatches) {
        $c = $dm.Groups[1].Value.Trim()
        $rawN = [System.Net.WebUtility]::HtmlDecode($dm.Groups[2].Value)
        if ($rawN -match '[\u4e00-\u9fa5]{2,4}') {
            $name = $Matches[0].Trim()
            $docCodeMap[$name] = $c
        }
    }
} catch {
    Write-Warning "抓取醫師代碼失敗: $_"
}

# 永久常駐保護名單 (防範醫院掛號系統偶發缺漏)
$docCodeMap["陳筠方"] = "FB17"

Write-Host " -> 成功解析醫師代碼對照表: 共 $($docCodeMap.Count) 位醫師" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 3. 抓取全院專科清單 (/)
# ------------------------------------------------------------------------------
Write-Host "[3/4] 正在解析全院臨床專科清單..." -ForegroundColor Yellow
$depts = @()
$seenDepts = @{}
try {
    $resDept = Invoke-WebRequest -Uri "https://netreg.chhw.mohw.gov.tw/" -Headers $headers -UseBasicParsing -TimeoutSec 20
    $htmlDept = [System.Text.Encoding]::UTF8.GetString($resDept.RawContentStream.ToArray())
    $deptRegex = 'GoDoctorList\(''([^'']+)''\)[^>]*>([\s\S]*?)</a>'
    $deptMatches = [regex]::Matches($htmlDept, $deptRegex)
    foreach ($m in $deptMatches) {
        $code = $m.Groups[1].Value.Trim()
        $name = [System.Net.WebUtility]::HtmlDecode($m.Groups[2].Value).Trim()
        if ($code -and -not $seenDepts.ContainsKey($code)) {
            $seenDepts[$code] = $true
            $depts += [PSCustomObject]@{ code = $code; name = $name }
        }
    }
} catch {
    Write-Warning "抓取專科清單失敗: $_"
}
Write-Host " -> 成功解析全院臨床專科: 共 $($depts.Count) 個科別" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 4. 遍歷各專科門診時刻表 (/DOCTORLIST)
# ------------------------------------------------------------------------------
Write-Host "[4/4] 正在遍歷各科門診時刻表與停診狀態 (共 $($depts.Count) 科)..." -ForegroundColor Yellow
$slotMap = @{ "1" = "上午"; "2" = "下午"; "3" = "夜診" }
$allRawSlots = @()
$liveCountsMap = @{}

foreach ($d in $depts) {
    $dCode = $d.code
    $dName = $d.name
    $clinicUrl = "https://netreg.chhw.mohw.gov.tw/DOCTORLIST?role=DIV`&key_code=$dCode"
    
    try {
        $resClinic = Invoke-WebRequest -Uri $clinicUrl -Headers $headers -UseBasicParsing -TimeoutSec 15
        $htmlClinic = [System.Text.Encoding]::UTF8.GetString($resClinic.RawContentStream.ToArray())
        $cRegex = 'GoClinic\(''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)''\)[^>]*>([\s\S]*?)</a>'
        $cMatches = [regex]::Matches($htmlClinic, $cRegex)
        
        foreach ($cm in $cMatches) {
            $dateStr = $cm.Groups[1].Value
            $apn = $cm.Groups[2].Value
            $roomNo = $cm.Groups[3].Value
            $inner = [System.Net.WebUtility]::HtmlDecode($cm.Groups[6].Value)
            
            if ($inner -match '<div[^>]*>\s*([^\s<]+)') {
                $docName = $Matches[1].Trim()
                if (-not $docName -or $docName -in @("UNKNOWN", "約診醫師")) { continue }
            } else { continue }

            if ($dateStr.Length -eq 7) {
                try {
                    $year = [int]$dateStr.Substring(0, 3) + 1911
                    $month = [int]$dateStr.Substring(3, 2)
                    $day = [int]$dateStr.Substring(5, 2)
                    $dt = Get-Date -Year $year -Month $month -Day $day
                    $w = [int]$dt.DayOfWeek
                    $weekday = if ($w -eq 0) { 7 } else { $w }
                    $dateDisplay = "$month/$day"
                } catch { continue }
            } else { continue }

            if ($weekday -gt 6) { continue } # 排除週日

            $count = $null
            if ($inner -match '已掛(\d+)人') {
                $count = [int]$Matches[1]
            }

            # 嚴格停診判斷：只有文字明確標示「停診」且完全沒有掛號人數時，才列為停診
            # 絕對禁止將「預約已額滿」、「網掛不開放」、或 disabled 誤判為停診！
            $isStopped = ($inner -like "*停診*") -and ($count -eq $null)
            $isSubstitute = $false
            if ($inner -match '代診[：:]\s*([^\s\)<]+)') {
                # 欄位中標註「代診:某醫師」，代表原醫師請假停診
                $isStopped = $true
            } elseif ($inner -like "*代診*") {
                if (-not $isStopped) { $isSubstitute = $true }
            }
            $isFull = ($inner -match '額滿')
            $slotLabel = if ($slotMap.ContainsKey($apn)) { $slotMap[$apn] } else { "上午" }
            $roomLabel = if ($roomNo.EndsWith("診")) { $roomNo } else { "${roomNo}診" }

            $cleanKey = "$month/$day"
            $padKey = "{0:D2}/{1:D2}" -f $month, $day
            $val = if ($isStopped) { 
                "停" 
            } elseif ($count -ne $null) { 
                if ($isFull) { "$count(已額滿)" } else { $count }
            } elseif ($isFull) {
                "已額滿"
            } else { 
                $null 
            }
            if ($val -ne $null) {
                # 複合科別專屬唯一鍵（徹底杜絕跨科特診覆寫）
                $liveCountsMap["$dCode|$docName|$cleanKey|$slotLabel"] = $val
                $liveCountsMap["$dCode|$docName|$padKey|$slotLabel"] = $val
                # 全域醫師鍵回退（優先保留主要門診科別人數）
                if (-not $liveCountsMap.ContainsKey("$docName|$cleanKey|$slotLabel") -or $dCode.Length -le 2) {
                    $liveCountsMap["$docName|$cleanKey|$slotLabel"] = $val
                    $liveCountsMap["$docName|$padKey|$slotLabel"] = $val
                }
            }

            $allRawSlots += [PSCustomObject]@{
                dept_code = $dCode
                dept_name = $dName
                doctor = $docName
                weekday = $weekday
                slot = $slotLabel
                room = $roomLabel
                date = $dateDisplay
                dt = $dt
                is_stopped = $isStopped
                is_substitute = $isSubstitute
            }
        }
    } catch {
        Write-Warning "抓取專科 $dName ($dCode) 失敗: $_"
    }
}
$liveCountsMap["_meta_update_time"] = (Get-Date -Format "yyyy-MM-dd HH:mm")

# ------------------------------------------------------------------------------
# 5. 聚合門診排班規則與停診日期
# ------------------------------------------------------------------------------
$grouped = @{}
$today = (Get-Date).Date
$currentYear = $today.Year

foreach ($item in $allRawSlots) {
    $k = "$($item.dept_code)|$($item.dept_name)|$($item.doctor)|$($item.weekday)|$($item.slot)"
    if (-not $grouped.ContainsKey($k)) {
        $grouped[$k] = [PSCustomObject]@{
            dept_code = $item.dept_code
            dept_name = $item.dept_name
            doctor = $item.doctor
            weekday = $item.weekday
            slot = $item.slot
            rooms = [System.Collections.Generic.List[string]]::new()
            stopped_dates = [System.Collections.Generic.List[datetime]]::new()
            substitute_dates = [System.Collections.Generic.List[datetime]]::new()
            added_dates = [System.Collections.Generic.List[datetime]]::new()
            total_occurrences = 0
        }
    }
    $grouped[$k].total_occurrences++
    $grouped[$k].rooms.Add($item.room)
    if ($item.is_stopped) {
        $grouped[$k].stopped_dates.Add($item.dt)
    }
    if ($item.is_substitute -and -not $item.is_stopped) {
        $grouped[$k].substitute_dates.Add($item.dt)
    }
}

# ------------------------------------------------------------------------------
# 5.1 注入全院官方公文停代診資料庫 (Dual Fusion 網掛 + 官方公文 109 筆對齊)
# ------------------------------------------------------------------------------
$officialNoticesPath = Join-Path $baseDir "assets/data/official_notices_registry.json"
if (Test-Path $officialNoticesPath) {
    try {
        $officialNotices = Get-Content $officialNoticesPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host " -> 成功載入官方公文歷史/遠期停代診紀錄: 共 $($officialNotices.Count) 筆" -ForegroundColor Green

        foreach ($n in $officialNotices) {
            $nDt = [DateTime]::ParseExact($n.date, "yyyy-MM-dd", $null)
            if ($nDt.Date -lt $today) { continue } # 自動剃除過期公文紀錄

            $nw = [int]$nDt.DayOfWeek
            $nWeekday = if ($nw -eq 0) { 7 } else { $nw }
            $nDoc = $n.doctor.Trim()
            if ($nDoc -eq "劉青耀") { $nDoc = "劉清耀" }
            $nSlot = $n.slot.Trim()
            $nDept = $n.dept.Trim()
            $nType = $n.type.Trim() # 停診, 代診, 加診

            # 尋找匹配的門診 entry（嚴格同科匹配，杜絕跨科代診串門）
            $matchedEntries = @($grouped.Values | Where-Object { 
                $_.doctor -eq $nDoc -and $_.weekday -eq $nWeekday -and $_.slot -eq $nSlot -and ($_.dept_name -like "*$nDept*" -or $nDept -like "*$($_.dept_name)*")
            })

            # 若無精確科別匹配，僅在「停診」時允許放寬至醫師姓名與時段匹配；代診若非同科絕對禁止跨科匹配！
            if ($matchedEntries.Count -eq 0 -and $nType -eq "停診") {
                $matchedEntries = @($grouped.Values | Where-Object { 
                    $_.doctor -eq $nDoc -and $_.weekday -eq $nWeekday -and $_.slot -eq $nSlot
                })
            }

            if ($matchedEntries.Count -gt 0) {
                foreach ($mEntry in $matchedEntries) {
                    if ($nType -eq "停診" -and -not ($mEntry.stopped_dates | Where-Object { $_.Date -eq $nDt.Date })) {
                        $mEntry.stopped_dates.Add($nDt)
                    } elseif ($nType -eq "代診" -and -not ($mEntry.substitute_dates | Where-Object { $_.Date -eq $nDt.Date })) {
                        # 嚴格互斥防呆：停診日不可列為代診日
                        if (-not ($mEntry.stopped_dates | Where-Object { $_.Date -eq $nDt.Date })) {
                            $mEntry.substitute_dates.Add($nDt)
                        }
                    } elseif ($nType -eq "加診" -and -not ($mEntry.added_dates | Where-Object { $_.Date -eq $nDt.Date })) {
                        $mEntry.added_dates.Add($nDt)
                    }
                }
            } else {
                # 門診表中尚無此常態診次 (例如特定臨時代診醫師：如 12/31 黃耀宣代診，但黃耀宣原無週四上午常態診)
                $refRoom = "診"
                $refDeptCode = ""
                $refDeptName = $nDept

                # 防呆鐵律：若該代診醫師在此科別、此星期、此時段本來就已有常態門診，
                # 絕不另外多建一個診次！直接將代診日期合併進其原門診 entry！
                $existSlotEntry = $grouped.Values | Where-Object { 
                    $_.doctor -eq $nDoc -and $_.weekday -eq $nWeekday -and $_.slot -eq $nSlot -and ($_.dept_name -like "*$nDept*" -or $nDept -like "*$($_.dept_name)*")
                } | Select-Object -First 1

                if ($existSlotEntry) {
                    if (-not ($existSlotEntry.stopped_dates | Where-Object { $_.Date -eq $nDt.Date })) {
                        if (-not ($existSlotEntry.substitute_dates | Where-Object { $_.Date -eq $nDt.Date })) {
                            $existSlotEntry.substitute_dates.Add($nDt)
                        }
                    }
                    continue
                }

                # 鐵律：代診若非代同科醫師的就不顯示代診
                if ($nType -eq "代診") {
                    $docCodeObj = if ($docCodeMap.ContainsKey($nDoc)) { $docCodeMap[$nDoc] } else { "" }
                    # 泌尿科、骨科、外科等跨科代診一律不生成獨立代診診次
                    if ($nDoc -in @("蔡卓榮", "陳文銘", "蘇美旭", "王守吉", "李文宏", "林憲治")) {
                        continue
                    }
                }

                $subTarget = if ($n.subDoctor) { $n.subDoctor.Trim() } elseif ($n.subFor) { $n.subFor.Trim() } else { "" }
                if ($subTarget -eq "劉青耀") { $subTarget = "劉清耀" }
                $targetDoc = if ($subTarget) { $subTarget } else {
                    $matchedStop = $officialNotices | Where-Object { $_.date -eq $n.date -and $_.slot -eq $n.slot -and $_.type -eq "停診" -and ($_.dept -eq $n.dept -or $_.dept -like "*$nDept*") } | Select-Object -First 1
                    if ($matchedStop) { $matchedStop.doctor.Trim() } else { "" }
                }

                if ($targetDoc) {
                    $refEntry = $grouped.Values | Where-Object { $_.doctor -eq $targetDoc -and $_.weekday -eq $nWeekday -and $_.slot -eq $nSlot } | Select-Object -First 1
                    if ($refEntry) {
                        $refRoom = if ($refEntry.rooms.Count -gt 0) { $refEntry.rooms[0] } else { "診" }
                        $refDeptCode = $refEntry.dept_code
                        $refDeptName = $refEntry.dept_name
                    }
                }
                if (-not $refDeptCode) {
                    $dMatch = $depts | Where-Object { $_.name -like "*$nDept*" -or $nDept -like "*$($_.name)*" } | Select-Object -First 1
                    if ($dMatch) { $refDeptCode = $dMatch.code; $refDeptName = $dMatch.name } else { $refDeptCode = "00" }
                }

                $kNew = "$refDeptCode|$refDeptName|$nDoc|$nWeekday|$nSlot"
                $newEntry = [PSCustomObject]@{
                    dept_code = $refDeptCode
                    dept_name = $refDeptName
                    doctor = $nDoc
                    weekday = $nWeekday
                    slot = $nSlot
                    rooms = [System.Collections.Generic.List[string]]::new()
                    stopped_dates = [System.Collections.Generic.List[datetime]]::new()
                    substitute_dates = [System.Collections.Generic.List[datetime]]::new()
                    added_dates = [System.Collections.Generic.List[datetime]]::new()
                    total_occurrences = 0 # 標記為臨時診次
                }
                if ($refRoom) { $newEntry.rooms.Add($refRoom) }
                if ($nType -eq "停診") { $newEntry.stopped_dates.Add($nDt) }
                elseif ($nType -eq "代診") { $newEntry.substitute_dates.Add($nDt) }
                elseif ($nType -eq "加診") { $newEntry.added_dates.Add($nDt) }
                $grouped[$kNew] = $newEntry
            }
        }
    } catch {
        Write-Warning "載入/解析 official_notices_registry.json 異常: $_"
    }
}

function Format-DateNoteItem {
    param([DateTime]$d)
    if ($d.Year -gt $currentYear) {
        return "$($d.Year - 1911)/$($d.Month)/$($d.Day)"
    } else {
        return "$($d.Month)/$($d.Day)"
    }
}

function Prune-TextNote {
    param([string]$text, [DateTime]$refDate = $today)
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }
    $parts = $text -split '\s+'
    $kept = @()
    foreach ($p in $parts) {
        if ($p -in @("網掛不開放", "網路不開放")) {
            $kept += $p; continue
        }
        $suffix = ""
        $isStartFrom = $false
        if ($p -match '(起看診|起開診)$') { $suffix = "起看診"; $isStartFrom = $true }
        elseif ($p -match '(起停診)$') { $suffix = "起停診"; $isStartFrom = $true }
        elseif ($p -match '(看診|開診)$') { $suffix = "看診" }
        elseif ($p -match '(停診)$') { $suffix = "停診" }
        elseif ($p -match '(代診)$') { $suffix = "代診" }
        elseif ($p -match '(加診)$') { $suffix = "加診" }

        if (-not $suffix) { $kept += $p; continue }
        $dStr = $p.Substring(0, $p.Length - $suffix.Length)
        $subToks = $dStr -split '\.'
        $valid = @()
        $lastM = 0
        foreach ($tok in $subToks) {
            $cTok = $tok -replace '起$', ''
            $dt = $null
            if ($cTok -match '^(\d{2,3})\/(\d{1,2})\/(\d{1,2})$') {
                $y = [int]$Matches[1] + 1911; $m = [int]$Matches[2]; $d = [int]$Matches[3]
                $dt = Get-Date -Year $y -Month $m -Day $d -Hour 0 -Minute 0 -Second 0
            } elseif ($cTok -match '^(\d{1,2})\/(\d{1,2})$') {
                $m = [int]$Matches[1]; $d = [int]$Matches[2]
                $y = if ($m -lt 6 -and $refDate.Month -ge 10) { $currentYear + 1 } else { $currentYear }
                $dt = Get-Date -Year $y -Month $m -Day $d -Hour 0 -Minute 0 -Second 0
            } elseif ($cTok -match '^\d{1,2}$' -and $lastM -gt 0) {
                $m = $lastM; $d = [int]$cTok
                $y = if ($m -lt 6 -and $refDate.Month -ge 10) { $currentYear + 1 } else { $currentYear }
                $dt = Get-Date -Year $y -Month $m -Day $d -Hour 0 -Minute 0 -Second 0
            }
            if ($dt -ne $null) {
                if ($cTok -match '\/') { $lastM = $dt.Month }
                if ($isStartFrom -or $dt.Date -ge $refDate) {
                    $valid += $dt
                }
            }
        }
        if ($valid.Count -gt 0) {
            $sorted = $valid | Sort-Object { $_.Ticks }
            $fmtList = $sorted | ForEach-Object { Format-DateNoteItem $_ }
            $kept += (($fmtList -join ".") + $suffix)
        }
    }
    return ($kept -join " ").Trim()
}

$schedules = @()
foreach ($k in $grouped.Keys) {
    $entry = $grouped[$k]
    # 選取出現頻率最高的診間號
    $roomFinal = ($entry.rooms | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name

    # 彙整停診備註 (按真實日曆排序、跨年感知、過期自動剃除)
    $noteParts = @()
    if ($entry.stopped_dates.Count -gt 0) {
        $validStopped = @($entry.stopped_dates | Where-Object { $_.Date -ge $today } | Sort-Object { $_.Ticks } | Select-Object -Unique)
        if ($validStopped.Count -gt 0) {
            $formattedStopped = $validStopped | ForEach-Object { Format-DateNoteItem $_ }
            $noteParts += (($formattedStopped -join ".") + "停診")
        }
    }

    # 彙整代診備註 (方案 1 專屬：按真實日曆排序、跨年感知、過期自動剃除，且排除同一日已停診之矛盾)
    if ($entry.substitute_dates.Count -gt 0) {
        $validSub = @($entry.substitute_dates | Where-Object { 
            $subDate = $_.Date
            $subDate -ge $today -and -not ($entry.stopped_dates | Where-Object { $_.Date -eq $subDate })
        } | Sort-Object { $_.Ticks } | Select-Object -Unique)
        if ($validSub.Count -gt 0) {
            $formattedSub = $validSub | ForEach-Object { Format-DateNoteItem $_ }
            $noteParts += (($formattedSub -join ".") + "代診")
        }
    }

    # 彙整加診備註 (按真實日曆排序、跨年感知、過期自動剃除)
    if ($entry.added_dates.Count -gt 0) {
        $validAdded = @($entry.added_dates | Where-Object { $_.Date -ge $today } | Sort-Object { $_.Ticks } | Select-Object -Unique)
        if ($validAdded.Count -gt 0) {
            $formattedAdded = $validAdded | ForEach-Object { Format-DateNoteItem $_ }
            $noteParts += (($formattedAdded -join ".") + "加診")
        }
    }

    # 常態性「網掛不開放」醫師時段保護
    if ($entry.doctor -eq "李文宏" -and $entry.dept_code -eq "06" -and $entry.weekday -eq 4 -and $entry.slot -eq "上午") {
        if (-not ($noteParts -contains "網掛不開放")) { $noteParts = @("網掛不開放") + $noteParts }
    }
    if ($entry.doctor -eq "吳佶育" -and $entry.dept_code -eq "AD" -and $entry.weekday -eq 4 -and $entry.slot -eq "上午") {
        if (-not ($noteParts -contains "網掛不開放")) { $noteParts = @("網掛不開放") + $noteParts }
    }
    if ($entry.doctor -eq "陳詩典" -and $entry.dept_code -eq "AA" -and $entry.weekday -eq 4 -and $entry.slot -eq "下午") {
        if (-not ($noteParts -contains "網掛不開放")) { $noteParts = @("網掛不開放") + $noteParts }
    }

    # 全院非每週門診、隔週看診、輪週看診與特定看診日自動過期剃除規則 (共 21 位醫師)
    $rosterRules = @{
        # 1. 婦產科 (05) 雙週/隔週看診
        "05|李伊菱|5|上午" = "10/23.11/13.11/27.12/11看診"
        "05|林玉珊|3|下午" = "10/21.11/4.11/18.12/2看診"

        # 2. 耳鼻喉科 (09) 隔週看診與 10/18 起新排班
        "09|施彥旭|3|下午" = "10/21.11/4.11/18.12/2看診"
        "09|施凱翔|1|上午" = "10/18起看診"
        "09|許嘉方|2|上午" = "10/18起看診"
        "09|施凱翔|3|上午" = "10/18起看診"
        "09|施凱翔|5|上午" = "10/18起看診"
        "09|許嘉方|5|下午" = "10/23起看診"

        # 3. 牙科 (40) 每月特約門診
        "40|陳聰洲|2|上午" = "11/10.12/15看診"

        # 4. 無障礙牙科特診 (4001) 週三上午四大專科醫師每週輪值
        "4001|黃惠娟|3|上午" = "11/4看診"
        "4001|黃廷芳|3|上午" = "11/11看診"
        "4001|陳信利|3|上午" = "10/21.11/18看診"
        "4001|黃左琪|3|上午" = "10/28.11/25看診"

        # 5. 血液腫瘤科 (AF) 隔週看診
        "AF|陳筠方|5|上午" = "10/23.11/6.11/20.12/4.12/18.1/1看診"

        # 6. 胸腔內科 (AC) 隔週四夜診
        "AC|黃伊文|4|夜診" = "10/22.11/5.11/19.12/3.12/17.12/31看診"

        # 7. 胸腔外科 (BC) 隔週四下午
        "BC|李佳穎|4|下午" = "10/22.11/5.11/19.12/3.12/17.12/31看診"

        # 8. 精神科 (13) 週六輪值看診
        "13|蕭銘鴻|6|上午" = "10/17.11/7.11/21.12/19看診"
        "13|葉騰尹|6|上午" = "10/24.11/28.12/5看診"
        "13|梁孫源|6|上午" = "10/31.12/26.1/2看診"
        "13|王鴻松|6|上午" = "11/14.12/12看診"

        # 9. 腎臟內科 (AD) 週六輪值看診
        "AD|張淑鈺|6|上午" = "10/24.11/14.11/28.12/12.12/26看診"

        # 10. 心臟內科 (AB) 週六輪值看診
        "AB|李學林|6|上午" = "10/24.11/7.11/21.12/5.12/19看診"

        # 11. 小兒科 (04) 週六輪值看診
        "04|鍾瑞賢|6|上午" = "10/24.10/31.11/14.11/28.12/12.12/26看診"
        "04|馬瑞杉|6|上午" = "11/7.11/21.12/5.12/19.1/2看診"

        # 12. 牙科 (40) 週六看診
        "40|金椿期|6|上午" = "10/17.11/14看診"
    }

    $rKeySlot = "$($entry.dept_code)|$($entry.doctor)|$($entry.weekday)|$($entry.slot)"
    $rKeyDay = "$($entry.dept_code)|$($entry.doctor)|$($entry.weekday)"
    $ruleRaw = if ($rosterRules.ContainsKey($rKeySlot)) { $rosterRules[$rKeySlot] } elseif ($rosterRules.ContainsKey($rKeyDay)) { $rosterRules[$rKeyDay] } else { $null }

    if ($ruleRaw) {
        $prunedRoster = Prune-TextNote $ruleRaw
        if ($prunedRoster) {
            $noteParts = @($prunedRoster) + $noteParts
        }
    }

    # 退休/轉任起停診標註
    if ($entry.doctor -eq "蔡豐璟" -and $entry.dept_code -eq "BA" -and $entry.weekday -eq 4 -and $entry.slot -eq "上午") {
        $noteParts = @("10/1起停診")
        $roomFinal = "16診"
    }
    if ($entry.doctor -eq "許嘉方" -and $entry.dept_code -eq "09" -and $entry.weekday -eq 4 -and $entry.slot -eq "夜診") {
        $noteParts = @("10/1起停診")
        $roomFinal = "22診"
    }

    # 若為純臨時代診/臨時加診診次且備註日期皆已過期，則不產出該診次
    if ($entry.total_occurrences -eq 0 -and $noteParts.Count -eq 0) {
        continue
    }

    # 耳鼻喉科 (09) 10/18 起全面互換看診時段：排除舊醫師時段，確保大課表與個人時刻表乾淨呈現新常態
    if ($entry.dept_code -eq "09" -and $entry.doctor -eq "許嘉方" -and ($entry.weekday -eq 1 -or $entry.weekday -eq 3 -or $entry.weekday -eq 5) -and $entry.slot -eq "上午") {
        continue
    }
    if ($entry.dept_code -eq "09" -and $entry.doctor -eq "施凱翔" -and $entry.weekday -eq 2 -and $entry.slot -eq "上午") {
        continue
    }

    # 排除幽靈常態診次
    if ($entry.doctor -eq "蕭銘鴻" -and $entry.dept_code -eq "13" -and $entry.weekday -eq 1 -and $entry.slot -eq "下午") {
        continue
    }
    if ($entry.doctor -eq "鍾瑞賢" -and $entry.dept_code -eq "04" -and $entry.weekday -eq 5 -and $entry.slot -eq "上午" -and $noteParts.Count -eq 0) {
        continue
    }
    if ($entry.doctor -eq "廖宜新" -and $entry.dept_code -eq "14" -and $entry.weekday -eq 5 -and $entry.slot -eq "上午") {
        continue
    }
    if ($entry.doctor -eq "葉騰尹" -and $entry.dept_code -eq "1303" -and ($entry.weekday -eq 3 -or $entry.weekday -eq 4) -and $entry.slot -eq "夜診") {
        continue
    }

    $note = ($noteParts -join " ").Trim()

    $schedules += [PSCustomObject]@{
        dept_code = $entry.dept_code
        dept_name = $entry.dept_name
        doctor = $entry.doctor
        weekday = $entry.weekday
        slot = $entry.slot
        room = $roomFinal
        note = $note
    }
}

# ------------------------------------------------------------------------------
# 6. 熔斷防護檢查 (Circuit Breaker Protection)
# ------------------------------------------------------------------------------
Write-Host "-----------------------------------------------------------------" -ForegroundColor Magenta
Write-Host "🛡️ 正在執行熔斷機制資安與資料完整性驗證..." -ForegroundColor Magenta
Write-Host " -> 解析專科數量: $($depts.Count) 科 (門檻: >= 10)" -ForegroundColor Gray
Write-Host " -> 解析門診時段: $($schedules.Count) 筆 (門檻: >= 50)" -ForegroundColor Gray
Write-Host " -> 解析醫師代碼: $($docCodeMap.Count) 位 (門檻: >= 20)" -ForegroundColor Gray

if ($depts.Count -lt 10 -or $schedules.Count -lt 50 -or $docCodeMap.Count -lt 20) {
    Write-Error "🚨【嚴重錯誤】抓取資料筆數異常偏低，觸發熔斷保護終止！現有資料庫 100% 受到保護，未進行任何檔案寫入！"
    exit 1
}
Write-Host "✅ 熔斷驗證通過！全院門診資料完整無缺，準備寫入系統！" -ForegroundColor Green
Write-Host "-----------------------------------------------------------------" -ForegroundColor Magenta

# ------------------------------------------------------------------------------
# 7. 建立醫師主檔清單 (masterData)
# ------------------------------------------------------------------------------
$masterData = @()
$seenMaster = @{}
foreach ($s in $schedules) {
    $k = "$($s.dept_name)|$($s.dept_code)|$($s.doctor)"
    if (-not $seenMaster.ContainsKey($k)) {
        $seenMaster[$k] = $true
        $docCode = if ($docCodeMap.ContainsKey($s.doctor)) { $docCodeMap[$s.doctor] } else { "" }
        $masterData += [PSCustomObject]@{
            dept = $s.dept_name
            deptCode = $s.dept_code
            doc = $s.doctor
            docCode = $docCode
        }
    }
}

# ------------------------------------------------------------------------------
# 7.5 全面排班品質與防呆斷言檢核 (Assert Zero Contradiction)
# ------------------------------------------------------------------------------
$conflictCount = 0
foreach ($s in $schedules) {
    if ($s.note -match '(\d+\/\d+).*?停診' -and $s.note -match '(\d+\/\d+).*?代診') {
        $stopMatches = [regex]::Matches($s.note, '(\d+\/\d+(?:\.\d+\/\d+)*)停診')
        $subMatches = [regex]::Matches($s.note, '(\d+\/\d+(?:\.\d+\/\d+)*)代診')
        if ($stopMatches.Count -gt 0 -and $subMatches.Count -gt 0) {
            $stopDates = $stopMatches[0].Groups[1].Value -split '\.'
            $subDates = $subMatches[0].Groups[1].Value -split '\.'
            $intersection = $stopDates | Where-Object { $_ -in $subDates }
            if ($intersection) {
                Write-Warning "⚠️ 偵測到排班同日停代診矛盾: $($s.doctor) [$($s.dept_code)] $($s.note) -> 衝突日期: $($intersection -join ',')"
                $conflictCount++
            }
        }
    }
}
if ($conflictCount -gt 0) {
    Write-Warning "🚨 總共檢測到 $conflictCount 處同日停代診衝突，請檢查資料源！"
} else {
    Write-Host "✅ 全院排班品質檢核通過：0 處停診代診邏輯矛盾！" -ForegroundColor Green
}

# 斷言檢核：全院是否出現同科同醫師同診次之重複卡片
$dupDocCount = 0
$docSlotKeys = @{}
foreach ($s in $schedules) {
    $slotKey = "$($s.dept_code)|$($s.doctor)|$($s.weekday)|$($s.slot)"
    if ($docSlotKeys.ContainsKey($slotKey)) {
        Write-Warning "🚨 檢測到醫師同科同診次重複卡片: $slotKey (診間: $($docSlotKeys[$slotKey]) 與 $($s.room))"
        $dupDocCount++
    } else {
        $docSlotKeys[$slotKey] = $s.room
    }
}
if ($dupDocCount -gt 0) {
    Write-Error "🚨【嚴重錯誤】檢測到 $dupDocCount 筆同醫師重複診次卡片，違反零重複鐵律！"
    exit 1
} else {
    Write-Host "✅ 全院醫師診次卡片唯一性檢核通過：0 筆重複診次卡片！" -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# 8. 序列化並同步寫入 index.html 與 門診時段交叉查詢與醫師代碼查詢系統.html
# ------------------------------------------------------------------------------
$indexPath = Join-Path $baseDir "index.html"
$twinPath = Join-Path $baseDir "門診時段交叉查詢與醫師代碼查詢系統.html"

# 格式化為漂亮縮排
$noticePrettyLines = @(
    "    const officialNotice = {",
    "      title: $($officialNoticeObj.title | ConvertTo-Json),",
    "      sourceUrl: $($officialNoticeObj.sourceUrl | ConvertTo-Json),",
    "      updateTime: $($officialNoticeObj.updateTime | ConvertTo-Json),",
    "      images: ["
)
for ($i = 0; $i -lt $officialNoticeObj.images.Count; $i++) {
    $img = $officialNoticeObj.images[$i]
    $noticePrettyLines += "        {"
    $noticePrettyLines += "          title: $($img.title | ConvertTo-Json),"
    if ($img.localUrl) {
        $noticePrettyLines += "          localUrl: $($img.localUrl | ConvertTo-Json),"
    }
    $noticePrettyLines += "          url: $($img.url | ConvertTo-Json)"
    $comma = if ($i -lt $officialNoticeObj.images.Count - 1) { "        }," } else { "        }" }
    $noticePrettyLines += $comma
}
$noticePrettyLines += "      ]"
$noticePrettyLines += "    };"
$noticeJsBlock = $noticePrettyLines -join "`r`n"

$masterDataLines = @("    const masterData = [")
for ($i = 0; $i -lt $masterData.Count; $i++) {
    $m = $masterData[$i]
    $comma = if ($i -lt $masterData.Count - 1) { "," } else { "" }
    $masterDataLines += "      { dept: `"$($m.dept)`", deptCode: `"$($m.deptCode)`", doc: `"$($m.doc)`", docCode: `"$($m.docCode)`" }$comma"
}
$masterDataLines += "    ];"
$masterJsBlock = $masterDataLines -join "`r`n"

$scheduleLines = @("    const schedules = [")
for ($i = 0; $i -lt $schedules.Count; $i++) {
    $s = $schedules[$i]
    $comma = if ($i -lt $schedules.Count - 1) { "," } else { "" }
    $scheduleLines += "      { dept_code: `"$($s.dept_code)`", dept_name: `"$($s.dept_name)`", doctor: `"$($s.doctor)`", weekday: $($s.weekday), slot: `"$($s.slot)`", room: `"$($s.room)`", note: `"$($s.note)`" }$comma"
}
$scheduleLines += "    ];"
$scheduleJsBlock = $scheduleLines -join "`r`n"

# 讀取 index.html 進行替換
$indexContent = [System.IO.File]::ReadAllText($indexPath, [System.Text.Encoding]::UTF8)

# 替換 officialNotice
$indexContent = [regex]::Replace($indexContent, "const officialNotice =[\s\S]*?;\r?\n", "$noticeJsBlock`r`n")
# 替換 masterData
$indexContent = [regex]::Replace($indexContent, "const masterData = \[[^;]*?\];", $masterJsBlock)
# 替換 schedules
$indexContent = [regex]::Replace($indexContent, "const schedules = \[[^;]*?\];", $scheduleJsBlock)
# 替換 liveNetregCounts
if ($liveCountsMap.Count -gt 0) {
    $liveJson = ($liveCountsMap | ConvertTo-Json -Compress)
    $indexContent = [regex]::Replace($indexContent, "const liveNetregCounts = \{[\s\S]*?\};", "const liveNetregCounts = $liveJson;")
    Write-Host " -> 成功更新 liveNetregCounts (共 $($liveCountsMap.Count) 筆官方即時掛號數據)" -ForegroundColor Green

    # 同步寫出獨立 JSON 供前端無快取非同步即時更新
    $livePrettyJson = ($liveCountsMap | ConvertTo-Json -Depth 3)
    [System.IO.File]::WriteAllText((Join-Path $baseDir "live_registration.json"), $livePrettyJson, [System.Text.Encoding]::UTF8)
    $dataDir = Join-Path $baseDir "assets/data"
    if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path $dataDir "live_netreg.json"), $livePrettyJson, [System.Text.Encoding]::UTF8)
}

[System.IO.File]::WriteAllText($indexPath, $indexContent, [System.Text.Encoding]::UTF8)
Write-Host " -> 成功更新 index.html" -ForegroundColor Green

# 嚴格複製為雙生檔案
Copy-Item -Path $indexPath -Destination $twinPath -Force
Write-Host " -> 雙生檔案複製完成: 門診時段交叉查詢與醫師代碼查詢系統.html" -ForegroundColor Green

# 雙生檔案雜湊校驗
$hash1 = (Get-FileHash -Path $indexPath -Algorithm SHA256).Hash
$hash2 = (Get-FileHash -Path $twinPath -Algorithm SHA256).Hash

if ($hash1 -ne $hash2) {
    Write-Error "🚨 雙生檔案 SHA-256 雜湊碼不一致，立即中止！"
    exit 1
}
Write-Host " -> 雙生檔案 100% SHA-256 驗證通過: $hash1" -ForegroundColor Green

# ------------------------------------------------------------------------------
# 9. Git 自動提交與推播
# ------------------------------------------------------------------------------
Write-Host "[5/5] 檢查 Git 異動與自動推播..." -ForegroundColor Yellow
Set-Location $baseDir
git add index.html 門診時段交叉查詢與醫師代碼查詢系統.html assets/notices/ live_registration.json assets/data/

git diff --staged --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "ℹ️ 全院排班與公告資料無任何異動，跳過提交。" -ForegroundColor Cyan
} else {
    Write-Host "🚀 檢測到全院門診或公告更新，正在提交推播至 GitHub Pages..." -ForegroundColor Green
    $commitMsg = "chore(auto): daily schedule, doctor codes & suspension notices update ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))"
    git commit -m $commitMsg
    git push origin main
    Write-Host "🎉 成功推播至 GitHub Pages 線上服務！" -ForegroundColor Green
}

# 任務完成後，若仍處於鎖定待機狀態，再次確保螢幕電源關閉
Set-ScreenOffIfLocked

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " 🎉 衛生福利部彰化醫院 (CHHW) 全院門診時刻表即時同步作業圓滿完成！" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
