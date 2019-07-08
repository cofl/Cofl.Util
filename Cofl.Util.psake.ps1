#Requires -Modules PSake

[string]$DotNet = Get-Command 'dotnet.exe' -CommandType Application -ErrorAction Stop | Select-Object -ExpandProperty Source

[string]$PowerShellSrcRoot = "$PSScriptRoot/src/Cofl.Util.PowerShell"
[string]$OutName = 'build'
[string]$OutDir = "$PSScriptRoot/$OutName"
[string]$ModuleName = 'Cofl.Util'
[string]$ModuleOutDir = "$OutDir/$ModuleName"

Task default -depends Build

Task Init {
	if(!(Test-Path -LiteralPath $OutDir)){
		$null = New-Item -ItemType Directory -Path $PSScriptRoot -Name $OutName -Verbose:$VerbosePreference
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

Task Build -depends Clean {
    if([string]::IsNullOrWhiteSpace($ModuleVersion))
    {
        $ModuleVersion = '0.0.0'
    }
	if(!(Test-Path -LiteralPath $ModuleOutDir)){
        $null = New-Item -ItemType Directory -Path $OutDir -Name $ModuleName -Verbose:$VerbosePreference
    }
    $dir = New-Item -ItemType Directory -Path $ModuleOutDir -Name $ModuleVersion -Verbose:$VerbosePreference -Force

    & $DotNet build -c:Release
    Copy-Item -Recurse -Exclude $Exclude -Path $PowerShellSrcRoot/* -Destination $dir.FullName
    Copy-Item -Path "$PSScriptRoot/src/Cofl.Util/bin/Release/netstandard2.0/Cofl.Util.dll" -Destination $dir.FullName
}

Task Deploy -depends BuildHelp {
	if(!(Get-Module PSDeploy -ListAvailable)){
		throw "$(psake.context.currentTaskName) - PSDeploy is not available, cannot deploy."
	} else {
		Import-Module PSDeploy
	}
	Push-Location $PSScriptRoot
	Invoke-PSDeploy
	Pop-Location
}
