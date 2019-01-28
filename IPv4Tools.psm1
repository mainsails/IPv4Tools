# Get Public and Private Function definition files
$Public  = @(Get-ChildItem -Path "$PSScriptRoot\Public"  -Filter '*.ps1')
$Private = @(Get-ChildItem -Path "$PSScriptRoot\Private" -Filter '*.ps1')

# Dot source the Functions
ForEach ($Import in @($Public + $Private)) {
    Try {
        . $Import.FullName
    }
    Catch {
        Write-Error -Message "Failed to import Function : [$($Import.BaseName)] : $_"
    }
}

# Set Module Variable
$Script:IANAPortRegistry = "$PSScriptRoot\Resources\IANA_ServiceName_and_TransportProtocolPortNumber_Registry.xml"