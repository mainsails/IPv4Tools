Function Invoke-IPv4Scan {
    <#
    .SYNOPSIS
        Asynchronous IPv4 Network Scanner
    .DESCRIPTION
        This asynchronous IPv4 Network Scanner allows you to scan an IPv4 Range.
        The default result will contain the the IPv4 Address, Status (Up or Down), Hostname and MAC Address.
    .PARAMETER StartIPv4Address
        Starting IP Address.
    .PARAMETER EndIPv4Address
        Ending IP Address.
    .PARAMETER IPv4Address
        The IPv4 adress to use alongside either the 'Netmask' or 'CIDR' parameters for IP range input.
    .PARAMETER Netmask
        The netmask address to use alongside the 'IPv4Address' parameter for IP range input.
    .PARAMETER CIDR
        The CIDR prefix to use alongside the 'IPv4Address' parameter for IP range input.
    .PARAMETER DisableDNSResolution
        This is an optional parameter switch that disables DNS resolution during the scan.
    .PARAMETER DisableMACResolution
        This is an optional parameter switch that disables MAC address resolution during the scan.
    .PARAMETER ExtendedInformation
        This is an optional parameter switch that includes buffer size, response time and TTL in the output.
    .PARAMETER IncludeInactive
        This is an optional parameter switch that includes addresses that don't respond (all) in the output.
    .PARAMETER Threads
        This is an optional parameter that sets the number of threads to run concurrently.
    .PARAMETER Count
        This is an optional parameter that sets the number of echo requests to send.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        Invoke-IPv4Scan -StartIPv4Address 192.168.0.1 -EndIPv4Address 192.168.0.255

        IPv4Address   Status MAC               Hostname
        -----------   ------ ---               --------
        192.168.0.25  Up     36-8A-2C-02-93-D4 Computer1.Domain.com

    .EXAMPLE
        Invoke-IPv4Scan -IPv4Address 192.168.0.1 -CIDR 24 -DisableDNSResolution

        IPv4Address   Status MAC
        -----------   ------ ---
        192.168.0.25  Up     36-8A-2C-02-93-D4

    .EXAMPLE
        Invoke-IPv4Scan -IPv4Address 192.168.0.1 -CIDR 24 -DisableMACResolution

        IPv4Address   Status Hostname
        -----------   ------ ---
        192.168.0.25  Up     Computer1.Domain.com

    .EXAMPLE
        Invoke-IPv4Scan -IPv4Address 192.168.0.1 -CIDR 24 -IncludeInactive -ExtendedInformation

        IPv4Address  : 192.168.0.1
        Status       : Down
        MAC          :
        Hostname     :
        BufferSize   :
        ResponseTime :
        TTL          :

        IPv4Address  : 192.168.0.2
        Status       : Up
        MAC          : 92-A0-B5-67-89-97
        Hostname     : Computer2.Domain.com
        BufferSize   : 32
        ResponseTime : 4
        TTL          : 128
    #>

    [CmdletBinding(DefaultParameterSetName='CIDR')]
    Param (
        [Parameter(ParameterSetName='Range',Position=0,Mandatory=$true)]
        [IPAddress]$StartIPv4Address,
        [Parameter(ParameterSetName='Range',Position=1,Mandatory=$true)]
        [IPAddress]$EndIPv4Address,
        [Parameter(ParameterSetName='Address',Position=0,Mandatory=$true)]
        [IPAddress]$IPv4Address,
        [Parameter(ParameterSetName='Mask',Position=1,Mandatory=$true)]
        [Parameter(ParameterSetName='Address')]
        [ValidateScript({ $_ -match "^(254|252|248|240|224|192|128|0).0.0.0$|^255.(254|252|248|240|224|192|128|0).0.0$|^255.255.(254|252|248|240|224|192|128|0).0$|^255.255.255.(255|254|252|248|240|224|192|128|0)$" })]
        [String]$Netmask,
        [Parameter(ParameterSetName='CIDR',Position=1,Mandatory=$true)]
        [Parameter(ParameterSetName='Address')]
        [ValidateRange(0,32)]
        [Int32]$CIDR,
        [Switch]$DisableDNSResolution,
        [Switch]$DisableMACResolution,
        [Switch]$ExtendedInformation,
        [Switch]$IncludeInactive,
        [Int32]$Threads = 256,
        [Int32]$Count = 2
    )

    Begin {}
    Process {
        # Calculate IP range
        If ($IPv4Address -and $Netmask) { $Mask = Convert-SubnetMask -Netmask $Netmask }
        If ($IPv4Address -and $CIDR)    { $Mask = Convert-SubnetMask -CIDR $CIDR }
        If ($IPv4Address -and $Mask) {
            $IP = Get-IPv4Calculation -IPv4Address $IPv4Address -Netmask $($Mask.Netmask)
            $StartIPv4Address = $IP.HostMin
            $EndIPv4Address   = $IP.HostMax
        }
        [string[]]$IPRange = New-IPv4Range -StartIPv4Address $StartIPv4Address -EndIPv4Address $EndIPv4Address
        Write-Verbose -Message "Scanning IP range from [$StartIPv4Address] to [$EndIPv4Address] :: $($IPRange.Count) IPs"

        # Set output properties
        $PropertiesToDisplay = @()
        $PropertiesToDisplay += 'IPv4Address','Status'
        If ($DisableMACResolution -eq $false) {
            $PropertiesToDisplay += 'MAC'
        }
        If ($DisableDNSResolution -eq $false) {
            $PropertiesToDisplay += 'Hostname'
        }
        If ($ExtendedInformation) {
            $PropertiesToDisplay += 'BufferSize','ResponseTime','TTL'
        }

        # Define scriptblock
        [System.Management.Automation.ScriptBlock]$ScriptBlock = {
            Param (
                $IPv4Address,
                $Count,
                $DisableDNSResolution,
                $DisableMACResolution,
                $ExtendedInformation,
                $IncludeInactive
            )

            # ICMP
            $Status = [String]::Empty
            For ($i = 0; $i -lt $Count; i++) {
                Try {
                    $PingObj    = New-Object -TypeName System.Net.NetworkInformation.Ping
                    $Timeout    = 1000
                    $Buffer     = New-Object -TypeName Byte[] -ArgumentList 32
                    $PingResult = $PingObj.Send($IPv4Address,$Timeout,$Buffer)

                    If ($PingResult.Status -eq 'Success') {
                        $Status = 'Up'
                        break
                    }
                    Else {
                        $Status = 'Down'
                    }
                }
                Catch {
                    $Status = 'Down'
                    break
                }
            }

            # Extended Information
            $BufferSize   = [String]::Empty
            $ResponseTime = [String]::Empty
            $TTL          = $null
            If ($ExtendedInformation -and ($Status -eq 'Up')) {
                Try {
                    $BufferSize   = $PingResult.Buffer.Length
                    $ResponseTime = $PingResult.RoundtripTime
                    $TTL          = $PingResult.Options.Ttl
                }
                Catch {}
            }

            # DNS
            $Hostname = [String]::Empty
            If ((-not ($DisableDNSResolution)) -and (($Status -eq 'Up') -or $IncludeInactive)) {
                Try {
                    $Hostname = ([System.Net.Dns]::GetHostEntry($IPv4Address).HostName)
                }
                Catch {}
            }

            # MAC
            $MAC = [String]::Empty
            If ((-not ($DisableMACResolution)) -and (($Status -eq 'Up') -or $IncludeInactive)) {
                $Arp_Result = (& ARP -a).ToUpper()
                Foreach ($Line in $Arp_Result) {
                    If ($Line.TrimStart().StartsWith($IPv4Address)) {
                        $MAC = [Regex]::Matches($Line,'([0-9A-F][0-9A-F]-){5}([0-9A-F][0-9A-F])').Value
                    }
                }
            }

            # Result
            If (($Status -eq 'Up') -or $IncludeInactive) {
                [PSCustomObject] @{
                    IPv4Address  = $IPv4Address
                    Status       = $Status
                    Hostname     = $Hostname
                    MAC          = $MAC
                    BufferSize   = $BufferSize
                    ResponseTime = $ResponseTime
                    TTL          = $TTL
                }
            }
            Else {
                $null
            }
        }

        # Create RunspacePool
        $RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,$Threads,$Host)
        $RunspacePool.Open()
        [System.Collections.ArrayList]$Jobs = @()

        # Create job for all IPs in range
        $IPRange | ForEach-Object -Process {
            $Counter++
            $IPv4Address = $_

            # Create parameter hashtable
            $ScriptParams = @{
                IPv4Address          = $IPv4Address
                Count                = $Count
                DisableDNSResolution = $DisableDNSResolution
                DisableMACResolution = $DisableMACResolution
                ExtendedInformation  = $ExtendedInformation
                IncludeInactive      = $IncludeInactive
            }

            # Create new jobs
            Write-Progress -Activity 'Adding jobs' -Id 1 -Status "Current IP-Address : [$IPv4Address]" -PercentComplete (($Counter / $($IPRange.Count)) * 100)
            $Job = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddParameters($ScriptParams)
            $Job.RunspacePool = $RunspacePool
            $JobObj = [PSCustomObject] @{
                RunNum = $JobNum++
                Pipe   = $Job
                Result = $Job.BeginInvoke()
            }
            [void]$Jobs.Add($JobObj)
        }

        # Process jobs
        $TotalJobs = $Jobs.Count
        Do {
            $Jobs_Remaining = ($Jobs | Where-Object -FilterScript { $_.Result.IsCompleted -eq $false }).Count
            $Jobs_ToProcess = $Jobs | Where-Object -FilterScript { $_.Result.IsCompleted }
            If ($null -eq $Jobs_ToProcess) {
                Start-Sleep -Milliseconds 500
                Continue
            }
            Write-Progress -Activity "Waiting for jobs to complete :: ($($Threads - $($RunspacePool.GetAvailableRunspaces())) of $Threads threads running)" -Id 1 -PercentComplete ((($TotalJobs - $Jobs_Remaining) / $TotalJobs) * 100) -Status "$Jobs_Remaining remaining"
            Write-Verbose -Message "Processing $(If ($null -eq $Jobs_ToProcess.Count) { '1' } Else { $Jobs_ToProcess.Count }) job(s)"

            # Process completed jobs
            ForEach ($Job in $Jobs_ToProcess) {
                # Get the result
                $Job_Result = $Job.Pipe.EndInvoke($Job.Result)
                $Job.Pipe.Dispose()

                # Remove job
                $Jobs.Remove($Job)

                # Check result
                If ($Job_Result.Status) {
                    $Job_Result | Select-Object -Property $PropertiesToDisplay
                }
            }
        }
        While ($Jobs.Count -gt 0)

        # Close the RunspacePool
        $RunspacePool.Close()
        $RunspacePool.Dispose()
    }
    End {}
}