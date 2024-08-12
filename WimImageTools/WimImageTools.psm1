<#
WimImageTools.psm1
.SYNOPSIS
    WimImageTools - A comprehensive module for managing Windows Image (WIM) files.
.DESCRIPTION
    This module provides a suite of functions for mounting, modifying, and managing Windows Image (WIM) files,
    including adding drivers, packages, and features. It also includes functions for working with
    Configuration Manager (CM) boot images and performing various WIM-related operations.
.NOTES
    Version: 2.0
    Creation Date: 2024-08-11
    Copyright (c) 2024 https://github.com/bentman
    https://github.com/bentman/PoShWinPEWimImage
#>

# Module initialization
$script:adkRoot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
$script:adkArch = "amd64"
$script:adkOptPath = Join-Path -Path $script:adkRoot -ChildPath "OptionalComponents\$script:adkArch"
$script:OptionalComponents = @(
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

function Initialize-DismModule {
    <#
    .SYNOPSIS
        Checks if the DISM module is available and loads it if needed.
    .DESCRIPTION
        This function ensures that the DISM module is available for use. If it's not loaded, the function attempts to load it.
    .OUTPUTS
        [bool] Indicates if the module was loaded successfully.
    .NOTES
        The DISM module is required for various WIM-related operations.
    #>
    $moduleAvailable = Get-Module -Name DISM -ListAvailable
    $moduleLoaded = $false

    if (-not $moduleAvailable) {
        # Try to load the DISM module if not available
        try {
            Import-Module -Name DISM -ErrorAction Stop
            $moduleLoaded = $true
        } 
        catch { Write-Error "Error importing DISM module: $_" }
    } 
    else { $moduleLoaded = $true }
    return $moduleLoaded
}

function Mount-WimImage {
    <#
    .SYNOPSIS
        Mounts a WIM image for customization.
    .DESCRIPTION
        This function mounts a specified WIM image to a given directory so that it can be customized.
    .PARAMETER wimImagePath
        Full path to the WIM file.
    .PARAMETER mountDir
        Directory where the WIM will be mounted.
    .PARAMETER wimIndex
        Index of the image to mount (default: 1).
    .OUTPUTS
        [string] Returns the mount directory if successful.
    .NOTES
        The WIM file can contain multiple images, indexed from 1.
    #>
    param([string]$wimImagePath, [string]$mountDir, [int]$wimIndex = 1)

    try {
        # Mount the WIM image to the specified directory
        Mount-WindowsImage -ImagePath $wimImagePath -Path $mountDir -Index $wimIndex -Verbose
        return $mountDir
    } 
    catch { Write-Error "Error mounting WIM: $_" }
}

function Add-WimImageOptComps {
    <#
    .SYNOPSIS
        Adds optional components to a mounted WIM image.
    .DESCRIPTION
        This function adds specified optional components to a mounted WIM image, which can be useful for customizing a Windows environment.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .PARAMETER OptComp
        Array of optional components to add.
    .PARAMETER wimLang
        Language of the WIM image (default: en-US).
    .NOTES
        The components are expected to be in CAB files, with language-specific files in subdirectories.
    #>
    param([string]$mountDir, [string[]]$OptComp, [string]$wimLang = 'en-US')

    foreach ($component in $OptComp) {
        # Construct paths to the component CAB and language-specific CAB
        $optCompPath = Join-Path -Path $script:adkOptPath -ChildPath "$component.cab"
        $langCabPath = Join-Path -Path $script:adkOptPath -ChildPath "$wimLang\$($component)_$($wimLang).cab"
        # Add the main component if it exists
        if (Test-Path -Path $optCompPath) {
            Add-WindowsPackage -Path $mountDir -PackagePath $optCompPath -Verbose
        }
        # Add the language-specific component if it exists
        if (Test-Path -Path $langCabPath) {
            Add-WindowsPackage -Path $mountDir -PackagePath $langCabPath -Verbose
        }
    }
}

function Add-WimImageUpdate {
    <#
    .SYNOPSIS
        Adds a cumulative update or optional component to a mounted WIM.
    .DESCRIPTION
        This function adds an update or additional package to a mounted WIM image.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .PARAMETER wimMsuPath
        Path to the MSU or CAB file to add.
    .NOTES
        The update must be provided as an MSU or CAB file.
    #>
    param([string]$mountDir, [string]$wimMsuPath)

    try {
        # Add the update or package to the WIM image
        Add-WindowsPackage -Path $mountDir -PackagePath $wimMsuPath -Verbose
    } 
    catch { Write-Error "Error adding package: $_" }
}

function Dismount-WimImage {
    <#
    .SYNOPSIS
        Dismounts and saves a WIM image.
    .DESCRIPTION
        This function dismounts a WIM image from its mount directory, saving any changes made during the mount session.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .NOTES
        Use this function after all desired modifications to the WIM image have been completed.
    #>
    param([string]$mountDir)

    try {
        # Dismount the WIM image and save changes
        Dismount-WindowsImage -Path $mountDir -Save -Verbose
    } 
    catch { Write-Error "Error dismounting WIM: $_" }
}

function Invoke-WimImageCleanup {
    <#
    .SYNOPSIS
        Performs cleanup operations on a mounted WIM image.
    .DESCRIPTION
        This function runs cleanup tasks on a mounted WIM image to reduce its size and remove unnecessary files.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .NOTES
        Cleanup can include removing superseded components and resetting the base state.
    #>
    param([string]$mountDir)

    try {
        # Perform cleanup on the mounted WIM image using DISM
        & Dism "/Image:$mountDir" '/Cleanup-Image' '/StartComponentCleanup' '/ResetBase'
    } 
    catch { Write-Error "Error during cleanup: $_" }
}

function Export-WimImage {
    <#
    .SYNOPSIS
        Exports a specific index of a WIM file.
    .DESCRIPTION
        This function exports a specified image from a WIM file, effectively creating a new WIM file containing only that image.
    .PARAMETER exportWimImage
        Path to the source WIM image to be exported.
    .PARAMETER exportWimIndex
        Index of the WIM image to export (default: 1).
    .NOTES
        This can be useful for extracting and working with a specific image from a multi-image WIM file.
    #>
    param([string]$exportWimImage, [int]$exportWimIndex = 1)

    $tempImageName = [IO.Path]::ChangeExtension($exportWimImage, "tmp")

    try {
        # Temporarily move the original WIM file
        Move-Item -Path $exportWimImage -Destination $tempImageName
        # Export the specified image from the temporary WIM to a new WIM file
        Export-WindowsImage -SourceImagePath $tempImageName -SourceIndex $exportWimIndex -DestinationImagePath $exportWimImage
        # Remove the temporary WIM if the export was successful
        if (Test-Path -Path $exportWimImage) { Remove-Item -Path $tempImageName }
    } 
    catch {
        Write-Error "Error exporting WIM: $_"
        # Restore the original WIM file in case of an error
        Move-Item -Path $tempImageName -Destination $exportWimImage
    }
}

function Split-WimImage {
    <#
    .SYNOPSIS
        Splits a WIM image into smaller SWM files.
    .DESCRIPTION
        This function splits a large WIM file into smaller SWM files, which can be useful for media with size limitations.
    .PARAMETER wimImagePath
        Path to the source WIM image to split.
    .NOTES
        The resulting SWM files will have a maximum size of 4GB by default.
    #>
    param([string]$wimImagePath)

    $wimImageDirectory = Split-Path -Path $wimImagePath -Parent
    $wimImageBaseName = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path -Path $wimImagePath -Leaf))
    $destinationWimPath = Join-Path -Path $wimImageDirectory -ChildPath "$($wimImageBaseName).swm"

    try {
        # Split the WIM image into smaller SWM files
        Split-WindowsImage -ImagePath $wimImagePath -DestinationImagePath $destinationWimPath -FileSizeMB 4000
        # Check if SWM files were created and remove the original WIM if successful
        $SWMFiles = Get-ChildItem -Path $wimImageDirectory -Filter "$($wimImageBaseName)*.swm"
        if ($SWMFiles.Count -gt 0) { Remove-Item -Path $wimImagePath -Force }
    } 
    catch { Write-Error "Error splitting WIM: $_" }
}

