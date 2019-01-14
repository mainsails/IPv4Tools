Function Get-IANAPortNumberRegistry {
# Function to assign service with port
    Param($Result)
    Begin {}
    Process {
        $XML_PortList = [xml](Get-Content -Path $Script:XML_PortList_Path)
        
        $Service     = [String]::Empty
        $Description = [String]::Empty

        ForEach ($XML_Node in $XML_PortList.Registry.Record) {
            If (($Result.Protocol -eq $XML_Node.protocol) -and ($Result.Port -eq $XML_Node.number)) {
                $Service     = $XML_Node.name
                $Description = $XML_Node.description
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