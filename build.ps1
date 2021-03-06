#Requires -Modules psake
[CmdletBinding(DefaultParameterSetName='Do')]
PARAM (
	[Parameter(Position=0,ParameterSetName='Do')][string[]]$Task = 'Build',
	[Parameter(ParameterSetName='Show')][switch]$ListTasks
)

if($ListTasks){
	Invoke-Psake $PSScriptRoot\Cofl.Util.psake.ps1 -docs -parameters $Parameters -Verbose:$VerbosePreference
} else {
	Invoke-Psake $PSScriptRoot\Cofl.Util.psake.ps1 -taskList $Task -parameters $Parameters -Verbose:$VerbosePreference
}