function Add-WimDriver {
    <#
    .SYNOPSIS
        Adds a single driver to a mounted WIM image.
    .DESCRIPTION
        This function adds a specified driver to a mounted WIM image, allowing the driver to be included in the image.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .PARAMETER driverPath
        Full path to the driver file.
    .NOTES
        The driver should be provided in a format compatible with the Add-WindowsDriver cmdlet.
    #>
    param([string]$mountDir, [string]$driverPath)

    try {
        # Navigate to the driver's directory
        $driverDir = Split-Path -Path $driverPath -Parent
        $driverFileLocation = Split-Path -Path $driverPath -Leaf
        Push-Location $driverDir
        # Add the driver to the mounted WIM image
        Add-WindowsDriver -Path $mountDir -Driver $driverFileLocation
    } 
    catch { Write-Error "Error adding driver: $_" } 
    finally { Pop-Location }
}

function Remove-WimDriversAll {
    <#
    .SYNOPSIS
        Removes all OEM*.inf drivers from a mounted WIM image.
    .DESCRIPTION
        This function removes all OEM-supplied drivers from a mounted WIM image.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .NOTES
        This is useful for stripping unnecessary drivers from an image.
    #>
    param([string]$mountDir)

    $infFolderPath = Join-Path -Path $mountDir -ChildPath "windows\inf"

    try {
        # Find all OEM drivers in the WIM image
        $oemInfFiles = Get-ChildItem -Path $infFolderPath -Filter "oem*.inf" -File
        # Remove each found driver
        foreach ($infFile in $oemInfFiles) { Remove-WindowsDriver -Path $mountDir -Driver $infFile.FullName }
    }
    catch { Write-Error "Error removing drivers: $_" }
}

