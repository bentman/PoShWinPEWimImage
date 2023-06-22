<#
.SYNOPSIS
    This script contains functions for working with Windows Imaging (WIM) files using DISM.exe and module cmdlets.
    Script functionality is specifically designed for customizing WinPE and WinRE images, but also works with WinOS.
    This script does not execute any actions and is intended to be dot-sourced for use in other scripts.
    Dot-sourcing is a method in PowerShell that allows you to call functions in your shell from an external script.

.EXAMPLE
    . .\Use-WimImageFunctions.ps1

.DESCRIPTION
    The script provides the following functions:
    - Export-WimImage: Exports a WIM image with a specified index (esp. after a cleanup).
    - Split-WimImage: Splits a WIM image into multiple smaller files less than 4gb (ex. fat32 USB).
    - Add-WimDriver: Adds single a driver to a mounted image directly from driver's folder (ex. iaStorVD.inf).
    - Invoke-WimImageCleanup: Performs cleanup operations on a mounted image (esp. after adding updates).
    - Add-WimImageOsdPackages: Adds common OSD (Operating System Deployment) packages to a mounted image.
    - Enable-WimOptFeature: # Enable Features in a mounted WimImage by name (ex. NetFX3). Path to source files can be specified.

    #### Because DISM.exe output format is easy to read ####
    - Get-WimImage: Lists details of a WIM image using DISM.exe (for logging).
    - Get-WimDrivers: Lists drivers using DISM.exe from a mounted image (for logging).
    - Get-WimPackage: Lists packages using DISM.exe from a mounted image (for logging).
    - Get-WimOptFeature: Lists optional features using DISM.exe from a mounted image (for logging).

.LINK
    More information about DISM module cmdlets: https://docs.microsoft.com/en-US/powershell/module/dism

.NOTES
    Version: 2.0
    Creation Date: 2023-06-10
    Copyright (c) 2023 https://github.com/bentman
    https://github.com/bentman/PoShWinPEWimImage
#>

# Edit array of optional components to be added to the WimImage when using Add-WimImageOsdPackages function
$OsdOptionalComponents = @(
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

# Check if DISM module is available and loaded
$moduleAvailable = Get-Module -Name DISM -ListAvailable
if (-not $moduleAvailable) {
    try {
        # Module not available, import it
        Write-Host "`nImporting DISM module..."
        Import-Module DISM -ErrorAction Stop
    }
    catch {
        Write-Host "`nFailed to import DISM module:"
        Write-Host $_.Exception.Message
        return
    }
}
else {
    Write-Host "`nDISM module found."
}

function Export-WimImage { # Exports a Windows Imaging (WIM) file with a specified index.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$sourceImagePath,
        [Parameter(Mandatory=$true)][int]$sourceIndex
    )
    $tempImageName = [IO.Path]::ChangeExtension($sourceImagePath, "tmp")
    try {
        Write-Host "`nRenaming the source WIM file to a temporary file..."
        Move-Item -Path $sourceImagePath -Destination $tempImageName

        Write-Host "`nExecuting the WIM file export operation..."
        Export-WindowsImage -SourceImagePath $tempImageName -SourceIndex $sourceIndex -DestinationImagePath $sourceImagePath

        if (Test-Path -Path $sourceImagePath) {
            Write-Host "`nExport successful, deleting the temporary file..."
            Remove-Item -Path $tempImageName
        }
        else {
            throw "`nExport operation failed. Exported WIM file does not exist. Reverting to original WIM file name."
        }
    }
    catch {
        Write-Host "`nAn error occurred while exporting the image index: . "
        Write-Host $_.Exception.Message
        Write-Host "`nReverting to the original WIM file name..."
        Move-Item -Path $tempImageName -Destination $sourceImagePath
    }
}

function Split-WimImage { # Splits a WIM image into multiple smaller files less than 4gb
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$wimImagePath
    )
    $wimImageDirectory = Split-Path -Path $wimImagePath -Parent
    $wimImageBaseName = Split-Path -Path $wimImagePath -Leaf
    $wimImageBaseName = [System.IO.Path]::GetFileNameWithoutExtension($wimImageBaseName)
    $destinationImagePath = Join-Path -Path $wimImageDirectory -ChildPath "$($wimImageBaseName).swm"
    try {
        Write-Host "`nSplitting the WIM file into smaller files, each less than 4GB..."
        Split-WindowsImage `
            -ImagePath $wimImagePath `
            -DestinationImagePath $destinationImagePath `
            -FileSizeMB 4000
        $SWMFiles = Get-ChildItem -Path $wimImageDirectory -Filter "$($wimImageBaseName)*.swm"
        if ($SWMFiles.Count -gt 0) {
            Write-Host "`nDeleting the original WIM file..."
            Remove-Item -Path $wimImagePath -Force
        }
        else {
            throw "`nNo .swm files were created. The original WIM file will not be deleted."
        }
    }
    catch {
        Write-Host "`nAn error occurred while splitting the image:"
        Write-Host $_.Exception.Message
    }
}

