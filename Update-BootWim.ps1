<#
.SYNOPSIS
    Update-BootWim.ps1 - Customizes and updates a Windows Image (WIM) for WinPE.
.DESCRIPTION
    This script automates the process of mounting, customizing, updating, cleaning up, and exporting a Windows Image (WIM) file for use in WinPE.
.NOTES
    File Name: Update-BootWim.ps1
    Author:    bentman
    Purpose:   To streamline the preparation of WinPE boot images for deployment.
.LINK
    https://github.com/bentman/PoShWinPEWimImage
    https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/deploy-windows-pe--winpe
#>

############################## VARIABLES ##############################
$wimImagePath = "D:\Temp\Boot-Wim\boot.wim"
$mountDir = "D:\Temp\MOUNT"
$wimMsuPath = "D:\Temp\updates\windows11.0-kb5028185-x64.msu"
$optionalComponents = @(
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
    "WinPE-WinReCfg"
)
$adkArch = "amd64"
$adkRoot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
$adkOptPath = Join-Path -Path $adkRoot -ChildPath "$adkArch\WinPE_OCs"
$adkImagePath = "$adkRoot\$adkArch\en-us\winpe.wim"

############################## VERIFICATION ############################
$moduleAvailable = Get-Module -Name DISM -ListAvailable
$moduleLoaded = $false
if (-not $moduleAvailable) {
    try { Import-Module -Name DISM -ErrorAction Stop; $moduleLoaded = $true }
    catch { Write-Error "Error importing DISM module: $_"; return $false }
}
else { Write-Host "DISM module already loaded."; $moduleLoaded = $true }
return $moduleLoaded

try {
    if ((Test-Path -Path $adkRoot) -and (Test-Path -Path $adkOptPath)) {
        Write-Output "ADK installation verified. Optional components available at: $adkOptPath"
    }
    else { throw "ADK installation or optional components path not found." }
}
catch { Write-Error "Verification failed: $_"; return }

############################## FUNCTIONS ###############################
function Mount-WimImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$wimImagePath,
        [Parameter(Mandatory = $true)] [string]$mountDir,
        [Parameter(Mandatory = $false)] [int]$wimIndex = 1
    )
    try {
        Write-Host "Mounting the WimImage at $wimImagePath to $mountDir using index $wimIndex..."
        Mount-WindowsImage -ImagePath $wimImagePath -Path $mountDir -Index $wimIndex -Verbose
    }
    catch { Write-Error "An error occurred while mounting the WimImage: $_" }
}

function Dismount-WimImage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string]$mountDir)
    try {
        Write-Host "Dismounting and saving the mounted WimImage at $mountDir..."
        Dismount-WindowsImage -Path $mountDir -Save -Verbose
    }
    catch { Write-Error "An error occurred while dismounting the WimImage: $_" }
}

function Add-WimImageOptComps {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]$mountDir,
        [Parameter(Mandatory = $true)] [string[]]$optionalComponents,
        [Parameter(Mandatory = $false)] [string]$wimLang = 'en-US'
    )
    try {
        foreach ($component in $optionalComponents) {
            $optCompPath = Join-Path -Path $adkOptPath -ChildPath "$component.cab"
            if (Test-Path -Path $optCompPath) {
                Add-WindowsPackage -Path $mountDir -PackagePath $optCompPath -Verbose
            }
            else { Write-Warning "Cannot find $component at $optCompPath" }
        }
    }
    catch { Write-Error "An error occurred while adding OSD packages: $_" }
}

function Add-WimImageUpdate {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string]$mountDir, [Parameter(Mandatory = $true)] [string]$wimMsuPath)
    try {
        Write-Host "Adding package $wimMsuPath to the mounted WimImage at $mountDir..."
        Add-WindowsPackage -Path $mountDir -PackagePath $wimMsuPath -Verbose
    }
    catch { Write-Error "An error occurred while adding the package: $_" }
}

function Invoke-WimImageCleanup {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string]$mountDir)
    try {
        Write-Host "Performing cleanup on mounted WimImage at $mountDir..."
        & Dism "/Image:$mountDir" "/Cleanup-Image" "/StartComponentCleanup" "/ResetBase"
    }
    catch { Write-Error "An error occurred during cleanup: $_" }
}

function Export-WimImage {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string]$exportWimImage, [Parameter(Mandatory = $false)] [int]$exportWimIndex = '1')
    $tempImageName = [IO.Path]::ChangeExtension($exportWimImage, "tmp")
    try {
        Move-Item -Path $exportWimImage -Destination $tempImageName
        Export-WindowsImage -SourceImagePath $tempImageName -SourceIndex $exportWimIndex -DestinationImagePath $exportWimImage
        if (Test-Path -Path $exportWimImage) { Remove-Item -Path $tempImageName }
        else { throw "Export operation failed." }
    }
    catch { Write-Error "An error occurred during export: $_" }
}

############################## EXECUTION ###############################
Push-Location $env:SystemDrive

Copy-Item -Path $adkImagePath -Destination $wimImagePath

Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir

Add-WimImageOptComps -mountDir $mountDir -optionalComponents $optionalComponents

Dismount-WimImage -mountDir $mountDir

Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir

Add-WimImageUpdate -mountDir $mountDir -wimMsuPath $wimMsuPath

Dismount-WimImage -mountDir $mountDir

Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir

Invoke-WimImageCleanup -mountDir $mountDir

Dismount-WimImage -mountDir $mountDir

Export-WimImage -exportWimImage $wimImagePath

Pop-Location