function Enable-WimOptFeature {
    <#
    .SYNOPSIS
        Enables features in a mounted WIM image.
    .DESCRIPTION
        This function enables optional features in a mounted WIM image.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .PARAMETER featureName
        Name of the feature to enable.
    .PARAMETER sourcePath
        Optional source path for the feature.
    .NOTES
        The feature must be available in the mounted image or via the source path.
    #>
    param([string]$mountDir, [string]$featureName, [string]$sourcePath)

    try {
        # Enable the optional feature in the WIM image
        if ($sourcePath) { Enable-WindowsOptionalFeature -Path $mountDir -FeatureName $featureName -All -Source $sourcePath }
        else { Enable-WindowsOptionalFeature -Path $mountDir -FeatureName $featureName -All }
    }
    catch { Write-Error "Error enabling feature: $_" }
}

function Get-WimImage {
    <#
    .SYNOPSIS
        Lists details of a WIM image using DISM.exe.
    .DESCRIPTION
        This function retrieves detailed information about the images contained in a WIM file.
    .PARAMETER wimImagePath
        Full path to the WIM file.
    .OUTPUTS
        Writes the information to the host.
    .NOTES
        Useful for understanding the contents of a WIM file before modification.
    #>
    param([string]$wimImagePath)

    try {
        # Get image information from the WIM file using DISM
        $output = & dism.exe "/Get-ImageInfo /ImageFile:$wimImagePath /Format:Table"
        Write-Host $output
    }
    catch { Write-Error "Error getting WIM info: $_" }
}

function Get-WimDrivers {
    <#
    .SYNOPSIS
        Lists drivers from a mounted WIM image using DISM.exe.
    .DESCRIPTION
        This function retrieves a list of drivers from a mounted WIM image.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .OUTPUTS
        Writes the list of drivers to the host.
    .NOTES
        The output can help verify the drivers included in the WIM image.
    #>
    param([string]$mountDir)

    try {
        # Get a list of drivers from the mounted WIM image
        $output = & dism.exe "/Get-Drivers /Image:$mountDir /Format:Table"
        Write-Host $output
    }
    catch { Write-Error "Error getting drivers: $_" }
}

function Get-WimPackages {
    <#
    .SYNOPSIS
        Lists packages from a mounted WIM image using DISM.exe.
    .DESCRIPTION
        This function retrieves a list of packages from a mounted WIM image.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .OUTPUTS
        Writes the list of packages to the host.
    .NOTES
        Useful for verifying what packages are included in the WIM image.
    #>
    param([string]$mountDir)

    try {
        # Get a list of packages from the mounted WIM image
        $output = & dism.exe "/Get-Packages /Image:$mountDir /Format:Table"
        Write-Host $output
    }
    catch { Write-Error "Error getting packages: $_" }
}