function Add-WimDriver { # Adds a single driver to a mounted Windows Imaging (WIM) file.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$driverPath
    )
    try {
        $driverDir = Split-Path -Path $driverPath -Parent
        $driverFileName = Split-Path -Path $driverPath -Leaf
        Write-Host "`nChanging directory to $driverDir..."
        Push-Location $driverDir
        Write-Host "`nAdding driver $driverFileName to the mounted WIM file at $mountDir..."
        Add-WindowsDriver -Path $mountDir -Driver $driverFileName
    }
    catch {
        Write-Host "`nAn error occurred while adding the driver: $_"
        Write-Host $_.Exception.Message
    }
    finally {
        Write-Host "`nReturning to the original directory..."
        Pop-Location
    }
}

function Invoke-WimImageCleanup { # Performs cleanup operations on a mounted Windows Imaging (WIM) file.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir
    )
    try {
        Write-Host "`nPerforming cleanup operations on mounted WIM file at $mountDir..."
        & Dism "/Image:$mountDir" '/Cleanup-Image' '/StartComponentCleanup' '/ResetBase'
    }
    catch {
        Write-Host "`nAn error occurred while performing cleanup operations:"
        Write-Host $_.Exception.Message
    }
}

function Add-WimImageOsdPackages { # Adds OSD packages to a mounted image
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$wimImageOc,
        [Parameter(Mandatory=$true)][string]$wimImageLang
    )
    try {
        foreach ($component in $OsdOptionalComponents) {
            $componentCab = "$component.cab"
            $languageCab = "$wimImageLang\$component" + "_$($wimImageLang).cab"
            $packagePath = Join-Path -Path $wimImageOc -ChildPath $componentCab
            $languagePackPath = Join-Path -Path $wimImageOc -ChildPath $languageCab
            if (Test-Path -Path $packagePath) {
                Write-Host "`nAdding $component to WimImage..."
                Add-WindowsPackage -Path $mountDir -PackagePath $packagePath
            } else {
                Write-Host "`nCannot find $component at $packagePath"
            }
            if (Test-Path -Path $languagePackPath) {
                Write-Host "`nAdding $wimImageLang language pack for $component to WimImage..."
                Add-WindowsPackage -Path $mountDir -PackagePath $languagePackPath
            } else {
                Write-Host "`nCannot find $wimImageLang language pack for $component at $languagePackPath"
            }
        }
    }
    catch {
        Write-Error "`nAn error occurred while adding OSD packages:"
        Write-Host $_.Exception.Message
    }
}

function Enable-WimOptFeature { # Enable Features in a mounted WimImage by name. Path to source files can be specified.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$FeatureName,
        [Parameter(Mandatory=$false)][string]$sourcePath
    )

    try {
        if ($sourcePath) {
            Write-Host "`nEnabling feature $FeatureName in the mounted WIM file at $mountDir with source path $sourcePath..."
            Enable-WindowsOptionalFeature -Path $mountDir -FeatureName $FeatureName -All -Source $sourcePath
        }
        else {
            Write-Host "`nEnabling feature $FeatureName in the mounted WIM file at $mountDir..."
            Enable-WindowsOptionalFeature -Path $mountDir -FeatureName $FeatureName -All
        }
    }
    catch {
        Write-Host "`nAn error occurred while enabling the feature:"
        Write-Host $_.Exception.Message
    }
}

function Get-WimImage { # Lists details of a WIM Image using DISM.exe (for logging)
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$wimImagePath
    )
    try {
        Write-Host "`nRetrieving WIM image details for: $wimImagePath"
        $output = & dism.exe /Get-ImageInfo /ImageFile:$wimImagePath /Format:Table
        Write-Host $output
    }
    catch {
        Write-Host "`nFailed to retrieve WIM image details for $wimImagePath"
        Write-Error $_.Exception.Message
    }
}

