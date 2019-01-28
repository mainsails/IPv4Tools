Function Get-ARPCache {
    <#
    .SYNOPSIS
        Get the ARP cache.
    .DESCRIPTION
        Get the Address Resolution Protocol (ARP) tables for all network interfaces on the local computer.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        Get-ARPCache

        Interface   IPv4Address     MACAddress        Type
        ---------   -----------     ----------        ----
        192.168.1.1 192.168.1.2     00-0C-29-63-AF-D0 dynamic
        192.168.1.1 192.168.1.255   FF-FF-FF-FF-FF-FF static
        192.168.1.1 224.0.0.22      01-00-5E-00-00-16 static
        192.168.1.1 224.0.0.252     01-00-5E-00-00-FC static
        192.168.1.1 239.255.255.250 01-00-5E-7F-FF-FA static
        192.168.1.1 255.255.255.255 FF-FF-FF-FF-FF-FF static
    #>

    [CmdletBinding()]
    Param()

    Begin {
        # Regex for IPv4 and MAC
        $RegexIPv4 = "(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
        $RegexMAC  = "([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})|([0-9A-Fa-f]{2}){6}"
    }
    Process {
        # Get the ARP tables
        $ARP_Result = & ARP -a

        ForEach ($Line in $ARP_Result) {
            # Find Interface separator
            If ($Line -like '*---*') {
                $InterfaceIPv4 = [regex]::Matches($Line,$RegexIPv4).Value
            }
            ElseIf ($Line -match $RegexMAC) {
                ForEach ($Split in $Line.Split(' ')) {
                    # Find IPv4 address
                    If ($Split -match $RegexIPv4) {
                        $IPv4Address = $Split
                    }
                    # Find MAC address
                    ElseIf ($Split -match $RegexMAC) {
                        $MACAddress = $Split.ToUpper()
                    }
                    # Find Type
                    ElseIf (-not ([String]::IsNullOrEmpty($Split))) {
                        $Type = $Split
                    }
                }
                [PSCustomObject] @{
                    Interface   = $InterfaceIPv4
                    IPv4Address = $IPv4Address
                    MACAddress  = $MACAddress
                    Type        = $Type
                }
            }
        }
    }
    End {}
}