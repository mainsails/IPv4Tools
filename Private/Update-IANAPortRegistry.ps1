Function Update-IANAPortRegistry {
    <#
    .SYNOPSIS
        Private function for downloading an XML copy of the IANA Service Name and Transport Protocol Port Number Registry.
    .LINK
        Invoke-IPv4PortScan
    .LINK
        Get-IANAPortRegistry
    #>

    $IANAPortRegistryUri = 'https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xml'
    $IANAPortRegistryPath = Split-Path -Path $Script:IANAPortRegistry -Parent
    Try {
        # Create folder structure
        If (-not(Test-Path -Path $IANAPortRegistryPath)) {
            New-Item -Path $IANAPortRegistryPath -Type Directory | Out-Null
        }
        # Download xml-file from IANA and save it
        Write-Verbose -Message 'Updating Service Name and Transport Protocol Port Number Registry from IANA.org'
        [xml]$IANAPortRegistryXML = Invoke-WebRequest -Uri $IANAPortRegistryUri -ErrorAction Stop
        $IANAPortRegistryXML.Save($Script:IANAPortRegistry)
    }
    Catch {
        $_.Exception.Message
    }
}