# Create a new Data Center and Add ESXi Host to the new Data Center
# PowerCLI Session must be connected to vCenter Server using Connect-VIServer

# Name of the new Data Center
$vcs = "10.1.222.100"
$vcsuser = "administrator@vsphere.local"
$datacenter = "gsocls3"

# List of ESXi Hosts to Add to New Data Center
# Use the IP Addresses or FQDNs of the ESXi hosts to be added
# Example using IP: $esxhosts = "192.168.1.25","192.168.1.26"
# Example using FQDN: $esxhosts = "esx0.lab.local","esx1.lab.local"
$esxhosts = "gsocls2-1.gso.lab","gsocls2-2.gso.lab","gsocls2-3.gso.lab","gsocls3-1.gso.lab","gsocls3-2.gso.lab","gsocls3-3.gso.lab"

# Prompt for ESXi Root Credentials
$esxcred = Get-Credential 

Connect-VIServer -Server $vcs -Username $vcsuser
#Write-Host "Creating Datacenter $datacenter" -ForegroundColor green
#$location = Get-Folder -NoRecursion
#New-DataCenter -Location $location -Name $datacenter

foreach ($esx in $esxhosts) {
  Write-Host "Adding ESX Host $esx to $datacenter" -ForegroundColor green
  Add-VMHost -Name $esx -Location (Get-Datacenter $datacenter) -Credential $esxcred -Force -RunAsync -Confirm:$false
}

Write-Host "Done!" -ForegroundColor green