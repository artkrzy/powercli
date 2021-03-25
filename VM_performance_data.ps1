Connect-VIServer -Server vimwt02.ecb01.ecb.de
$outputfile = "z:\results\VM_performance.csv"
Get-Cluster -name Labnet | Get-VM | where {$_.PowerState -eq "PoweredOn"} | `
	Select name, Host, NumCpu, MemoryMB, 
#		@{N="Mem.Usage.Average";E={(get-stat -entity $_ -Start ((Get-Date).AddDays(-7)) -Finish (Get-Date) -stat mem.usage.average) }}
#		@{N="Cpu.Usage.Average";E={(get-stat -entity $_ -Start ((Get-Date).AddDays(-7)) -Finish (Get-Date) -stat cpu.usage.average) }} | 
		@{N="Mem.Usage.Average";E={(get-stat -entity $_ -Start ((Get-Date).AddDays(-7)) -Finish (Get-Date) -stat mem.usage.average | Measure-Object -Property Value -Average).Average}},
		@{N="Cpu.Usage.Average";E={(get-stat -entity $_ -Start ((Get-Date).AddDays(-7)) -Finish (Get-Date) -stat cpu.usage.average | Measure-Object -Property Value -Average).Average}} | `
		Export-Csv -NoClobber -NoTypeInformation $outputfile 
# {noformat}
Disconnect-VIServer -Server * -Force -Confirm:$false