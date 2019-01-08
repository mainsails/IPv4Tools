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
        [Parameter(ParameterSetName='Mask',Position=0,Mandatory=$true)]
        [IPAddress]$IPv4Address,
        [Parameter(ParameterSetName='Mask',Position=1,Mandatory=$true)]
        [ValidateScript({ $_ -match "^(254|252|248|240|224|192|128|0).0.0.0$|^255.(254|252|248|240|224|192|128|0).0.0$|^255.255.(254|252|248|240|224|192|128|0).0$|^255.255.255.(255|254|252|248|240|224|192|128|0)$" })]
        [String]$Mask,
        [Parameter(ParameterSetName='CIDR',Position=1,Mandatory=$true)]
        [ValidateRange(0,31)]
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
        # Calculate Subnet (Start and End IPv4-Address)
        If ($PSCmdlet.ParameterSetName -eq 'CIDR' -or $PSCmdlet.ParameterSetName -eq 'Mask') {
            # Convert Subnetmask
            If ($PSCmdlet.ParameterSetName -eq 'Mask') {
                $CIDR = (Convert-Subnetmask -Mask $Mask).CIDR
            }

            # Create new subnet
            $Subnet = Get-IPv4Subnet -IPv4Address $IPv4Address -CIDR $CIDR

            # Assign Start and End IPv4-Address
            $StartIPv4Address = $Subnet.NetworkID
            $EndIPv4Address   = $Subnet.Broadcast
        }

        # Convert Start and End IPv4-Address to Int64
        $StartIPv4Address_Int64 = (Convert-IPv4Address -IPv4Address $StartIPv4Address.ToString()).Int64
        $EndIPv4Address_Int64   = (Convert-IPv4Address -IPv4Address $EndIPv4Address.ToString()).Int64

        # Check if range is valid
        If ($StartIPv4Address_Int64 -gt $EndIPv4Address_Int64) {
            Write-Error -Message 'Invalid IP-Range... Check your input!' -Category InvalidArgument -ErrorAction Stop
        }

        # Calculate IPs to scan (range)
        $IPsToScan = ($EndIPv4Address_Int64 - $StartIPv4Address_Int64)

        Write-Verbose -Message "Scanning range from $StartIPv4Address to $EndIPv4Address ($($IPsToScan + 1) IPs)"
        Write-Verbose -Message "Running with max $Threads threads"
        Write-Verbose -Message "ICMP checks per IP is set to $Tries"

        # Properties which are displayed in the output
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


        # Scriptblock --> will run in runspaces (threads)...
        [System.Management.Automation.ScriptBlock]$ScriptBlock = {
            Param (
                $IPv4Address,
                $Tries,
                $DisableDNSResolving,
                $EnableMACResolving,
                $ExtendedInformation,
                $IncludeInactive
            )

            # +++ Send ICMP requests +++
            $Status = [String]::Empty

            For ($i = 0; $i -lt $Tries; i++) {
                Try {
                    $PingObj    = New-Object System.Net.NetworkInformation.Ping
                    $Timeout    = 1000
                    $Buffer     = New-Object Byte[] 32
                    $PingResult = $PingObj.Send($IPv4Address, $Timeout, $Buffer)

                    If ($PingResult.Status -eq 'Success') {
                        $Status = 'Up'
                        break # Exit loop, if host is reachable
                    }
                    Else {
                        $Status = 'Down'
                    }
                }
                Catch {
                    $Status = 'Down'
                    break # Exit loop, if there is an error
                }
            }

            # +++ Resolve DNS +++
            $Hostname = [String]::Empty

            If ((-not ($DisableDNSResolving)) -and ($Status -eq 'Up' -or $IncludeInactive)) {
                Try {
                    $Hostname = ([System.Net.Dns]::GetHostEntry($IPv4Address).HostName)
                }
                Catch {} # No DNS
            }

            # +++ Get MAC-Address +++
            $MAC = [String]::Empty

            If (($EnableMACResolving) -and (($Status -eq 'Up') -or ($IncludeInactive))) {
                $Arp_Result = (ARP -a).ToUpper()
                ForEach ($Line in $Arp_Result) {
                    If ($Line.TrimStart().StartsWith($IPv4Address)) {
                        $MAC = [Regex]::Matches($Line,"([0-9A-F][0-9A-F]-){5}([0-9A-F][0-9A-F])").Value
                    }
                }
            }

            # +++ Get extended informations +++
            $BufferSize   = [String]::Empty
            $ResponseTime = [String]::Empty
            $TTL          = $null

            If ($ExtendedInformation -and ($Status -eq 'Up')) {
                Try {
                    $BufferSize   = $PingResult.Buffer.Length
                    $ResponseTime = $PingResult.RoundtripTime
                    $TTL          = $PingResult.Options.Ttl
                }
                Catch {} # Failed to get extended informations
            }

            # +++ Result +++
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

        # Create RunspacePool and Jobs
        Write-Verbose -Message 'Setting up RunspacePool...'
        $RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,$Threads,$Host)
        $RunspacePool.Open()
        [System.Collections.ArrayList]$Jobs = @()

        # Set up Jobs for each IP...
        Write-Verbose -Message 'Setting up Jobs...'
        For ($i = $StartIPv4Address_Int64; $i -le $EndIPv4Address_Int64; $i++) {
            # Convert IP back from Int64
            $IPv4Address = (Convert-IPv4Address -Int64 $i).IPv4Address

            # Create hashtable to pass parameters
            $ScriptParams = @{
                IPv4Address          = $IPv4Address
                Tries                = $Tries
                DisableDNSResolving  = $DisableDNSResolving
                EnableMACResolving   = $EnableMACResolving
                ExtendedInformations = $ExtendedInformation
                IncludeInactive      = $IncludeInactive
            }

            # Catch when trying to divide through zero
            Try {
                $Progress_Percent = (($i - $StartIPv4Address_Int64) / $IPsToScan) * 100
            }
            Catch {
                $Progress_Percent = 100
            }


            # Create new job
            Write-Progress -Activity 'Setting up jobs...' -Id 1 -Status "Current IP-Address: $IPv4Address" -PercentComplete $Progress_Percent
            $Job = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddParameters($ScriptParams)
            $Job.RunspacePool = $RunspacePool

            $JobObj = [pscustomobject] @{
                RunNum = $i - $StartIPv4Address_Int64
                Pipe   = $Job
                Result = $Job.BeginInvoke()
            }

            # Add job to collection
            [void]$Jobs.Add($JobObj)
        }

        Write-Verbose -Message 'Waiting for jobs to complete & starting to process results...'

        # Total jobs to calculate percent complete, because jobs are removed after they are processed
        $Jobs_Total = $Jobs.Count

        # Process results, while waiting for other jobs
        Do {
            # Get all jobs, which are completed
            $Jobs_ToProcess = $Jobs | Where-Object -FilterScript { $_.Result.IsCompleted }

            # If no jobs finished yet, wait 500 ms and try again
            If ($null -eq $Jobs_ToProcess) {
                Write-Verbose -Message 'No jobs completed, wait 500ms...'
                Start-Sleep -Milliseconds 500
                continue
            }

            # Get jobs, which are not complete yet
            $Jobs_Remaining = ($Jobs | Where-Object -FilterScript { $_.Result.IsCompleted -eq $false }).Count

            # Catch when trying to divide through zero
            Try {
                $Progress_Percent = 100 - (($Jobs_Remaining / $Jobs_Total) * 100)
            }
            Catch {
                $Progress_Percent = 100
            }

            Write-Progress -Activity "Waiting for jobs to complete... ($($Threads - $($RunspacePool.GetAvailableRunspaces())) of $Threads threads running)" -Id 1 -PercentComplete $Progress_Percent -Status "$Jobs_Remaining remaining..."

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

        # Close the RunspacePool and free resources
        Write-Verbose -Message 'Closing RunspacePool and free resources...'
        $RunspacePool.Close()
        $RunspacePool.Dispose()
    }
    End {}
}