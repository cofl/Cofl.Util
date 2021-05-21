<#
.SYNOPSIS
Reads properties for multiple items.

.DESCRIPTION
Read-MultiDataSequential accepts a base object and a list of properties. While values are being entered,
generate a new object from the base object and the additional properties.

To stop entering values, provide no value for any property for a whole object.

.EXAMPLE
PS C:\> Read-MultiData -BaseObject ([pscustomobject]@{ Test = $true }) -Properties InstanceNumber

Prompts for InstanceNumber 3 times, emitting objects with two properties (InstanceNumber with the supplied value, and Test being $true).
#>
function Read-MultiDataSequential {
    [CmdletBinding()]
    PARAM (
        # Property names to populate
        [Parameter(Mandatory)][string[]]$Properties,
        # A base object.
        [psobject]$BaseObject = [pscustomobject]@{}
    )

    Write-Host "To exit, enter no value for one whole object."
    for(;;){
        [array]$Data = foreach($Name in $Properties){
            [pscustomobject]@{
                Key = $Name
                Value = Read-Host -Prompt $Name
            }
        }

        if(!($Data.Value | Where-Object { ![string]::IsNullOrEmpty($_) })){
            break
        }

        Select-Object -InputObject $BaseObject -Property @(
            '*'
            foreach($Datum in $Data){
                @{
                    Name = $Datum.Key
                    Expression = [scriptblock]::Create("""$($Datum.Value -replace '"', '""')""")
                }
            }
        )
    }
}
