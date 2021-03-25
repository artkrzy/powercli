function Copy-CSVtoSheet{
	param($to, $CSVname)

	$csvBook = $excelApp.Workbooks.Open($CSVname)
	$csvSheet = $csvBook.Worksheets.Item(1)
	$csvSheet.UsedRange.Copy() | Out-Null
	$to.Paste()
	$to.UsedRange.EntireColumn.AutoFit() | Out-Null
	$csvbook.Application.CutCopyMode = $false
	$csvBook.Close($false,$null,$null)
}

# Remember current VIServer mode
#$oldMode = (Get-PowerCLIConfiguration).DefaultVIServerMode
# Set VIServer mode to multiple
#Set-PowerCLIConfiguration -DefaultVIServerMode "Multiple" -Confirm:$false | Out-Null
#Connect-VIServer -Server vimwp02.ecb01.ecb.de
$hostinventory = "d:\dmz_hosts.csv"
Get-VMHost | Select Name | Export-Csv $hostinventory -NoTypeInformation
$inputCsv = $hostinventory
$myHosts = Import-Csv $inputCsv | %{Get-VMHost -Name $_.Name}
$tempCSV = $env:Temp + "\Report-" + (Get-Date).Ticks + ".csv"

$excelApp = New-Object -ComObject "Excel.Application"
# $excelApp.Visible = $true
$workBook = $excelApp.Workbooks.Add()

#$inputCsv = ""
#$myHosts = Import-Csv $inputCsv | %{
#	Connect-VIServer -Server $_.Name -User root -Password Kastemato01 |Out-Null
#	Get-VMHost -Name $_.Name
#}
#$tempCSV = $env:Temp + "\Report-" + (Get-Date).Ticks + ".csv"

#$excelApp = New-Object -ComObject "Excel.Application"
#$workBook = $excelApp.Workbooks.Add()

# Report 1: ESX report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "ESX report"

$report = $myHosts | Select Name, Version,Build, Manufacturer, Model, ProcessorType,
@{N="NumCPU";E={($_| Get-View).Hardware.CpuInfo.NumCpuPackages}},
@{N="Cores";E={($_| Get-View).Hardware.CpuInfo.NumCpuCores}},
@{N="Service Console IP";E={($_|Get-VMHostNetwork).ConsoleNic[0].IP}},
@{N="vMotion IP";E={($_|Get-VMHostNetwork).VirtualNic[0].IP}},
@{N="HBA count";E={($_| Get-VMHostHba | where {$_.Type -eq "FibreChannel"}).Count}},
@{N="Physical NICS count";E={($_ | Get-View).Config.Network.Pnic.Count}} 

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV

# Report 2: VM report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "VM report"

$report = $myHosts | Get-VM | %{
	$VM = $_
	$VMview = $VM | Get-View
	$VMResourceConfiguration = $VM | Get-VMResourceConfiguration -ErrorAction SilentlyContinue
	$VMHardDisks = $VM | Get-HardDisk
	$HardDisksSizesGB = @()
	$Temp = $VMHardDisks | ForEach-Object { $HardDisksSizesGB += [Math]::Round($_.CapacityKB/1MB) }
	$VmdkSizeGB = ""
	$Temp = $HardDisksSizesGB | ForEach-Object { $VmdkSizeGB += "$_+" }
	$VmdkSizeGB = $VmdkSizeGB.TrimEnd("+")
	$TotalHardDisksSizeGB = 0
	$Temp = $HardDisksSizesGB | ForEach-Object { $TotalHardDisksSizeGB += $_ }
	$Snapshots = $VM | Get-Snapshot
	$row = "" | Select-Object VMname,ESXname,MemoryGB,vCPUcount,vNICcount,IPaddresses,VmdkSizeGB,TotalVmdkSizeGB,DatastoreName,ToolsVersion,ToolsUpdate,SnapshotCount,GuestOS
	$row.VMName = $VM.name
	$row.ESXname = $VM.Host
	$row.MemoryGB = $VM.MemoryMB/1024
	$row.vCPUcount = $VM.NumCpu
	$row.vNICcount = $VM.Guest.Nics.Count
	$row.IPaddresses = [system.string]::Join(" ",$VM.Guest.IPAddress)
	$row.VmdkSizeGB = $VmdkSizeGB
	$row.TotalVmdkSizeGB = $TotalHardDisksSizeGB
	$row.DatastoreName = [system.string]::Join(" ",@($VMview.Config.DatastoreUrl | %{$_.Name}))
	$row.ToolsVersion = $VMview.Config.Tools.ToolsVersion
	$row.ToolsUpdate = $VMview.Guest.ToolsStatus
	$row.SnapshotCount = (@($VM | Get-Snapshot)).Count
	$row.GuestOS = $VM.Guest.OSFullName
	$row
}

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV

