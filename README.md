# IPv4 Tools PowerShell Module

## Description
The IPv4 Tools module enables a set of functions to assist with common IP Address administration tasks, including :
* The ability to convert subnet masks between dotted decimal, CIDR, wildcard and binary.
* The ability to calculate the resulting broadcast, network, wildcard mask and host range based upon an entered IP address and netmask.
* The ability to validate an IPv4 address.
* The ability to generate an array of IP Addresses based on a start and end address.
* The ability to display current ARP entries.


## Requirements
* PowerShell Version 4

## Usage
```powershell
Convert-SubnetMask -Netmask 255.255.0.0

Netmask     CIDR Wildcard    Binary
----        ---- --------    ------
255.255.0.0   16 0.0.255.255 11111111111111110000000000000000
```

```powershell
Get-IPv4Calculation -IPv4Address 10.10.100.5/24

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

```powershell
New-IPv4Range -StartIPv4Address 192.168.0.0 -EndIPv4Address 192.168.0.10 -Exclude @(0,1,255)

192.168.0.2
192.168.0.3
192.168.0.4
192.168.0.5
192.168.0.6
192.168.0.7
192.168.0.8
192.168.0.9
192.168.0.10
```

```powershell
Get-ARPCache

Interface   IPv4Address     MACAddress        Type
---------   -----------     ----------        ----
192.168.1.1 192.168.1.2     00-0C-29-63-AF-D0 dynamic
192.168.1.1 192.168.1.255   FF-FF-FF-FF-FF-FF static
192.168.1.1 224.0.0.22      01-00-5E-00-00-16 static
192.168.1.1 224.0.0.252     01-00-5E-00-00-FC static
192.168.1.1 239.255.255.250 01-00-5E-7F-FF-FA static
192.168.1.1 255.255.255.255 FF-FF-FF-FF-FF-FF static
```