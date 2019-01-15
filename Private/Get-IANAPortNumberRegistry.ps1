Function Get-IANAPortRegistry {
    <#
    .SYNOPSIS
        Private function for linking service names and descriptions to ports using a local XML copy of the IANA Service Name and Transport Protocol Port Number Registry.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .LINK
        Invoke-IPv4PortScan
    .LINK
        Update-IANAPortRegistry
    #>

    Param ($Result)
    Begin {}
    Process {
        $PortList = [xml](Get-Content -Path $Script:IANAPortRegistry)

        $Service     = [String]::Empty
        $Description = [String]::Empty

        ForEach ($Node in $PortList.Registry.Record) {
            If (($Result.Protocol -eq $XML_Node.protocol) -and ($Result.Port -eq $Node.number)) {
                $Service     = $Node.name
                $Description = $Node.description
                break
            }
        }

        [PSCustomObject] @{
            Port               = $Result.Port
            Protocol           = $Result.Protocol
            ServiceName        = $Service
            ServiceDescription = $Description
            Status             = $Result.Status
        }
    }
    End {}
}