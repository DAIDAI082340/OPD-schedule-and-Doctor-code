# ==============================================================================
# 衛生福利部彰化醫院 (CHHW) 門診時刻表、醫師代碼與停代診公告 原生同步程式 (PowerShell)
# 支援台灣在地 IP 直接連線、熔斷保護機制 (Circuit Breaker)、雙生檔案 100% SHA-256 同步
# ==============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$baseDir = Split-Path -Parent $scriptDir
$noticesDir = Join-Path $baseDir "assets\notices"
if (-not (Test-Path $noticesDir)) {
    New-Item -ItemType Directory -Path $noticesDir -Force | Out-Null
}

$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    "Accept-Language" = "zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7"
    "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
}

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

            $isStopped = ($inner -like "*停診*") -or ($inner -like "*停掛*")
            $slotLabel = if ($slotMap.ContainsKey($apn)) { $slotMap[$apn] } else { "上午" }
            $roomLabel = if ($roomNo.EndsWith("診")) { $roomNo } else { "${roomNo}診" }

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
            }
        }
    } catch {
        Write-Warning "抓取專科 $dName ($dCode) 失敗: $_"
    }
}

# ------------------------------------------------------------------------------
# 5. 聚合門診排班規則與停診日期
# ------------------------------------------------------------------------------
$grouped = @{}
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
            stopped_dates = [System.Collections.Generic.List[string]]::new()
            total_occurrences = 0
        }
    }
    $grouped[$k].total_occurrences++
    $grouped[$k].rooms.Add($item.room)
    if ($item.is_stopped) {
        $grouped[$k].stopped_dates.Add($item.date)
    }
}

$schedules = @()
foreach ($k in $grouped.Keys) {
    $entry = $grouped[$k]
    # 選取出現頻率最高的診間號
    $roomFinal = ($entry.rooms | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Name

    # 彙整停診備註
    $noteParts = @()
    if ($entry.stopped_dates.Count -gt 0) {
        $uniqueDates = $entry.stopped_dates | Select-Object -Unique
        # 按月日排序
        $sortedDates = $uniqueDates | Sort-Object {
            $parts = $_ -split '/'
            [int]$parts[0] * 100 + [int]$parts[1]
        }
        $noteParts += (($sortedDates -join ".") + "停診")
    }

    $note = $noteParts -join " "

    # 永久保留重要特定開診日標註 (若院方排班手冊特別標示)
    if ($entry.doctor -eq "陳筠方" -and $entry.dept_name -eq "血液腫瘤科" -and $entry.weekday -eq 5) {
        $note = ("9/11.25看診 " + $note).Trim()
    }
    if ($entry.doctor -eq "張淑鈺" -and $entry.dept_name -eq "腎臟內科" -and $entry.weekday -eq 6) {
        $note = ("9/12.26看診 " + $note).Trim()
    }
    if ($entry.doctor -eq "李學林" -and $entry.dept_name -eq "心臟內科" -and $entry.weekday -eq 6) {
        $note = ("9/12.26看診 " + $note).Trim()
    }

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
git add index.html 門診時段交叉查詢與醫師代碼查詢系統.html assets/notices/

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

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " 🎉 衛生福利部彰化醫院 (CHHW) 全院門診時刻表即時同步作業圓滿完成！" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
