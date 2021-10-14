@{
    RootModule = 'Cofl.Menu.dll'
	ModuleVersion = '1.0.0'
	GUID = '0cbe0d5c-3820-409b-af73-e7bd4549ca06'
	Author = 'Christian LaCourt <cllacour@mtu.edu>'
    Description = 'Menu cmdlets from Cofl.Util'

    CmdletsToExport = @(
        'Invoke-Menu'
        'New-Menu'
        'New-MenuDelayedTask'
        'New-MenuFunction'
        'New-MenuText'
    )
}