function Get-WimDrivers { # Lists drivers using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir
    )
    try {
        Write-Host "`nRetrieving drivers from mounted WIM file at $mountDir..."
        $output = & dism.exe /Get-Drivers /Image:$mountDir /Format:Table
        Write-Host $output
    }
    catch {
        Write-Host "`nAn error occurred while retrieving drivers from $mountDirs"
        Write-Error $_.Exception.Message
    }
}

function Get-WimPackage { # Lists packages using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$mountDir
    )
    try {
        Write-Host "`nRetrieving packages from mounted WIM file at $mountDir..."
        $output = & dism.exe /Get-Packages /Image:$mountDir /Format:Table
        Write-Host $output
    } catch {
        Write-Host "`nAn error occurred while retrieving packages from $mountDir"
        Write-Error $_.Exception.Message
    }
}

function Get-WimOptFeature { # Lists optional features using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir
    )
    try {
        Write-Host "`nRetrieving optional features from mounted WIM file at $mountDir..."
        $output = & dism.exe /Image:$mountDir /Get-Features /Format:Table
        Write-Host $output
    }
    catch {
        Write-Host "`nAn error occurred while retrieving optional features from $mountDir"
        Write-Error $_.Exception.Message
    }
}

<#
.VARIABLE EXAMPLES
# Variables for copying to scripts
$wimImagePath = "C:\Path\to\image.wim"       # Path to the WIM image
$sourceImagePath = "C:\Path\to\image.wim"  # Source path of the WIM image for export
$sourceIndex = 1                          # Index of the WIM image to export
$mountDir = "C:\Mount"                     # Directory where the image is mounted
$driverPath = "C:\Path\to\driver.inf"      # Path to the driver to be added
$wimImageOc = "C:\Path\to\osd_packages"    # Path to the OSD packages
$wimImageLang = "en-US"                    # Language of the OSD packages
#>

<#
# Variables used in functions
$moduleAvailable = $null   # Boolean variable to check if DISM module is available and loaded

# Get-WimImage variables
$wimImagePath = "C:\Path\to\image.wim"       # Path to the WIM image

# Export-WimImage variables
$sourceImagePath = "C:\Path\to\image.wim"  # Source path of the WIM image for export
$sourceIndex = 1                          # Index of the WIM image to export

# Split-WimImage variables
$wimImageDirectory = $null      # Directory of the WIM image
$wimImageBaseName = $null       # Base name of the WIM image
$destinationImagePath = $null  # Path of the destination split WIM image

# Add-WimDriver variables
$mountDir = $null           # Directory where the image is mounted
$driverPath = $null         # Path to the driver to be added

# Get-WimDriver variables
$mountDir = $null           # Directory where the image is mounted

# Get-WimPackage variables
$mountDir = $null           # Directory where the image is mounted

# Get-WimOptFeature variables
$mountDir = $null           # Directory where the image is mounted

# Invoke-WimImageCleanup variables
$mountDir = $null           # Directory where the image is mounted

# Add-WimImageOsdPackages variables
$mountDir = $null           # Directory where the image is mounted
$wimImageOc = $null         # Path to the OSD packages
$wimImageLang = $null       # Language of the OSD packages
$OsdOptionalComponents = $null # Array of optional components

# Try-Catch variables
$tempImageName = $null      # Temporary name for the image during export operation
$componentCab = $null       # Name of the component CAB file
$languageCab = $null        # Name of the language pack CAB file
$packagePath = $null        # Path to the component CAB file
$languagePackPath = $null   # Path to the language pack CAB file
$SWMFiles = $null           # Array of SWM files created during split operation

############# Convenient Redundant Functions #############

function Dismount-WimImage { # Dismount WimImage & Save
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir
    )
    try {
        Write-Host "`nDismounting and saving the mounted WIM image at $mountDir..."
        Dismount-WindowsImage -Path $mountDir -Save
    }
    catch {
        Write-Host "`nAn error occurred while dismounting and saving the WIM image:"
        Write-Host $_.Exception.Message
    }
}

function Expand-WimImage { # Apply WimImage by Index to path
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$wimImagePath,
        [Parameter(Mandatory=$true)][string]$ApplyPath,
        [Parameter(Mandatory=$true)][int]$Index
    )
    try {
        Write-Host "`nExpanding the WIM image at $wimImagePath to $ApplyPath using index $Index..."
        Expand-WindowsImage -ImagePath $wimImagePath -ApplyPath $ApplyPath -Index $Index
    }
    catch {
        Write-Host "`nAn error occurred while expanding the WIM image:"
        Write-Host $_.Exception.Message
    }
}