function Get-WimOptFeature {
    <#
    .SYNOPSIS
        Lists optional features from a mounted WIM image using DISM.exe.
    .DESCRIPTION
        This function retrieves a list of optional features from a mounted WIM image.
    .PARAMETER mountDir
        Directory where the WIM is mounted.
    .OUTPUTS
        Writes the list of features to the host.
    .NOTES
        Useful for verifying which optional features are enabled or available in the WIM image.
    #>
    param([string]$mountDir)

    try {
        # Get a list of optional features from the mounted WIM image
        $output = & dism.exe "/Image:$mountDir /Get-Features /Format:Table"
        Write-Host $output
    }
    catch { Write-Error "Error getting features: $_" }
}

function New-CmBootWimImage {
    <#
    .SYNOPSIS
        Adds a new Boot Image to Configuration Manager.
    .DESCRIPTION
        This function creates a new boot image for Configuration Manager by copying a source WIM and registering it.
    .PARAMETER cmBootWimRoot
        Path to CM Boot Image content location.
    .PARAMETER newCmBootFolder
        New CM Boot Image folder name.
    .PARAMETER newCmBootName
        New CM Boot Image name.
    .PARAMETER sourceBootWim
        Source WIM to copy.
    .NOTES
        The boot image can then be used within Configuration Manager for various deployment tasks.
    #>
    param(
        [string]$cmBootWimRoot,
        [string]$newCmBootFolder,
        [string]$newCmBootName,
        [string]$sourceBootWim
    )

    try {
        # Create the new boot image folder if it does not exist
        $newBootImagePath = Join-Path -Path $cmBootWimRoot -ChildPath $newCmBootFolder
        if (-Not (Test-Path -Path $newBootImagePath)) { New-Item -ItemType Directory -Path $newBootImagePath | Out-Null }
        # Copy the source WIM to the new boot image folder
        $destinationWimPath = Join-Path -Path $newBootImagePath -ChildPath "$newCmBootName.wim"
        Copy-Item -Path $sourceBootWim -Destination $destinationWimPath -Force
        # Add the new boot image to Configuration Manager
        Import-CMDriverPackage -Path $destinationWimPath -Name $newCmBootName
        Write-Host "New CM Boot Image created successfully at $destinationWimPath"
    }
    catch { Write-Error "Error creating CM Boot Image: $_" }
}

function Get-CmBootWimImage {
    <#
    .SYNOPSIS
        Gets information from an active CM Boot Image.
    .DESCRIPTION
        This function retrieves detailed information about a specified Configuration Manager Boot Image.
    .PARAMETER cmBootWimInfo
        Name of the CM Boot WIM to gather information from.
    .PARAMETER infoOutput
        Folder location to store info collected.
    .OUTPUTS
        Writes the information to the specified file and the host.
    .NOTES
        The information can be useful for documentation or troubleshooting.
    #>
    param(
        [string]$cmBootWimInfo,
        [string]$infoOutput = "$env:USERPROFILE\Documents\cmBootWimInfo.txt"
    )

    try {
        # Get the CM Boot WIM information
        $infCmBootWim = Get-CmBootWim -Name $cmBootWimInfo
        # Gather detailed information about the boot image
        $data = @"
CM Boot Image Information for $($cmBootWimInfo):
--------------------------------------------
Name: $($infCmBootWim.Name)
Version: $($infCmBootWim.Version)
Size: $($infCmBootWim.Size) MB
Created On: $($infCmBootWim.CreationDate)
Last Modified: $($infCmBootWim.LastModifiedDate)
"@
        # Output the information to the specified file
        Out-File -FilePath $infoOutput -InputObject $data
        Write-Host "CM Boot Image information saved to $infoOutput"
    }
    catch { Write-Error "Error getting CM Boot WIM info: $_" }
}

function Remove-CmBootWimImage {
    <#
    .SYNOPSIS
        Removes a CM Boot Image by name and its associated files.
    .DESCRIPTION
        This function removes a specified Configuration Manager Boot Image and its associated files.
    .PARAMETER remCmBootWim
        Name of the CM Boot Image to remove.
    .NOTES
        Ensure that the Boot Image is no longer needed before removal.
    #>
    param([string]$remCmBootWim)

    try {
        # Remove the boot image from Configuration Manager
        Remove-CmBootWim -Name $remCmBootWim -Force
        # TODO: Add code to remove associated files and folders if necessary
    }
    catch { Write-Error "Error removing CM Boot WIM: $_" }
}

# Export module members
Export-ModuleMember -Function *
Initialize-DismModule