# Report 3: pNIC report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "pNIC report"

$report = foreach($esxImpl in $myHosts){ 
	$esx = $esxImpl | Get-View
	$netSys = Get-View $esx.ConfigManager.NetworkSystem -Server ($defaultVIServers | where {$_.Name -eq $esxImpl.Name})
	foreach($pnic in $esx.Config.Network.Pnic){
		$vSw = $esxImpl | Get-VirtualSwitch | where {$_.Nic -contains $pNic.Device}
		$pg = $esxImpl | Get-VirtualPortGroup | where {$_.VirtualSwitchName -eq $vSw.Name}
		$order = ($esx.Config.Network.Vswitch | where {$_.Name -eq $vSw.Name}).Spec.Policy.NicTeaming.NicOrder
		$cdpInfo = $netSys.QueryNetworkHint($pnic.Device)
		$pnic | Select @{N="ESXname";E={$esxImpl.Name}},
			@{N="pNic";E={$pnic.Device}}, 
			@{N="Model";E={($esx.Hardware.PciDevice | where {$_.Id -eq $pnic.Pci}).DeviceName}},
			@{N="vSwitch";E={$vSw.Name}},
			@{N="Portgroups";E={$pg | %{$_.Name}}},
			@{N="Speed";E={$pnic.LinkSpeed.SpeedMb}},
			@{N="Status";E={if($pnic.LinkSpeed -ne $null){"up"}else{"down"}}},
			@{N="PCI Location";E={$pnic.Pci}},
			@{N="Active/stand-by/unassigned";E={if($order.ActiveNic -contains $pnic.Device){"active"}elseif($order.StandByNic -contains $pnic.Device){"standby"}else{"unused"}}},
			@{N="IP range";E={[string]::Join("/",@($cdpInfo[0].Subnet | %{$_.IpSubnet + "(" + $type + ")"}))}},
			@{N="Physical switch";E={&{if($cdpInfo[0].connectedSwitchPort){$cdpInfo[0].connectedSwitchPort.devId}else{"CDP not configured"}}}},
			@{N="PortID";E={&{if($cdpInfo[0].connectedSwitchPort){$cdpInfo[0].connectedSwitchPort.portId}else{"CDP not configured"}}}}
	}
}

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV

# Report 4: Portgroup report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "Portgroup report"

$report = foreach($esxImpl in $myHosts ){ 
	$esx = $esxImpl | Get-View
	$netSys = Get-View $esx.ConfigManager.NetworkSystem -Server ($defaultVIServers | where {$_.Name -eq $esxImpl.Name})
	foreach($pg in $esx.Config.Network.Portgroup){
		$pNICStr = @()
		$pciStr = @()
		$cdpStr = @()
		foreach($a in $pg.ComputedPolicy.NicTeaming.NicOrder.ActiveNic){
			if($a){
				$pNICStr += ($a + "(a)")
				$pciStr += ($esx.Config.Network.Pnic | where {$_.Device -eq $a} | %{$_.Pci + "(a)"})
				$cdpInfo = $netSys.QueryNetworkHint($a)
				$cdpStr += &{if($cdpInfo[0].connectedSwitchPort){
								$cdpInfo[0].connectedSwitchPort.devId + "(a):" + $cdpInfo[0].connectedSwitchPort.PortId + "(a)"
							}
							else{"CDP not configured(a)"}}
			}
		}
		foreach($s in $pg.ComputedPolicy.NicTeaming.NicOrder.StandbyNic){
			if($s){
				$pNICStr += ($s + "(s)")
				$pciStr += ($esx.Config.Network.Pnic | where {$_.Device -eq $s} | %{$_.Pci + "(s)"})
				$cdpInfo = $netSys.QueryNetworkHint($s)
				$cdpStr += &{if($cdpInfo[0].connectedSwitchPort){
								$cdpInfo[0].connectedSwitchPort.devId + "(s):" + $cdpInfo[0].connectedSwitchPort.PortId + "(s)"
							}
							else{"CDP not configured(s)"}}
			}
		}

		$pg | Select @{N="ESXname";E={$esxImpl.Name}},
		@{N="vSwitch";E={($esx.Config.Network.Vswitch | where {$_.Key -eq $pg.Vswitch}).Name}},
		@{N="Portgroup";E={$pg.Spec.Name}},
		@{N="VLANid";E={$pg.Spec.VlanId}},
		@{N="pNIC";E={$pNICStr}},
		@{N="PCI location";E={$pciStr}},
		@{N="Physical switch";E={$cdpStr}}
	}
}

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV

# Report 5: SCSI HBA report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "SCSI HBA report"

