using namespace System.Text

function Get-Weather
{
    [CmdletBinding(DefaultParameterSetName='ZipCodeForecast')]
    [OutputType([string])]
    PARAM (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='ZipCodeForecast')]
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='ZipCodeAlert')]
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='ZipCodeForecastAlert')]
            [int]$ZipCode,
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true,ParameterSetName='GeoForecast')]
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true,ParameterSetName='GeoAlert')]
        [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true,ParameterSetName='GeoForecastAlert')]
            [double]$Latitude,
        [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='GeoForecast')]
        [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='GeoAlert')]
        [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='GeoForecastAlert')]
            [double]$Longitude,
        [Parameter(ParameterSetName='ZipCodeForecast')]
        [Parameter(ParameterSetName='GeoForecast')]
        [Parameter(ParameterSetName='ZipCodeForecastAlert')]
        [Parameter(ParameterSetName='GeoForecastAlert')]
            [ValidateSet(0,1,2,3,4,5,6,7,8,9,10,11,12,13)][int]$PeriodsFromNow = 0,
        [Parameter(ParameterSetName='ZipCodeForecast')]
        [Parameter(ParameterSetName='GeoForecast')]
        [Parameter(Mandatory=$true,ParameterSetName='ZipCodeForecastAlert')]
        [Parameter(Mandatory=$true,ParameterSetName='GeoForecastAlert')]
            [ValidateSet('Short', 'Detailed')][string]$ForecastType = 'Short',
        [Parameter(ParameterSetName='ZipCodeForecast')]
        [Parameter(ParameterSetName='GeoForecast')]
        [Parameter(ParameterSetName='ZipCodeForecastAlert')]
        [Parameter(ParameterSetName='GeoForecastAlert')]
            [switch]$IncludeLocation,
        [Parameter(ParameterSetName='ZipCodeForecast')]
        [Parameter(ParameterSetName='GeoForecast')]
        [Parameter(ParameterSetName='ZipCodeForecastAlert')]
        [Parameter(ParameterSetName='GeoForecastAlert')]
            [switch]$IncludeTime,
        [Parameter(Mandatory=$true,ParameterSetName='ZipCodeAlert')]
        [Parameter(Mandatory=$true,ParameterSetName='GeoAlert')]
        [Parameter(Mandatory=$true,ParameterSetName='ZipCodeForecastAlert')]
        [Parameter(Mandatory=$true,ParameterSetName='GeoForecastAlert')]
            [ValidateSet('Short', 'Detailed', 'Full')][string]$AlertType,
        [Parameter(ParameterSetName='ZipCodeAlert')]
        [Parameter(ParameterSetName='GeoAlert')]
        [Parameter(ParameterSetName='ZipCodeForecastAlert')]
        [Parameter(ParameterSetName='GeoForecastAlert')]
            [switch]$IncludeAlertCount,
        [Parameter()]
            [switch]$Speakable
    )

    begin
    {
        $GeoData = $null
        $Abbreviations = @{
            AL = 'Alabama';        AK = 'Alaska';         AZ = 'Arizona'
            AR = 'Arkansas';       CA = 'California';     CO = 'Colorado'
            CT = 'Connecticut';    DE = 'Delaware';       DC = 'DC'
            FL = 'Florida';        GA = 'Georgia';        HI = 'Hawaii'
            ID = 'Idaho';          IL = 'Illinois';       IN = 'Indiana'
            IA = 'Iowa';           KS = 'Kansas';         KY = 'Kentucky'
            LA = 'Louisiana';      ME = 'Maine';          MD = 'Maryland'
            MA = 'Massachusetts';  MI = 'Michigan';       MN = 'Minnesota'
            MS = 'Mississippi';    MO = 'Missouri';       MT = 'Montana'
            NE = 'Nebraska';       NV = 'Nevada';         NH = 'New Hampshire'
            NJ = 'New Jersey';     NM = 'New Mexico';     NY = 'New York'
            NC = 'North Carolina'; ND = 'North Dakota';   OH = 'Ohio'
            OK = 'Oklahoma';       OR = 'Oregon';         PA = 'Pennsylvania'
            RI = 'Rhode Island';   SC = 'South Carolina'; CZ = 'in the Panama Canal Zone'
            TN = 'Tennessee';      TX = 'Texas';          AE = 'in the U.S. Armed Forces - Europe'
            VT = 'Vermont';        VA = 'Virginia';       CM = 'in the Northern Mariana Islands'
            WV = 'West Virginia';  WI = 'Wisconsin';      AA = 'in the U.S. Armed Forces - Americas'
            AS = 'American Samoa'; GU = 'Guam';           MP = 'Northern Mariana Islands'
            PR = 'Puerto Rico';    NB = 'Nebraska';       VI = 'in the U.S. Virgin Islands'
            WY = 'Wyoming';        UT = 'Utah';           AP = 'in the U.S. Armed Forces - Pacific'
            WA = 'Washington';     SD = 'South Dakota';   PI = 'in the Philippine Islands'
            TT = 'in the Trust Territory of the Pacific Islands'
        }

        function Format-NiceDate ([datetime]$Date)
        {
            $Date.ToString('dddd MMMM * a\t h:mm tt') -replace '\*', (Get-OrdinalNumber -Number $Date.Day)
        }

        function Format-AlertHeadline ($Alert)
        {
            [datetime]$Issued = $Alert.sent
            [datetime]$Effective = $Alert.effective
            [datetime]$Ends = if($Alert.ends) { $Alert.ends } else { $Alert.expires }
            [string[]]$Areas = $Alert.areaDesc -split '; '
            [string]$AreaDescription = if($Areas.Count -gt 1) { ($Areas[0..$($Areas.Count-2)] -join ', ') + ' and ' + ($Areas[-1]) } else { $Areas[0] }

            if($Issued -eq $Effective)
            {
                "$($Alert.status) $($Alert.severity) $($Alert.event) issued $(Format-NiceDate $Issued) for $AreaDescription, effective until $(Format-NiceDate $Ends). "
            } else
            {
                "$($Alert.status) $($Alert.severity) $($Alert.event) issued $(Format-NiceDate $Issued) for $AreaDescription, effective from $(Format-NiceDate $Effective) until $(Format-NiceDate $Ends). "
            }
        }
    }

    process
    {
        # Get the $Location table for our $PointURI
        $Location = @{ LAT = $Latitude; LNG = $Longitude }
        if($PSCmdlet.ParameterSetName.StartsWith('ZipCode'))
        {
            if($null -eq $GeoData)
            {
                # Don't import the Zip/GPS mapping until we need it.
                $GeoData = Import-Csv -Path "$PSScriptRoot/../data/zip-geo.csv"
            }
            $Location = $GeoData | Where-Object ZIP -EQ $ZipCode
            if(!$Location)
            {
                throw "Could not find location $ZipCode in the available data."
            }
        }

        [string]$PointUri = "https://api.weather.gov/points/$($Location.LAT),$($Location.LNG)"
        $PointData = Invoke-RestMethod -Uri $PointUri -UseBasicParsing -Headers @{Accept='application/geo+json'}
        [string]$ZoneID = $PointData.properties.forecastZone -replace 'https?://api\.weather\.gov/zones/forecast/'
        # After this statement, assume $Location is a string.
        if($PointData.properties.relativeLocation.properties.city)
        {
            $Location = "$($PointData.properties.relativeLocation.properties.city) $($Abbreviations[$PointData.properties.relativeLocation.properties.state])"
        } elseif($PSCmdlet.ParameterSetName -eq 'ZipCode')
        {
            $Location = "Zip Code $("$ZipCode" -split '' -join ' ')"
        } else
        {
            $Location = "Latitude $Latitude, Longitude $Longitude, "
        }

        $APIResponse = Invoke-RestMethod -Uri $PointData.properties.forecast -UseBasicParsing -Headers @{Accept='application/geo+json'}
        $ForecastData = $APIResponse.properties.periods[$PeriodsFromNow]
        [StringBuilder]$Output = [StringBuilder]::new()
        [bool]$IsForecast = $PSCmdlet.ParameterSetName.Contains('Forecast') -or $PSBoundParameters.ContainsKey('ForecastType')
        [bool]$IsAlert = $PSBoundParameters.ContainsKey('AlertType')

        if($IsForecast)
        {
            if($IncludeLocation)
            {
                if($IncludeTime)
                {
                    [void]$Output.Append("The forecast $($ForecastData.name) for $Location is: ")
                } else
                {
                    [void]$Output.Append("The forecast for $Location is: ")
                }
            } elseif($IncludeTime)
            {
                [void]$Output.Append("The forecast for $($ForecastData.name) is: ")
            }

            if($ForecastType -eq 'Short')
            {
                [void]$Output.Append($ForecastData.shortForecast)
            } else
            {
                [void]$Output.Append($ForecastData.detailedForecast)
            }
            [void]$Output.Append("`n")
        }

        if($IsAlert)
        {
            $APIResponse = Invoke-RestMethod -URI "https://api.weather.gov/alerts/active/zone/$ZoneID"

            if($APIResponse.features.Count -eq 0)
            {
                [void]$Output.Append("There are no current alerts for $($Location -replace ', $').")
                [string]$OutputString = $Output.ToString().Trim()
                if($Speakable)
                {
                    $OutputString = $OutputString -replace '\bwind(s?)\b', 'winnd$1'
                }
                return $OutputString # early-out
            }

            if($IncludeAlertCount)
            {
                [void]$Output.Append("There $(if($APIResponse.features.Count -eq 1) { 'is' } else { 'are' }) $($APIResponse.features.Count) current alerts for $($Location -replace ', $'):`n")
            }

            foreach($Alert in $APIResponse.features)
            {
                $Alert = $Alert.properties
                [string]$Headline = Format-AlertHeadline $Alert
                switch ($AlertType)
                {
                    'Short' {
                        [void]$Output.Append($Headline)
                    }
                    'Detailed' {
                        [void]$Output.Append($Headline)
                        [void]$Output.Append("The description is: ").Append(($Alert.description -replace '^\.\.', '' -replace '\\n', ' ' -replace "`n", ' ' -replace '\* ', ' '))
                        [void]$Output.Append("`n")
                    }
                    'Full' {
                        [void]$Output.Append($Headline)
                        [void]$Output.Append("The description is: ").Append(($Alert.description -replace '^\.\.', '' -replace '\\n', ' ' -replace "`n", ' ' -replace '\* ', ' '))
                        [void]$Output.Append(($Alert.instruction -replace '\\n', ' ' -replace "`n", '' -replace '\* ', ' '))
                        [void]$Output.Append("`n")
                    }
                }
                [void]$Output.Append("`n")
            }
        }

        [string]$OutputString = $Output.ToString().Trim()
        if($Speakable)
        {
            $OutputString = $OutputString -replace '\bwind(s?)\b', 'winnd$1' -replace '\bmph\b', 'miles per hour'
        }
        return $OutputString
    }
}
