param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot "config.json"),
    [string]$ApiKey,
    [string]$ChannelHandle,
    [string]$ChannelIdFallback,
    [int]$MinLongVideoSeconds,
    [switch]$OldestToNewest,
    [switch]$NewestToOldest,
    [string]$OutputFolder
)

$ErrorActionPreference = "Stop"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
}

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
}

function Get-PlainTextFromSecureString {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$SecureText
    )

    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureText)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Read-JsonConfig {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "Config dosyası okunamadı: $Path`n$($_.Exception.Message)"
    }
}

function Get-ConfigValue {
    param(
        [object]$Config,
        [string]$Name,
        $DefaultValue
    )

    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains $Name) {
        $value = $Config.$Name

        if ($null -ne $value -and "$value" -ne "") {
            return $value
        }
    }

    $DefaultValue
}

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    Join-Path $PSScriptRoot $Path
}

function Get-ConfiguredTimeZone {
    param(
        [string]$TimeZoneName
    )

    $candidates = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($TimeZoneName)) {
        $candidates.Add($TimeZoneName)
    }

    if ($TimeZoneName -eq "Europe/Istanbul") {
        $candidates.Add("Turkey Standard Time")
    }

    $candidates.Add("Turkey Standard Time")
    $candidates.Add("Europe/Istanbul")

    foreach ($timeZoneId in $candidates) {
        try {
            return [System.TimeZoneInfo]::FindSystemTimeZoneById($timeZoneId)
        } catch {
        }
    }

    throw "Saat dilimi bulunamadı. Config içindeki timezone değerini kontrol edin."
}

function Invoke-YouTubeApi {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Endpoint,

        [Parameter(Mandatory = $true)]
        [hashtable]$Params
    )

    if ([string]::IsNullOrWhiteSpace($script:ApiKey)) {
        throw "API key boş. config.json içine youtube_api_key yazın veya çalıştırırken girin."
    }

    $queryParts = New-Object System.Collections.Generic.List[string]

    foreach ($key in $Params.Keys) {
        $value = $Params[$key]

        if ($null -ne $value -and "$value" -ne "") {
            $encodedKey = [System.Uri]::EscapeDataString([string]$key)
            $encodedValue = [System.Uri]::EscapeDataString([string]$value)
            $queryParts.Add("$encodedKey=$encodedValue")
        }
    }

    $queryParts.Add("key=$([System.Uri]::EscapeDataString($script:ApiKey))")

    $uri = "https://www.googleapis.com/youtube/v3/{0}?{1}" -f $Endpoint, ($queryParts -join "&")

    try {
        Invoke-RestMethod -Uri $uri -Method Get
    } catch {
        Write-Host ""
        Write-Host "API hatası:" -ForegroundColor Red

        if ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                Write-Host $reader.ReadToEnd()
            } catch {
                Write-Host $_.Exception.Message
            }
        } else {
            Write-Host $_.Exception.Message
        }

        throw
    }
}

function ConvertTo-SafeFileName {
    param(
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return "youtube_channel"
    }

    $safeName = [regex]::Replace($Name, '[\\/:*?"<>|]', "_")
    $safeName = [regex]::Replace($safeName, "\s+", "_").Trim("_")

    if ($safeName.Length -gt 120) {
        return $safeName.Substring(0, 120)
    }

    $safeName
}

function Convert-YouTubeDurationToSeconds {
    param(
        [string]$Duration
    )

    if ([string]::IsNullOrWhiteSpace($Duration)) {
        return $null
    }

    try {
        return [int][System.Xml.XmlConvert]::ToTimeSpan($Duration).TotalSeconds
    } catch {
        $match = [regex]::Match(
            $Duration,
            '^P(?:(?<days>\d+)D)?(?:T(?:(?<hours>\d+)H)?(?:(?<minutes>\d+)M)?(?:(?<seconds>\d+)S)?)?$'
        )

        if (-not $match.Success) {
            return $null
        }

        $days = if ($match.Groups["days"].Success) { [int]$match.Groups["days"].Value } else { 0 }
        $hours = if ($match.Groups["hours"].Success) { [int]$match.Groups["hours"].Value } else { 0 }
        $minutes = if ($match.Groups["minutes"].Success) { [int]$match.Groups["minutes"].Value } else { 0 }
        $seconds = if ($match.Groups["seconds"].Success) { [int]$match.Groups["seconds"].Value } else { 0 }

        ($days * 86400) + ($hours * 3600) + ($minutes * 60) + $seconds
    }
}

