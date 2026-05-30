# =================================================================================
# Tool:        Octopus Network Toolkit - Enterprise Diagnostics Suite
# Author:      Baanujan Vijayarajan
# GitHub:      https://github.com/bj-brain
# Description: Low-level diagnostic, telemetry, and forensic analysis tool suite.
# =================================================================================

# Explicitly set output encoding to UTF-8 for pristine ASCII/Unicode rendering
$OutputEncoding = [System.Text.Encoding]::UTF8
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

# ==========================================
# SCRIPT AUTOMATION: AUTO-ELEVATE TO ADMIN
# ==========================================
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Administrative Privileges for deep inspection..." -ForegroundColor Yellow
    $ScriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    $ScriptDirectory = Split-Path -Parent $ScriptPath
    Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$ScriptPath`"") -WorkingDirectory $ScriptDirectory -Verb RunAs
    Exit
}

try {
    $Host.UI.RawUI.WindowTitle = "Octopus Network Toolkit - Enterprise Diagnostics Suite"
} catch {}

# Color definition: Custom TrueColor ANSI escape map for Hex #60D673 (RGB: 96, 214, 115)
$OctoColor  = "$([char]27)[38;2;96;214;115m"
$CyanColor  = "$([char]27)[38;2;0;242;254m"
$ResetColor = "$([char]27)[0m"

# Global Menu Graphic Banner
$OctopusArt = @'

  /$$$$$$   /$$$$$$  /$$$$$$$$ /$$$$$$  /$$$$$$$  /$$   /$$  /$$$$$$ 
 /$$__  $$ /$$__  $$|__  $$__//$$__  $$| $$__  $$| $$  | $$ /$$__  $$
| $$  \ $$| $$  \__/   | $$  | $$  \ $$| $$  \ $$| $$  | $$| $$  \__/
| $$  | $$| $$         | $$  | $$  | $$| $$$$$$$/| $$  | $$|  $$$$$$ 
| $$  | $$| $$         | $$  | $$  | $$| $$____/ | $$  | $$ \____  $$
| $$  | $$| $$    $$   | $$  | $$  | $$| $$      | $$  | $$ /$$  \ $$
|  $$$$$$/|  $$$$$$/   | $$  |  $$$$$$/| $$      |  $$$$$$/|  $$$$$$/
 \______/  \______/    |__/   \______/ |__/       \______/  \______/ 
                                                                                                                             
 /$$$$$$$$ /$$$$$$   /$$$$$$  /$$       /$$   /$$ /$$$$$$ /$$$$$$$$  
|__  $$__//$$__  $$ /$$__  $$| $$      | $$  /$$/|_  $$_/|__  $$__/  
   | $$  | $$  \ $$| $$  \ $$| $$      | $$ /$$/   | $$     | $$     
   | $$  | $$  | $$| $$  | $$| $$      | $$$$$/    | $$     | $$     
   | $$  | $$  | $$| $$  | $$| $$      | $$  $$    | $$     | $$     
   | $$  | $$  | $$| $$  | $$| $$      | $$\  $$   | $$     | $$     
   | $$  |  $$$$$$/|  $$$$$$/| $$$$$$$$| $$ \  $$ /$$$$$$   | $$     
   |__/   \______/  \______/ |________/|__/  \__/|______/   |__/     
'@

function Pause-Menu {
    echo ""
    Read-Host "Press Enter to return to the main menu..."
}

function Confirm-Action {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prompt
    )

    $Response = Read-Host "$Prompt Type YES to continue"
    return ($Response -eq 'YES')
}

function Get-OctopusDesktopPath {
    $DesktopPath = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
        $DesktopPath = Join-Path $env:USERPROFILE 'Desktop'
    }
    if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
        $DesktopPath = (Get-Location).Path
    }
    return $DesktopPath
}

function Get-OctopusTempPath {
    $TempPath = [System.IO.Path]::GetTempPath()
    if ([string]::IsNullOrWhiteSpace($TempPath)) {
        $TempPath = $env:TEMP
    }
    if ([string]::IsNullOrWhiteSpace($TempPath)) {
        $TempPath = (Get-Location).Path
    }
    return $TempPath.TrimEnd('\')
}

function Get-OctopusStateDirectory {
    $BasePath = $env:LOCALAPPDATA
    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        $BasePath = Get-OctopusTempPath
    }

    $StateDirectory = Join-Path $BasePath 'OctopusNetworkToolkit'
    if (-not (Test-Path -LiteralPath $StateDirectory)) {
        New-Item -Path $StateDirectory -ItemType Directory -Force | Out-Null
    }
    return $StateDirectory
}

function Get-OctopusTraceStatePath {
    return (Join-Path (Get-OctopusStateDirectory) 'trace-session.json')
}

function Get-NetshTraceStatus {
    $StatusText = netsh trace show status 2>&1 | Out-String
    $ExitCode = $LASTEXITCODE

    [PSCustomObject]@{
        Text      = $StatusText
        ExitCode  = $ExitCode
        IsRunning = ($ExitCode -eq 0 -and $StatusText -notmatch 'There is no trace session currently in progress')
    }
}

function ConvertTo-IPv4UInt32 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Address
    )

    $ParsedAddress = [System.Net.IPAddress]::Parse($Address)
    $Bytes = $ParsedAddress.GetAddressBytes()
    if ($Bytes.Count -ne 4) {
        throw "Address is not IPv4: $Address"
    }

    return ([uint64]$Bytes[0] -shl 24) -bor ([uint64]$Bytes[1] -shl 16) -bor ([uint64]$Bytes[2] -shl 8) -bor [uint64]$Bytes[3]
}

function ConvertFrom-IPv4UInt32 {
    param(
        [Parameter(Mandatory = $true)]
        [uint64]$Value
    )

    return "{0}.{1}.{2}.{3}" -f (($Value -shr 24) -band 255), (($Value -shr 16) -band 255), (($Value -shr 8) -band 255), ($Value -band 255)
}

function Get-IPv4SubnetBounds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [Parameter(Mandatory = $true)]
        [ValidateRange(0, 32)]
        [int]$PrefixLength
    )

    $AddressInt = ConvertTo-IPv4UInt32 $IPAddress
    $BlockSize = [uint64][math]::Pow(2, 32 - $PrefixLength)
    $NetworkInt = [uint64]([math]::Floor([double]$AddressInt / [double]$BlockSize) * $BlockSize)
    $BroadcastInt = $NetworkInt + $BlockSize - 1

    if ($PrefixLength -ge 31) {
        $FirstHostInt = $NetworkInt
        $LastHostInt = $BroadcastInt
    } else {
        $FirstHostInt = $NetworkInt + 1
        $LastHostInt = $BroadcastInt - 1
    }

    [PSCustomObject]@{
        NetworkInt   = $NetworkInt
        BroadcastInt = $BroadcastInt
        FirstHostInt = $FirstHostInt
        LastHostInt  = $LastHostInt
        HostCount    = [uint64]($LastHostInt - $FirstHostInt + 1)
        Network      = ConvertFrom-IPv4UInt32 $NetworkInt
        Broadcast    = ConvertFrom-IPv4UInt32 $BroadcastInt
        FirstHost    = ConvertFrom-IPv4UInt32 $FirstHostInt
        LastHost     = ConvertFrom-IPv4UInt32 $LastHostInt
    }
}

function Test-IPv4InRange {
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,

        [Parameter(Mandatory = $true)]
        [uint64]$FirstAddressInt,

        [Parameter(Mandatory = $true)]
        [uint64]$LastAddressInt
    )

    try {
        $AddressInt = ConvertTo-IPv4UInt32 $IPAddress
        return ($AddressInt -ge $FirstAddressInt -and $AddressInt -le $LastAddressInt)
    } catch {
        return $false
    }
}

function Resolve-IPv4HostnamesQuick {
    param(
        [string[]]$IPAddresses,

        [int]$TimeoutMs = 1200,

        [int]$MaxLookups = 64
    )

    $Results = @{}
    $UniqueAddresses = @($IPAddresses | Where-Object { $_ } | Sort-Object -Unique | Select-Object -First $MaxLookups)
    if (-not $UniqueAddresses) {
        return $Results
    }

    $Pending = New-Object System.Collections.Generic.List[object]
    foreach ($IP in $UniqueAddresses) {
        try {
            $AsyncResult = [System.Net.Dns]::BeginGetHostEntry($IP, $null, $null)
            $Pending.Add([PSCustomObject]@{
                IP     = $IP
                Lookup = $AsyncResult
            })
        } catch {}
    }

    $Deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
    while ($Pending.Count -gt 0 -and [DateTime]::UtcNow -lt $Deadline) {
        $Completed = @($Pending | Where-Object { $_.Lookup.IsCompleted })
        foreach ($Item in $Completed) {
            try {
                $HostEntry = [System.Net.Dns]::EndGetHostEntry($Item.Lookup)
                if ($HostEntry.HostName) {
                    $Results[$Item.IP] = $HostEntry.HostName
                }
            } catch {}
            [void]$Pending.Remove($Item)
        }

        if ($Pending.Count -gt 0) {
            Start-Sleep -Milliseconds 50
        }
    }

    return $Results
}

function Invoke-IPv4PingSweep {
    param(
        [Parameter(Mandatory = $true)]
        [uint64]$FirstHostInt,

        [Parameter(Mandatory = $true)]
        [uint64]$LastHostInt,

        [int]$TimeoutMs = 350,

        [int]$OverallTimeoutMs = 2500
    )

    $LiveAddresses = New-Object System.Collections.Generic.List[string]
    $Pending = New-Object System.Collections.Generic.List[object]

    for ($AddressInt = $FirstHostInt; $AddressInt -le $LastHostInt; $AddressInt++) {
        $IP = ConvertFrom-IPv4UInt32 $AddressInt
        try {
            $Ping = New-Object System.Net.NetworkInformation.Ping
            $Task = $Ping.SendPingAsync($IP, $TimeoutMs)
            $Pending.Add([PSCustomObject]@{
                IP   = $IP
                Ping = $Ping
                Task = $Task
            })
        } catch {
            if ($Ping) {
                $Ping.Dispose()
            }
        }
    }

    $Deadline = [DateTime]::UtcNow.AddMilliseconds($OverallTimeoutMs)
    while ($Pending.Count -gt 0 -and [DateTime]::UtcNow -lt $Deadline) {
        $Completed = @($Pending | Where-Object { $_.Task.IsCompleted })
        foreach ($Item in $Completed) {
            try {
                $Reply = $Item.Task.Result
                if ($Reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    $LiveAddresses.Add($Item.IP)
                }
            } catch {}

            $Item.Ping.Dispose()
            [void]$Pending.Remove($Item)
        }

        if ($Pending.Count -gt 0) {
            Start-Sleep -Milliseconds 25
        }
    }

    for ($Index = $Pending.Count - 1; $Index -ge 0; $Index--) {
        try {
            $Pending[$Index].Ping.Dispose()
        } catch {}
    }

    return @($LiveAddresses | Sort-Object -Unique)
}

function Read-ValidatedTcpPort {
    param(
        [int]$DefaultPort = 80
    )

    $PortInput = Read-Host "Enter Target TCP Port (e.g., 443, 80, 22)"
    if ([string]::IsNullOrWhiteSpace($PortInput)) {
        return $DefaultPort
    }

    $PortNumber = 0
    if ([int]::TryParse($PortInput, [ref]$PortNumber) -and $PortNumber -ge 1 -and $PortNumber -le 65535) {
        return $PortNumber
    }

    Write-Host "[-] Invalid TCP port. Using default port $DefaultPort." -ForegroundColor Yellow
    return $DefaultPort
}

# Main Application Execution Loop
while ($true) {
    Clear-Host
    # Print the custom-colored artwork
    Write-Host "$OctoColor$OctopusArt$ResetColor"
    Write-Host "$CyanColor ================================================================="
    Write-Host "  O C T O P U S   A D V A N C E D   N E T W O R K   T O O L K I T"
    Write-Host "  By: Baanujan Vijayarajan | GitHub: https://github.com/bj-brain" -ForegroundColor DarkGray
    Write-Host " =================================================================" -ForegroundColor Cyan
    echo ""
    Write-Host "--- Core Mechanics: Ephemerality & Stack Resets ---" -ForegroundColor DarkGray
    Write-Host " 1. DHCP Lease Renegotiation & DNS Cache Purge"
    Write-Host " 2. Kernel-Level Winsock & TCP/IP Stack Restoration"
    echo ""
    Write-Host "--- Data Link & Physical Layers: RF Intelligence ---" -ForegroundColor DarkGray
    Write-Host " 3. 802.11 Airspace Reconnaissance (BSSID/RSSI/Channel)"
    Write-Host " 4. Hardware Level Transceiver Interface Cycle"
    echo ""
    Write-Host "--- Network Layer: Ingress, Routing & Discovery ---" -ForegroundColor DarkGray
    Write-Host " 5. WAN Edge Query & Autonomous System (ASN) Lookup"
    Write-Host " 6. Virtual Adapter Verification & Crypto Tunnel Audit"
    Write-Host " 7. ICMP Multi-Hop Path-Ping Execution"
    Write-Host " 8. Local ARP Table Topology Discovery"
    echo ""
    Write-Host "--- Transport to Application Layers: App Analytics ---" -ForegroundColor DarkGray
    Write-Host " 9. Process-to-Socket Association mapping (PID/EXE Bindings)"
    Write-Host "10. Automated TCP Handshake Probe (Arbitrary Port Tester)"
    echo ""
    Write-Host "--- Diagnostics, Telemetry & Forensic Capture ---" -ForegroundColor DarkGray
    Write-Host "11. Provision Kernel Packet Capture Engine (.etl Stream)"
    Write-Host "12. De-provision Capture Engine & Output Payload"
    Write-Host "13. Event Log Scraping (Microsoft-Windows-TCPIP Stack)"
    Write-Host "14. Compile 802.11 Wireless Diagnostic Report"
    echo ""
    Write-Host "--- ADVANCED OPERATIONS ---" -ForegroundColor DarkGray
    Write-Host "15. Local Topology Map & Packet Transfer Simulation"
    Write-Host "16. Geolocation Intelligence (IP, City, Country, ISP)"
    Write-Host "17. Extract Wi-Fi Profile Passwords"
    Write-Host "18. Deep Stealth Proxy/VPN Detection (VLESS, SSH, Clash)"
    Write-Host "19. Smart Local Subnet Scanner & Device Classifier"
    echo ""
    Write-Host "20. Terminate Session"
    Write-Host "=================================================================" -ForegroundColor Cyan
    
    $Choice = Read-Host "Execute Subsystem (1-20)"
    
    switch ($Choice) {
        '1' {
            Clear-Host
            Write-Host "This action releases and renews IP leases for network adapters." -ForegroundColor Yellow
            if (Confirm-Action "Continue with DHCP renegotiation?") {
                Write-Host "Releasing current IP address..." -ForegroundColor Yellow
                ipconfig /release | Out-Null
                Write-Host "Renewing IP address..." -ForegroundColor Yellow
                ipconfig /renew | Out-Null
                Write-Host "Flushing DNS Cache..." -ForegroundColor Green
                Clear-DnsClientCache
            } else {
                Write-Host "[-] DHCP renegotiation cancelled by operator." -ForegroundColor Yellow
            }
            Pause-Menu
        }
        '2' {
            Clear-Host
            Write-Host "This action resets Winsock and TCP/IP stack state and normally requires a reboot." -ForegroundColor Yellow
            if (Confirm-Action "Continue with network stack reset?") {
                Write-Host "Resetting Winsock catalog..." -ForegroundColor Yellow
                netsh winsock reset
                Write-Host "Resetting TCP/IP IP stack..." -ForegroundColor Yellow
                netsh int ip reset
                Write-Host "`n[!] Reset complete. Please restart your computer for configuration changes to bind." -ForegroundColor Cyan
            } else {
                Write-Host "[-] Network stack reset cancelled by operator." -ForegroundColor Yellow
            }
            Pause-Menu
        }
        '3' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "       WIRELESS & RF ANALYSIS" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Showing active Wi-Fi interface state..." -ForegroundColor Yellow
            netsh wlan show interfaces
            echo ""
            Write-Host "Scanning local RF airspace for visible network BSSIDs..." -ForegroundColor Yellow
            netsh wlan show networks bssid
            Pause-Menu
        }
        '4' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "      INTERFACE & POWER MANAGEMENT" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "This action temporarily disconnects all physical network adapters." -ForegroundColor Yellow
            if (Confirm-Action "Restart all physical network adapters?") {
                $PhysicalAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
                if ($PhysicalAdapters) {
                    try {
                        $PhysicalAdapters | Restart-NetAdapter -Confirm:$false -ErrorAction Stop
                        Write-Host "[+] Physical network adapters cycled successfully." -ForegroundColor Green
                    } catch {
                        Write-Host "[-] Failed to cycle one or more physical network adapters." -ForegroundColor Red
                        Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
                    }
                } else {
                    Write-Host "[-] No physical network adapters were detected." -ForegroundColor Yellow
                }
            } else {
                Write-Host "[-] Adapter cycle cancelled by operator." -ForegroundColor Yellow
            }
            Pause-Menu
        }
        '5' {
            Clear-Host
            Write-Host "Fetching Public WAN Metadata..." -ForegroundColor Cyan
            try {
                Invoke-RestMethod -Uri 'https://ipinfo.io/json' -ErrorAction Stop | Format-List *
            } catch {
                Write-Host "[-] Failed to fetch WAN metadata. Verify WAN connectivity or remote API availability." -ForegroundColor Red
                Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
            }
            Pause-Menu
        }
        '6' {
            Clear-Host
            Write-Host "Scanning for active Virtual Network / Crypto Tunnel Adapters..." -ForegroundColor Cyan
            echo ""
            $VpnAdapters = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'VPN|TAP|WireGuard|NordVPN|ExpressVPN|OpenVPN|Cisco|Fortinet|Proton|Tunnel|Tailscale|ZeroTier' -or $_.Name -match 'VPN|TAP|WireGuard|NordVPN|ExpressVPN|OpenVPN|Cisco|Fortinet|Proton|Tunnel|Tailscale|ZeroTier' }
            if ($VpnAdapters) {
                $VpnAdapters | Select-Object Name, InterfaceDescription, Status | Format-Table -AutoSize
            } else {
                Write-Host "[-] No standard virtual VPN/TAP adapters detected." -ForegroundColor Yellow
            }
            Pause-Menu
        }
        '7' {
            Clear-Host
            $Target = Read-Host "Enter IP or Domain for Pathping Target (e.g., 8.8.8.8)"
            if (-not $Target) { $Target = "8.8.8.8" }
            Write-Host "`nRunning multi-hop calculation to $Target. This may take up to 3-5 minutes..." -ForegroundColor Cyan
            pathping $Target
            Pause-Menu
        }
        '8' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "   NETWORK DISCOVERY & LOCAL ARP CACHE" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            arp -a
            Pause-Menu
        }
        '9' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "   ENDPOINT & APPLICATION SOCKET BINDINGS" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Mapping network processes to sockets. Press [Ctrl+C] to abort stream pagination.`n" -ForegroundColor Yellow
            netstat -abno | Out-Host -Paging
            Pause-Menu
        }
        '10' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "   POWERSHELL CORE: AUTOMATED PORT TESTER" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            $HostName = Read-Host "Enter Target IP or Domain Name"
            $PortNum  = Read-ValidatedTcpPort -DefaultPort 80
            if (-not $HostName) { $HostName = "127.0.0.1" }
            
            Write-Host "`nInitializing TCP Handshake sequence to $HostName on port $PortNum..." -ForegroundColor Cyan
            try {
                Test-NetConnection -ComputerName $HostName -Port $PortNum -ErrorAction Stop | Select-Object ComputerName, RemoteAddress, RemotePort, TcpTestSucceeded | Format-List
            } catch {
                Write-Host "[-] TCP probe failed before a result could be produced." -ForegroundColor Red
                Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
            }
            Pause-Menu
        }
        '11' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "   PACKET CAPTURING & KERNEL TRACING" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            $TraceStatus = Get-NetshTraceStatus
            if ($TraceStatus.IsRunning) {
                Write-Host "[-] A Windows trace session is already active. Octopus will not attach to or overwrite it." -ForegroundColor Red
                Write-Host "    Stop the existing trace first if you want Octopus to start a new capture." -ForegroundColor Yellow
                Pause-Menu
                continue
            }

            Write-Host "Provisioning core event trace engine..." -ForegroundColor Yellow
            $TraceFileName = "Octopus_NetTrace_{0}.etl" -f (Get-Date -Format 'yyyyMMdd_HHmmss')
            $TracePath = Join-Path (Get-OctopusDesktopPath) $TraceFileName
            $TraceStatePath = Get-OctopusTraceStatePath

            & netsh trace start capture=yes "tracefile=$TracePath" maxsize=250
            if ($LASTEXITCODE -eq 0) {
                [PSCustomObject]@{
                    TracePath = $TracePath
                    StartedAt = (Get-Date).ToString('o')
                } | ConvertTo-Json | Set-Content -LiteralPath $TraceStatePath -Encoding UTF8

                Write-Host "`n[+] Capture actively logging stream parameters to:" -ForegroundColor Green
                Write-Host "    $TracePath" -ForegroundColor Cyan
                Write-Host "Reproduce target diagnostic anomalies, then run Option 12 to decouple tracing." -ForegroundColor Cyan
            } else {
                Write-Host "`n[-] Trace engine failed to start." -ForegroundColor Red
            }
            Pause-Menu
        }
        '12' {
            Clear-Host
            Write-Host "De-provisioning capture engine and flushing stream buffer to file system..." -ForegroundColor Yellow
            $TraceStatePath = Get-OctopusTraceStatePath
            $TraceStatus = Get-NetshTraceStatus
            $TraceRunning = $TraceStatus.IsRunning

            if (-not (Test-Path -LiteralPath $TraceStatePath)) {
                if ($TraceRunning) {
                    Write-Host "[-] A trace session is active, but Octopus has no ownership record for it." -ForegroundColor Red
                    Write-Host "    Refusing to stop a trace session that may belong to another tool." -ForegroundColor Yellow
                } else {
                    Write-Host "[-] No Octopus trace session record exists and no active trace was detected." -ForegroundColor Yellow
                }
                Pause-Menu
                continue
            }

            try {
                $TraceState = Get-Content -LiteralPath $TraceStatePath -Raw -ErrorAction Stop | ConvertFrom-Json
            } catch {
                Write-Host "[-] Octopus trace state exists but cannot be read. Refusing to stop any trace." -ForegroundColor Red
                Write-Host "    $TraceStatePath" -ForegroundColor DarkGray
                Pause-Menu
                continue
            }

            if (-not $TraceRunning) {
                Write-Host "[-] Octopus trace state was stale; no active trace was detected." -ForegroundColor Yellow
                Remove-Item -LiteralPath $TraceStatePath -Force -ErrorAction SilentlyContinue
                Pause-Menu
                continue
            }

            if ($TraceStatus.Text -notmatch [regex]::Escape($TraceState.TracePath)) {
                Write-Host "[-] An active trace session exists, but it does not match the Octopus capture path." -ForegroundColor Red
                Write-Host "    Expected: $($TraceState.TracePath)" -ForegroundColor DarkGray
                Write-Host "    Refusing to stop a trace session that may belong to another tool." -ForegroundColor Yellow
                Pause-Menu
                continue
            }

            & netsh trace stop
            if ($LASTEXITCODE -eq 0) {
                Remove-Item -LiteralPath $TraceStatePath -Force -ErrorAction SilentlyContinue
                Write-Host "`n[+] Octopus trace stopped and flushed to:" -ForegroundColor Green
                Write-Host "    $($TraceState.TracePath)" -ForegroundColor Cyan
            } else {
                Write-Host "`n[-] Trace engine stop request failed." -ForegroundColor Red
            }
            Pause-Menu
        }
        '13' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "       LOG AGGREGATION & TRACE SCRAPING" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Filtering the 10 most critical events from Microsoft-Windows-TCPIP Stack:`n" -ForegroundColor Yellow
            Get-WinEvent -ProviderName "Microsoft-Windows-TCPIP" -MaxEvents 10 -ErrorAction SilentlyContinue | Format-List TimeCreated, Id, Message
            Pause-Menu
        }
        '14' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "       COMPREHENSIVE TELEMETRY REPORT" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Generating OS-level wireless diagnostic database..." -ForegroundColor Yellow
            & netsh wlan show wlanreport
            
            $ReportPath = "C:\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html"
            if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $ReportPath)) {
                Write-Host "`n[+] Launching native Windows wireless report stream..." -ForegroundColor Green
                Start-Process -FilePath $ReportPath
            } else {
                Write-Host "`n[-] Core diagnostic report file generation unverified." -ForegroundColor Red
            }
            Pause-Menu
        }
        '15' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "    LOCAL TOPOLOGY & PACKET SIMULATION" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Identifying active nodes on local layer-2 subnet..." -ForegroundColor Yellow
            $NeighborEntries = Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.State -in @('Reachable', 'Stale') -and $_.IPAddress -notmatch '^(224|239|255|127|0)' }
            $NeighborEntries | Select-Object IPAddress, LinkLayerAddress, State, InterfaceAlias | Sort-Object @{ Expression = { ConvertTo-IPv4UInt32 $_.IPAddress } } | Format-Table -AutoSize
            echo ""
            Write-Host "[Tx] Initiating simulated Deep Packet Inspection telemetry loops..." -ForegroundColor Magenta
            echo ""
            foreach ($Entry in $NeighborEntries) {
                $IP = $Entry.IPAddress
                if ($IP) {
                    Write-Host "[Tx->Rx] Scanning node telemetry for $IP ..." -ForegroundColor Cyan
                    Start-Sleep -Milliseconds 400
                }
            }
            Write-Host "`n[+] Simulation complete. Topo-layer state: Nominal." -ForegroundColor Green
            Pause-Menu
        }
        '16' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "         GEOLOCATION INTELLIGENCE" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Querying external WAN edge telemetry..." -ForegroundColor Yellow
            echo ""
            try {
                $Data = Invoke-RestMethod -Uri 'https://ipinfo.io/json' -ErrorAction Stop
                Write-Host "IP Address:  $($Data.ip)" -ForegroundColor Green
                Write-Host "City:        $($Data.city)" -ForegroundColor Yellow
                Write-Host "Region:      $($Data.region)" -ForegroundColor Yellow
                Write-Host "Country:     $($Data.country)" -ForegroundColor Yellow
                Write-Host "Provider:    $($Data.org)" -ForegroundColor Cyan
                Write-Host "Location:    $($Data.loc)" -ForegroundColor Magenta
            } catch {
                Write-Host "[-] Failed to fetch geolocation info. Verify WAN layer connectivity." -ForegroundColor Red
                Write-Host "    $($_.Exception.Message)" -ForegroundColor DarkGray
            }
            Pause-Menu
        }
        '17' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "       WIFI PROFILE PASSWORDS" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Extracting all cleartext security keys discovered in system vault...`n" -ForegroundColor Yellow

            $ExportRoot = Join-Path (Get-OctopusTempPath) ("OctopusWifiProfiles_{0}" -f ([guid]::NewGuid().ToString('N')))
            New-Item -Path $ExportRoot -ItemType Directory -Force | Out-Null

            try {
                & netsh wlan export profile key=clear "folder=$ExportRoot" | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "[-] Wireless profile export failed." -ForegroundColor Red
                    Pause-Menu
                    continue
                }

                $ProfileFiles = Get-ChildItem -LiteralPath $ExportRoot -Filter '*.xml' -File -ErrorAction SilentlyContinue

                if ($ProfileFiles) {
                    foreach ($ProfileFile in $ProfileFiles) {
                        try {
                            [xml]$ProfileXml = Get-Content -LiteralPath $ProfileFile.FullName -Raw
                            $NameNode = $ProfileXml.SelectSingleNode('//*[local-name()="WLANProfile"]/*[local-name()="name"]')
                            if (-not $NameNode) {
                                $NameNode = $ProfileXml.SelectSingleNode('//*[local-name()="name"]')
                            }
                            $KeyNode = $ProfileXml.SelectSingleNode('//*[local-name()="keyMaterial"]')

                            if ($NameNode) {
                                $Profile = $NameNode.InnerText
                            } else {
                                $Profile = $ProfileFile.BaseName
                            }

                            if ($KeyNode -and -not [string]::IsNullOrWhiteSpace($KeyNode.InnerText)) {
                                $Password = $KeyNode.InnerText.Trim()
                                Write-Host "Profile: " -NoNewline -ForegroundColor White
                                Write-Host ($Profile.PadRight(25)) -NoNewline -ForegroundColor Cyan
                                Write-Host " -> Key Material: " -NoNewline -ForegroundColor DarkGray
                                Write-Host $Password -ForegroundColor Green
                            } else {
                                Write-Host "Profile: " -NoNewline -ForegroundColor White
                                Write-Host ($Profile.PadRight(25)) -NoNewline -ForegroundColor Cyan
                                Write-Host " -> Key Material: " -NoNewline -ForegroundColor DarkGray
                                Write-Host "[None / Enterprise Isolated]" -ForegroundColor Yellow
                            }
                        } catch {
                            Write-Host "[-] Failed to read exported profile XML: $($ProfileFile.Name)" -ForegroundColor Yellow
                        }
                    }
                } else {
                    Write-Host "[-] No wireless network configuration maps located on host transceiver." -ForegroundColor Red
                }
            } finally {
                Remove-Item -LiteralPath $ExportRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
            Pause-Menu
        }
        '18' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "     DEEP STEALTH PROXY & VPN INSPECTOR" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "Scanning process memory bounds for proxy/encapsulation endpoints..." -ForegroundColor Yellow
            echo ""
            $Engines = @('v2ray','xray','clash','sing-box','openvpn','wireguard','tailscale','zerotier-one','ssh','plink')
            $Found = $false
            foreach ($Eng in $Engines) {
                $Procs = Get-Process -Name $Eng -ErrorAction SilentlyContinue
                if ($Procs) {
                    foreach ($P in $Procs) {
                        Write-Host "[DETECTED] Potential proxy/tunnel process: $($P.Name).exe (PID: $($P.Id))" -ForegroundColor Yellow
                        $Found = $true
                    }
                }
            }
            if (-not $Found) {
                Write-Host "[CLEAR] Memory architecture clear of standard circumvention processes." -ForegroundColor Green
            }
            Pause-Menu
        }
        '19' {
            Clear-Host
            Write-Host "==========================================" -ForegroundColor Cyan
            Write-Host "   SMART LOCAL SUBNET SCANNER & CLASSIFIER" -ForegroundColor Cyan
            Write-Host "==========================================" -ForegroundColor Cyan
            
            $DefaultRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
                Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
                Sort-Object @{ Expression = { $_.RouteMetric + $_.InterfaceMetric } }, RouteMetric, InterfaceMetric |
                Select-Object -First 1

            if (-not $DefaultRoute) {
                Write-Host "Error: Local network default routing gateway unresolvable." -ForegroundColor Red
                Pause-Menu
                continue
            }

            $InterfaceIndex = $DefaultRoute.ifIndex
            $RouterIP = $DefaultRoute.NextHop
            $LocalAddress = Get-NetIPAddress -AddressFamily IPv4 -InterfaceIndex $InterfaceIndex -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -notmatch '^(169\.254|127\.)' } |
                Select-Object -First 1

            if (-not $LocalAddress) {
                Write-Host "Error: Active IPv4 interface address unresolvable for interface index $InterfaceIndex." -ForegroundColor Red
                Pause-Menu
                continue
            }

            $SubnetBounds = Get-IPv4SubnetBounds -IPAddress $LocalAddress.IPAddress -PrefixLength $LocalAddress.PrefixLength
            Write-Host "Selected interface: $($DefaultRoute.InterfaceAlias) (ifIndex $InterfaceIndex)" -ForegroundColor Cyan
            Write-Host "Local IPv4:         $($LocalAddress.IPAddress)/$($LocalAddress.PrefixLength)" -ForegroundColor Cyan
            Write-Host "Default gateway:   $RouterIP" -ForegroundColor Cyan
            Write-Host "Subnet range:      $($SubnetBounds.FirstHost) - $($SubnetBounds.LastHost)" -ForegroundColor Cyan
            
            $ShouldSweep = $true
            $MaxSweepHosts = 4096
            if ($SubnetBounds.HostCount -gt $MaxSweepHosts) {
                Write-Host "`n[!] This subnet contains $($SubnetBounds.HostCount) usable addresses, which exceeds the active sweep limit of $MaxSweepHosts." -ForegroundColor Yellow
                $ShouldSweep = $false
            } elseif ($SubnetBounds.HostCount -gt 1024) {
                Write-Host "`n[!] This subnet contains $($SubnetBounds.HostCount) usable addresses." -ForegroundColor Yellow
                $ShouldSweep = Confirm-Action "Run the full ping sweep before reading the neighbor table?"
            }

            if ($ShouldSweep) {
                Write-Host "`nBroadcasting validation sweep across calculated subnet..." -ForegroundColor Cyan
                $PingReplyIPs = @(Invoke-IPv4PingSweep -FirstHostInt $SubnetBounds.FirstHostInt -LastHostInt $SubnetBounds.LastHostInt -TimeoutMs 350 -OverallTimeoutMs 2500)
                Write-Host "ICMP-responsive hosts: $($PingReplyIPs.Count)" -ForegroundColor DarkGray
            } else {
                Write-Host "`n[-] Active sweep skipped; compiling currently cached neighbor entries only." -ForegroundColor Yellow
                $PingReplyIPs = @()
            }
            
            $LiveIPSet = @{}
            $LiveIPSet[$LocalAddress.IPAddress] = $true
            $LiveIPSet[$RouterIP] = $true
            foreach ($IP in $PingReplyIPs) {
                $LiveIPSet[$IP] = $true
            }

            $LocalDevices = @($LiveIPSet.Keys | Sort-Object { ConvertTo-IPv4UInt32 $_ })

            Write-Host "Compiling topological report data..." -ForegroundColor Yellow
            Write-Host "Showing this device, the gateway, and hosts that replied to ICMP. Devices blocking ping may not appear." -ForegroundColor DarkGray
            $HostNameMap = @{}
            $LookupIPs = @($LocalDevices | Where-Object { $_ -ne $LocalAddress.IPAddress -and $_ -ne $RouterIP })
            if ($LookupIPs.Count -gt 0) {
                if ($LookupIPs.Count -le 64) {
                    Write-Host "Resolving hostnames with a bounded timeout...`n" -ForegroundColor DarkGray
                    $HostNameMap = Resolve-IPv4HostnamesQuick -IPAddresses $LookupIPs -TimeoutMs 1200 -MaxLookups 64
                } else {
                    Write-Host "Skipping hostname lookup for $($LookupIPs.Count) devices to keep the scan responsive.`n" -ForegroundColor DarkGray
                }
            } else {
                Write-Host ""
            }
            
            $NetworkReport = foreach ($IP in $LocalDevices) {
                $DeviceType = 'End Device'
                $HostName = 'Unknown'

                if ($IP -eq $LocalAddress.IPAddress) {
                    $DeviceType = 'This Device'
                    $HostName = $env:COMPUTERNAME
                } elseif ($IP -eq $RouterIP) {
                    $DeviceType = 'Gateway Router'
                    $HostName = 'Router'
                } elseif ($HostNameMap.ContainsKey($IP)) {
                    $HostName = $HostNameMap[$IP]
                    if ($HostName -match 'server|nas|dc|plex|ubuntu|synology|truenas') { $DeviceType = 'Infrastructure Server' }
                }

                [PSCustomObject]@{
                    'IP Address'  = $IP
                    'Device Type' = $DeviceType
                    'Device Name' = $HostName
                }
            }
            $NetworkReport | Format-Table -AutoSize
            Pause-Menu
        }
        '20' {
            Clear-Host
            Write-Host "De-allocating toolkit resource pipelines. Exiting session safely." -ForegroundColor Green
            Exit
        }
        default {
            Write-Host "Invalid sequence criteria selected. Re-indexing toolkit menu..." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
}
