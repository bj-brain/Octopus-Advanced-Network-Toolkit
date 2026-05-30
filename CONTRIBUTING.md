# Contributing

Thanks for considering a contribution to Octopus Advanced Network Toolkit.

## Guidelines

- Keep the toolkit Windows PowerShell 5.1 compatible.
- Prefer built-in Windows tools and modules over new dependencies.
- Do not add destructive behavior without an explicit confirmation prompt.
- Keep generated files out of the repository.
- Avoid committing screenshots, packet captures, logs, Wi-Fi exports, or secrets.

## Local Validation

Run a parser check before submitting changes:

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

If `$errors` is empty, the script parsed successfully.

## Pull Requests

Include:

- What changed
- Why it changed
- Which menu options were tested
- Whether the change is read-only or disruptive
- Any Windows version used for testing
