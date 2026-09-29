$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    "Accept-Language" = "zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7"
}
$slotMap = @{ "1" = "上午"; "2" = "下午"; "3" = "夜診" }

Write-Host "Fetching department list..."
$resDept = Invoke-WebRequest -Uri "https://netreg.chhw.mohw.gov.tw/" -Headers $headers -UseBasicParsing -TimeoutSec 15
$htmlDept = [System.Text.Encoding]::UTF8.GetString($resDept.RawContentStream.ToArray())
$deptRegex = 'GoDoctorList\(''([^'']+)''\)[^>]*>([\s\S]*?)</a>'
$deptMatches = [regex]::Matches($htmlDept, $deptRegex)

$seenDepts = @{}
$depts = @()
foreach ($dm in $deptMatches) {
    $code = $dm.Groups[1].Value.Trim()
    $name = [System.Net.WebUtility]::HtmlDecode($dm.Groups[2].Value).Trim()
    if ($code -and -not $seenDepts.ContainsKey($code) -and $name -notmatch "體檢|預防醫學") {
        $seenDepts[$code] = $true
        $depts += [PSCustomObject]@{ code = $code; name = $name }
    }
}
Write-Host "Found $($depts.Count) departments to scrape."

$cRegex = 'GoClinic\(''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)''\)[^>]*>([\s\S]*?)</a>'

$liveMap = @{}
$sw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($d in $depts) {
    $dCode = $d.code
    $clinicUrl = "https://netreg.chhw.mohw.gov.tw/DOCTORLIST?role=DIV`&key_code=$dCode"
    try {
        $resClinic = Invoke-WebRequest -Uri $clinicUrl -Headers $headers -UseBasicParsing -TimeoutSec 10
        $htmlClinic = [System.Text.Encoding]::UTF8.GetString($resClinic.RawContentStream.ToArray())
        $cMatches = [regex]::Matches($htmlClinic, $cRegex)
        foreach ($cm in $cMatches) {
            $dateStr = $cm.Groups[1].Value
            $apn = $cm.Groups[2].Value
            $fullA = $cm.Value
            $inner = [System.Net.WebUtility]::HtmlDecode($cm.Groups[6].Value)
            
            if ($inner -match '<div[^>]*>\s*([^\s<]+)') {
                $docName = $Matches[1].Trim()
                if (-not $docName -or $docName -in @("UNKNOWN", "約診醫師")) { continue }
            } else { continue }
            
            if ($dateStr.Length -eq 7) {
                $month = [int]$dateStr.Substring(3, 2)
                $day = [int]$dateStr.Substring(5, 2)
                $mm = $dateStr.Substring(3, 2)
                $dd = $dateStr.Substring(5, 2)
                $dateKey = "$month/$day"
                $dateFormatted = "$mm/$dd"
            } else { continue }
            
            $slotLabel = if ($slotMap.ContainsKey($apn)) { $slotMap[$apn] } else { "上午" }
            
            # 優先提取官方真實掛號人數（無論是否額滿或網掛不開放）
            $count = $null
            if ($inner -match '已掛(\d+)人') {
                $count = [int]$Matches[1]
            }

            # 嚴格停診判斷：只有文字明確包含「停診」且完全沒有掛號人數時，才列為停診
            # 絕對禁止將「預約已額滿」、「網掛不開放」或 disabled 誤判為停診！
            $isStopped = ($inner -like "*停診*") -and ($count -eq $null)
            $isSubstitute = ($inner -like "*代診*")
            
            $mapKey = "$docName|$dateKey|$slotLabel"
            $liveMap[$mapKey] = @{
                doctor = $docName
                date = $dateKey
                dateFormatted = $dateFormatted
                slot = $slotLabel
                count = $count
                isStopped = $isStopped
                isSubstitute = $isSubstitute
            }
        }
    } catch {
        Write-Warning "Failed to fetch $dCode"
    }
}
$sw.Stop()
Write-Host "Scraped $($liveMap.Count) slots in $($sw.Elapsed.TotalSeconds) seconds."

# Save to json file
$json = $liveMap | ConvertTo-Json -Depth 3
[System.IO.File]::WriteAllText("live_registration.json", $json, [System.Text.Encoding]::UTF8)
Write-Host "Saved live_registration.json successfully!"

Write-Host "Records for 蔡旻叡:"
$liveMap.Keys | Where-Object { $_ -like "蔡旻叡*" } | Sort-Object | ForEach-Object {
    $item = $liveMap[$_]
    Write-Host "$_ => count: $($item.count) | stop: $($item.isStopped) | sub: $($item.isSubstitute)"
}
