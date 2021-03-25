Connect-VIServer -Server vimwt02.ecb01.ecb.de
$outputfile = "e:\ak\VM_vmdk_2.csv"
$dsImpl = Get-VMHost | Get-Datastore | where {$_.Type -eq "VMFS"}
$dsImpl | % {
	$ds = $_ | Get-View
	$path = "[" + $ds.Name + "]"
	$dsBrowser = Get-View $ds.Browser
	$spec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
	$spec.Details = New-Object VMware.Vim.FileQueryFlags
	$spec.Details.fileSize = $true
	$spec.Details.fileType = $true
	$vmdkQry = New-Object VMware.Vim.VmDiskFileQuery
	$spec.Query = (New-Object VMware.Vim.FileQuery)
	#Workaround for vSphere 4 fileOwner bug
	if ($dsBrowser.Client.Version -eq "Vim4") {
		$spec = [VMware.Vim.VIConvert]::ToVim4($spec)
		$spec.details.fileOwnerSpecified = $true
		$dsBrowserMoRef = [VMware.Vim.VIConvert]::ToVim4($dsBrowser.MoRef);
		$taskMoRef = $dsBrowser.Client.VimService.SearchDatastoreSubFolders_Task($dsBrowserMoRef, $path, $spec)
		$result = [VMware.Vim.VIConvert]::ToVim($dsBrowser.WaitForTask([VMware.Vim.VIConvert]::ToVim($taskMoRef)))
	} else {
		$taskMoRef = $dsBrowser.SearchDatastoreSubFolders_Task($path, $spec)
		$task = Get-View $taskMoRef
		while("running","queued" -contains $task.Info.State){
			$task.UpdateViewData("Info")
		}
		$result = $task.Info.Result
	}

	$result | % {
		$vmName = ([regex]::matches($_.FolderPath,"\[\w*\]\s*([^/]+)"))[0].groups[1].value
		$_.File | % {
			New-Object PSObject -Property @{
				DSName = $ds.Name
				VMname = $vmName
				FileName = $_.Path
				FileSize = $_.FileSize
			}
		}
	}
} | Export-Csv $outputfile -NoTypeInformation -UseCulture
Disconnect-VIServer -Server * -Force -Confirm:$false
