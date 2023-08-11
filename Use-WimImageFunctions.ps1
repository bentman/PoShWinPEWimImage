# Edit array of optional components to be added to the WimImage when using Add-WimImageOsdPackages function
$OsdOptComp = @(
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
# Edit location of Assessment and Deployment Kit (if different than default)
$wimImageOc = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"

# Check if DISM module is available and loaded
$moduleAvailable = Get-Module -Name DISM -ListAvailable
if (-not $moduleAvailable) {
    try { # If module not available, import it
        Write-Host "`nImporting DISM module..."
        Import-Module DISM -ErrorAction Stop
    } catch {
        Write-Host "`nFailed to import DISM module:"
        Write-Error $_.Exception.Message
        return
    }
} else {
    Write-Host "`nDISM module found."
}

function Invoke-WimImageCleanup { # Function to perform cleanup operations on a mounted Windows Imaging (WIM) file
    # USAGE: Invoke-WimImageCleanup -mountDir $mountDir 
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir  # Path to the mounted WIM directory
    )
    try {
        Write-Host "`nPerforming cleanup operations on mounted WIM file at $mountDir..."
        & Dism "/Image:$mountDir" '/Cleanup-Image' '/StartComponentCleanup' '/ResetBase'
    } catch {
        Write-Host "`nAn error occurred while performing cleanup operations."
        Write-Error $_.Exception.Message
    }
}
    
function Export-WimImage { # Function to export a specific index of a Windows Imaging (WIM) file
    # USAGE: Export-WimImage -sourceImagePath $wimImagePath -sourceIndex 1
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$sourceImagePath,  # Path to the source WIM file
        [Parameter(Mandatory=$true)][int]$sourceIndex          # Index of the image to export
    )
    # Rename the source WIM file to a temporary name
    $tempImageName = [IO.Path]::ChangeExtension($sourceImagePath, "tmp")
    try {
        Write-Host "`nRenaming the source WIM file to a temporary file..."
        Move-Item -Path $sourceImagePath -Destination $tempImageName
        # Export the WIM image with the specified index
        Write-Host "`nExecuting the WIM file export operation..."
        Export-WindowsImage -SourceImagePath $tempImageName -SourceIndex $sourceIndex -DestinationImagePath $sourceImagePath
        # Check if export was successful and delete the temporary file
        if (Test-Path -Path $sourceImagePath) {
            Write-Host "`nExport successful, deleting the temporary file..."
            Remove-Item -Path $tempImageName
        } else {
            throw "`nExport operation failed. Exported WIM file does not exist. Reverting to original WIM file name."
        }
    } catch {
        Write-Host "`nAn error occurred while exporting the image index: $sourceIndex "
        Write-Error $_.Exception.Message
        Write-Host "`nReverting to the original WIM file name..."
        Move-Item -Path $tempImageName -Destination $sourceImagePath
    }
}

function Add-WimImageOsdPackages { # Function to add OSD packages to a mounted WIM image. 
    # USAGE: Add-WimImageOsdPackages -mountDir $mountDir -OsdOptComp $OsdOptComp -wimImageLang 'en-us'
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$wimImageLang,
        [Parameter(Mandatory=$false)][string[]]$OsdOptComp
    )
    if (-not $wimImageOc) { Write-Host "ADK WinPE_OCs not found in default location"; break }
    try { foreach ($component in $OsdOptComp) {
            $componentCab = "$component.cab"
            $packagePath = Join-Path -Path $wimImageOc -ChildPath $componentCab
            if (Test-Path -Path $packagePath) {
                Write-Host "`nAdding $component to WimImage..."
                Add-WindowsPackage -Path $mountDir -PackagePath $packagePath
            } else {Write-Host "`nCannot find $component at $packagePath"}
            $languageCab = "$wimImageLang\$component" + "_$($wimImageLang).cab"
            $languagePackPath = Join-Path -Path $wimImageOc -ChildPath $languageCab
            if (Test-Path -Path $languagePackPath) {
                Write-Host "`nAdding $wimImageLang language pack for $component to WimImage..."
                Add-WindowsPackage -Path $mountDir -PackagePath $languagePackPath
            } else {Write-Host "`nCannot find $wimImageLang language pack for $component at $languagePackPath"}
        }
    } catch {
        Write-Error "`nAn error occurred while adding OSD packages."
        Write-Error $_.Exception.Message
    }
}

