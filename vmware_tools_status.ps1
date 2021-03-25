# Connect-VIServer "Name"
Get-VM -Name "*" | Sort Name | `
Select  @{N="VMName"; E={$_.Name}},
  @{N="HardwareVersion"; E={$_.Extensiondata.Config.Version}},
  @{N="ToolsVersion"; E={$_.Extensiondata.Config.Tools.ToolsVersion}},
  @{N="ToolsStatus"; E={$_.Extensiondata.Summary.Guest.ToolsStatus}},
  @{N="ToolsVersionStatus"; E={$_.Extensiondata.Summary.Guest.ToolsVersionStatus}},
  @{N="ToolsRunningStatus"; E={$_.Extensiondata.Summary.Guest.ToolsRunningStatus}},
  @{N="Cluster"; E={(Get-Cluster -VM $_.Name).Name}},
  @{N="ESX Host"; E={$_.VMHost.Name}},
  @{N="ESX Version"; E={$_.VMHost.Version}},
  @{N="ESX Build"; E={$_.VMHost.Build}} | Export-Csv "D:\PROD_Tools_status.csv" -NoTypeInformation

Disconnect-VIServer * -Confirm:$false
