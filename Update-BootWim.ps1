<#
.SYNOPSIS
    Update-BootWim.ps1 - A PowerShell script to customize and update a Windows Image (WIM) file.

.DESCRIPTION
    This script automates the process of customizing and updating a Windows Image (WIM) file used in Windows Preinstallation Environment (WinPE).
    It mounts the WIM image, adds optional components and language packs, applies cumulative updates, performs cleanup, and exports the modified image.

.NOTES
    File Name      : Update-BootWim.ps1
    Prerequisites  : Windows Assesment and Deployment Kit (WinADK)
                     Windows Preinstallation Environment (WinPE)
#>
############################## VARIABLES #############################
# Output Image Path + Name
$wimImagePath = "D:\Temp\bentley\Boot-Wim\boot.wim"
$mountDir = "D:\Temp\bentley\MOUNT"
$wimMsuPath = "D:\Temp\bentley\windows11.0-kb5028185-x64.msu"
# Array of optional components added to the WimImage BEFORE updating with *.msu
$OptComp = @( 
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

############################## GENERATED #############################
# ADK Architecture version (x86 removed from ADK, arm64 is not utilized)
$adkArch = "amd64" 
# Edit location of Assessment and Deployment Kit (if different than default)
$adkRoot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
# ADK Architecture subfolder path for Optional Components
$adkOptComp = "$adkArch\WinPE_OCs" 
# ADK Optional Components Path
$adkOptPath = Join-Path -Path $adkRoot -ChildPath $adkOptComp
# Use default WinPE.wim from ADK (or specify alternate)
$adkImagePath = "$adkRoot\$adkArch\en-us\winpe.wim"
############################## FUNCTIONS ###############################
function Mount-WimImage {
    # Mount WimImage for customization
    # USAGE: Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir -wimIndex $wimIndex
    [CmdletBinding()]
    param(
        # Full Path and File Name ($_.FullName) of WimImage to be mounted
        [Parameter(Mandatory = $true)] [string]$wimImagePath,
        # Folder where WimImage will be mounted for servicing
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # WimImage index to be mounted
        [Parameter(Mandatory = $false)] [int]$wimIndex = '1'
    )
    try {
        Write-Host "`nMounting the WimImage at $wimImagePath to $mountDir using index $wimIndex..."
        Mount-WindowsImage -ImagePath $wimImagePath -Path $mountDir -Index $wimIndex -Verbose
    }
    catch {
        Write-Host "`nAn error occurred while mounting the WimImage:"
        Write-Error $_.Exception.Message
    }
}

function Add-WimImageOptComps {
    # Function to add OSD packages to a mounted WimImage. 
    # USAGE: Add-WimImageOptComps -mountDir $mountDir -OptComp $OptComp -wimLang $wimLang
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # Array containing list of Optional Components to add
        [Parameter(Mandatory = $true)] [string[]]$OptComp,
        # Language of mounted WimImage
        [Parameter(Mandatory = $false)] [string]$wimLang = 'en-US'
    )
    try {
        foreach ($component in $OptComp) {
            $optCompCab = "$component.cab"
            $optCompPath = Join-Path -Path $adkOptPath -ChildPath $optCompCab
            if (Test-Path -Path $optCompPath) {
                Add-WindowsPackage -Path $mountDir -PackagePath $optCompPath -Verbose
            }
            else { Write-Warning "Cannot find $component at $optCompPath" }
            $langCab = "$wimLang\$($component)_$($wimLang).cab"
            $langCabPath = Join-Path -Path $adkOptPath -ChildPath $langCab
            if (Test-Path -Path $langCabPath) {
                Add-WindowsPackage -Path $mountDir -PackagePath $langCabPath -Verbose
            }
            else { Write-Warning "Cannot find $wimLang language pack for $component at $langCabPath" }
        }
    }
    catch {
        Write-Error "`nAn error occurred while adding OSD packages."
        Write-Error $_.Exception.Message
    }
}

function Add-WimImageUpdate {
    # Add Cumulative Update by *.msu (or Optional Component by *.cab) to a mounted WimImage
    # USAGE: Add-WimImageUpdate -mountDir $mountDir -wimMsuPath $wimMsuPath
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # Full Path and File Name ($_.FullName) of *.msu (or *.cab)
        [Parameter(Mandatory = $true)] [string]$wimMsuPath
    )
    try {
        Write-Host "`nAdding package $wimMsuPath to the mounted WimImage at $mountDir..."
        Add-WindowsPackage -Path $mountDir -PackagePath $wimMsuPath -Verbose
    }
    catch {
        Write-Host "`nAn error occurred while adding the package:"
        Write-Error $_.Exception.Message
    }
}

function Dismount-WimImage {
    # Dismount WimImage & Save
    # USAGE: Dismount-WimImage -mountDir $mountDir
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir
    )
    try {
        Write-Host "`nDismounting and saving the mounted WimImage at $mountDir..."
        Dismount-WindowsImage -Path $mountDir -Save -Verbose
    }
    catch {
        Write-Host "`nAn error occurred while dismounting and saving the WimImage:"
        Write-Error $_.Exception.Message
    }
}

