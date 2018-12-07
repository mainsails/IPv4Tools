# IPv4 Tools PowerShell Module

## Description
The IPv4 Tools module enables a set of functions to assist with common IP Address administration tasks, including :
* The ability to convert subnet masks between dotted decimal, CIDR, wildcard and binary.
* The ability to calculate the resulting broadcast, network, wildcard mask and host range based upon an entered IP address and netmask.
* The ability to validate an IPv4 address.


## Requirements
* All Windows Client Operating Systems are supported
   Windows 7 SP1 and Windows Server 2008R2 through to Windows 10 CB and Windows Server 2016
* PowerShell Version 4

## Usage
```powershell
Convert-SubnetMask -Netmask 255.255.0.0
Convert-SubnetMask -CIDR 24
Get-IPv4Calculation -Address 10.10.100.5/24
Test-IPv4Address -IPv4Address 192.168.0.1
```