Function Invoke-IPv4PortScan {
    <#
    .SYNOPSIS
        Asynchronous IPv4 Port Scanner.
    .DESCRIPTION
        This asynchronous IPv4 Port Scanner allows you to scan port ranges. Only TCP-Ports are scanned.
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
        22   tcp      ssh          The Secure Shell (SSH) Protocol  open
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
        Write-Verbose -Message "Scanning range from [$StartPort] to [$EndPort] :: $PortsToScan Ports"

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
               throw "Could not get IPv4-Address for [$ComputerName]. (Try to enter an IPv4-Address instead of the Hostname)"
            }
        }

        # Define scriptblock
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

        # Create RunspacePool
        $RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1,$Threads,$Host)
        $RunspacePool.Open()
        [System.Collections.ArrayList]$Jobs = @()

        # Create job for all ports in range
        ForEach ($Port in $StartPort..$EndPort) {
            $Counter++

            # Create parameter hashtable
            $ScriptParams = @{
                IPv4Address = $IPv4Address
                Port        = $Port
            }

            # Create new jobs
            Write-Progress -Activity "Adding jobs" -Id 1 -Status "Current Port: [$Port]" -PercentComplete (($Counter / $($StartPort..$EndPort)) * 100)
            $Job = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock).AddParameters($ScriptParams)
            $Job.RunspacePool = $RunspacePool
            $JobObj = [PSCustomObject] @{
                RunNum = $Port - $StartPort
                Pipe   = $Job
                Result = $Job.BeginInvoke()
            }
            [void]$Jobs.Add($JobObj)
        }

        # Process jobs
        $TotalJobs = $Jobs.Count
        Do {
            $Jobs_Remaining = ($Jobs | Where-Object -FilterScript { $_.Result.IsCompleted -eq $false }).Count
            $Jobs_ToProcess = $Jobs | Where-Object -FilterScript {$_.Result.IsCompleted}
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

        # Close the RunspacePool
        $RunspacePool.Close()
        $RunspacePool.Dispose()
    }
    End {}
}