function Split-WimImage { # Function to split a Windows Imaging (WIM) image into smaller files
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$wimImagePath  # Path to the source WIM file
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
        } else {
            throw "`nNo *.swm files were created & original WIM file will not be deleted."
        }
    } catch {
        Write-Host "`nAn error occurred while splitting the image:"
        Write-Error $_.Exception.Message
    }
}

function Add-WimDriver { # Function to add a single driver to a mounted Windows Imaging (WIM) file
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,      # Path to the mounted WIM directory
        [Parameter(Mandatory=$true)][string]$driverPath      # Path to the driver to be added
    )
    try {
        $driverDir = Split-Path -Path $driverPath -Parent
        $driverFileName = Split-Path -Path $driverPath -Leaf
        Write-Host "`nChanging directory to $driverDir..."
        Push-Location $driverDir
        Write-Host "`nAdding driver $driverFileName to the mounted WIM file at $mountDir..."
        Add-WindowsDriver -Path $mountDir -Driver $driverFileName
    } catch {
        Write-Host "`nAn error occurred while adding the driver: $_"
        Write-Error $_.Exception.Message
    } finally {
        Write-Host "`nReturning to the original directory..."
        Pop-Location
    }
}

function Enable-WimOptFeature { # Function to enable features in a mounted WimImage by name
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,       # Path to the mounted WIM directory
        [Parameter(Mandatory=$true)][string]$FeatureName,    # Name of the feature to enable
        [Parameter(Mandatory=$false)][string]$sourcePath     # Optional source path for the feature
    )
    try {
        if ($sourcePath) {
            Write-Host "`nEnabling feature $FeatureName in the mounted WIM file at $mountDir with source path $sourcePath..."
            Enable-WindowsOptionalFeature -Path $mountDir -FeatureName $FeatureName -All -Source $sourcePath
        } else {
            Write-Host "`nEnabling feature $FeatureName in the mounted WIM file at $mountDir..."
            Enable-WindowsOptionalFeature -Path $mountDir -FeatureName $FeatureName -All
        }
    } catch {
        Write-Host "`nAn error occurred while enabling the feature:"
        Write-Error $_.Exception.Message
    }
}

function Get-WimImage { # Function to list details of a WIM Image using DISM.exe (for logging)
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$wimImagePath    # Path to the WIM image
    )
    try {
        Write-Host "`nRetrieving WIM image details for: $wimImagePath"
        $output = & dism.exe /Get-ImageInfo /ImageFile:$wimImagePath /Format:Table
        Write-Host $output
    } catch {
        Write-Host "`nFailed to retrieve WIM image details for $wimImagePath"
        Write-Error $_.Exception.Message
    }
}

function Get-WimDrivers { # Function to list drivers using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir    # Path to the mounted image directory
    )
    try {
        Write-Host "`nRetrieving drivers from mounted WIM file at $mountDir..."
        $output = & dism.exe /Get-Drivers /Image:$mountDir /Format:Table
        Write-Host $output
    } catch {
        Write-Host "`nAn error occurred while retrieving drivers from $mountDir."
        Write-Error $_.Exception.Message
    }
}

function Get-WimPackages { # Function to list packages using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$mountDir   # Path to the mounted image directory
    )
    try {
        Write-Host "`nRetrieving packages from mounted WIM file at $mountDir..."
        $output = & dism.exe /Get-Packages /Image:$mountDir /Format:Table
        Write-Host $output
    } catch {
        Write-Host "`nAn error occurred while retrieving packages from $mountDir."
        Write-Error $_.Exception.Message
    }
}

