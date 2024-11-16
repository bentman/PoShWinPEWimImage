<#
.SYNOPSIS
    Helper script for managing and customizing WinPE boot images using DISM.
.DESCRIPTION
    This script provides a collection of functions for mounting, updating, customizing, and finalizing Windows Image (Wim) files.
    It is designed to be dot-sourced and integrated into larger automation workflows.
.EXAMPLE
    Dot-source the script and mount a Wim image:
        . .\Use-WimImageFunctions.ps1
        Mount-WimImage -wimImagePath "C:\path\to\image.wim" -mountDir "C:\mount"
.NOTES
    File Name: Use-WimImageFunctions.ps1
    Author:    bentman
    Purpose:   To streamline the preparation of WinPE boot images for deployment.
.LINK
    https://github.com/bentman/PoShWinPEWimImage
    https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/deploy-windows-pe--winpe
#>
############################## DECLARATION ##############################
$scriptName = (Get-PSCallStack).InvocationInfo.MyCommand.Name
$scriptVer = "2.5" # Minor Corrections
Write-Host "`nDot-Sourcing functions in $scriptName v$scriptVer..."

# Verifies DISM Module is available and loaded
$moduleAvailable = Get-Module -Name DISM -ListAvailable
$moduleLoaded = $false
if (-not $moduleAvailable) {
    try { Import-Module -Name DISM -ErrorAction Stop; $moduleLoaded = $true }
    catch { Write-Error "Error importing DISM module: $_"; return $false }
}
else { Write-Host "DISM module already loaded."; $moduleLoaded = $true }
return $moduleLoaded

# Verifies ADK installation and optional components path
$adkRoot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
$adkArch = "amd64"
$adkOptPath = Join-Path -Path $adkRoot -ChildPath "$adkArch\WinPE_OCs"
try {
    if ((Test-Path -Path $adkRoot) -and (Test-Path -Path $adkOptPath)) {
        Write-Output "ADK installation verified. Optional components available at: $adkOptPath"
    }
    else { throw "ADK installation or optional components path not found." }
}
catch { Write-Error "Verification failed: $_"; return }

# Edit array of optional components to be added to the WimImage when using Add-WimImageOptComps function
$optionalComponents = @( # Common blend of OCs for CM/Intune
    "WinPE-HTA",
    "WinPE-MDAC",
    "WinPE-Scripting",
    "WinPE-WMI",
    "WinPE-NetFX",
    "WinPE-PowerShell",
    "WinPE-DismCmdlets",
    "WinPE-SecureBootCmdlets",
    "WinPE-StorageWMI",
    "WinPE-EnhancedStorage",
    "WinPE-WinReCfg",
    "WinPE-PlatformId"
)
Write-Host "`nADK Optional Components to be added during this session..."
foreach ($component in $optionalComponents) { Write-Host "    $component" }
Write-Host "" # Empty line for logging readability

############################## COMPLETION ##############################
Write-Host "`nSuccessful dot-sourcing of ..."
Write-Host "    Script Name = $scriptName"
Write-Host "    Script Version = $scriptVer"
