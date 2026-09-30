$content = [System.IO.File]::ReadAllText('div13.html', [System.Text.Encoding]::UTF8)
$regex = 'GoClinic\(''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)''\)[^>]*>([\s\S]*?)</a>'
$matches = [regex]::Matches($content, $regex)
foreach ($m in $matches) {
    if ($m.Groups[2].Value -eq '2') {
        $dStr = $m.Groups[1].Value
        $y = [int]$dStr.Substring(0, 3) + 1911
        $mo = $dStr.Substring(3, 2)
        $d = $dStr.Substring(5, 2)
        $dt = Get-Date -Year $y -Month ([int]$mo) -Day ([int]$d)
        if ($dt.DayOfWeek -eq [DayOfWeek]::Monday) {
            $dec = [System.Net.WebUtility]::HtmlDecode($m.Groups[6].Value)
            $clean = ($dec -replace '<[^>]+>', ' ').Trim() -replace '\s+', ' '
            [Console]::WriteLine($mo + '/' + $d + ' room=' + $m.Groups[3].Value + ' | ' + $clean)
        }
    }
}
