using namespace System.Collections
using namespace System.Collections.Generic

<#
.SYNOPSIS
Selects properties as in Select-Object, but with a more terse syntax.

.DESCRIPTION
Select-Property functions similarly to Select-Object, but offers an alternate syntax for selecting
properties.

Valid property values are:
1. A property equivalency in the form of a string "NewName=OldName"
2. Any other string that could be passed to Select-Object
3. A hashtable. The keys of the hashtable will be used as the new property names. The values can be:
    - A string (the old property name).
    - A scriptblock (as in Select-Object)
    - A type (will cast the property with the same name as the key to that type).
#>
function Select-Property {
    [CmdletBinding()]
    PARAM (
        [Parameter(Position=0)]
            [object[]]$Property,
        [Parameter()]
            [string[]]$LiteralProperty,
        [Parameter()]
            [string[]]$ExcludeProperty,
        [Parameter(ValueFromPipeline)][psobject]$InputObject,
        [Parameter()][int]$First,
        [Parameter()][int]$Last,
        [Parameter()][int]$Skip
    )

    begin {
        $Properties = @(
            $LiteralProperty | Where-Object { ![string]::IsNullOrEmpty($_) }
            foreach($Item in $Property){
                if($Item -is [string] -and $Item -match '^([^=]+)=(.+)$'){
                    @{
                        Name = $Matches[1]
                        Expression = $Matches[2]
                    }
                } elseif($Item -is [IDictionary]){
                    foreach($Key in $Item.Keys){
                        $Value = $Item[$Key]
                        if($Value -is [type]){
                            @{
                                Name = $Key
                                Expression = [scriptblock]::Create("`$_.'$($Key -replace "'", "''")' -as ([type]'$($Value -replace "'", "''")')")
                            }
                        } else {
                            @{
                                Name = $Key
                                Expression = $Item[$Key]
                            }
                        }
                    }
                } else {
                    $Item
                }
            })
        $HasFirst = $PSBoundParameters.ContainsKey('First')
        $HasLast = $PSBoundParameters.ContainsKey('Last')
        if($HasLast){
            $LastObjects = [Queue[psobject]]::new()
        }
    }

    process {
        if($Skip -gt 0){
            $Skip -= 1
            return
        }

        if($HasFirst){
            if($First -le 0){
                return
            }
            $First -= 1
        }

        if($HasLast){
            $LastObjects.Enqueue($InputObject)
            if($LastObjects.Count -gt $Last)
            {
                $null = $LastObjects.Dequeue()
            }
            return
        }

        Select-Object -Property $Properties -ExcludeProperty $ExcludeProperty -InputObject $InputObject
    }

    end {
        if($HasLast){
            foreach($Item in $LastObjects){
                Select-Object -Property $Properties -ExcludeProperty $ExcludeProperty -InputObject $Item
            }
        }
    }
}
