Function Invoke-IPv4PortScan {
    <#
    .SYNOPSIS
        Asynchronous IPv4 Port Scanner.
    .DESCRIPTION
        This asynchronous IPv4 Port Scanner allows you to scan every Port-Range you want (500 to 2600 would work). Only TCP-Ports are scanned.
        The result will contain the Port number, Protocol, Service name, Description and the Status.
    .PARAMETER ComputerName
        ComputerName or IPv4-Address of the device which you want to scan.
    .PARAMETER StartPort
        First port which should be scanned (Default=1).
    .PARAMETER EndPort
        Last port which should be scanned (Default=65535).
    .PARAMETER Threads
        Maximum number of threads at the same time (Default=500).
    .PARAMETER UpdateList
        Update Service Name and Transport Protocol Port Number Registry from IANA.org.
    .OUTPUTS
        System.Management.Automation.PSCustomObject
    .EXAMPLE
        Invoke-IPv4PortScan -ComputerName ComputerA.domain.com -EndPort 100

        Port Protocol ServiceName  ServiceDescription               Status
        ---- -------- -----------  ------------------               ------
        21   tcp      ftp          File Transfer Protocol [Control] open
        53   tcp      domain       Domain Name Server               open
        80   tcp      http         World Wide Web HTTP              open
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Position=0,Mandatory=$true)]
        [String]$ComputerName,
        [Parameter(Position=1)]
        [ValidateRange(1,65535)]
        [Int32]$StartPort=1,
        [Parameter(Position=2)]
        [ValidateRange(1,65535)]
        [ValidateScript({ $_ -gt $StartPort })]
        [Int32]$EndPort=65535,
        [Parameter(Position=3)]
        [Int32]$Threads=500,
        [Parameter(Position=4)]
        [switch]$UpdateList
    )

    Begin {}
    Process {
        # Update IANA port number registry
        If ($UpdateList) {
            Update-IANAPortRegistry
        }
        $PortListAvailable = Test-Path -Path $Script:IANAPortRegistry -PathType Leaf

        # Check if it is possible to assign service with port
        If ($PortListAvailable) {
            $AssignServiceWithPort = $true
        }
        Else {
            Write-Warning -Message 'IANA Port Number Registry not available :: Consider using the "-UpdateList" switch'
            $AssignServiceWithPort = $false
        }

        # Check if host is reachable
        Write-Verbose -Message 'Test if host is pingable'
        If (-not(Test-Connection -ComputerName $ComputerName -Count 2 -Quiet)) {
            Write-Warning -Message "$ComputerName is not pingable"
        }

        $PortsToScan = ($EndPort - $StartPort)

        Write-Verbose -Message "Scanning range from $StartPort to $EndPort ($PortsToScan Ports)"
        Write-Verbose -Message "Running with max $Threads threads"

        # Check if ComputerName is already an IPv4 Address and if not, try to resolve it
        $IPv4Address = [String]::Empty
        If ([bool]($ComputerName -as [IPAddress])) {
            $IPv4Address = $ComputerName
        }
        Else {
            Try {
                $AddressList = @(([System.Net.Dns]::GetHostEntry($ComputerName)).AddressList)

                ForEach ($Address in $AddressList) {
                    If ($Address.AddressFamily -eq 'InterNetwork') {
                        $IPv4Address = $Address.IPAddressToString
                        break
                    }
                }
            }
            Catch {}

            If ([String]::IsNullOrEmpty($IPv4Address)) {
               throw "Could not get IPv4-Address for $ComputerName. (Try to enter an IPv4-Address instead of the Hostname)"
            }
        }

        # Scriptblock --> will run in runspaces (threads)...
        [System.Management.Automation.ScriptBlock]$ScriptBlock = {
            Param (
                $IPv4Address,
                $Port
            )

            Try {
                $Socket = New-Object System.Net.Sockets.TcpClient($IPv4Address,$Port)

                If ($Socket.Connected) {
                    $Status = 'Open'
                    $Socket.Close()
                }
                Else {
                    $Status = 'Closed'
                }
            }
            Catch {
                $Status = 'Closed'
            }

            If ($Status -eq 'Open') {
                [PSCustomObject] @{
                    Port     = $Port
                    Protocol = 'tcp'
                    Status   = $Status
                }
            }
        }

        # Create RunspacePool and Jobs
        Write-Verbose -Message 'Setting up RunspacePool'
        $RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,$Threads,$Host)
        $RunspacePool.Open()
        [System.Collections.ArrayList]$Jobs = @()

        #Set up job for each port...
        Write-Verbose -Message 'Setting up Jobs'
        ForEach ($Port in $StartPort..$EndPort) {
            $ScriptParams = @{
                IPv4Address = $IPv4Address
                Port        = $Port
            }

            # Catch when trying to divide through zero
            Try {
                $Progress_Percent = (($Port - $StartPort) / $PortsToScan) * 100
            }
            Catch {
                $Progress_Percent = 100
            }

            Write-Progress -Activity "Setting up jobs..." -Id 1 -Status "Current Port: $Port" -PercentComplete ($Progress_Percent)

            # Create new job
            $Job = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddParameters($ScriptParams)
            $Job.RunspacePool = $RunspacePool

            $JobObj = [PSCustomObject] @{
                RunNum = $Port - $StartPort
                Pipe   = $Job
                Result = $Job.BeginInvoke()
            }

            # Add job to collection
            [void]$Jobs.Add($JobObj)
        }

        Write-Verbose -Message 'Waiting for jobs to complete & starting to process results'

        # Total jobs to calculate percent complete, because jobs are removed after they are processed
        $Jobs_Total = $Jobs.Count

        # Process results, while waiting for other jobs
        Do {
            # Get all jobs, which are completed
            $Jobs_ToProcess = $Jobs | Where-Object -FilterScript {$_.Result.IsCompleted}

            # If no jobs finished yet, wait 500 ms and try again
            If ($null -eq $Jobs_ToProcess) {
                Write-Verbose -Message 'No jobs completed, wait 500ms'
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

            Write-Verbose -Message "Processing $(If ($null -eq $Jobs_ToProcess.Count) { '1' } Else { $Jobs_ToProcess.Count }) job(s)"

            # Processing completed jobs
            ForEach ($Job in $Jobs_ToProcess) {
                # Get the result...
                $Job_Result = $Job.Pipe.EndInvoke($Job.Result)
                $Job.Pipe.Dispose()

                # Remove job from collection
                $Jobs.Remove($Job)

                # Check if result is null --> if not, return it
                If ($Job_Result.Status) {
                    If ($AssignServiceWithPort) {
                        Get-IANAPortRegistry -Result $Job_Result
                    }
                    Else {
                        $Job_Result
                    }
                }
            }
        }
        While ($Jobs.Count -gt 0)

        Write-Verbose -Message "Closing RunspacePool and free resources..."

        # Close the RunspacePool and free resources
        $RunspacePool.Close()
        $RunspacePool.Dispose()
    }
    End {}
}