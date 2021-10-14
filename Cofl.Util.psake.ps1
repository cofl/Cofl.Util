#Requires -Modules PSake

[CmdletBinding()] PARAM ()

[string]$DotNet = Get-Command 'dotnet.exe' -CommandType Application -ErrorAction Stop | Select-Object -ExpandProperty Source

[string]$OutDir = "$PSScriptRoot/build"
$Modules = @{
    'Cofl.Util' = @{
        Version = (Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.Util.PowerShell/Cofl.Util.psd1" -ErrorAction Stop).ModuleVersion
        Source = "$PSScriptRoot/src/Cofl.Util.PowerShell"
        Include = @(
            'Cofl.GetFilteredChildItem'
            'Cofl.EncodedStrings'
            'Cofl.Menu'
        )
    }
    'Cofl.GetFilteredChildItem' = @{
        Version = (Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.GetFilteredChildItem.PowerShell/Cofl.GetFilteredChildItem.psd1" -ErrorAction Stop).ModuleVersion
        Source = "$PSScriptRoot/src/Cofl.GetFilteredChildItem.PowerShell"
        Include = @(
            'Cofl.GetFilteredChildItem'
        )
    }
    'Cofl.EncodedStrings' = @{
        Version = (Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.EncodedStrings.PowerShell/Cofl.EncodedStrings.psd1" -ErrorAction Stop).ModuleVersion
        Source = "$PSScriptRoot/src/Cofl.EncodedStrings.PowerShell"
        Include = @(
            'Cofl.EncodedStrings'
        )
    }
    'Cofl.Menu' = @{
        Version = (Import-PowerShellDataFile -Path "$PSScriptRoot/src/Cofl.Menu.PowerShell/Cofl.Menu.psd1" -ErrorAction Stop).ModuleVersion
        Source = "$PSScriptRoot/src/Cofl.Menu.PowerShell"
        Include = @(
            'Cofl.Menu'
        )
    }
}

Task default -depends Build

Task Init {
	if(!(Test-Path -LiteralPath $OutDir)){
		$null = New-Item -ItemType Directory -Path $OutDir -Verbose:$VerbosePreference
	} else {
		Write-Verbose "$($psake.context.currentTaskName) - directory already exists."
	}
}

Task Clean -depends Init {
    if(Test-Path $OutDir)
    {
        Remove-Item -Path $OutDir -Recurse -Force -Verbose:$VerbosePreference
    }
}

Task BuildRelease -depends Clean {
    & $DotNet build -c:Release
}

Task BuildDebug -depends Clean {
    & $DotNet build -c:Debug
}

foreach($ModuleName in $Modules.Keys){
    $Version = $Modules[$ModuleName].Version
    Task "$ModuleName - Init" -depends Init ([scriptblock]::Create(@"
    Copy-Item -Recurse -Path "$($Modules[$ModuleName].Source)/*" -Destination (New-Item -ItemType Directory -Path "`$OutDir/$ModuleName/$Version" -Force).FullName;
"@))

    Task $ModuleName -depends BuildRelease, "$ModuleName - Init" ([scriptblock]::Create(@"
    $(foreach($Include in $Modules[$ModuleName].Include){@"
    Copy-Item -Path "$PSScriptRoot/src/$Include/bin/Release/netstandard2.0/$Include.dll" -Destination (New-Item -ItemType Directory -Path "`$OutDir/$ModuleName/$Version" -Force).FullName;
"@})
"@))

    Task "DEBUG - $ModuleName" -depends BuildDebug, "$ModuleName - Init" ([scriptblock]::Create(@"
    $(foreach($Include in $Modules[$ModuleName].Include){@"
    Copy-Item -Path "$PSScriptRoot/src/$Include/bin/Debug/netstandard2.0/$Include.dll" -Destination (New-Item -ItemType Directory -Path "`$OutDir/$ModuleName/$Version" -Force).FullName;
"@})
"@))
}

Task Build -depends $Modules.Keys

Task Deploy -depends Build {
	if(!(Get-Module PSDeploy -ListAvailable)){
		throw "$(psake.context.currentTaskName) - PSDeploy is not available, cannot deploy."
	} else {
		Import-Module PSDeploy
	}
	Push-Location $PSScriptRoot
	Invoke-PSDeploy -Path "$PSScriptRoot/Cofl.Util.PSDeploy.ps1"
	Pop-Location
}

Task Test -depends ($Modules.Keys | ForEach-Object { "DEBUG - $_" }) {
    Import-Module "$OutDir/Cofl.Util/$($Modules['Cofl.Util'].Version)/Cofl.Util.psd1" -Force
    Push-Location $PSScriptRoot
	Invoke-Pester -Verbose:$VerbosePreference
	Pop-Location
}
