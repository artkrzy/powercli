#connect-viserver -Server 
Get-VM | Select @{N="Host";E={$_.Host.Name}},Name,
    @{N="Datastore";E={[string]::Join(',',($_.Extensiondata.Config.DatastoreUrl | %{$_.Name}))}},
    @{N="Lun";E={
       			[string]::Join(',',(
                Get-Datastore -Name ($_.Extensiondata.Config.DatastoreUrl | %{$_.Name}) | %{
                    $_.Extensiondata.Info.Vmfs.Extent[0].DiskName
            }))
    }} | Export-Csv "z:\unix_VM-VMFS-location.csv" -NoTypeInformation