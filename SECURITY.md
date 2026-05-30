# Security Policy

## Responsible Use

Octopus Advanced Network Toolkit is intended for diagnostics on systems and networks you own or are authorized to test.

Do not use this toolkit to access, inspect, disrupt, or capture traffic on networks without permission.

## Sensitive Data

Some options can expose sensitive local information:

- Option `9`: process and socket mappings
- Option `11`: packet capture files
- Option `13`: network event logs
- Option `17`: stored Wi-Fi profile keys

Do not upload generated traces, logs, Wi-Fi profile exports, or screenshots containing credentials to public issues.

## Reporting Issues

If you find a security problem, open a private report if GitHub security advisories are enabled for the repository. If not, contact the maintainer directly.

When reporting, include:

- A short description
- Affected menu option
- Windows version
- Steps to reproduce
- Whether credentials, packet captures, or private network details are involved