function Convert-SecondsToHms {
    param(
        [Nullable[int]]$Seconds
    )

    if ($null -eq $Seconds) {
        return ""
    }

    $timeSpan = [TimeSpan]::FromSeconds($Seconds)

    if ($timeSpan.TotalHours -ge 1) {
        return "{0:00}:{1:00}:{2:00}" -f [int][Math]::Floor($timeSpan.TotalHours), $timeSpan.Minutes, $timeSpan.Seconds
    }

    "{0:00}:{1:00}" -f $timeSpan.Minutes, $timeSpan.Seconds
}

function Get-VideoLengthType {
    param(
        [Nullable[int]]$DurationSeconds
    )

    if ($null -eq $DurationSeconds) {
        return "sure_bilinmiyor"
    }

    if ($DurationSeconds -ge $script:MinLongVideoSeconds) {
        return "muhtemel_normal_video"
    }

    "muhtemel_shorts_veya_kisa"
}

function Get-ChannelInfo {
    $handleVariants = New-Object System.Collections.Generic.List[string]

    if ($script:ChannelHandle.StartsWith("@")) {
        $handleVariants.Add($script:ChannelHandle)
        $handleVariants.Add($script:ChannelHandle.Substring(1))
    } else {
        $handleVariants.Add($script:ChannelHandle)
        $handleVariants.Add("@$($script:ChannelHandle)")
    }

    $data = $null

    foreach ($handle in $handleVariants) {
        $data = Invoke-YouTubeApi -Endpoint "channels" -Params @{
            part = "id,contentDetails,snippet,statistics"
            forHandle = $handle
        }

        if ($data.items -and $data.items.Count -gt 0) {
            break
        }
    }

    if (-not $data -or -not $data.items -or $data.items.Count -eq 0) {
        $data = Invoke-YouTubeApi -Endpoint "channels" -Params @{
            part = "id,contentDetails,snippet,statistics"
            id = $script:ChannelIdFallback
        }
    }

    if (-not $data.items -or $data.items.Count -eq 0) {
        throw "Kanal bulunamadı. Handle veya kanal ID yanlış olabilir."
    }

    $channel = $data.items[0]

    [pscustomobject]@{
        ChannelId = $channel.id
        ChannelTitle = $channel.snippet.title
        UploadsPlaylistId = $channel.contentDetails.relatedPlaylists.uploads
        PublicVideoCount = $channel.statistics.videoCount
    }
}

function Get-AllVideoIdsFromUploadsPlaylist {
    param(
        [Parameter(Mandatory = $true)]
        [string]$UploadsPlaylistId
    )

    $videoIds = New-Object System.Collections.Generic.List[string]
    $nextPageToken = $null

    while ($true) {
        $params = @{
            part = "contentDetails"
            playlistId = $UploadsPlaylistId
            maxResults = 50
        }

        if ($nextPageToken) {
            $params.pageToken = $nextPageToken
        }

        $data = Invoke-YouTubeApi -Endpoint "playlistItems" -Params $params

        foreach ($item in @($data.items)) {
            $videoId = $item.contentDetails.videoId

            if ($videoId) {
                $videoIds.Add($videoId)
            }
        }

        $nextPageToken = $data.nextPageToken

        if (-not $nextPageToken) {
            break
        }
    }

    $videoIds
}

