<#
.SYNOPSIS
   Script generates vm_inventory_report.csv file containing information vms running under control of given vcenter
.DESCRIPTION
   Script connects to vCenter server passed as parameter and enumerates all virtual machines per connected host.
   VM Templates are excluded 
.PARAMETER vCenterServer
   Mandatory parameter indicating vCenter server to connect to (FQDN or IP address)
.EXAMPLE
   .\vm-inventory_reportv2.ps1 -vCenterServer vcenter.seba.local
.EXAMPLE   
   .\vm-inventory_reportv2.ps1
#>

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$false,Position=1)]
   [string]$vCenterServer = 'vcswp01.esx.unix.ecb.de'
)

#variables
$StartTime = Get-Date -Format "yyyyMMddHHmmss_"
$ScriptRoot = Split-Path $MyInvocation.MyCommand.Path
$csvoutfile = $ScriptRoot + "\" + $StartTime +"vm_inventory_report.csv"
$vms_inventory =@()

$vmsnapin = Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue
$Error.Clear()
if ($vmsnapin -eq $null) 	
	{
	Add-PSSnapin VMware.VimAutomation.Core
	if ($error.Count -eq 0)
		{
		write-host "$($(get-date -format "[yyyy-MM-dd HH:mm:ss] "))PowerCLI VimAutomation.Core Snap-in was successfully enabled." -ForegroundColor Green
		}
	else
		{
		write-host "$($(get-date -format "[yyyy-MM-dd HH:mm:ss] "))ERROR: Could not enable PowerCLI VimAutomation.Core Snap-in, exiting script" -ForegroundColor Red
		Exit
		}
	}
else
	{
	Write-Host "$($(get-date -format "[yyyy-MM-dd HH:mm:ss] "))PowerCLI VimAutomation.Core Snap-in is already enabled" -ForegroundColor Green
	}

$Error.Clear()
#connect vCenter from parameter
Connect-VIServer -Server $vCenterServer -ErrorAction SilentlyContinue | Out-Null

#execute only if connection successful
if ($error.Count -eq 0){
	
	Write-Host "$($(get-date -format "[yyyy-MM-dd HH:mm:ss] "))vCenter $vCenterServer successfuly connected. Working on the report ..." -ForegroundColor yellow
	
	$stop_watch = [Diagnostics.Stopwatch]::StartNew()
	
	$vmhosts = get-vmhost -state connected
	
	foreach ($vmhost in $vmhosts){
	
		$vms = get-vm -location $vmhost | where-object {( -not $_.Config.Template)}
	
			foreach ($vm in $vms){
		
				$networknames =""
				$vm_info = New-Object PSObject
				$vm_info | Add-Member -Name VMClusterName -Value $vmhost.Parent.Name -MemberType NoteProperty
				$vm_info | Add-Member -Name VMHostName -Value $vmhost.Name -MemberType NoteProperty
				$vm_info | Add-Member -Name VMName -Value $vm.name -MemberType NoteProperty
				$vm_info | Add-Member -Name VMGuesOSHostname -Value $vm.guest.hostname -MemberType NoteProperty
				$vm_info | Add-Member -Name VMGuestOS -Value $vm.Guest.OSFullName -MemberType NoteProperty
				$vm_info | Add-Member -Name VMvCPUCount -Value $vm.numCpu -MemberType NoteProperty
				$vm_info | Add-Member -Name VMvRAMMB -Value $vm.memoryMB -MemberType NoteProperty
				foreach ($networkadaptername in ($vm | get-networkadapter | select-object -property NetworkName)){
					$networknames += ("|" + $networkadaptername.networkname)
				}
				$vm_info | Add-Member -Name VMvNetworks -Value $networknames -MemberType NoteProperty
				if ($vm.Guest.IPAddress) {
					$vm_info | Add-Member -Name VMIPAddress -Value ([string]::Join('|',$vm.Guest.IPAddress)) -MemberType NoteProperty
				} else {
					$vm_info | Add-Member -Name VMIPAddress -Value "none" -MemberType NoteProperty
				}
				$vm_info | Add-Member -Name VMDescription -Value $vm.notes -MemberType NoteProperty
			
				$vms_inventory += $vm_info
		
			}
	}
	#export to CSV
	$vms_inventory | sort-object -property VMClusterName | Export-Csv -NoTypeInformation -Path $csvoutfile
	
	$stop_watch.Stop()
    $elapsed_seconds = ($stop_watch.elapsedmilliseconds)/1000
	
	Write-Host "$($(get-date -format "[yyyy-MM-dd HH:mm:ss] "))Report successfully created in $($csvoutfile)" -ForegroundColor Green
	Write-Host "$($(get-date -format "[yyyy-MM-dd HH:mm:ss] "))Total $($vms_inventory.count) VMs reported in $("{0:N2}" -f $elapsed_seconds)s." -ForegroundColor Green

	#disconnect vCenter
	Disconnect-VIServer -Confirm:$false
}
else{
Write-Host "$($(get-date -format "[yyyy-MM-dd HH:mm:ss] "))Error connecting vCenter server $vCenterServer, exiting" -ForegroundColor Red
}