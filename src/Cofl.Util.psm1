Get-ChildItem "$PSScriptRoot/Public/*.ps1" | Foreach-Object { . $_.FullName }
