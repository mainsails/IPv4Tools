Function Get-IPv4Calculation {
    <#
    .SYNOPSIS
        Get-IPv4Calculation calculates the IP subnet information based upon the entered IP address and netmask.
    .DESCRIPTION
        Get-IPv4Calculation calculates the resulting broadcast, network, wildcard mask and host range based upon the entered IP address and netmask.
    .PARAMETER IPv4Address
        IP Address to perform calculation on.
    .PARAMETER CIDR
        The CIDR prefix to perform calculation on.
    .PARAMETER Netmask
        The dotted decimal subnet mask to perform calculation on.
    .EXAMPLE
        Get-IPv4Calculation -IPv4Address 10.10.100.0 -CIDR 24

        Address     : 10.10.100.0
        Netmask     : 255.255.255.0
        Wildcard    : 0.0.0.255
        Network     : 10.10.100.0/24
        Broadcast   : 10.10.100.255
        HostMin     : 10.10.100.1
        HostMax     : 10.10.100.254
        HostsPerNet : 254

    .EXAMPLE
        Get-IPv4Calculation -IPv4Address 10.100.100.0 -Netmask 255.255.255.0

        Address     : 10.100.100.0
        Netmask     : 255.255.255.0
        Wildcard    : 0.0.0.255
        Network     : 10.100.100.0/24
        Broadcast   : 10.100.100.255
        HostMin     : 10.100.100.1
        HostMax     : 10.100.100.254
        HostsPerNet : 254
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Position=0,Mandatory=$true)]
        [ValidateScript({ Test-IPv4Address -IPv4Address $_ })]
        [string]$IPv4Address,
        [Parameter(ParameterSetName='CIDR',Position=1,Mandatory=$true)]
        [ValidateRange(0,32)]
        [Int32]$CIDR,
        [Parameter(ParameterSetName='Netmask',Position=1,Mandatory=$true)]
        [ValidateScript({ $_ -match "^(254|252|248|240|224|192|128|0).0.0.0$|^255.(254|252|248|240|224|192|128|0).0.0$|^255.255.(254|252|248|240|224|192|128|0).0$|^255.255.255.(255|254|252|248|240|224|192|128|0)$" })]
        [string]$Netmask
    )

    Begin {}
    Process {
        Switch ($PSCmdlet.ParameterSetName) {
            'CIDR' {
                $Mask = Convert-SubnetMask -CIDR $CIDR
            }
            'Netmask' {
                $Mask = Convert-SubnetMask -Netmask $Netmask
            }
        }
        $IPBinary = ConvertTo-Binary -DottedDecimal $IPv4Address

        # Identify subnet boundaries
        $NetworkBinary   = $IPBinary.Substring(0,$($Mask.CIDR)).PadRight(32,'0')
        $BroadCastBinary = $IPBinary.Substring(0,$($Mask.CIDR)).PadRight(32,'1')
        $Network         = ConvertTo-DottedDecimal -Binary $NetworkBinary
        $BroadCast       = ConvertTo-DottedDecimal -Binary $BroadCastBinary
        $StartAddress    = ConvertTo-DottedDecimal -Binary $($IPBinary.Substring(0,$($Mask.CIDR)).PadRight(31,'0') + '1')
        $EndAddress      = ConvertTo-DottedDecimal -Binary $($IPBinary.Substring(0,$($Mask.CIDR)).PadRight(31,'1') + '0')
        $HostsPerNet     = ([System.Convert]::ToInt32($BroadCastBinary,2) - [System.Convert]::ToInt32($NetworkBinary,2)) - '1'

        [PSCustomObject]@{
            'Address'     = $IPv4Address
            'Netmask'     = $Mask.Netmask
            'Wildcard'    = $Mask.Wildcard
            'Network'     = "$Network/$($Mask.CIDR)"
            'Broadcast'   = $BroadCast
            'HostMin'     = $StartAddress
            'HostMax'     = $EndAddress
            'HostsPerNet' = $HostsPerNet
        }
    }
    End {}
}