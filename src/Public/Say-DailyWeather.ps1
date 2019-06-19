<#
.SYNOPSIS
Says the forecast aloud.

.DESCRIPTION
Fetches the forecast and performs a greeting using Text-To-Speech once per day (or more frequently if the -Force)
parameter is used. The last date is stored at "$DocumentsFolderRoot/WindowsPowerShell/say-daily-weather.date". The
intended use is for this function to be added to your PowerShell profile. Weather alerts are not included.

This cmdlet returns immediately, and uses a job to avoid blocking the main thread.

The Windows Location API is used.

.EXAMPLE
PS C:\> Say-DailyWeather

Performs a greeting and says the current forecast.
#>
function Say-DailyWeather
{
    [CmdletBinding()]
    PARAM (
        [Parameter()]
            # Force the use of
            [switch]$Force
    )
    $DateLocation = [System.Environment]::GetFolderPath('MyDocuments') + '/WindowsPowerShell/say-daily-weather.date'
    $Last = try { Get-Date (Get-Content $DateLocation -ea 0) } catch { [datetime]::Today.AddDays(-1) }
    if($Last -lt [datetime]::Today -or $Force) {
        Set-Content -Path $DateLocation -NoNewLine -Encoding Ascii -Value ([datetime]::Today.ToString().Trim())
        $null = Start-Job -Name 'SayDailyWeatherJob' -ScriptBlock {
			Import-Module Cofl.Util -DisableNameChecking
            [datetime]$Now = [datetime]::Now
            [int]$Century = $Now.Year / 100
            [int]$Year = $Now.Year % 100
            [string]$YearString = if($Year -lt 10) { "o $Year" } else { "$Year" }
            $Greeting = switch($Now.Hour)
            {
                { $_ -lt 12 } { 'Good morning.'; break; }
                { $_ -lt 20} { 'Good afternoon.'; break; }
                default { 'Good evening.'; break; }
            }
			$Location = Get-GeoLocation
            @(
                "$Greeting Today is $($Now.ToString('dddd, MMMM')) $(Get-OrdinalNumber $Now.Day), $($Century) $($YearString). It is $($Now.ToString('t'))."
                (Get-Weather -Latitude $Location.Latitude -Longitude $Location.Longitude -ForecastType Detailed -IncludeLocation -IncludeTime -Speakable)
            ) | Say-String
        }
    }
}
