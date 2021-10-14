@{
    RootModule = 'Cofl.Util.psm1'
	ModuleVersion = '1.3.2'
	GUID = 'daa1909e-262f-43d8-9c1d-3df6015d0415'
	Author = 'Christian LaCourt <cllacour@mtu.edu>'
    Description = 'Util functions'

    FunctionsToExport = @(
        'Get-DailyWeather'
        'Get-GeoLocation'
        'Get-OrdinalNumber'
        'Get-Weather'
        'Invoke-DelayedTask'
        'Invoke-Ditty'
        'Invoke-Speech'
        'Read-MultiData'
        'Read-MultiDataSequential'
        'Select-Property'
    )

    CmdletsToExport = @(
        'ConvertTo-EncodedString'
        'ConvertFrom-EncodedString'
        'Get-FilteredChildItem'

        # menu cmdlets
        'Invoke-Menu'
        'New-Menu'
        'New-MenuDelayedTask'
        'New-MenuFunction'
        'New-MenuText'
    )
}
