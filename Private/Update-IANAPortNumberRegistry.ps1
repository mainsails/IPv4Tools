Function Update-IANAPortNumberRegistry {
# Function to update the list from IANA (Port list)
# IANA Service Name and Transport Protocol Port Number Registry (xml)
    $IANA_PortList_WebUri = 'https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xml'
    Try {
        # Download xml-file from IANA and save it
        Write-Verbose -Message 'Updating Service Name and Transport Protocol Port Number Registry from IANA.org'
        [xml]$New_XML_PortList = Invoke-WebRequest -Uri $IANA_PortList_WebUri -ErrorAction Stop
        $New_XML_PortList.Save($Script:XML_PortList_Path)
    }
    Catch {
        $_.Exception.Message
    }
}