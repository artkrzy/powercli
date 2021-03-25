add-pssnapin VMware.VimAutomation.Core
#Connect-VIServer -Server localhost
Get-VM | Get-Snapshot -Name vmbk_snap | Where { $_.Created -lt (Get-Date).AddDays(-2)} | Remove-Snapshot