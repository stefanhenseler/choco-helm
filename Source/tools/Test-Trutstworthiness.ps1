[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true)]
    $PackageBinPath
)

$ErrorActionPreference = 'Stop'

# Set the version of the package version you want to verify
$Version = '2.7.2'
$FileName = "helm-v$($Version)-windows-amd64.tar.gz"
$TempFilePath = Join-Path $Env:TEMP $FileName

Write-Verbose "File Name is [$FileName]"

$ReleasesUrl = 'https://storage.googleapis.com/kubernetes-helm/'
$BinDownloadUrl = ($ReleasesUrl + $FileName)

Write-Verbose "Download Url is [$BinDownloadUrl]"

# Get 7zip in order to extract the archive
Install-Module 7Zip4Powershell -Scope CurrentUser -Repository PSGallery
Import-Module 7Zip4Powershell

# Download the helm binary
Write-Verbose "Downloading file from [$BinDownloadUrl] to [$TempFilePath]"
(New-Object System.Net.WebClient).DownloadFile($BinDownloadUrl,$TempFilePath)

$TempFolderPath = $(Split-Path $TempFilePath)

# Extract the archive
Expand-7Zip -ArchiveFileName $TempFilePath -TargetPath $TempFolderPath
Expand-7Zip -ArchiveFileName $TempFilePath.Trim('.gz') -TargetPath $TempFolderPath

$SourceBinPath = $(Join-Path $TempFolderPath 'windows-amd64\helm.exe')

# Get SHA256 Hash
Write-Verbose "Getting file hash from [$SourceBinPath]"
$SourceBinHash = Get-FileHash -Path $SourceBinPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash
Write-Verbose "File hash from file [$SourceBinPath] is [$SourceBinHash]"

Write-Verbose "Getting file hash from [$PackageBinPath]"
$PackageBinHash = Get-FileHash -Path $PackageBinPath -Algorithm SHA256 | Select-Object -ExpandProperty Hash
Write-Verbose "File hash from file [$PackageBinPath] is [$PackageBinHash]"

# Compare Hash
if ($SourceBinHash -eq $PackageBinHash) {
    Write-Output $true
} else {
    Write-Output $false
}

