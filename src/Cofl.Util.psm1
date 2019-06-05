Add-Type -AssemblyName System.Device
Get-ChildItem "$PSScriptRoot/Public/*.ps1" | Foreach-Object { . $_.FullName }
