#Requires -Modules PSDeploy

if(!$env:CoflNugetAPIKey)
{
    throw 'Missing API Key in $env:CoflNugetAPIKey!'
    exit 1
}

[string]$OldPSModulePath = $env:PSModulePath
try
{
    [string]$ModuleVersion = (Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.Util.PowerShell/Cofl.Util.psd1").ModuleVersion
    [string]$ModuleVersion2 = (Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.GetFilteredChildItem.PowerShell/Cofl.GetFilteredChildItem.psd1").ModuleVersion
    [string]$BuildRoot = "$PSScriptRoot/build"
    [string]$Source = "$BuildRoot/Cofl.Util/$ModuleVersion/"
    [string]$Source2 = "$BuildRoot/Cofl.GetFilteredChildItem/$ModuleVersion2/"
    if(!(Test-Path $Source))
    {
        & "$PSScriptRoot/build.ps1" -Task Build, BuildGetFilteredChildItem
    }

    $env:PSModulePath += [System.IO.Path]::PathSeparator + $BuildRoot

    Deploy 'Cofl.Util' {
        By PSGalleryModule {
            FromSource -Source $Source
            To -Targets PSGallery
            WithOptions -Options @{
                ApiKey = $env:CoflNugetAPIKey
            }
        }
    }

    Deploy 'Cofl.GetFilteredChildItem' {
        By PSGalleryModule {
            FromSource -Source $Source2
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