function Mount-WimImage { # Mount WimImage for customization
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$wimImagePath,
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][int]$Index
    )
    try {
        Write-Host "`nMounting the WIM image at $wimImagePath to $mountDir using index $Index..."
        Mount-WindowsImage -ImagePath $wimImagePath -Path $mountDir -Index $Index
    }
    catch {
        Write-Host "`nAn error occurred while mounting the WIM image:"
        Write-Host $_.Exception.Message
    }
}

function Mount-WimImage { # Mount WimImage for customization
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$wimImagePath,
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][int]$Index
    )
    try {
        Write-Host "`nMounting the WIM image at $wimImagePath to $mountDir using index $Index..."
        Mount-WindowsImage -ImagePath $wimImagePath -Path $mountDir -Index $Index
    }
    catch {
        Write-Host "`nAn error occurred while mounting the WIM image:"
        Write-Host $_.Exception.Message
    }
}

function Save-WimImage { # Saves a WimImage. Saves incremental WimImage to an alternate path if provided.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$false)][string]$destinationImagePath
    )
    try {
        if ($PSBoundParameters.ContainsKey('DestinationImagePath')) {
            Write-Host "`nSaving the WIM image from $mountDir to $destinationImagePath..."
            Save-WindowsImage -Path $mountDir -DestinationImagePath $destinationImagePath
        } else {
            Write-Host "`nSaving the WIM image from $mountDir..."
            Save-WindowsImage -Path $mountDir
        }
    }
    catch {
        Write-Host "`nAn error occurred while saving the WIM image:"
        Write-Host $_.Exception.Message
    }
}

function Add-WimDrivers { # Add multiple recursed drivers to a mounted WimImage
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$driversPath
    )
    try {
        Write-Host "`nAdding drivers from $driversPath to the mounted WIM file at $mountDir..."
        Add-WindowsDriver -Path $mountDir -Driver $driversPath -Recurse
    }
    catch {
        Write-Host "`nAn error occurred while adding the drivers:"
        Write-Host $_.Exception.Message
    }
}

function Export-WimDriver { # Export drivers from a mounted WimImage
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$destination
    )
    try {
        Write-Host "`nExporting drivers from the mounted WIM file at $mountDir to $destination..."
        Export-WindowsDriver -Path $mountDir -Destination $destination
    }
    catch {
        Write-Host "`nAn error occurred while exporting the drivers:"
        Write-Host $_.Exception.Message
    }
}

function Remove-WimDriver { # Remove driver by specifying the OEM*.inf file name from a mounted WimImage
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$driverFileName
    )
    try {
        Write-Host "`nRemoving driver $driverFileName from the mounted WIM file at $mountDir..."
        Remove-WindowsDriver -Path $mountDir -WimDriver $driverFileName
    }
    catch {
        Write-Host "`nAn error occurred while removing the driver:"
        Write-Host $_.Exception.Message
    }
}

function Add-WimPackage { # Add Optional Components by *.cab or updates by *.msu to a mounted WimImage
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$PackagePath
    )

    try {
        Write-Host "`nAdding package $PackagePath to the mounted WIM file at $mountDir..."
        Add-WindowsPackage -Path $mountDir -WimPackagePath $PackagePath
    }
    catch {
        Write-Host "`nAn error occurred while adding the package:"
        Write-Host $_.Exception.Message
    }
}

function Remove-WimPackage { # Remove Optional Components by *.cab or updates by *.msu from a mounted WimImage by name
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$PackageName
    )
    try {
        Write-Host "`nRemoving package $PackageName from the mounted WIM file at $mountDir..."
        Remove-WindowsPackage -Path $mountDir -WimPackageName $PackageName
    }
    catch {
        Write-Host "`nAn error occurred while removing the package:"
        Write-Host $_.Exception.Message
    }
}

function Disable-WimOptFeature { # Disable Features in mounted WimImage by name
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$FeatureName
    )
    try {
        Write-Host "`nDisabling feature '$FeatureName' in mounted WIM image at '$mountDir'..."
        Disable-WindowsOptionalFeature -Path $mountDir -FeatureName $FeatureName
    }
    catch {
        Write-Host "`nAn error occurred while disabling the feature:"
        Write-Host $_.Exception.Message
    }
}

#>
