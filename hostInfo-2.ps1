Get-VMHost | Select Name, Version,
	Build, 
	@{N="Cluster Name";E={($_ | Get-Cluster).Name}},
	Manufacturer, Model, ProcessorType,
	@{N="NumCPU";E={($_| Get-View).Hardware.CpuInfo.NumCpuPackages}},
	@{N="Cores";E={($_| Get-View).Hardware.CpuInfo.NumCpuCores}},
	@{N="Service Console IP";E={($_|Get-VMHostNetwork).ConsoleNic[0].IP}},
	@{N="vMotion IP";E={($_|Get-VMHostNetwork).VirtualNic[0].IP}},
	@{N="HBA count";E={($_| Get-VMHostHba | where {$_.Type -eq "FibreChannel"}).Count}},
	@{N="Datastores";E={[string]::Join(",",( $_ | Get-Datastore | %{$_.Name}))}},
	@{N="FC Device";E={[string]::Join(",",(($_ | Get-View).Config.StorageDevice.HostBusAdapter | where{$_.GetType().Name -eq "HostFibreChannelHba"} | %{$_.Device}))}},
	@{N="FC WWN";E={[string]::Join(",",(($_ | Get-View).Config.StorageDevice.HostBusAdapter | where{$_.GetType().Name -eq "HostFibreChannelHba"} | %{"{0:x}" -f $_.NodeWorldWideName}))}},
	@{N="Physical NICS count";E={($_ | Get-View).Config.Network.Pnic.Count}},
	@{N="vSwitches";E={[string]::Join(",",( $_ | Get-VirtualSwitch | %{$_.Name}))}},
	@{N="Portgroups";E={[string]::Join(",",( $_ | Get-VirtualPortGroup | %{$_.Name}))}}

