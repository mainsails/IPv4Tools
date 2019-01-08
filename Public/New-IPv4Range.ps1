Function New-IPv4Range {
    <#
    .SYNOPSIS
        Returns an array of IP Addresses based on a start and end address.
    .DESCRIPTION
        Returns an array of IP Addresses based on a start and end address.
    .PARAMETER StartIPv4Address
        Starting IP Address.
    .PARAMETER EndIPv4Address
        Ending IP Address.
    .PARAMETER Exclude
        Exclude addresses with this final octet.
        eg. '5' excludes *.*.*.5
    .EXAMPLE
        New-IPv4Range -StartIPv4Address 192.168.0.1 -EndIPv4Address 192.168.10.254
        Create an array from 192.168.0.1 to 192.168.10.254
    .EXAMPLE
        New-IPv4Range -StartIPv4Address 192.168.20.20 -EndIPv4Address 192.168.30.30 -Exclude @(0,1,255)
        Create an array from 192.168.20.20 to 192.168.30.30, excluding *.*.*.[0,1,255]
    #>

    [CmdletBinding()]
    Param (
        [parameter(Mandatory=$true,Position=0)]
        [System.Net.IPAddress]$StartIPv4Address,
        [Parameter(Mandatory=$true,Position=1)]
        [System.Net.IPAddress]$EndIPv4Address,
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateRange(0,255)]
        [int[]]$Exclude
    )

    Begin {}
    Process {
        Write-Verbose "Start IP [$StartIPv4Address] :: End IP [$EndIPv4Address]"

        $IPStart = $StartIPv4Address.GetAddressBytes()
        [Array]::Reverse($IPStart)
        $IPStart = ([System.Net.IPAddress]($IPStart -join '.')).Address

        $IPEnd = ($EndIPv4Address).GetAddressBytes()
        [Array]::Reverse($IPEnd)
        $IPEnd = ([System.Net.IPAddress]($IPEnd -join '.')).Address

        For ($i=$IPStart; $i -le $IPEnd; $i++) {
            $IP = ([System.Net.IPAddress]$i).GetAddressBytes()
            [Array]::Reverse($IP)
            If ($Exclude -notcontains $IP[3]) {
                $IP -join '.'
            }
        }
    }
    End {}
}