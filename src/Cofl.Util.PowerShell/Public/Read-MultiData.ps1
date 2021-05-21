<#
.SYNOPSIS
Reads properties for multiple objects in parallel, then outputs values for all.

.DESCRIPTION
Reads properties for multiple objects in parallel, then outputs new objects for all.

The properties parameter is a map of key names to constants (passed through), script blocks (evaluated with the index), and $null (queries for a value).
#>
function Read-MultiData {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory)]
            # The number of objects to get data for.
            [ValidateScript({ $_ -gt 0 })]
            [int]$Count,
        [ValidateNotNullOrEmpty()]
            # Property mappings to populate. Scriptblock values will be passed the current index, constant values will pass through, and null values will prompt a query.
            [hashtable]$Properties = @{},
        [ValidateNotNullOrEmpty()]
            # Extra properties to query for.
            [string[]]$QueryProperty = @()
    )

    $ObjectProperties = @(
        $Properties.GetEnumerator().ForEach({ $_ })
        $QueryProperty | Where-Object { $_ } | ForEach-Object {
            [pscustomobject]@{
                Key = $_
                Value = $null
            }
        }
    )

    [array]$ValueData = foreach($Property in $ObjectProperties){
        [pscustomobject]@{
            Name = $Property.Key.ToString()
            Values = [array]@(foreach($Index in 0..($Count - 1)){
                if($null -eq $Property.Value){
                    Read-Host -Prompt $Property.Key
                } elseif($Property.Value -is [scriptblock]) {
                    $Index | ForEach-Object -Process $Property.Value
                } else {
                    $Property.Value
                }
            })
        }
    }

    foreach($Index in 0..($Count - 1)){
        $Values = [ordered]@{}
        foreach($Entry in $ValueData){
            $Values[$Entry.Name] = $Entry.Values[$Index]
        }
        [pscustomobject]$Values
    }
}
