@{
    RootModule = 'Cofl.Util.psm1'
	ModuleVersion = '1.2.1'
	GUID = 'daa1909e-262f-43d8-9c1d-3df6015d0415'
	Author = 'Christian LaCourt <cllacour@mtu.edu>'
    Description = 'Util functions'

    FunctionsToExport = @(
        'Get-DailyWeather'
        'Get-GeoLocation'
        'Get-OrdinalNumber'
        'Get-Weather'
        'Invoke-Speech'
    )

    CmdletsToExport = @(
        'Get-FilteredChildItem'
    )
}
