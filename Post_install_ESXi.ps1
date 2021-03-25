param([string] $file = $(Read-Host -Prompt "Please specify a configuration file ...."))
#############################################################################
# Scriptname:	Post_install_ESXi.ps1
# Author:		(C) Levente Fulop (levente_fulop@cz.ibm.com)
# Version:		5.25
# Date:			May 12 2010
# ###########################################################################
#				
# Description:	- This Script reads the contents of an .ini file and based on 
#                 that configuration file it perfeorms the post installation
#                 steps. 
# 				- Blank lines and lines beginning with '[' or ';' are
# 				  ignored in the config file.
#				- The function Get-Settings() returns the result in
# 				  $hashtable as a hash table.
#				  --> $hashtable = (Get-Content $path | Get-Settings)
# Usage:        - Start the script with a ini file containing the settings.
#				  each server will have to have individual config file, that 
#                 should be stored in our documentation.
#				- Restrictions: The hash table contains all the key and value
#				  pairs. Do not use the same key twice in the same ini file!
#
#
#
#############################################################################


# ***************************************************************************
# ************ Functions ****************************************************
# ***************************************************************************


# Each line of the .ini File will be processed through the pipe.
# The splitted lines fill a hastable. Empty lines and lines beginning with
# '[' or ';' are ignored. $ht returns the results as a hashtable.
Add-PSSnapin VMware.VimAutomation.Core -ea SilentlyContinue

$Version = "5.25"

# Turn off Errors
#$ErrorActionPreference = "silentlycontinue"

if ($file -eq ""){
	Write-Host
	Write-Host "No Config file supplied, please specify a configuration file ...."
	Write-Host "Usage: "
    Write-Host "      powershell.exe ./Post_install_ESXi.ps1 host_ini_file.ini"
	Write-Host
	Write-Host
	exit
}

	if ((Test-Path -Path $file) -eq $false) {
			Write-Host
	        Write-Host "Config file not found on the specified location, please specify a configuration file ...."
	        Write-Host "Usage: "
            Write-Host "      powershell.exe Post_install_ESXi.ps1 esxi_deehqex330abbn6.ini"
	        Write-Host
	        Write-Host
	        exit
	}

function Get-Settings()
{
	BEGIN
	{
		$ht = @{}
	}
	PROCESS
	{
		$key = [regex]::split($_,'=')
		if(($key[0].CompareTo("") -ne 0) `
		-and ($key[0].StartsWith("[") -ne $True) `
		-and ($key[0].StartsWith(";") -ne $True))
		{
			$ht.Add($key[0], $key[1])
		}
	}
	END
	{
		return $ht
	}
}

