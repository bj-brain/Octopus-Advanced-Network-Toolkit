# Octopus Advanced Network Toolkit

```text

                               @@@@@@@@@                                                       
                          @@@@@@@@@@@@@@@                                                      
                        @@@@@@@@@@@@@@@@@@@                                                    
                       @@@@@@@@@@@@@@@@@@@@@@                                                  
                       @@@@@@@@@@@@@@@@@@@@@@                                                  
              @@@      @@@@@@@@@@@@@@@@@@@@@@      @@@
             @    @@   @@@@@@@@@@@@@@@@@@@@@@   @@    @
                  @@   @@@@@@@@@@@@@@@@@@@@@@   @@     
                 @@@     @@@  @@@@@@@@@  @@@     @@@   
                @@@@     @@@    @@@@    @@@     @@@@   
                @@@@       @@@ @@@@@ @@@       @@@@    
            @      @@     @@@@@@@@@@@@@@@     @@     @@
          @         @@@@@@@@@@@@@@@@@@@@@@@@@@@        @ 
          @@@@@@       @@@@@@@@@@@@@@@@@@@@@      @@@@@@ 
            @@@@@@@@@@  @@@@@@@@@@@@@@@@@@@  @@@@@@@@@   
                       @@@  @@@@@   @@@@  @@@          
                     @@@@  @@@@@@   @@@@@@  @@@@       
              @@@@@@@@@@@  @@@@       @@@@  @@@@@@@@@@ 
             @@@            @@@         @@@            @@
            @@              @@@         @@@              @@
            @@@      @@      @@         @@@    @@@      @@@
             @@      @       @@         @@@      @@      @@
                     @@    @@@@         @@@@  @@@@       
                       @@@@             @@@@          

                       
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
```

Octopus is a Windows PowerShell network diagnostics toolkit for local troubleshooting, wireless reporting, adapter checks, packet capture control, and basic subnet discovery.

The script is menu driven and is designed for Windows systems where the built-in networking cmdlets and `netsh` tools are available.

## Features

- DHCP lease release/renew and DNS cache flush
- Winsock and TCP/IP stack reset
- Wi-Fi interface and BSSID scan
- Physical adapter restart
- Public WAN/IP metadata lookup
- VPN and tunnel adapter detection
- Pathping and TCP port testing
- Process-to-socket mapping with `netstat`
- Windows packet capture using `netsh trace`
- TCP/IP event log review
- Windows WLAN diagnostic report launch
- Local topology and live subnet scanner
- Wi-Fi profile key extraction for profiles stored on the local machine
- Common proxy/tunnel process detection

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1
- Administrator privileges
- Internet access for WAN metadata/geolocation options
- Wi-Fi adapter required for Wi-Fi-specific options

No external PowerShell modules are required. The toolkit uses Windows built-in tools and modules such as:

- `netsh`
- `ipconfig`
- `pathping`
- `netstat`
- `Get-NetAdapter`
- `Get-NetRoute`
- `Get-NetNeighbor`
- `Get-NetIPAddress`
- `Test-NetConnection`
- `Get-WinEvent`

## Setup

1. Download or clone this repository.

   ```powershell
   git clone https://github.com/bj-brain/Octopus_Advanced_Network_Toolkit.git
   cd Octopus_Advanced_Network_Toolkit
   ```

2. If Windows marks the script as downloaded from the internet, unblock it:

   ```powershell
   Unblock-File .\Octopus.ps1
   ```

3. Use a process-scoped execution policy for the current terminal session:

   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```

## Launch

Run PowerShell as Administrator, then launch:

```powershell
cd C:\Path\To\Octopus_Advanced_Network_Toolkit
powershell -NoProfile -ExecutionPolicy Bypass -File .\Octopus.ps1
```

You can also run the script from a normal PowerShell window. It will request elevation and relaunch itself as Administrator.

## How It Works

Octopus displays a numbered menu. Enter a number from `1` to `20` to run a subsystem.

The script uses native Windows networking commands and PowerShell cmdlets. Some actions only read system state, while others change network state. Disruptive actions now ask for confirmation before running.

### Important Output Paths

- Packet capture ETL files:

  ```text
  %USERPROFILE%\Desktop\Octopus_NetTrace_yyyyMMdd_HHmmss.etl
  ```

- Trace ownership state:

  ```text
  %LOCALAPPDATA%\OctopusNetworkToolkit\trace-session.json
  ```

- Windows WLAN report:

  ```text
  C:\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html
  ```

- Temporary Wi-Fi profile XML export:

  ```text
  %TEMP%\OctopusWifiProfiles_*
  ```

The temporary Wi-Fi profile export folder is removed after option `17` completes.

## Menu Overview

| Option | Description                                  | Impact                                      |
| ------ | -------------------------------------------- | ------------------------------------------- |
| 1      | DHCP lease renegotiation and DNS cache purge | Disruptive                                  |
| 2      | Winsock and TCP/IP stack reset               | Disruptive, reboot usually required         |
| 3      | Wi-Fi interface and RF scan                  | Read-only                                   |
| 4      | Restart physical network adapters            | Disruptive                                  |
| 5      | Public WAN metadata lookup                   | External API                                |
| 6      | VPN/tunnel adapter check                     | Read-only                                   |
| 7      | Pathping target                              | Network diagnostic traffic                  |
| 8      | ARP table display                            | Read-only                                   |
| 9      | Process-to-socket mapping                    | Read-only, requires admin for process names |
| 10     | TCP port probe                               | Network diagnostic traffic                  |
| 11     | Start packet capture                         | Writes ETL file                             |
| 12     | Stop Octopus-owned packet capture            | Stops only matching Octopus trace           |
| 13     | TCP/IP event log review                      | Read-only                                   |
| 14     | Generate WLAN report                         | Writes Windows WLAN report files            |
| 15     | Local topology simulation                    | Read-only                                   |
| 16     | Geolocation lookup                           | External API                                |
| 17     | Extract Wi-Fi profile passwords              | Sensitive local credential display          |
| 18     | Proxy/VPN process detection                  | Read-only                                   |
| 19     | Smart local subnet scanner                   | ICMP scan                                   |
| 20     | Exit                                         | None                                        |

## Safety Notes

Use this toolkit only on systems and networks you own or are authorized to test.

The following options can temporarily interrupt connectivity:

- Option `1`: DHCP release/renew
- Option `2`: Winsock/TCP/IP reset
- Option `4`: physical adapter restart
- Option `11`: packet capture start
- Option `12`: packet capture stop

Option `17` displays Wi-Fi keys stored on the local machine. Treat this output as sensitive.

Option `19` shows this device, the gateway, and hosts that respond to ICMP. Devices that block ping may not appear.

## Troubleshooting

### The script closes or asks for admin

Run PowerShell as Administrator and launch the script again.

### Execution policy blocks the script

Use a process-scoped bypass:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Octopus.ps1
```

### WLAN report does not open

Run option `14` as Administrator and check:

```text
C:\ProgramData\Microsoft\Windows\WlanReport\wlan-report-latest.html
```

### Subnet scanner shows fewer devices than expected

Option `19` relies on ICMP replies for connected-device accuracy. Some devices block ping by firewall policy. This prevents false positives but can hide devices that do not reply.

## Development

Before opening a pull request, run a syntax check:

```powershell
$errors = $null
$tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\Octopus.ps1),
    [ref]$tokens,
    [ref]$errors
) | Out-Null
$errors
```

No output from `$errors` means the script parsed successfully.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
