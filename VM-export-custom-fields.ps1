Connect-VIServer -Server vimwt02.ecb01.ecb.de
$outputfile = "e:\ak\VM-custom-fields.csv"
Get-VM | ForEach-Object {
  $VM = $_
  $VM | Get-Annotation |`
    ForEach-Object {
      $Report = "" | Select-Object VM,Name,Value
      $Report.VM = $VM.Name
      $Report.Name = $_.Name
      $Report.Value = $_.Value
      $Report
    }
} | Export-Csv -Path $outputfile -NoTypeInformation
Disconnect-VIServer -Server * -Force -Confirm:$false