$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
}

$outputPath = Join-Path $PSScriptRoot "zaman_dilimleri.txt"

$header = @(
    "Windows zaman dilimi ID listesi",
    "Config dosyasındaki timezone alanına soldaki ID değerini yazın.",
    "Örnek: Central Standard Time (Mexico)",
    ""
)

$zones = [System.TimeZoneInfo]::GetSystemTimeZones() |
    Sort-Object Id |
    ForEach-Object {
        "{0} | {1}" -f $_.Id, $_.DisplayName
    }

$content = $header + $zones

$content | Tee-Object -FilePath $outputPath

Write-Host ""
Write-Host "Liste kaydedildi: $outputPath"
Write-Host "Config dosyasındaki timezone alanına soldaki ID değerlerinden birini yazabilirsiniz."
