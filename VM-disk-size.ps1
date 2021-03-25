#Connect-VIServer -Server vimwp01.ecb01.ecb.de
$report = foreach($vm in Get-VM -Location ecb-vi){
     Get-HardDisk -VM $vm | Select @{N="VM Name";E={$vm.Name}},
               @{N="RDM Name";E={($_ | where {"RawPhysical","RawVirtual" -contains $_.DiskType}).FileName}},
               @{N="Datastore";E={($_ | where {"RawPhysical","RawVirtual" -notcontains $_.DiskType}).Filename.Split(']')[0].TrimStart('[')}},
               @{N="HD Name";E={$_.Name}},
               @{N="HD Size GB";E={$_.CapacityKB/1MB}},
}
$report | Export-Csv "d:\VM_report-disk-size.csv" -NoTypeInformation
