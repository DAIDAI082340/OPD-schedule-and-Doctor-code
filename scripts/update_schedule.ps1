param (
    [switch]$CheckLastDay,
    [switch]$DryRun
)

# 衛生福利部彰化醫院 (CHHW) 門診時刻表、醫師代碼與官方停代診公告 PowerShell 更新腳本
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($CheckLastDay) {
    $today = [DateTime]::Today
    $tomorrow = $today.AddDays(1)
    if ($tomorrow.Day -ne 1) {
        Write-Host "今日 ($($today.ToString('yyyy-MM-dd'))) 不是當月最後一天，安全退出。" -ForegroundColor Yellow
        exit 0
    }
    Write-Host "今日 ($($today.ToString('yyyy-MM-dd'))) 為當月最後一天，開始執行排程！" -ForegroundColor Green
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " 🏥 啟動衛生福利部彰化醫院 (CHHW) 門診時刻與官方停代診公告同步程式" -ForegroundColor Yellow
Write-Host "================================================================" -ForegroundColor Cyan

# 1. 抓取官方停診代診公告專頁 (iid=15)
$noticeUrl = 'https://www.chhw.mohw.gov.tw/?aid=320&page_name=detail&iid=15'
Write-Host "[1/4] 正在抓取官方停代診公告: $noticeUrl" -ForegroundColor Cyan
$noticeTitle = "醫師停診、代診公告"
$noticeImages = @()

try {
    $noticeResp = Invoke-WebRequest -Uri $noticeUrl -UseBasicParsing -TimeoutSec 30
    $noticeHtml = $noticeResp.Content

    $titleMatch = [regex]::Match($noticeHtml, '(\d+月[^\s<]*?醫師停[^\s<]*?公告)')
    if ($titleMatch.Success) {
        $noticeTitle = $titleMatch.Groups[1].Value.Trim()
    }

    $imgMatches = [regex]::Matches($noticeHtml, '<a[^>]*href=["''](/public/news1/320/[^"'']+\.jpg)["''][^>]*title=["'']([^"'']+)["'']')
    $seenUrls = @{}
    foreach ($im in $imgMatches) {
        $rawPath = $im.Groups[1].Value
        $fullUrl = "https://www.chhw.mohw.gov.tw" + $rawPath
        $rawT = $im.Groups[2].Value -replace '\(另開新視窗\s*\)', ''
        $rawT = $rawT.Trim()
        if ($rawT -match '^\d+$' -or $rawT.Length -lt 3 -or $rawPath.Contains('0d49156d349d7fa0e223d371cc3cba4a')) {
            continue
        }
        if (-not $seenUrls.ContainsKey($fullUrl)) {
            $seenUrls[$fullUrl] = $true
            $noticeImages += [PSCustomObject]@{
                title = $rawT
                url = $fullUrl
            }
        }
    }
    Write-Host " -> 成功擷取官方公告標題: $noticeTitle (共 $($noticeImages.Count) 張停代診公文圖檔)" -ForegroundColor Green
} catch {
    Write-Host " -> 抓取公告專頁失敗: $_" -ForegroundColor Red
}

$officialNoticeObj = [PSCustomObject]@{
    title = $noticeTitle
    sourceUrl = $noticeUrl
    updateTime = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    images = $noticeImages
}

# 2. 抓取醫師代碼表 (/DOCTOR)
$doctorUrl = "https://netreg.chhw.mohw.gov.tw/DOCTOR"
Write-Host "[2/4] 正在抓取全院醫師代碼: $doctorUrl" -ForegroundColor Cyan
$docMap = @{}
try {
    $docResp = Invoke-WebRequest -Uri $doctorUrl -UseBasicParsing -TimeoutSec 30
    $docMatches = [regex]::Matches($docResp.Content, 'GoDoctorList\(''(\d{4})''\)[^>]*>([\s\S]*?)</a>')
    foreach ($dm in $docMatches) {
        $code = $dm.Groups[1].Value.Trim()
        $rawName = [System.Net.WebUtility]::HtmlDecode($dm.Groups[2].Value)
        $nameMatch = [regex]::Match($rawName, '[\u4e00-\u9fa5]{2,4}')
        if ($nameMatch.Success) {
            $name = $nameMatch.Value.Trim()
            $docMap[$name] = $code
        }
    }
    Write-Host " -> 成功解析醫師代碼: 共 $($docMap.Count) 位醫師" -ForegroundColor Green
} catch {
    Write-Host " -> 抓取醫師代碼失敗: $_" -ForegroundColor Red
}

# 3. 抓取臨床專科清單 (/)
Write-Host "[3/4] 正在抓取全院臨床專科清單..." -ForegroundColor Cyan
$depts = @()
try {
    $rootResp = Invoke-WebRequest -Uri "https://netreg.chhw.mohw.gov.tw/" -UseBasicParsing -TimeoutSec 30
    $deptMatches = [regex]::Matches($rootResp.Content, 'GoDoctorList\(''([^'']+)''\)[^>]*>([\s\S]*?)</a>')
    $seenDepts = @{}
    foreach ($dm in $deptMatches) {
        $code = $dm.Groups[1].Value.Trim()
        $name = [System.Net.WebUtility]::HtmlDecode($dm.Groups[2].Value).Trim()
        if ($code -and -not $seenDepts.ContainsKey($code)) {
            $seenDepts[$code] = $true
            $depts += [PSCustomObject]@{ code = $code; name = $name }
        }
    }
    Write-Host " -> 成功解析臨床專科清單: 共 $($depts.Count) 個專科" -ForegroundColor Green
} catch {
    Write-Host " -> 抓取專科清單失敗: $_" -ForegroundColor Red
}

# 4. 遍歷各專科門診時刻表並解析停診日
Write-Host "[4/4] 正在抓取並比對各科門診排班與停診日期..." -ForegroundColor Cyan
$slotMap = @{ "1" = "上午"; "2" = "下午"; "3" = "夜診" }
$rawSlots = @()

foreach ($dept in $depts) {
    $dCode = $dept.code
    $dName = $dept.name
    $url = "https://netreg.chhw.mohw.gov.tw/DOCTORLIST?role=DIV&key_code=$dCode"
    try {
        $pResp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
        $cMatches = [regex]::Matches($pResp.Content, 'GoClinic\(''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)''\)[^>]*>([\s\S]*?)</a>')
        foreach ($cm in $cMatches) {
            $dateStr = $cm.Groups[1].Value
            $apn = $cm.Groups[2].Value
            $roomNo = $cm.Groups[3].Value
            $inner = [System.Net.WebUtility]::HtmlDecode($cm.Groups[6].Value)

            $docM = [regex]::Match($inner, '<div[^>]*>\s*([^\s<]+)')
            if (-not $docM.Success) { continue }
            $docName = $docM.Groups[1].Value.Trim()
            if (-not $docName -or $docName -in @("UNKNOWN", "約診醫師")) { continue }

            if ($dateStr.Length -eq 7) {
                $y = [int]$dateStr.Substring(0, 3) + 1911
                $m = [int]$dateStr.Substring(3, 2)
                $d = [int]$dateStr.Substring(5, 2)
                $dt = [DateTime]::new($y, $m, $d)
                $w = [int]$dt.DayOfWeek
                if ($w -eq 0) { continue } # 排除週日
                $dateDisp = "$m/$d"
            } else { continue }

            $isStopped = ($inner.Contains("停診") -or $inner.Contains("停掛"))
            $noteCandidates = [regex]::Matches($inner, '<small[^>]*>([^<]+)</small>')
            $specNote = ""
            foreach ($nc in $noteCandidates) {
                $c = $nc.Groups[1].Value.Trim()
                if ($c -and $c -notmatch '^\(已掛\d+人\)$' -and $c -notin @("停診", "停掛")) {
                    $specNote = $c
                }
            }

            $slotLabel = if ($slotMap.ContainsKey($apn)) { $slotMap[$apn] } else { "上午" }
            $roomLabel = if ($roomNo.EndsWith("診")) { $roomNo } else { "$($roomNo)診" }

            $rawSlots += [PSCustomObject]@{
                DeptCode = $dCode
                DeptName = $dName
                Doctor = $docName
                Weekday = $w
                Slot = $slotLabel
                Room = $roomLabel
                Date = $dateDisp
                DateObj = $dt
                IsStopped = $isStopped
                SpecialNote = $specNote
            }
        }
    } catch {
        # continue
    }
}

# 聚合常規門診與停診日期（唯一鍵排除 Room，防止同一時段產生重複門診卡片）
$grouped = @{}
foreach ($item in $rawSlots) {
    $k = "$($item.DeptCode)___$($item.DeptName)___$($item.Doctor)___$($item.Weekday)___$($item.Slot)"
    if (-not $grouped.ContainsKey($k)) {
        $grouped[$k] = @{
            DeptCode = $item.DeptCode
            DeptName = $item.DeptName
            Doctor = $item.Doctor
            Weekday = $item.Weekday
            Slot = $item.Slot
            RoomRecords = [System.Collections.Generic.List[PSCustomObject]]::new()
            StoppedDates = [System.Collections.Generic.List[string]]::new()
            SpecialNotes = [System.Collections.Generic.HashSet[string]]::new()
        }
    }
    $grouped[$k].RoomRecords.Add([PSCustomObject]@{ Date = $item.DateObj; Room = $item.Room })
    if ($item.IsStopped) {
        if (-not $grouped[$k].StoppedDates.Contains($item.Date)) {
            $grouped[$k].StoppedDates.Add($item.Date)
        }
    }
    if ($item.SpecialNote) {
        $grouped[$k].SpecialNotes.Add($item.SpecialNote) | Out-Null
    }
}

$schedules = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($k in $grouped.Keys) {
    $val = $grouped[$k]
    # 依日期排序，若跨月換診間，以最新月份之診間為準
    $sortedRooms = @($val.RoomRecords | Sort-Object { $_.Date })
    $chosenRoom = if ($sortedRooms.Count -gt 0) { $sortedRooms[-1].Room } else { "" }

    $noteParts = @()
    if ($val.SpecialNotes.Count -gt 0) {
        $noteParts += ($val.SpecialNotes -join "/")
    }
    if ($val.StoppedDates.Count -gt 0) {
        $sortedDates = @($val.StoppedDates | Sort-Object { [int]($_ -split '/')[0] * 100 + [int]($_ -split '/')[1] })
        # 依使用者需求全面完整列出所有具體停診日期，取消等N診之縮寫
        $noteParts += (($sortedDates -join ".") + "停診")
    }
    $finalNote = $noteParts -join " "

    $schedules.Add([PSCustomObject]@{
        dept_code = $val.DeptCode
        dept_name = $val.DeptName
        doctor = $val.Doctor
        weekday = $val.Weekday
        slot = $val.Slot
        room = $chosenRoom
        note = $finalNote
    })
}

Write-Host " -> 成功聚合產生常規排班規則: 共 $($schedules.Count) 筆" -ForegroundColor Green

# 建立 masterData
$masterData = [System.Collections.Generic.List[PSCustomObject]]::new()
$seenMD = @{}
foreach ($s in $schedules) {
    $k = "$($s.dept_code)___$($s.doctor)"
    if (-not $seenMD.ContainsKey($k)) {
        $seenMD[$k] = $true
        $code = if ($docMap.ContainsKey($s.doctor)) { $docMap[$s.doctor] } else { "" }
        $masterData.Add([PSCustomObject]@{
            dept = $s.dept_name
            deptCode = $s.dept_code
            doc = $s.doctor
            docCode = $code
        })
    }
}
Write-Host " -> 成功建立醫師主檔: 共 $($masterData.Count) 位" -ForegroundColor Green

# 輸出更新檔案
if ($DryRun) {
    Write-Host "[Dry Run] 測試完成，不寫入檔案。" -ForegroundColor Yellow
    exit 0
}

$currDir = Split-Path -Parent $PSScriptRoot
if (-not $currDir) { $currDir = (Get-Location).Path }
$targetIndex = Join-Path $currDir "index.html"
$targetTwin = Join-Path $currDir "門診時段交叉查詢與醫師代碼查詢系統.html"

# 構建 JavaScript 字串
$noticeJson = $officialNoticeObj | ConvertTo-Json -Depth 5
$noticeJs = "    const officialNotice = $noticeJson;"

$masterLines = @("    const masterData = [")
foreach ($m in $masterData) {
    $masterLines += "      { dept: `"$($m.dept)`", deptCode: `"$($m.deptCode)`", doc: `"$($m.doc)`", docCode: `"$($m.docCode)`" },"
}
if ($masterLines.Count -gt 1) {
    $masterLines[$masterLines.Count - 1] = $masterLines[$masterLines.Count - 1].TrimEnd(',')
}
$masterLines += "    ];"
$masterJs = $masterLines -join "`r`n"

$schedLines = @("    const schedules = [")
foreach ($s in $schedules) {
    $schedLines += "      { dept_code: `"$($s.dept_code)`", dept_name: `"$($s.dept_name)`", doctor: `"$($s.doctor)`", weekday: $($s.weekday), slot: `"$($s.slot)`", room: `"$($s.room)`", note: `"$($s.note)`" },"
}
if ($schedLines.Count -gt 1) {
    $schedLines[$schedLines.Count - 1] = $schedLines[$schedLines.Count - 1].TrimEnd(',')
}
$schedLines += "    ];"
$schedJs = $schedLines -join "`r`n"

# 讀取並替換 index.html
$content = [System.IO.File]::ReadAllText($targetIndex, [System.Text.Encoding]::UTF8)

# 替換或注入 officialNotice
if ($content -match 'const officialNotice =[\s\S]*?;') {
    $content = [regex]::Replace($content, 'const officialNotice =[\s\S]*?;', $noticeJs)
} else {
    $content = $content.Replace("    const masterData =", "$noticeJs`r`n`r`n    const masterData =")
}

# 替換 masterData
$content = [regex]::Replace($content, 'const masterData = \[[^;]*?\];', $masterJs)

# 替換 schedules
$content = [regex]::Replace($content, 'const schedules = \[[^;]*?\];', $schedJs)

[System.IO.File]::WriteAllText($targetIndex, $content, [System.Text.Encoding]::UTF8)
Write-Host " -> 已成功更新 $targetIndex" -ForegroundColor Green

# 保持完全同步複製
Copy-Item $targetIndex -Destination $targetTwin -Force
Write-Host " -> 已同步至 $targetTwin" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host " 🎉 資料庫更新完成！" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan
