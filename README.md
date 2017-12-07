# Chocolatey Package for Helm

This repo contains the source of the helm package for chocolatey.

## Install the latest version

```Powershell
    # Chocolatey has to be installed
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    # Install helm
    choco install helm
```