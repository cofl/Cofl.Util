# Cofl.Util

A collection of miscellaneous functions I wrote or found amusing.

## Get-Weather
This one is particularly fun:

```powershell
PS C:\> Get-Weather -ZipCode $ZipCode -ForecastType Detailed -AlertType Full -IncludeLocation -IncludeTime -IncludeAlertCount -Speakable | Say-String
```

Just remember to put in your zipcode!