$report = $myHosts | %{
	$esxImpl = $_
	$esxImpl | Get-VMHostHba | select @{N="ESX Name";E={$esxImpl.Name}},
			@{N="Device";E={$_.Device}},
			@{N="HBA Model";E={$_.Model}},
			@{N="HBA Type";E={$_.Type}},
			@{N="Driver";E={$_.Driver}},
			@{N="PCI";E={$_.Pci}},
			@{N="PWWN";E={$hbaKey = $_.Key; "{0:x}" -f (($esxImpl | Get-View).Config.StorageDevice.HostBusAdapter | where {$_.GetType().Name -eq "HostFibreChannelHba" -and $_.Key -eq $hbaKey}).PortWorldWideName}}
}

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV

# Report 6: Datastore report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "Datastore report"

$dsTab = @{}
$report = $myHosts | %{
	$esxImpl = $_
	$ds = $esxImpl | Get-Datastore | %{$dsTab[$_.Name] = $_}
	$esxImpl | Get-VMHostStorage | %{
		$_.FileSystemVolumeInfo | %{
			$sizeGB = $_.Capacity/1GB
			$usedGB = ($_.Capacity/1MB - ($dsTab[$_.Name]).FreeSpaceMB)/1KB
			$usedPerc = $usedGB / $sizeGB
			$availGB = ($dsTab[$_.Name]).FreeSpaceMB/1KB
			$ds = Get-View $dsTab[$_.Name].Id
			$_ | select @{N="ESX Name";E={$esxImpl.Name}},
				@{N="FS Name";E={$_.Name}},
				@{N="Type";E={$_.Type}},
				@{N="SizeGB";E={"{0:N1}" -f $sizeGB}},
				@{N="UsedGB";E={"{0:N1}" -f $usedGB}},
				@{N="AvailableGB";E={"{0:N1}" -f $availGB}},
				@{N="Used%";E={"{0:P1}" -f $usedPerc}},
				@{N="Mount point";E={$_.Path}},
				@{N="Extents";E={if($_.Type -eq "VMFS"){$ds.Info.Vmfs.Extent[0].DiskName}
								elseif($_.Type -eq "NFS"){$ds.Info.Nas.RemoteHost + ":" + $ds.Info.Nas.RemotePath}}}
		}
	}
}

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV

# Report 7: Firewall report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "Firewall report"

$report = $myHosts | %{
	$esxImpl = $_
	$_ | Get-VMHostFirewallException -Enabled:$true | %{
		if($_.IncomingPorts){
			$row = "" | Select "ESX name","In/out",ServiceName,Port,Protocol
			$row."ESX name" = $esxImpl.Name
			$row."In/out" = "in"
			$row.ServiceName = $_.Name
			$row.Port = $_.IncomingPorts
			$row.Protocol = $_.Protocols
			$row
		}
		if($_.OutgoingPorts){
			$row = "" | Select "ESX name","In/out",ServiceName,Port,Protocol
			$row."ESX name" = $esxImpl.Name
			$row."In/out" = "out"
			$row.ServiceName = $_.Name
			$row.Port = $_.OutgoingPorts
			$row.Protocol = $_.Protocols
			$row
		}
	}
}

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV

# Report 8: Time servers report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "Time servers report"

$report = $myHosts | %{
	$esxImpl = $_
	$_ | Get-VMHostNtpServer | %{
		$row = "" | Select "ESX name","Time Server"
		$row."ESX name" = $esxImpl.Name
		$row."Time Server" = $_
		$row
	}
}

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV

# Report 9: DNS servers report
$sheet = $excelApp.Worksheets.Add()
$sheet.Name = "DNS servers report"

$report = $myHosts | %{
	$esxImpl = $_
	($_ | Get-View).Config.Network.DnsConfig.Address | %{
		$row = "" | Select "ESX name","DNS Server"
		$row."ESX name" = $esxImpl.Name
		$row."DNS Server" = $_
		$row
	}
}

$report | Export-Csv -Path $tempCSV -NoTypeInformation
Copy-CSVtoSheet $sheet $tempCSV
#Clean up workbook & close
$workbook.Sheets | where {$_.Name -like "Sheet*"} | %{$_.Delete()}
$nrSheets = $workbook.Sheets.Count
1..($nrSheets-1) |%{
	$workbook.Sheets.Item($nrSheets).Move($workbook.Sheets.Item($_))
}
$workbook.Sheets.Item(1).Select()
$workbook.SaveAs("D:\PROD_OLD_complete_inventory.xls")
$excelApp.Quit()
Stop-Process -Name "Excel"

# Set VIServer mode to original value
Set-PowerCLIConfiguration -DefaultVIServerMode $oldMode -Confirm:$false | Out-Null
Disconnect-VIServer -Server * -Force -Confirm:$false
