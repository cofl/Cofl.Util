#Requires -Modules PSDeploy

if(!$env:CoflNugetAPIKey)
{
    throw 'Missing API Key!'
    exit 1
}
[string]$BuildRoot = "$PSScriptRoot/build"
if($BuildRoot -eq '/build')
{
    throw 'Invalid PSScriptRoot!'
    exit 1
}
[string]$OldPSModulePath = $env:PSModulePath

try
{
    [string]$ModuleVersion = Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.Util.psd1" | Select-Object -ExpandProperty ModuleVersion
    [string]$BuildTarget = "$BuildRoot/Cofl.Util/$ModuleVersion/"

    $null = Remove-Item -Recurse -Force -Path $BuildRoot
    $null = New-Item -ItemType Directory -Path $BuildTarget -Force
    $null = Copy-Item -Path "$PSScriptRoot/*" -Recurse -Destination $BuildTarget -Force

    $env:PSModulePath += [System.IO.Path]::PathSeparator + $BuildRoot

    Deploy 'Cofl.Util' {
        By PSGalleryModule {
            FromSource -Source 'Cofl.Util'
            To -Targets PSGallery
            WithOptions -Options @{
                ApiKey = $env:CoflNugetAPIKey
            }
        }
    }
} finally
{
    $env:PSModulePath = $OldPSModulePath
}
