Connect-VIServer -Server vimwt02.ecb01.ecb.de
$Days=7
$Today = Get-Date
$Before = $Today.AddDays(-$Days)
Get-VM | `
Get-Snapshot | `
Where-Object {$_.Created -le $Before} | `
Remove-Snapshot -Confirm:$false
Disconnect-VIServer -Server * -Force -Confirm:$false