$null = Import-Module -Name "$PSScriptRoot/Cofl.Util.dll" -Scope Local

[bool]$LoadedSystemDevice = $null -ne (Add-Type -AssemblyName System.Device -ErrorAction SilentlyContinue -PassThru)
[bool]$LoadedSystemSpeech = $null -ne (Add-Type -AssemblyName System.Speech -ErrorAction SilentlyContinue -PassThru)

if($LoadedSystemDevice)
{
    . "$PSScriptRoot/Public/Get-GeoLocation.ps1"
}

if($LoadedSystemSpeech)
{
    . "$PSScriptRoot/Public/Invoke-Speech.ps1"
}

if($LoadedSystemDevice -and $LoadedSystemSpeech)
{
    . "$PSScriptRoot/Public/Get-DailyWeather.ps1"
}

. "$PSScriptRoot/Public/Get-OrdinalNumber.ps1"
. "$PSScriptRoot/Public/Get-Weather.ps1"
. "$PSScriptRoot/Public/Invoke-DelayedTask.ps1"
. "$PSScriptRoot/Public/Invoke-Ditty.ps1"
. "$PSScriptRoot/Public/Read-MultiData.ps1"
. "$PSScriptRoot/Public/Read-MultiDataSequential.ps1"
. "$PSScriptRoot/Public/Select-Property.ps1"