function Get-WimOptFeature { # Function to list optional features using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir   # Path to the mounted image directory
    )
    try {
        Write-Host "`nRetrieving optional features from mounted WIM file at $mountDir..."
        $output = & dism.exe /Image:$mountDir /Get-Features /Format:Table
        Write-Host $output
    } catch {
        Write-Host "`nAn error occurred while retrieving optional features from $mountDir."
        Write-Error $_.Exception.Message
    }
}

function Get-WimImageCmBoot { # Function to get information and settings from an active CM Boot Image
    # WARNING: Requires running from CM Site Server PSDrive location & UNC path access to Site Content
    # USAGE: Get-WimImageCmBoot -infoCmBootImage $infoCmBootImage -infoOutput $infoOutput
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [string]$infoCmBootImage,
        [Parameter(Mandatory=$false)] [string]$infoOutput = "$env:USERPROFILE\Documents\infoCmBootImage.txt"
    )
    try {
        $infCmBootImage = Get-CMBootImage -Name $infoCmBootImage
        $data = "Getting CM boot image information from $infoCmBootImage..." + `
        "`nDescription:                       $($infCmBootImage.Description)"
        "ReferencedDrivers:                 $($infCmBootImage.ReferencedDrivers)" + `
        "DeployFromPxeDistributionPoint:    $($infCmBootImage.DeployFromPxeDistributionPoint)" + `
        "EnableLabShell (aka 'F8'):         $($infCmBootImage.EnableLabShell)" + `
        "Priority:                          $($infCmBootImage.Priority)" + `
        "ScratchSpace:                      $($infCmBootImage.ScratchSpace)" + `
        "OptionalComponents:                $($infCmBootImage.OptionalComponents)" + `
        ""
        Push-Location -Path $env:SystemDrive
        Write-Host $data
        Out-File -FilePath "$infoOutput\INFO-$infoCmBootImage.txt" -InputObject $data
        Pop-Location
    } catch {
        Write-Host "`nAn error occurred while getting CM boot image information from $infoCmBootImage."
        Write-Error $_.Exception.Message
        Pop-Location
    }
}

function Remove-WimImageCmBoot { # Function to remove a CM Boot Image by name and its associated files
    # WARNING: Requires running from CM Site Server PSDrive location & UNC path access to Site Content
    # USAGE:
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$remCmBootImage   # Name of the CM Boot Image to remove
    )
    # Get the CM Boot Image object to be removed
    $removeCmBootImage = Get-CMBootImage -Name $remCmBootImage
    try {
        Write-Host "`nRemoving CM boot image $remCmBootImage..."
        Remove-CMBootImage -Name $removeCmBootImage -Force
    } catch {
        Write-Host "`nAn error occurred while removing CM boot image $remCmBootImage."
        Write-Error $_.Exception.Message
    }
    # Remove the associated files and folders
    Push-Location -Path $env:SystemDrive
    try {
        $removeCmBootImagePathFolder = (Get-Item -Path $removeCmBootImage.ImagePath).Parent
        if ($removeCmBootImage.ImagePath) {Remove-Item -Path $removeCmBootImage.ImagePath}
        if ($removeCmBootImage.PkgSourcePath) {Remove-Item -Path $removeCmBootImage.PkgSourcePath}
        if (-not (Get-ChildItem -Path $removeCmBootImagePathFolder.FullName)) {
            Remove-Item -Path $removeCmBootImagePathFolder.FullName -Force}
    } catch {
        Write-Host "`nAn error occurred while removing CM boot files $remCmBootImage."
        Write-Error $_.Exception.Message
    }
Pop-Location
}

############# Convenient Redundant Functions #############

