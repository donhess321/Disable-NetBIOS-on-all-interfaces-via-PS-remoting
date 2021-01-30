<#
    .SYNOPSIS
    Get all interfaces that can use NetBIOS and set the NetbiosOptions to forced disable

    .DESCRIPTION
    Get all interfaces that can use NetBIOS and set the NetbiosOptions to forced disable.
    This can be run locally or over PS Remoting.

    .RETURNS
    Updated network adapter objects from the remote machine

    .OUPUTS
    Event log about updated network adapters.  This requires running as Admin.

    .PARAMETER Computers
    Array:  List of computer names to log into via PS Remoting
            To run locally, like in a GPO startup task, use "-Computers @($env:COMPUTERNAME)" 
            for the input

    .NOTES
    Update the Get-ADComputer line to filter for the type and number of computers you want

    Author: Donald Hess
    Version History:
        2.0  2018-05-30  Updated to work over PS remoting/local, code cleanup
        1.0  2010-01-22  Release
    
    .EXAMPLE
    Disable-NetBIOS on Workstations.ps1
    Get all computers in AD and run over PS Remoting against them

    .EXAMPLE
    Disable-NetBIOS on Workstations.ps1 -Computers 'comp1','comp2','etc'
    Run on only these computers

    .EXAMPLE
    Disable-NetBIOS on Workstations.ps1 -Computers @($env:COMPUTERNAME)
    Run on the local computer
#> 
param ( [array] $Computers = @() )

Set-StrictMode -Version latest -Verbose
$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['*:ErrorAction']='Stop'

if ( -not $Computers ) {
    # This will filter so we get only computer object that are backed by a real workstation
    # Update to your environment to get the workstations you want
    $sDomainSnip = (Get-WmiObject Win32_ComputerSystem).Domain.Trim().Substring(0,4)    
    $aComputers = Get-ADComputer -Filter * | Select-Object Name,DNSHostName,Enabled | `
        Where-Object { $_.Enabled -and $_.Name -Like "$sDomainSnip*" -and $null -ne $_.DNSHostName } | `
        ForEach-Object { $_.Name } | Sort
} else {
    # Something passed in
    $aComputers = $Computers
}

$sbFinal = {
    $aNbtList = Get-ChildItem "HKLM:\System\CurrentControlSet\Services\NetBT\Parameters\Interfaces" `
    | ForEach-Object{Get-ItemProperty $_.PSPath} | Select-Object "PSChildName","NetbiosOptions","PSPath"
    $sAdptRegRoot = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}"
    $aAdptList = Get-ChildItem $sAdptRegRoot -ErrorAction SilentlyContinue `
    | ForEach-Object{Get-ItemProperty $_.PSPath} | Select-Object "AdapterModel","DriverDesc","NetCfgInstanceId","NetType","Provider","ProviderName"

	# Set up the disable NetBIOS number and convert to HEX
	# 0 = Default via DHCP
	# 1 = Force Enabled
	# 2 = Force Disable
	$n = "{0:X}" -f 2

    $aNbtList | ForEach-Object {
	    if ( $null -eq $_.NetbiosOptions ) { # XP test and non-Netbios adapters
            return # Next in pipeline
        }
		# Set the NetBIOS registry value
		Set-ItemProperty -Path $_.PSPath -Name "NetbiosOptions" -Value $n
		
		# Get just the adapter UID so we can use it for other stuff
		"$_.PSChildName" -match "\{\w{8}-\w{4}-\w{4}-\w{4}-\w{12}\}" | Out-Null
		$sIfUid = $Matches[0].ToString()
				
		# Filter the adapters so we can display a nice name
		$oAdptOutput = $aAdptList | Where-Object { $_.NetCfgInstanceId -match $sIfUid }
		
		$eventLog = New-Object System.Diagnostics.EventLog
		$eventType = [System.Diagnostics.EventLogEntryType]::Information
		$eventID = 555
		$eventLog.Log = "System"
		$eventLog.Source = "PSscript-Sys"
		$sDesc = @("NetBIOS disabled for interface:  ", $oAdptOutput.DriverDesc, '  ', $oAdptOutput.NetCfgInstanceId) -join ''
		$eventLog.WriteEntry($sDesc,$eventType,$eventID)
		
		# Return back what we are working on
		$oAdptOutput
    }
}

#$sbFinal = [scriptblock]::create($sScriptBlockContent)
# Check for this computer name passed in and run scriptblock locally
if ( $aComputers.Length -eq 1 ) {  
    if ( $aComputers[0] -eq $env:COMPUTERNAME ) {
        & $sbFinal
    }
} else {
    Invoke-Command -ThrottleLimit 10 -ComputerName $aComputers -ScriptBlock $sbFinal -ErrorAction Continue
}