# Gets the path of the running script.
function Get-ScriptPath ([System.String]$Script = "", `
[System.Management.Automation.InvocationInfo]$MyInv = $myInvocation)
{
	$spath = $MyInv.get_MyCommand().Definition
	$spath = Split-Path $spath -parent
	$spath = Join-Path $spath $Script
	return $spath
}

function split_to_array()
{
	BEGIN
	{
		#write-host "start func"
        $ht1 = @{}
        
	}
	PROCESS
	{
		$key1 = [regex]::split($_,',')
		
        if(($key1[0].CompareTo("") -ne 0) `
		-and ($key1[0].StartsWith("[") -ne $True) `
		-and ($key1[0].StartsWith(";") -ne $True))
		{
			write-host "key" $key1[1]
            #$ht1.Add($key1[0], $key1[1])
            $ht1 = $key1[0], $key1[1]
            		}
	}
	END
	{
		return $ht1
	}
}

# ***************************************************************************
# ************ Main-Program *************************************************
# ***************************************************************************


Write-Host "ESX(i) Configuration script " $Version " for VMware ESX(i) Hosts version: " 
Write-Host 
$path = $file
$hashtable = (Get-Content $path | Get-Settings)


# To get an item from the hashtable use the Item method.
#Write-Host $hashtable.Item("LUNPolicy")

$myServer = $hashtable.Item("HostIP")
$hostIP = $myServer
Write-Host "Connecting to " $myServer
Write-Host 
Write-Host "Please provide the root password for this server"
Write-Host 
    $VC = Connect-VIServer -Server $myServer -Protocol https –Credential (Get-Credential)
    $esxhost = $VC
Write-Host 
Write-Host 
write-host "Entering Maintenance Mode"
      Set-VMHost -State maintenance
      sleep 10
Write-Host "Setting DNS info"
Write-Host 
Write-Host 

#Reading settings from file regarding DNS
    $PreferredDNS = $hashtable.Item("PreferredDNS")
    $AltDNS = $hashtable.Item("AltDNS")
    $DomainName = $hashtable.Item("DomainName")
    $DNSSearch = $hashtable.Item("DNSSearch")
    
#Setting DNS details on the ESX Server
    $vmHostNetworkInfo = Get-VmHostNetwork -VMHost $hostIP
    Set-VmHostNetwork -Network $vmHostNetworkInfo -DomainName $DomainName -SearchDomain $DNSSearch
    Set-VmHostNetwork -Network $vmHostNetworkInfo -DnsAddress $PreferredDNS, $AltDNS

Write-Host "DNS configured, continuing ..."
Write-Host 
Write-Host
#Setting DNS details on the ESX Server
Write-Host "NTPconfiguration in progress ..."
Write-Host 
Write-Host
$PriNTP = $hashtable.Item("NTP1")
$SecondaryNTP = $hashtable.Item("NTP2")
      write-host "Adding NTP Servers"

      Add-VmHostNtpServer -NtpServer $PriNTP #,$ntp2
      Add-VmHostNtpServer -NtpServer $SecondaryNTP
#-----------------Rescanning of the HBAs-----------------

Write-Host
$RescanAllHBA = $hashtable.Item("RescanAllHBA")
        if ($RescanAllHBA –ne "true" –and $RescanAllHBA –ne "false") {
            write-host "Error in config file at the HBA rescan part"
            write-host "Other valued passed than true OR false! Value is now " $RescanAllHBA
            Write-Host "Script will now Exit! Correct the config file and start again"
            
            exit
            }
            
        if ($RescanAllHBA -eq "true") {
                Write-Host "Rescan of ALL HBAs will be initiated."
                Get-VMHost | Get-VMHostStorage -RescanAllHba -RescanVmfs
            }




Write-Host
Write-Host
Write-Host

#-----------------vSwithc config --------------------------------
Write-Host "Configuring vSwitch0, the console ..."
Write-Host 
Write-Host

#splitting the text to correct format
$pattern = "ConsoleNics"
$re = new-object System.Text.RegularExpressions.Regex($pattern)

foreach ($line in $(Get-Content $file))
{
   $match = $re.Match($line);
   if($match.Success)
   {
      [string]$line
      $a=$line.split("=")
      $b = [string]$a[1]
      $c = $b.split(",")
      $d = @($c[0],$c[1])
      $i=1
      $e=@()
      foreach ($itemx in $c){
            #write-host $itemx
            $e=$e += $itemx
            $i++
            }
      #return $e
write-host "Setting Console nics to: " $e
$ConsoleNics = $e
   }
}



#----------------------vSwitch0---------------------
      $vs0 = Get-VirtualSwitch -Name vSwitch0
      Set-VirtualSwitch -VirtualSwitch $vs0 -Nic  $ConsoleNics
# Removes "VM Network" from the vSwitch0
      get-VirtualPortGroup | where { $_.Name -like "VM Network"} | Remove-VirtualPortGroup -Confirm:$false

#-------------adding new sw. vswitch1 -----
# Configure vSwitch1
      write-host "Configuring vSwitch1 ... "
     $vSwitch1VLAN1=0
     $vSwitch1VLAN2=0
     $vSwitch1NetworkNumPorts = $hashtable.Item("vSwitch1NumberOfPorts")
     $vSwitch1Name = $hashtable.Item("vSwitch1Name1")
     $vSwitch1Name2 = $hashtable.Item("vSwitch1Name2")
     $vSwitch1VLAN2 = $hashtable.Item("vSwitch1VLANID2")
     $vSwitch1VLAN1 = $hashtable.Item("vSwitch1VLANID1")
     #splitting the text to correct format
$pattern1 = "vSwitch1NetworkCards"
$re1 = new-object System.Text.RegularExpressions.Regex($pattern1)

foreach ($line1 in $(Get-Content $file))
{
   $match1 = $re1.Match($line1);
   if($match1.Success)
   {
      [string]$line1
      $a1=$line1.split("=")
      $b1 = [string]$a1[1]
      $c1 = $b1.split(",")
      $d1 = @($c1[0],$c1[1])
      $i=1
      $vSwitch1NetworkCards=@()
      foreach ($itemx1 in $c1){
            #write-host $itemx
            $vSwitch1NetworkCards = $vSwitch1NetworkCards += $itemx1
            $i++
            }
      #return $e
write-host "Setting vSwitch1 nics to: " $vSwitch1NetworkCards
   }
}
     $vs1 = New-VirtualSwitch -Name "vSwitch1" #-nic $vSwitch1_network_cards # $vmnics
     write-host "Creating ... " $vSwitch1Name
     Set-VirtualSwitch -VirtualSwitch $vs1 -NumPorts $vSwitch1NetworkNumPorts
     Set-VirtualSwitch -VirtualSwitch $vs1 -Nic $vSwitch1NetworkCards
     write-host "Configuring ..." $vSwitch1Name
      
     New-VirtualPortGroup -VirtualSwitch $vs1 -Name $vSwitch1Name -VLanId $vSwitch1VLAN1
     if ("0" -ne $vSwitch1VLAN1){
        if ("0" -ne $vSwitch1Name2){
        write-host "Configuring " $vSwitch1Name2
        New-VirtualPortGroup -VirtualSwitch $vs1 -Name $vSwitch1Name2 -VLanId $vSwitch1VLAN2
        }
     }

#--------end of vSwitch1 --------



#-------------adding new sw. vswitch2 -----
# Configure vSwitch1
      write-host "Configuring vSwitch2 ..."
     $vSwitch2VLAN1=0
     $vSwitch2VLAN2=0
     $vSwitch2NetworkNumPorts = $hashtable.Item("vSwitch2NumberOfPorts")
     $vSwitch2Name = $hashtable.Item("vSwitch2Name1")
     $vSwitch2Name2 = $hashtable.Item("vSwitch2Name2")
     $vSwitch2VLAN2 = $hashtable.Item("vSwitch2VLANID2")
     $vSwitch2VLAN1 = $hashtable.Item("vSwitch2VLANID1")
     #splitting the text to correct format
$pattern2 = "vSwitch2NetworkCards"
$re2 = new-object System.Text.RegularExpressions.Regex($pattern2)

foreach ($line2 in $(Get-Content $file))
{
   $match2 = $re2.Match($line2);
   if($match2.Success)
   {
      [string]$line2
      $a2=$line2.split("=")
      $b2 = [string]$a2[1]
      $c2 = $b2.split(",")
      $d2 = @($c2[0],$c2[1])
      $i=1
      $vSwitch2NetworkCards=@()
      foreach ($itemx2 in $c2){
            #write-host $itemx
            $vSwitch2NetworkCards = $vSwitch2NetworkCards += $itemx2
            $i++
            }
      #return $e
write-host "Setting vSwitch2 nics to: " $vSwitch2NetworkCards
   }
}
     $vs2 = New-VirtualSwitch -Name "vSwitch2" #-nic $vSwitch1_network_cards # $vmnics
     write-host "Creating ... " $vSwitch2Name
     Set-VirtualSwitch -VirtualSwitch $vs2 -NumPorts $vSwitch2NetworkNumPorts
     Set-VirtualSwitch -VirtualSwitch $vs2 -Nic $vSwitch2NetworkCards
     write-host "Configuring ... " $vSwitch2Name
      
     New-VirtualPortGroup -VirtualSwitch $vs2 -Name $vSwitch2Name -VLanId $vSwitch2VLAN1
     if ("0" -ne $vSwitch2VLAN1){
        if ("0" -ne $vSwitch2Name2){
        write-host "Configuring ... " $vSwitch2Name2
        New-VirtualPortGroup -VirtualSwitch $vs2 -Name $vSwitch2Name2 -VLanId $vSwitch2VLAN2
        }
     }

#--------end of vSwitch2 --------


#--------Start of vSwitch3 --------

$VMotionIP = $hashtable.Item("vSwitch3VmotionIP")
$VMotionSubnet = $hashtable.Item("vSwitch3VmotionSubnetMask")

$pattern3 = "vSwitch3NetworkCards"
$re3 = new-object System.Text.RegularExpressions.Regex($pattern3)
foreach ($line3 in $(Get-Content $file))
{
   $match3 = $re3.Match($line3);
   if($match3.Success)
   {
      [string]$line3
      $a3=$line3.split("=")
      $b3 = [string]$a3[1]
      $c3 = $b3.split(",")
      $d3 = @($c3[0],$c3[1])
      $i=1
      $vSwitch3NetworkCards=@()
      foreach ($itemx3 in $c3){
            #write-host $itemx
            $vSwitch3NetworkCards = $vSwitch3NetworkCards += $itemx3
            $i++
            }
      #return $e
write-host "Setting vSwitch2 nics to: " $vSwitch3NetworkCards
   }
}


      $vs3 = New-VirtualSwitch -Name "VMotion" #-nic $vSwitch3NetworkCards
      Set-VirtualSwitch -VirtualSwitch $vs3 -Nic $vSwitch3NetworkCards
      New-VMHostNetworkAdapter -PortGroup VMkernel -VirtualSwitch $vs3 -IP $VMotionIP -SubnetMask $VMotionSubnet -VMotionEnabled: $true
       


#--------end of vSwitch3 --------



# ------------ vSwitch Security
       # Configure vSwitch Security for all vSwitches
      
      $vSwitchPromiscuous = $hashtable.Item("vSwitchPromiscuous")
      $vSwitchPromiscuous = ($vSwitchPromiscuous).tolower()
      if ($vSwitchPromiscuous -ne "")
      {
        if ($vSwitchPromiscuous -eq "reject")
            {
            $vSwitchPromiscuous = $false
            write-host "Promiscuous will be set to Reject"
            } 
        if ($vSwitchPromiscuous -eq "accept")
            {
            $vSwitchPromiscuous = $true
            write-host "Promiscuous will be set to Accept"
            } 
      }
      
      $Transmits = $hashtable.Item("vSwitchForgedTransmits")
      $Transmits = ($Transmits).tolower()
      if ($Transmits -ne "")
      {
        if ($Transmits -eq "reject")
            {
            $Transmits = $false
            write-host "Transmits will be set to Reject"
            } 
        if ($Transmits -eq "accept")
            {
            $Transmits = $true
            write-host "Transmits will be set to Accept"
            } 
      }
      
      
      $macChanges = $hashtable.Item("vSwitchForgedTransmits")
      $macChanges = ($macChanges).tolower()
      if ($macChanges -ne "")
      {
        if ($macChanges -eq "reject")
            {
            $macChanges = $false
            write-host "macChanges will be set to Reject"
            } 
        if ($macChanges -eq "accept")
            {
            $macChanges = $true
            write-host "macChanges will be set to Accept"
            } 
      }
      
            
      
      write-host
      write-host 
      write-host "Configuring vSwitch Security settings for all vSwitches"
      write-host 
      
      foreach ($vswitchName in Get-VirtualSwitch $hostIP){
      $hostview = get-vmhost $hostIP | Get-View
      $ns = Get-View -Id $hostview.ConfigManager.NetworkSystem
      $vsConfig = $hostview.Config.Network.Vswitch | Where-Object { $_.Name -eq $vswitchName }
      $vsSpec = $vsConfig.Spec
      $vsSpec.Policy.Security.AllowPromiscuous = $vSwitchPromiscuous
      $vsSpec.Policy.Security.forgedTransmits = $Transmits
      $vsSpec.Policy.Security.macChanges = $macChanges
      $ns.UpdateVirtualSwitch( $VSwitchName, $vsSpec)
      }

#----------------LUN Policy----------------------



$LUN_required_policy = ($hashtable.Item("LUNPolicy")).ToLower()
write-host 
write-host 
write-host "Configuration of Lun Policy started ..."
write-host 
write-host 


#setting the LUN Policy

if ($LUN_required_policy -ne $null){

    $policy = new-object VMware.Vim.HostMultipathInfoFixedLogicalUnitPolicy

         if ($LUN_required_policy –ne "RoundRobin" –and $LUN_required_policy –ne "fixed") {
            write-host "Error in config file at the LUN policy part"
            write-host "Other valued passed than RoundRobin OR Fixed! Value is now " $LUN_required_policy
            Write-Host "Script will now Exit! Correct the config file and start again"
            
            exit
            }
            
        if ($LUN_required_policy -eq "roundrobin") {
                $policy.policy = "rr"
                #write-host "RoundRobin Policy"
            }
        if ($LUN_required_policy -eq "fixed") {
                $policy.policy = "fixed"
                #write-host "Fixed Policy"
            }
    write-host
    write-host
    write-host "Setting the LUN Policy to: " $LUN_required_policy
    write-host
    $GET_HOST = Get-VMhost $myServer
    $HOST_VIEW = Get-View $GET_HOST.id
    $STORAGESYSTEM = get-view $HOST_VIEW.ConfigManager.StorageSystem
    $ARRLUN = $STORAGESYSTEM.StorageDeviceInfo.MultipathInfo.lun | where { $_.Path.length -gt 1 }
        foreach ($LUN in $ARRLUN)
        {
            $GET_VMHBA = $LUN.Path 
            $policy.prefer = $GET_VMHBA.Name
            $storageSystem.SetMultipathLunPolicy($LUN.id, $policy)
        }
    } else {
        write-host "null"
        exit
 }


#Setting the proper hostname
$vmhost = ($hashtable.Item("HostName")).ToLower()
$vmHostNetworkInfo = Get-VmHostNetwork -VMHost $hostIP
      write-host "Setting the hostname for " $vmhost      
      Set-VmHostNetwork -Network $vmHostNetworkInfo -HostName $vmhost
      
      
#rebooting the host.
write-host 
write-host 
write-host "Setting the hostname for " $vmhost      
write-host 
write-host 
write-host 
write-host 
$VmhostReboot = ($hashtable.Item("RebootHost")).ToLower()
         if ($VmhostReboot –ne "yes" –and $VmhostReboot –ne "no") {
            write-host "Error in config file at the reboot part"
            write-host "Other valued passed than yes OR no! Value is now " $VmhostReboot
            Write-Host "Script will now Exit! Correct the config file and start again"
            
            exit
            }
            
        if ($VmhostReboot -eq "yes") {
                Restart-VMHost -server $hostIP -force -confirm:$false
                write-host "Reboot initiated ..."
            }
        if ($VmhostReboot -eq "no") {
               write-host "Reboot was not done, because that`s how you set it up in the config file."
               write-host "Please reboot the host manually, it is required for many settings"
               write-host
               write-host
               
            }
            
 Disconnect-VIServer -Confirm:$False
      write-host "Configuration step is now completed ..."
      write-host
      write-host "1. Wait for the host to reboot."
      write-host "2. Connect the Host to vCenter and assign a license"
      write-host "3. Verify the Host Configuration is correct"
      write-host "4. Confirm all patches have been applied (scan for updates)"
      Write-Host "5. Once complete take the ESXi host out of Maintenance Mode"