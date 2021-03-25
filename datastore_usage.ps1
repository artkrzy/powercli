
Connect-VIServer -Server vimwt02.ecb01.ecb.de -Protocol https -User ecb01\sa_krzywdz -password 
$filename = "Z:\results\TADNET_datastore_usage_2.csv"
#$Orig = Import-Csv $filename
#$Date = Get-Date
rm $filename
$Output = @()
Foreach ($Datastore in (get-datastore | where {$_.name -ne "*local"} ))
{
	$Details = "" | Select Name, FreeSpaceMB, CapacityMB
	$Details.Name = $datastore.Name
	$Details.FreeSpaceMB = $datastore.FreeSpaceMB
	$Details.CapacityMB = $datastore.CapacityMB
	$Output += $Details
}
$Output | Export-Csv -NoClobber -NoTypeInformation $filename
Disconnect-VIServer -Server * -Force -Confirm:$false