function Get-VideoDetails {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$VideoIds
    )

    $videos = New-Object System.Collections.Generic.List[object]

    for ($i = 0; $i -lt $VideoIds.Count; $i += 50) {
        $endIndex = [Math]::Min($i + 49, $VideoIds.Count - 1)
        $batch = $VideoIds[$i..$endIndex]

        $data = Invoke-YouTubeApi -Endpoint "videos" -Params @{
            part = "snippet,statistics,contentDetails,status"
            id = ($batch -join ",")
        }

        foreach ($item in @($data.items)) {
            $snippet = $item.snippet
            $stats = $item.statistics
            $content = $item.contentDetails
            $status = $item.status

            $publishedLocalDate = ""
            $publishedLocalTime = ""
            $publishedLocalFull = ""
            $publishedUtcFull = ""

            if ($snippet.publishedAt) {
                $publishedUtc = [DateTimeOffset]::Parse($snippet.publishedAt).ToUniversalTime()
                $publishedLocal = [System.TimeZoneInfo]::ConvertTime($publishedUtc, $script:TimeZone)

                $publishedLocalDate = $publishedLocal.ToString("yyyy-MM-dd")
                $publishedLocalTime = $publishedLocal.ToString("HH:mm:ss")
                $publishedLocalFull = $publishedLocal.ToString("yyyy-MM-dd HH:mm:ss")
                $publishedUtcFull = $publishedUtc.ToString("yyyy-MM-dd HH:mm:ss 'UTC'")
            }

            $durationIso = $content.duration
            $durationSeconds = Convert-YouTubeDurationToSeconds -Duration $durationIso
            $durationHms = Convert-SecondsToHms -Seconds $durationSeconds
            $videoLengthType = Get-VideoLengthType -DurationSeconds $durationSeconds
            $isProbablyLongVideo = ($null -ne $durationSeconds -and $durationSeconds -ge $script:MinLongVideoSeconds)

            $videos.Add([pscustomobject][ordered]@{
                published_local_date = $publishedLocalDate
                published_local_time = $publishedLocalTime
                published_local_full = $publishedLocalFull
                published_utc_full = $publishedUtcFull
                title = $snippet.title
                description = $snippet.description
                video_id = $item.id
                url = "https://www.youtube.com/watch?v=$($item.id)"
                duration_seconds = if ($null -ne $durationSeconds) { $durationSeconds } else { "" }
                duration_hms = $durationHms
                view_count = if ($stats.viewCount) { $stats.viewCount } else { "" }
                like_count = if ($stats.likeCount) { $stats.likeCount } else { "" }
                comment_count = if ($stats.commentCount) { $stats.commentCount } else { "" }
                privacy_status = if ($status.privacyStatus) { $status.privacyStatus } else { "" }
                made_for_kids = if ($null -ne $status.madeForKids) { $status.madeForKids } else { "" }
                video_length_type = $videoLengthType
                is_probably_long_video = $isProbablyLongVideo
            })
        }
    }

    if ($script:SortOldestToNewest) {
        $videos | Sort-Object published_local_full
    } else {
        $videos | Sort-Object published_local_full -Descending
    }
}

function Get-VideoExportColumns {
    @(
        "published_local_date",
        "published_local_time",
        "published_local_full",
        "published_utc_full",
        "title",
        "video_id",
        "url",
        "duration_seconds",
        "duration_hms",
        "view_count",
        "like_count",
        "comment_count",
        "privacy_status",
        "made_for_kids",
        "video_length_type",
        "is_probably_long_video"
    )
}

function Write-VideosToWorksheet {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Sheet,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Videos
    )

    $columns = Get-VideoExportColumns
    $columnCount = $columns.Count

    for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
        $Sheet.Cells.Item(1, $columnIndex + 1).Value2 = $columns[$columnIndex]
    }

    $videoIdColumn = [array]::IndexOf($columns, "video_id") + 1

    if ($videoIdColumn -gt 0) {
        $Sheet.Columns.Item($videoIdColumn).NumberFormat = "@"
    }

    if ($Videos.Count -gt 0) {
        for ($rowIndex = 0; $rowIndex -lt $Videos.Count; $rowIndex++) {
            for ($columnIndex = 0; $columnIndex -lt $columnCount; $columnIndex++) {
                $columnName = $columns[$columnIndex]
                $value = $Videos[$rowIndex].$columnName

                if ($null -eq $value) {
                    $value = ""
                }

                if ($columnName -eq "video_id") {
                    $value = [string]$value
                }

                $cell = $Sheet.Cells.Item($rowIndex + 2, $columnIndex + 1)
                $cell.Value2 = [string]$value

                if ($columnName -eq "url") {
                    $url = [string]$value

                    if (-not [string]::IsNullOrWhiteSpace($url)) {
                        $Sheet.Hyperlinks.Add($cell, $url, "", "", $url) | Out-Null
                    }
                }
            }
        }
    }

    $Sheet.Rows.Item(1).Font.Bold = $true
    $Sheet.UsedRange.AutoFilter() | Out-Null
    $Sheet.Columns.AutoFit() | Out-Null
}

