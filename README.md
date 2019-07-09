# Cofl.Util

A collection of miscellaneous functions I wrote or found amusing.

## Building

You'll need access to the [.NET Core SDK](https://dotnet.microsoft.com/download). Additionally, the module [`psake`](https://github.com/psake/psake) is used for building, and a recent version of [Pester](https://github.com/pester/Pester) for testing.

Once you have those, go to the root of the project and run

```powershell
PS C:/> ./build.ps1 -Task Build
```

which will automatically build all binary component using the .NET Core SDK and produce a compiled version of the module in the `build` directory.

## Cmdlets

### Get-Weather
This one is particularly fun:

```powershell
PS C:\> Get-Weather -ZipCode $ZipCode -ForecastType Detailed -AlertType Full -IncludeLocation -IncludeTime -IncludeAlertCount -Speakable | Say-String
```

Just remember to put in your zipcode!

### Others

There are more, I just haven't put them here yet.
