# Chocolatey Package for Helm

This repo contains the build code of the kubernetes helm package for chocolatey.

[![Build status](https://ci.appveyor.com/api/projects/status/9vli24fuw7knyyjh/branch/master?svg=true)](https://ci.appveyor.com/project/synax/choco-helm/branch/master)


## Install the latest version

```Powershell
    # Chocolatey has to be installed
    Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

    # Install helm
    choco install helm
```