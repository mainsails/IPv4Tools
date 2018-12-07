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

Netmask     CIDR Wildcard    Binary
----        ---- --------    ------
255.255.0.0   16 0.0.255.255 11111111111111110000000000000000
```

```powershell
Convert-SubnetMask -CIDR 24

Netmask       CIDR Wildcard  Binary
----          ---- --------  ------
255.255.255.0   24 0.0.0.255 11111111111111111111111100000000
```

```powershell
Get-IPv4Calculation -Address 10.10.100.5/24

Address   : 10.10.100.5
Netmask   : 255.255.255.0
Wildcard  : 0.0.0.255
Network   : 10.10.100.0/24
Broadcast : 10.10.100.255
HostMin   : 10.10.100.1
HostMax   : 10.10.100.254
Hosts/Net : 254000
```

```powershell
Test-IPv4Address -IPv4Address 192.168.0.1

Address            : 16820416
AddressFamily      : InterNetwork
ScopeId            :
IsIPv6Multicast    : False
IsIPv6LinkLocal    : False
IsIPv6SiteLocal    : False
IsIPv6Teredo       : False
IsIPv4MappedToIPv6 : False
IPAddressToString  : 192.168.0.1
```