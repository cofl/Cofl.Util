function Get-OrdinalNumber
{
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][int]$Number
    )

    process
    {
        [int]$ModHundred = $Number % 100
        [int]$ModTen = $Number % 10

        [string]$Suffix = 'th'
        if($ModHundred -gt 20 -or $ModHundred -lt 10)
        {
            switch($ModTen)
            {
                1 { $Suffix = 'st' }
                2 { $Suffix = 'nd' }
                3 { $Suffix = 'rd' }
            }
        }
        "$Number$Suffix"
    }
}
