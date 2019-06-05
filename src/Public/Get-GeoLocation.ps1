using namespace System.Device.Location

function Get-GeoLocation
{
    [CmdletBinding(DefaultParameterSetName='ByLocationAPI')]
    PARAM (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ParameterSetName='ByZipCode')]
            [int]$ZipCode,
        [Parameter()]
            [switch]$UseAPI
    )

    begin
    {
        $GeoData = $null
    }

    process
    {
        if($PSCmdlet.ParameterSetName -eq 'ByLocationAPI')
        {
            $Watcher = [GeoCoordinateWatcher]::new()
            $Watcher.Start()
            while($Watcher.Permission -ne 'Denied' -and $Watcher.Status -ne 'Ready')
            {
                Start-Sleep -Milliseconds 50
            }
            $Watcher.Position.Location
        } else
        {
            if($null -eq $GeoData)
            {
                $GeoData = Import-Csv -Path "$PSScriptRoot/../data/zip-geo.csv"
            }

            $Location = $GeoData | Where-Object ZIP -EQ $ZipCode
            [GeoCoordinate]::new($Location.LAT, $Location.LNG)
        }
    }
}