function Save-ExcelWorkbook {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$AllVideos,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$LongVideos,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ShortVideos,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $excel = $null
    $workbook = $null
    $sheets = New-Object System.Collections.Generic.List[object]

    try {
        $excel = New-Object -ComObject Excel.Application
    } catch {
        Write-Warning "Excel bulunamadığı için XLSX oluşturulamadı: $Path"
        return
    }

    try {
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $excel.SheetsInNewWorkbook = 3

        $workbook = $excel.Workbooks.Add()

        $sheetDefinitions = @(
            @{ Name = "All"; Videos = $AllVideos },
            @{ Name = "Long"; Videos = $LongVideos },
            @{ Name = "Shorts"; Videos = $ShortVideos }
        )

        for ($sheetIndex = 0; $sheetIndex -lt $sheetDefinitions.Count; $sheetIndex++) {
            $sheet = $workbook.Worksheets.Item($sheetIndex + 1)
            $sheet.Name = $sheetDefinitions[$sheetIndex].Name
            $sheets.Add($sheet)

            Write-VideosToWorksheet -Sheet $sheet -Videos $sheetDefinitions[$sheetIndex].Videos
        }

        $workbook.Worksheets.Item(1).Activate()
        $workbook.SaveAs($Path, 51)
    } finally {
        if ($workbook) {
            $workbook.Close($false) | Out-Null
        }

        if ($excel) {
            $excel.Quit() | Out-Null
        }

        foreach ($comObject in @($sheets.ToArray() + $workbook + $excel)) {
            if ($comObject) {
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($comObject)
            }
        }
    }
}

function Save-DescriptionsTxt {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Videos,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $separator = "-" * 41
    $lines = New-Object System.Collections.Generic.List[string]

    foreach ($video in $Videos) {
        $lines.Add([string]$video.title)
        $lines.Add("")
        $lines.Add([string]$video.description)
        $lines.Add($separator)
    }

    [System.IO.File]::WriteAllLines($Path, $lines, [System.Text.UTF8Encoding]::new($true))
}