function Mount-WimImage { # Mount WimImage for customization
    # USAGE: Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir -Index 1
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$wimImagePath,
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][int]$Index
    )
    try {
        Write-Host "`nMounting the WIM image at $wimImagePath to $mountDir using index $Index..."
        Mount-WindowsImage -ImagePath $wimImagePath -Path $mountDir -Index $Index
    } catch {
        Write-Host "`nAn error occurred while mounting the WIM image:"
        Write-Error $_.Exception.Message
    }
}

function Dismount-WimImage { # Dismount WimImage & Save
    # USAGE: Dismount-WimImage -mountDir $mountDir
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir
    )
    try {
        Write-Host "`nDismounting and saving the mounted WIM image at $mountDir..."
        Dismount-WindowsImage -Path $mountDir -Save
    } catch {
        Write-Host "`nAn error occurred while dismounting and saving the WIM image:"
        Write-Error $_.Exception.Message
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
    } catch {
        Write-Host "`nAn error occurred while expanding the WIM image:"
        Write-Error $_.Exception.Message
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
    } catch {
        Write-Host "`nAn error occurred while saving the WIM image:"
        Write-Error $_.Exception.Message
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
    } catch {
        Write-Host "`nAn error occurred while adding the drivers:"
        Write-Error $_.Exception.Message
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
    } catch {
        Write-Host "`nAn error occurred while exporting the drivers:"
        Write-Error $_.Exception.Message
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
        Remove-WindowsDriver -Path $mountDir -Driver $driverFileName
    } catch {
        Write-Host "`nAn error occurred while removing the driver:"
        Write-Error $_.Exception.Message
    }
}

function Remove-WimDrivers { # Remove all OEM*.inf drivers from a mounted WimImage
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir
    )
    # Define the path where the INF files are located in the mounted image
    $infFolderPath = Join-Path -Path $mountDir -ChildPath "windows\inf"
        try {
        # Get all oem*.inf files in the windows\inf directory
        $oemInfFiles = Get-ChildItem -Path $infFolderPath -Filter "oem*.inf" -File
        if ($oemInfFiles.Count -eq 0) {
            Write-Host "No OEM*.inf files found."
            return
        }
        foreach ($infFile in $oemInfFiles) {
            Write-Host "`nRemoving driver $($infFile.Name) from the mounted WIM file at $mountDir..."
            # Remove the driver using the specific INF file name
            Remove-WindowsDriver -Path $mountDir -Driver $infFile.FullName
        }
    } catch {
        Write-Host "`nAn error occurred while removing the driver:"
        Write-Error $_.Exception.Message
    }
}

function Add-WimPackage { # Add Optional Components by *.cab or updates by *.msu to a mounted WimImage
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$mountDir,
        [Parameter(Mandatory=$true)][string]$PackagePath
    )
    # Add-WimPackage -mountDir $mountDir -PackagePath $PackagePath
    try {
        Write-Host "`nAdding package $PackagePath to the mounted WIM file at $mountDir..."
        Add-WindowsPackage -Path $mountDir -PackagePath $PackagePath
    } catch {
        Write-Host "`nAn error occurred while adding the package:"
        Write-Error $_.Exception.Message
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
    } catch {
        Write-Host "`nAn error occurred while removing the package:"
        Write-Error $_.Exception.Message
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
    } catch {
        Write-Host "`nAn error occurred while disabling the feature:"
        Write-Error $_.Exception.Message
    }
}

<#
.VARIABLE EXAMPLES
# Variables for copying to scripts
$wimImagePath = "C:\Path\to\image.wim"     # Path to the WIM image
$sourceImagePath = "C:\Path\to\image.wim"  # Source path of the WIM image for export
$sourceIndex = 1                           # Index of the WIM image to export
$mountDir = "C:\Mount"                     # Directory where the image is mounted
$driverPath = "C:\Path\to\driver.inf"      # Path to the driver to be added
$wimImageOc = "C:\Path\to\osd_packages"    # Path to the OSD packages
$wimImageLang = "en-US"                    # Language of the OSD packages
#>

