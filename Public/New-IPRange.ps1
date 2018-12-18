Function New-IPRange {
    <#
    .SYNOPSIS
        Returns an array of IP Addresses based on a start and end address.
    .DESCRIPTION
        Returns an array of IP Addresses based on a start and end address.
    .PARAMETER Start
        Starting IP Address.
    .PARAMETER End
        Ending IP Address.
    .PARAMETER Exclude
        Exclude addresses with this final octet.
        eg. '5' excludes *.*.*.5
    .EXAMPLE
        New-IPRange -Start 192.168.0.1 -End 192.168.10.254
        Create an array from 192.168.0.1 to 192.168.10.254
    .EXAMPLE
        New-IPRange -Start 192.168.20.20 -End 192.168.30.30 -Exclude @(0,1,255)
        Create an array from 192.168.20.20 to 192.168.30.30, excluding *.*.*.[0,1,255]
    #>

    [CmdletBinding()]
    Param (
        [parameter(Mandatory=$true,Position=0)]
        [System.Net.IPAddress]$Start,
        [Parameter(Mandatory=$true,Position=1)]
        [System.Net.IPAddress]$End,
        [Parameter(Mandatory=$false,Position=2)]
        [ValidateRange(0,255)]
        [int[]]$Exclude
    )

    Begin {}
    Process {
        Write-Verbose "Start IP [$Start] :: End IP [$End]"

        $IPStart = $Start.GetAddressBytes()
        [Array]::Reverse($IPStart)
        $IPStart = ([System.Net.IPAddress]($IPStart -join '.')).Address

        $IPEnd = ($End).GetAddressBytes()
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