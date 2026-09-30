$content = [System.IO.File]::ReadAllText('div13.html', [System.Text.Encoding]::UTF8)
$regex = 'GoClinic\(''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)'',\s*''([^'']*)''\)[^>]*>([\s\S]*?)</a>'
$matches = [regex]::Matches($content, $regex)
foreach ($m in $matches) {
    $dec = [System.Net.WebUtility]::HtmlDecode($m.Groups[6].Value)
    if ($dec -like '*蕭銘鴻*') {
        $d = $m.Groups[1].Value
        $apn = $m.Groups[2].Value
        $room = $m.Groups[3].Value
        $clean = ($dec -replace '<[^>]+>', ' ').Trim()
        [Console]::WriteLine($d + ' | apn=' + $apn + ' | room=' + $room + ' | ' + $clean)
    }
}