<#
# Variables used in functions
$moduleAvailable = $null   # Boolean variable to check if DISM module is available and loaded

# Get-WimImage variables
$wimImagePath = "C:\Path\to\image.wim"     # Path to the WIM image

# Export-WimImage variables
$sourceImagePath = "C:\Path\to\image.wim"  # Source path of the WIM image for export
$sourceIndex = 1                           # Index of the WIM image to export

# Split-WimImage variables
$wimImageDirectory = $null                 # Directory of the WIM image
$wimImageBaseName = $null                  # Base name of the WIM image
$destinationImagePath = $null              # Path of the destination split WIM image

# Add-WimDriver variables
$mountDir = $null                          # Directory where the image is mounted
$driverPath = $null                        # Path to the driver to be added

# Get-WimDriver variables
$mountDir = $null                          # Directory where the image is mounted

# Get-WimPackage variables
$mountDir = $null                          # Directory where the image is mounted

# Get-WimOptFeature variables
$mountDir = $null                          # Directory where the image is mounted

# Invoke-WimImageCleanup variables
$mountDir = $null                          # Directory where the image is mounted

# Add-WimImageOsdPackages variables
$mountDir = $null                          # Directory where the image is mounted
$wimImageOc = $null                        # Path to the OSD packages
$wimImageLang = $null                      # Language of the OSD packages
$OsdOptionalComponents = $null             # Array of optional components

# Try-Catch variables
$tempImageName = $null                     # Temporary name for the image during export operation
$componentCab = $null                      # Name of the component CAB file
$languageCab = $null                       # Name of the language pack CAB file
$packagePath = $null                       # Path to the component CAB file
$languagePackPath = $null                  # Path to the language pack CAB file
$SWMFiles = $null                          # Array of SWM files created during split operation
#>

<# 
function Get-WimImageCmBoot { # Function to get information and settings from an active CM Boot Image
# WARNING: Requires running from CM Site Server PSDrive location & UNC path access to Site Content
# USAGE: Get-WimImageCmBoot -infoCmBootImage $infoCmBootImage -infoOutput $infoOutput
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$infoCmBootImage,   # Name of the CM Boot Image
        [Parameter(Mandatory=$false)][string]$infoOutput        # Local storage or UNC path for output
    )
    try {
        Write-Host "`nGetting CM boot image information from $infoCmBootImage..."
        $infCmBootImage = Get-CMBootImage -Name $infoCmBootImage
        Write-Host "`nReferencedDrivers by list..."
        $infCmBootImage.ReferencedDrivers # drivers
        Write-Host "`nDeployFromPxeDistributionPoint [true/false]..."
        $infCmBootImage.DeployFromPxeDistributionPoint # pxe t/f
        Write-Host "`nEnableLabShell (aka 'F8') [true/false]..."
        $infCmBootImage.EnableLabShell # f8 t/f 
        Write-Host "`nPriority by list [high/med/low]..."
        $infCmBootImage.Priority # high/med/low
        Write-Host "`nScratchSpace [32-2048]..."
        $infCmBootImage.ScratchSpace # 512 (kinda moot these days, but Dell was using 2048)
        Write-Host "`nOptionalComponents [array]..."
        $infCmBootImage.OptionalComponents # array
        Write-Host "`nDescription [array]..."
        $infCmBootImage.Description # plain text
        Push-Location -Path $env:SystemDrive
        if ($null -eq $infoOutput) {
            Out-File -FilePath "$env:USERPROFILE\Documents\infoCmBootImage.txt" -InputObject $infCmBootImage
        } else {
            Out-File -FilePath "$infoOutput\INFO-$infoCmBootImage.txt" -InputObject $infCmBootImage
        }
        Pop-Location
    } catch {
        Write-Host "`nAn error occurred while getting CM boot image information from $infoCmBootImage."
        Write-Error $_.Exception.Message
        Pop-Location
    }
}#>
