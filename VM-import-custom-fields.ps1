Connect-VIServer -Server vimwt02.ecb01.ecb.de
$inputfile = "e:\ak\VM-custom-fields.csv"
Import-Csv -Path $inputfile | Where-Object {$_.Value} | ForEach-Object {
  Get-VM $_.VM | Set-Annotation -CustomAttribute $_.Name -Value $_.Value
}
Disconnect-VIServer -Server * -Force -Confirm:$false