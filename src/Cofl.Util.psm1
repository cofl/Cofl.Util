Add-Type -AssemblyName System.Device
Add-Type -AssemblyName System.Speech
Get-ChildItem "$PSScriptRoot/Public/*.ps1" | Foreach-Object { . $_.FullName }
