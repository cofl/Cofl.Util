#Requires -Modules PSDeploy

if(!$env:CoflNugetAPIKey)
{
    throw 'Missing API Key in $env:CoflNugetAPIKey!'
    exit 1
}

[string]$OldPSModulePath = $env:PSModulePath
try
{
    [string]$BuildRoot = "$PSScriptRoot/build"
    $env:PSModulePath += [System.IO.Path]::PathSeparator + $BuildRoot

    Deploy 'Cofl.Util' {
        By PSGalleryModule {
            FromSource -Source "$BuildRoot/Cofl.Util/$((Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.Util.PowerShell/Cofl.Util.psd1").ModuleVersion)/"
            To -Targets PSGallery
            WithOptions -Options @{
                ApiKey = $env:CoflNugetAPIKey
            }
        }
    }

    Deploy 'Cofl.GetFilteredChildItem' {
        By PSGalleryModule {
            FromSource -Source "$BuildRoot/Cofl.GetFilteredChildItem/$((Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.GetFilteredChildItem.PowerShell/Cofl.GetFilteredChildItem.psd1").ModuleVersion)/"
            To -Targets PSGallery
            WithOptions -Options @{
                ApiKey = $env:CoflNugetAPIKey
            }
        }
    }

    Deploy 'Cofl.EncodedStrings' {
        By PSGalleryModule {
            FromSource -Source "$BuildRoot/Cofl.EncodedStrings/$((Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.EncodedStrings.PowerShell/Cofl.EncodedStrings.psd1").ModuleVersion)/"
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