function Invoke-WimImageCleanup {
    # Function to perform cleanup operations on a mounted Windows Image (WIM) file
    # USAGE: Invoke-WimImageCleanup -mountDir $mountDir 
    [CmdletBinding()]
    param(
        # Path to the mounted WIM directory
        [Parameter(Mandatory = $true)] [string]$mountDir
    )
    try {
        Write-Host "`nPerforming cleanup operations on mounted WimImage at $mountDir..."
        & Dism "/Image:$mountDir" '/Cleanup-Image' '/StartComponentCleanup' '/ResetBase'
    }
    catch {
        Write-Host "`nAn error occurred while performing cleanup operations."
        Write-Error $_.Exception.Message
    }
}

function Export-WimImage {
    # Function to export a specific index of a Windows Image (WIM) file
    # USAGE: Export-WimImage -exportWimImage $exportWimImage -exportWimIndex 1
    [CmdletBinding()]
    param(
        # Path to the source WimImage to be exported
        [Parameter(Mandatory = $true)] [string]$exportWimImage,
        # Index of the WimImage to export
        [Parameter(Mandatory = $false)] [int]$exportWimIndex = '1'
    )
    $tempImageName = [IO.Path]::ChangeExtension($exportWimImage, "tmp")
    try {
        # Rename the source WimImage to a temporary name
        Write-Host "`nRenaming the source WimImage to a temporary file..."
        Move-Item -Path $exportWimImage -Destination $tempImageName
        # Export the WimImage with the specified index
        Write-Host "`nExecuting the WimImage export operation..."
        Export-WindowsImage -SourceImagePath $tempImageName -SourceIndex $exportWimIndex -DestinationImagePath $exportWimImage
        # Check if export was successful and delete the temporary file
        if (Test-Path -Path $exportWimImage) {
            Write-Host "`nExport successful, deleting the temporary file..."
            Remove-Item -Path $tempImageName
        }
        else {
            Write-Warning "`nExport operation failed. Exported WimImage does not exist. Reverting to original WimImage name."
        }
    }
    catch {
        Write-Host "`nAn error occurred while exporting the image index: $exportWimIndex "
        Write-Error $_.Exception.Message
        Write-Host "`nReverting to the original WimImage name..."
        Move-Item -Path $tempImageName -Destination $exportWimIndex
    }
}

############################## VERIFICATION ############################
# Check if DISM module is available and loaded
$moduleAvailable = Get-Module -Name DISM -ListAvailable
if (-not $moduleAvailable) {
    try {
        # If module not available, import it
        Write-Host "`nImporting DISM module..."
        Import-Module -Name DISM 
    }
    catch {
        Write-Host "`nFailed to import DISM module:"
        Write-Error $_.Exception.Message
        return
    }
}
else {
    Write-Host "`nDISM module confirmed available and loaded."
    $moduleAvailable
}

# Ensure the ADK Optional Components are available
if (-not (Test-Path -Path $adkOptPath)) { Write-Error "`nADK not found in default location."; return }
else {
    Write-Host "`nADK Optional Components are available at default location."
    Write-Host "`nADK Root = $adkRoot"
}

# Read array of optional components to be added to the WimImage when using Add-WimImageOptComps function
Write-Host "`nADK Optional Components to be added during this session..."
foreach ($component in $OptComp) { Write-Host "    $component" }
Write-Host "" # Empty line for logging readability

############################## EXECUTION ###############################
# Ensure we are on $env:SystemDrive, not PSDrive for CM-Site
Push-Location $env:SystemDrive

# Copy Reference WinPE.wim
Copy-Item -Path $adkImagePath -Destination $wimImagePath

# Mount target boot.wim
if (-not (Test-Path -Path $wimImagePath)) { Write-Error "$wimImagePath not found"; throw }
Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir -wimIndex '1'

# Add boot.wim OSD Optional Components BEFORE applying *.msu Cumulative Update
if (-not $OptComp) { Write-Error "List of Optional components not specified"; throw }
if (-not (Test-Path -Path $adkOptPath)) { Write-Error "ADK WinPE_OCs not found in default location"; throw }
Add-WimImageOptComps -mountDir $mountDir -OptComp $OptComp -wimLang 'en-us'

# Dismount target boot.wim to commit components before updating
Dismount-WimImage -mountDir $mountDir

# Mount target boot.wim
Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir -wimIndex '1'

# Apply *.msu Cumulative Update 
Add-WimImageUpdate -mountDir $mountDir -wimMsuPath $wimMsuPath

# Dismount target boot.wim to commit updates before cleanup
Dismount-WimImage -mountDir $mountDir

# Mount target boot.wim
Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir -wimIndex '1'

# Cleanup boot.wim to disable WinOS components applied from Cumulative update
Invoke-WimImageCleanup -mountDir $mountDir

# Dismount target boot.wim to commit cleanup
Dismount-WimImage -mountDir $mountDir

# Export cleaned boot.wim to reduce size by removing updates not intended for WinPE
Export-WimImage -exportWimImage $wimImagePath -exportWimIndex 1

# Return to starting file system location
Pop-Location