function Write-VideoTable {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Videos,

        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host $Title
    Write-Host "Toplam: $($Videos.Count)"
    Write-Host ("-" * 130)

    $index = 1

    foreach ($video in $Videos) {
        Write-Host ("{0:00}. {1} | {2,8} | {3,8} views | {4} | {5}" -f `
            $index,
            $video.published_local_full,
            $video.duration_hms,
            $video.view_count,
            $video.title,
            $video.url)

        $index++
    }
}

$config = Read-JsonConfig -Path $ConfigPath

if (-not $PSBoundParameters.ContainsKey("ApiKey")) {
    $ApiKey = Get-ConfigValue -Config $config -Name "youtube_api_key" -DefaultValue ""
}

if (-not $PSBoundParameters.ContainsKey("ChannelHandle")) {
    $ChannelHandle = Get-ConfigValue -Config $config -Name "channel_handle" -DefaultValue "@example"
}

if (-not $PSBoundParameters.ContainsKey("ChannelIdFallback")) {
    $ChannelIdFallback = Get-ConfigValue -Config $config -Name "channel_id_fallback" -DefaultValue "UC_EXAMPLE_CHANNEL_ID"
}

if (-not $PSBoundParameters.ContainsKey("MinLongVideoSeconds")) {
    $MinLongVideoSeconds = [int](Get-ConfigValue -Config $config -Name "min_long_video_seconds" -DefaultValue 181)
}

if (-not $PSBoundParameters.ContainsKey("OutputFolder")) {
    $OutputFolder = Get-ConfigValue -Config $config -Name "output_folder" -DefaultValue "outputs"
}

$timeZoneName = Get-ConfigValue -Config $config -Name "timezone" -DefaultValue "Turkey Standard Time"
$script:TimeZone = Get-ConfiguredTimeZone -TimeZoneName $timeZoneName

if ($PSBoundParameters.ContainsKey("NewestToOldest")) {
    $script:SortOldestToNewest = $false
} elseif ($PSBoundParameters.ContainsKey("OldestToNewest")) {
    $script:SortOldestToNewest = $true
} else {
    $script:SortOldestToNewest = [bool](Get-ConfigValue -Config $config -Name "sort_oldest_to_newest" -DefaultValue $true)
}

$script:ApiKey = $ApiKey
$script:ChannelHandle = $ChannelHandle
$script:ChannelIdFallback = $ChannelIdFallback
$script:MinLongVideoSeconds = $MinLongVideoSeconds

if (
    ([string]::IsNullOrWhiteSpace($script:ChannelHandle) -or $script:ChannelHandle -eq "@example") -and
    ([string]::IsNullOrWhiteSpace($script:ChannelIdFallback) -or $script:ChannelIdFallback -eq "UC_EXAMPLE_CHANNEL_ID")
) {
    throw "config.json içindeki channel_handle veya channel_id_fallback alanlarından en az birini gerçek kanal bilgisiyle doldurun."
}

if ([string]::IsNullOrWhiteSpace($script:ApiKey) -or $script:ApiKey -like "YOUR_*") {
    $secureApiKey = Read-Host "YouTube Data API v3 API key" -AsSecureString
    $script:ApiKey = Get-PlainTextFromSecureString -SecureText $secureApiKey
}

$resolvedOutputFolder = Resolve-ToolPath -Path $OutputFolder

if (-not (Test-Path -LiteralPath $resolvedOutputFolder)) {
    New-Item -ItemType Directory -Path $resolvedOutputFolder | Out-Null
}

$channelInfo = Get-ChannelInfo
$safeChannelTitle = ConvertTo-SafeFileName -Name $channelInfo.ChannelTitle

Write-Host ""
Write-Host "Kanal adı: $($channelInfo.ChannelTitle)"
Write-Host "Kanal ID: $($channelInfo.ChannelId)"
Write-Host "Uploads playlist ID: $($channelInfo.UploadsPlaylistId)"
Write-Host "Public videoCount: $($channelInfo.PublicVideoCount)"
Write-Host "Sıralama: $(if ($script:SortOldestToNewest) { 'eskiden yeniye' } else { 'yeniden eskiye' })"
Write-Host "Çıktı klasörü: $resolvedOutputFolder"
Write-Host ""

Write-Host "Uploads playlist içindeki video ID'leri çekiliyor..."
$videoIds = @(Get-AllVideoIdsFromUploadsPlaylist -UploadsPlaylistId $channelInfo.UploadsPlaylistId)

Write-Host "Playlist'ten çekilen public yükleme sayısı: $($videoIds.Count)"
Write-Host "Video detayları çekiliyor..."

$allVideos = @(Get-VideoDetails -VideoIds $videoIds)
$longVideos = @($allVideos | Where-Object { $_.is_probably_long_video -eq $true })
$shortOrUnknownVideos = @($allVideos | Where-Object { $_.is_probably_long_video -ne $true })

$orderSuffix = if ($script:SortOldestToNewest) { "eskiden_yeniye" } else { "yeniden_eskiye" }

$workbookXlsx = Join-Path $resolvedOutputFolder "$($safeChannelTitle)_$orderSuffix.xlsx"
$descriptionsTxt = Join-Path $resolvedOutputFolder "$($safeChannelTitle)_aciklamalar_$orderSuffix.txt"

Save-ExcelWorkbook -AllVideos $allVideos -LongVideos $longVideos -ShortVideos $shortOrUnknownVideos -Path $workbookXlsx
Save-DescriptionsTxt -Videos $allVideos -Path $descriptionsTxt

Write-Host ""
Write-Host "Özet"
Write-Host ("-" * 60)
Write-Host "Toplam public yükleme: $($allVideos.Count)"
Write-Host "Muhtemel normal video, >= $script:MinLongVideoSeconds sn: $($longVideos.Count)"
Write-Host "Muhtemel Shorts/kısa/bilinmeyen, < $script:MinLongVideoSeconds sn: $($shortOrUnknownVideos.Count)"

Write-VideoTable -Videos $longVideos -Title "NORMAL VİDEOLAR"

Write-Host ""
Write-Host "Oluşturulan dosyalar:"
if (Test-Path -LiteralPath $workbookXlsx) {
    Write-Host $workbookXlsx
} else {
    Write-Host "XLSX oluşturulamadı. Microsoft Excel masaüstü uygulaması gerekli: $workbookXlsx" -ForegroundColor Yellow
}

if (Test-Path -LiteralPath $descriptionsTxt) {
    Write-Host $descriptionsTxt
}
Write-Host ""
