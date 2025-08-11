# ================================
# Azure P2S VPN Auto Connect Script
# ================================

# Parameters – change these for your environment
$ResourceGroup = "MyResourceGroup"
$VpnGatewayName = "MyVpnGateway"
$DownloadFolder = "$env:TEMP\AzureVPNProfile"
$PbkName = "AzureVPN"  # The name of the connection inside the PBK file

# 1. Login to Azure
Write-Host "Logging in to Azure..."
Connect-AzAccount -UseDeviceAuthentication

# 2. Get the VPN client config package
Write-Host "Downloading VPN profile..."
$profileUri = (Get-AzVpnClientPackage -ResourceGroupName $ResourceGroup -Name $VpnGatewayName -ProcessorArchitecture Amd64).VpnProfileSasUrl

# Create download folder if it doesn't exist
if (!(Test-Path $DownloadFolder)) {
    New-Item -ItemType Directory -Path $DownloadFolder | Out-Null
}

$zipPath = Join-Path $DownloadFolder "vpnprofile.zip"
Invoke-WebRequest -Uri $profileUri -OutFile $zipPath

# 3. Extract the profile
Write-Host "Extracting VPN profile..."
Expand-Archive -Path $zipPath -DestinationPath $DownloadFolder -Force

# Locate the PBK file
$pbkFile = Get-ChildItem -Path $DownloadFolder -Recurse -Filter *.pbk | Select-Object -First 1

if (-not $pbkFile) {
    Write-Error "PBK file not found in the downloaded profile."
    exit 1
}

# 4. Connect to VPN using rasdial
Write-Host "Connecting to VPN..."
rasdial $PbkName /PHONEBOOK:$($pbkFile.FullName)

Write-Host "VPN connection initiated."
