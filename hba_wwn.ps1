Connect-VIServer -server vimwt02.ecb01.ecb.de -User ecb01\sa_krzywdz -Password wasp-Label3mere
$report = @()
foreach ($esx in get-vmhost | get-view | sort-object name){
	foreach($hba in $esx.Config.StorageDevice.HostBusAdapter){
		if($hba.GetType().Name -eq "HostFibreChannelHba"){
			$row = "" | select Name,WWN
			$row.Name = $esx.name
			$wwn = $hba.PortWorldWideName
			$wwnhex = "{0:x}" -f $wwn
			$row.WWN = $wwnhex
			$report += $row
		}
	}
}
$report | export-csv z:\results\TADNET_wwn_01.csv -NoTypeInformation
Disconnect-VIServer