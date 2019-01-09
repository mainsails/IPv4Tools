Function Invoke-IPv4Scan {
    <#
    .SYNOPSIS
        Asynchronous IPv4 Network Scanner
    .DESCRIPTION
        This asynchronous IPv4 Network Scanner allows you to scan an IPv4-Range.
        The default result will contain the the IPv4-Address, Status (Up or Down) and the Hostname.
    .EXAMPLE
        Invoke-IPv4Scan -StartIPv4Address 10.210.86.0 -EndIPv4Address 10.210.86.255

        IPv4Address   Status Hostname
        -----------   ------ --------
        10.210.86.22  Up     rwx52014.berkshire.nhs.uk
    .EXAMPLE
        Invoke-IPv4Scan -StartIPv4Address 10.210.86.0 -EndIPv4Address 10.210.86.255 -DisableDNSResolving

        IPv4Address   Status
        -----------   ------
        10.210.86.1   Up
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
        [Int32]$Tries = 2,
        [Int32]$Threads = 256,
        [Switch]$DisableDNSResolving,
        [Switch]$EnableMACResolving,
        [Switch]$ExtendedInformation,
        [Switch]$IncludeInactive
    )

    Begin {}
    Process {
        # Calculate IP range
        If ($IPv4Address -and $Netmask) { $Mask = Convert-SubnetMask -Netmask $Netmask }
        If ($IPv4Address -and $CIDR) { $Mask = Convert-SubnetMask -Netmask $CIDR }
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
        If ($EnableMACResolving) {
            $PropertiesToDisplay += 'MAC'
        }
        If ($DisableDNSResolving -eq $false) {
            $PropertiesToDisplay += 'Hostname'
        }
        If ($ExtendedInformation) {
            $PropertiesToDisplay += 'BufferSize','ResponseTime','TTL'
        }

        # Define scriptblock
        [System.Management.Automation.ScriptBlock]$ScriptBlock = {
            Param (
                $IPv4Address,
                $Tries,
                $DisableDNSResolving,
                $EnableMACResolving,
                $ExtendedInformation,
                $IncludeInactive
            )

            # ICMP
            $Status = [String]::Empty
            For ($i = 0; $i -lt $Tries; i++) {
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
            If ((-not ($DisableDNSResolving)) -and ($Status -eq 'Up' -or $IncludeInactive)) {
                Try {
                    $Hostname = ([System.Net.Dns]::GetHostEntry($IPv4Address).HostName)
                }
                Catch {}
            }

            # MAC
            $MAC = [String]::Empty
            If (($EnableMACResolving) -and (($Status -eq 'Up') -or ($IncludeInactive))) {
                $ARPCache = Get-ARPCache
                foreach ($ARP in $ARPCache) {
                    If ($ARP.IPv4Address -eq $IPv4Address) {
                        $MAC = $ARP.MACAddress
                    }
                }
            }

            # Result
            If (($Status -eq 'Up') -or ($IncludeInactive)) {
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
        $IPRange | ForEach-Object {
            $Counter = 0
            $IPv4Address = $_

            # Create parameter hashtable
            $ScriptParams = @{
                IPv4Address          = $IPv4Address
                Tries                = $Tries
                DisableDNSResolving  = $DisableDNSResolving
                EnableMACResolving   = $EnableMACResolving
                ExtendedInformations = $ExtendedInformation
                IncludeInactive      = $IncludeInactive
            }

            # Create new jobs
            Write-Progress -Activity 'Adding jobs' -Id 1 -Status "Current IP-Address : [$IPv4Address]" -PercentComplete (($Counter / $IPRange.Count) * 100)
            $Job = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddParameters($ScriptParams)
            $Job.RunspacePool = $RunspacePool
            $JobObj = [PSCustomObject] @{
                RunNum = $Counter++
                Pipe   = $Job
                Result = $Job.BeginInvoke()
            }
            [void]$Jobs.Add($JobObj)
        }

        # Process jobs
        Write-Verbose -Message 'Waiting for jobs to complete & starting to process results...'
        Do {
            $Jobs_ToProcess = $Jobs | Where-Object -FilterScript { $_.Result.IsCompleted }
            If ($null -eq $Jobs_ToProcess) {
                Start-Sleep -Milliseconds 500
                continue
            }
            $Jobs_Remaining = ($Jobs | Where-Object -FilterScript { $_.Result.IsCompleted -eq $false }).Count
            Write-Progress -Activity "Waiting for jobs to complete :: ($($Threads - $($RunspacePool.GetAvailableRunspaces())) of $Threads threads running)" -Id 1 -PercentComplete (($Jobs_Remaining / $Jobs.Count) * 100) -Status "$Jobs_Remaining remaining"
            Write-Verbose -Message "Processing $(If ($null -eq $Jobs_ToProcess.Count) { '1' } Else { $Jobs_ToProcess.Count }) job(s)..."

            # Processing completed jobs
            ForEach ($Job in $Jobs_ToProcess) {
                # Get the result...
                $Job_Result = $Job.Pipe.EndInvoke($Job.Result)
                $Job.Pipe.Dispose()

                # Remove job from collection
                $Jobs.Remove($Job)

                # Check if result contains status
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