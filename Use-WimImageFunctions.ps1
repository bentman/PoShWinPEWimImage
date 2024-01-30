############################## DECLARATION #############################
$scriptName = (Get-PSCallStack).InvocationInfo.MyCommand.Name
$scriptVer = "2.2" # Optimization
Write-Host "`nDot-Sourcing functions in $scriptName v$scriptVer..."

############################## VERIFICATION ############################
# Check if DISM module is available and load it if needed
$moduleAvailable = Get-Module -Name DISM -ListAvailable 
# Set return value to false initially
$moduleLoaded = $false
# Trap any errors
trap {
    Write-Error $_
    break
}
# Load module if not already available
if (-not $moduleAvailable) {
    # Import the module 
    try {
        Import-Module -Name DISM -ErrorAction Stop
        $moduleLoaded = $true
    }
    catch {
        Write-Error "Error importing DISM module: $_"
    }
}
else {
    # Module is already available
    Write-Host "DISM module already loaded"
    $moduleLoaded = $true
}
# Return boolean value indicating if module loaded
return $moduleLoaded

# Check if ADK is installed and valid
# ADK root path (allow configuring if default not correct)
$adkRoot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment" 
# ADK architecture (default to amd64)
$adkArch = "amd64"
# Try to get ADK optional components path
try {
    $adkOptPath = Get-ChildItem -Path $adkRoot -Filter "$adkArch\WinPE_OCs" -ErrorAction Stop
}
catch {
    Write-Error "Error getting ADK optional components path: $_"
    return $false
}
# Check if optional components exist
if (-not (Test-Path -Path $adkOptPath)) {
    Write-Error "ADK not found at $adkRoot" 
    return $false
}
# If no errors, ADK is valid
Write-Output "ADK available at: $adkRoot"
return $true

# Edit array of optional components to be added to the WimImage when using Add-WimImageOptComps function
$OptionalComponents = @( # These are the most common blend of "traditional" and "modern" OC's for CM/Intune
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
foreach ($comp in $OptionalComponents) { Write-Host "    $comp" }
Write-Host "" # Empty line for logging readability

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

function Split-WimImage {
    # Function to split a Windows Image (WIM) image into *.swm files <4000mb
    [CmdletBinding()]
    param(
        # Path to the source WimImage to split
        [Parameter(Mandatory = $true)] [string]$wimImagePath  
    )
    $wimImageDirectory = Split-Path -Path $wimImagePath -Parent
    $wimImageBaseName = Split-Path -Path $wimImagePath -Leaf
    $wimImageBaseName = [System.IO.Path]::GetFileNameWithoutExtension($wimImageBaseName)
    $destinationWimPath = Join-Path -Path $wimImageDirectory -ChildPath "$($wimImageBaseName).swm"
    try {
        Write-Host "`nSplitting the WimImage into smaller files, each less than 4GB..."
        Split-WindowsImage `
            -ImagePath $wimImagePath `
            -DestinationImagePath $destinationWimPath `
            -FileSizeMB 4000
        $SWMFiles = Get-ChildItem -Path $wimImageDirectory -Filter "$($wimImageBaseName)*.swm"
        if ($SWMFiles.Count -gt 0) {
            Write-Host "`nDeleting the original WimImage..."
            Remove-Item -Path $wimImagePath -Force
        }
        else {
            throw "`nNo *.swm files were created & original WimImage will not be deleted."
        }
    }
    catch {
        Write-Host "`nAn error occurred while splitting the image:"
        Write-Error $_.Exception.Message
    }
}

function Add-WimDriver {
    # Function to add a single driver to a mounted Windows Image (WIM) file
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # Full Path and File Name ($_.FullName) to the driver to be added
        [Parameter(Mandatory = $true)] [string]$driverPath
    )
    try {
        $driverDir = Split-Path -Path $driverPath -Parent
        $driverFileLocation = Split-Path -Path $driverPath -Leaf
        Write-Host "`nChanging directory to $driverDir..."
        Push-Location $driverDir
        Write-Host "`nAdding driver $driverFileLocation to the mounted WimImage at $mountDir..."
        Add-WindowsDriver -Path $mountDir -Driver $driverFileLocation
    }
    catch {
        Write-Host "`nAn error occurred while adding the driver: $_"
        Write-Error $_.Exception.Message
    }
    finally {
        Write-Host "`nReturning to the original directory..."
        Pop-Location
    }
}

function Remove-WimDriversAll {
    # Remove all OEM*.inf drivers from a mounted WimImage
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir
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
            Write-Host "`nRemoving driver $($infFile.Name) from the mounted WimImage at $mountDir..."
            # Remove the driver using the specific INF file name
            Remove-WindowsDriver -Path $mountDir -Driver $infFile.FullName
        }
    }
    catch {
        Write-Host "`nAn error occurred while removing the drivers:"
        Write-Error $_.Exception.Message
    }
}

function Enable-WimOptFeature {
    # Function to enable features in a mounted WimImage by name
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # Name of the feature to enable
        [Parameter(Mandatory = $true)] [string]$featureName,
        # Optional path Source of the feature (aka NetFX3)
        [Parameter(Mandatory = $false)] [string]$sourcePath
    )
    try {
        if ($sourcePath) {
            Write-Host "`nEnabling feature $featureName in the mounted WimImage at $mountDir with source path $sourcePath..."
            Enable-WindowsOptionalFeature -Path $mountDir -FeatureName $featureName -All -Source $sourcePath
        }
        else {
            Write-Host "`nEnabling feature $featureName in the mounted WimImage at $mountDir..."
            Enable-WindowsOptionalFeature -Path $mountDir -FeatureName $featureName -All
        }
    }
    catch {
        Write-Host "`nAn error occurred while enabling the feature:"
        Write-Error $_.Exception.Message
    }
}

function Get-WimImage {
    # Function to list details of a WimImage using DISM.exe (for logging)
    [CmdletBinding()]
    param(
        # Full Path and File Name ($_.FullName) of WimImage to get info
        [Parameter(Mandatory = $true)] [string]$wimImagePath
    )
    try {
        Write-Host "`nRetrieving WimImage details for: $wimImagePath"
        $output = & dism.exe "/Get-ImageInfo /ImageFile:$wimImagePath /Format:Table"
        Write-Host $output
    }
    catch {
        Write-Host "`nFailed to retrieve WimImage details for $wimImagePath"
        Write-Error $_.Exception.Message
    }
}

function Get-WimDrivers {
    # Function to list drivers using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir
    )
    try {
        Write-Host "`nRetrieving drivers from mounted WimImage at $mountDir..."
        $output = & dism.exe "/Get-Drivers /Image:$mountDir /Format:Table"
        Write-Host $output
    }
    catch {
        Write-Host "`nAn error occurred while retrieving drivers from $mountDir."
        Write-Error $_.Exception.Message
    }
}

function Get-WimPackages {
    # Function to list packages using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param (
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir
    )
    try {
        Write-Host "`nRetrieving packages from mounted WimImage at $mountDir..."
        $output = & dism.exe "/Get-Packages /Image:$mountDir /Format:Table"
        Write-Host $output
    }
    catch {
        Write-Host "`nAn error occurred while retrieving packages from $mountDir."
        Write-Error $_.Exception.Message
    }
}

function Get-WimOptFeature {
    # Function to list optional features using DISM.exe from a mounted image (for logging)
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir   # Path to the mounted image directory
    )
    try {
        Write-Host "`nRetrieving optional features from mounted WimImage at $mountDir..."
        $output = & dism.exe "/Image:$mountDir /Get-Features /Format:Table"
        Write-Host $output
    }
    catch {
        Write-Host "`nAn error occurred while retrieving optional features from $mountDir."
        Write-Error $_.Exception.Message
    }
}

function New-CmBootWimImage {
    # Function to add CM Boot Image
    # WARNING: Requires running from CM Site Server PSDrive location & UNC path access to Site Content
    # USAGE: New-CmBootWimImage -CmBootWimRoot $cmBootWimRoot -newCmBootFolder $newCmBootFolder -newCmBootName $newCmBootName -sourceBootWim $sourceBootWim 
    [CmdletBinding()]
    param(
        # Path to CM Boot Image content location
        [Parameter(Mandatory = $true)] [string]$cmBootWimRoot,
        # New CM Boot Image Folder Name (defaults to OS-Build "major.minor")
        [Parameter(Mandatory = $false)] [string]$newCmBootFolder,
        # New CM Boot Image name (defaults to OS-Build "major.minor.wim")
        [Parameter(Mandatory = $false)] [string]$newCmBootName,
        # Source WIM to copy (defaults to ADK WinPE.wim)
        [Parameter(Mandatory = $false)] [string]$sourceBootWim
    )
    # Get the CM Boot Image object to be removed
    try {
    }
    catch {
        Write-Host "`nAn error occurred ."
        Write-Error $_.Exception.Message
    }
    Push-Location -Path $env:SystemDrive
    try {
    }
    catch {
        Write-Host "`nAn error occurred ."
        Write-Error $_.Exception.Message
    }
    Pop-Location
}

function Get-CmBootWimImage {
    # Function to get information and settings from an active CM Boot Image
    # WARNING: Requires running from CM Site Server PSDrive location & UNC path access to Site Content
    # USAGE: Get-CmBootWimImage -cmBootWimInfo $cmBootWimInfo -infoOutput $infoOutput
    [CmdletBinding()]
    param(
        # Name of the CM Boot Wim to gather information from
        [Parameter(Mandatory = $true)] [string]$cmBootWimInfo,
        # Folder location to store info collected (Defaults to "$env:USERPROFILE\Documemts\INFO-<BootWimName>.txt")
        [Parameter(Mandatory = $false)] [string]$infoOutput = "$env:USERPROFILE\Documents\cmBootWimInfo.txt"
    )
    try {
        $infCmBootWim = Get-CmBootWim -Name $cmBootWimInfo
        $data = "Getting CM boot image information from $cmBootWimInfo..." + `
            "`nPriority:                          $($infCmBootWim.Priority)" + `
            "`nDescription:                       $($infCmBootWim.Description)"
        "`nDeployFromPxeDistributionPoint:    $($infCmBootWim.DeployFromPxeDistributionPoint)" + `
            "`nEnableLabShell (aka 'F8'):         $($infCmBootWim.EnableLabShell)" + `
            "`nScratchSpace (mostly moot):        $($infCmBootWim.ScratchSpace)" + `
            "`nOptionalComponents:                $($infCmBootWim.OptionalComponents)" + `
            "`nReferencedDrivers:                 $($infCmBootWim.ReferencedDrivers)" + `
            ""
        Push-Location -Path $env:SystemDrive
        Write-Host $data
        if ($null -eq $infoOutput) {
            Out-File -FilePath "$env:USERPROFILE\Documemts\INFO-$cmBootWimInfo.txt -InputObject $data"
        }
        else { Out-File -FilePath "$infoOutput\INFO-$cmBootWimInfo.txt" -InputObject $data }
        Pop-Location
    }
    catch {
        Write-Host "`nAn error occurred while getting CM boot image information from $cmBootWimInfo."
        Write-Error $_.Exception.Message
        Pop-Location
    }
}

function Remove-CmBootWimImage {
    # Function to remove a CM Boot Image by name and its associated files
    # WARNING: Requires running from CM Site Server PSDrive location & UNC path access to Site Content
    # USAGE: Remove-CmBootWimImage -remCmBootWim $-remCmBootWim
    [CmdletBinding()]
    param(
        # Name of the CM Boot Image to remove (required)
        [Parameter(Mandatory = $true)] [string]$remCmBootWim
    )
    # Get the CM Boot Image object to be removed
    $removeCmBootWim = Get-CmBootWim -Name $remCmBootWim
    try {
        Write-Host "`nRemoving CM boot image $remCmBootWim..."
        Remove-CmBootWim -Name $removeCmBootWim -Force
    }
    catch {
        Write-Host "`nAn error occurred while removing CM boot image $remCmBootWim."
        Write-Error $_.Exception.Message
    }
    # Remove the associated files and folders
    Push-Location -Path $env:SystemDrive
    try {
        $removeCmBootWimPath = (Get-Item -Path $removeCmBootWim.ImagePath).Parent
        if ($removeCmBootWim.ImagePath) { Remove-Item -Path $removeCmBootWim.ImagePath }
        if ($removeCmBootWim.PkgSourcePath) { Remove-Item -Path $removeCmBootWim.PkgSourcePath }
        if (-not (Get-ChildItem -Path $removeCmBootWimPath.FullName)) {
            Remove-Item -Path $removeCmBootWimPath.FullName -Force
        }
    }
    catch {
        Write-Host "`nAn error occurred while removing CM boot files $remCmBootWim."
        Write-Error $_.Exception.Message
    }
    Pop-Location
}

############# Convenient Redundant Functions #############

function Expand-WimImage {
    # Apply WimImage by Index to path
    # USAGE: Expand-WimImage -wimImagePath $wimImagePath -wimIndex $wimIndex -wimApplyPath $wimApplyPath
    [CmdletBinding()]
    param(
        # Full Path and File Name ($_.FullName) of WimImage to be applied
        [Parameter(Mandatory = $true)] [string]$wimImagePath,
        # Index of WimImage to apply
        [Parameter(Mandatory = $true)] [int]$wimIndex,
        # Path to apply WimImage
        [Parameter(Mandatory = $true)] [string]$wimApplyPath
    )
    try {
        Write-Host "`nExpanding the WimImage at $wimImagePath to $wimApplyPath using index: $wimIndex..."
        Expand-WindowsImage -ImagePath $wimImagePath -wimApplyPath $wimApplyPath -wimIndex $wimIndex
    }
    catch {
        Write-Host "`nAn error occurred while expanding the WimImage:"
        Write-Error $_.Exception.Message
    }
}

function Save-WimImage {
    # Saves a WimImage. Saves incremental WimImage to an alternate path if provided.
    # USAGE: Save-WimImage -mountDir $mountDir -destinationWimPath $destinationWimPath
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage being saved
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # Full Folder Path and File Name to save incrimental WimImage
        [Parameter(Mandatory = $false)] [string]$destinationWimPath
    )
    try {
        if ($PSBoundParameters.ContainsKey('DestinationImagePath')) {
            Write-Host "`nSaving the WimImage from $mountDir to $destinationWimPath..."
            Save-WindowsImage -Path $mountDir -DestinationImagePath $destinationWimPath
        }
        else {
            Write-Host "`nSaving the WimImage from $mountDir..."
            Save-WindowsImage -Path $mountDir
        }
    }
    catch {
        Write-Host "`nAn error occurred while saving the WimImage:"
        Write-Error $_.Exception.Message
    }
}

function Add-WimDrivers {
    # Add multiple recursed drivers to a mounted WimImage
    # USAGE: Add-WimDrivers -mountDir $mountDir -driversPath $driversPath
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # Folder Path to drivers being applied recursively
        [Parameter(Mandatory = $true)] [string]$driversPath
    )
    try {
        Write-Host "`nAdding drivers from $driversPath to the mounted WimImage at $mountDir..."
        Add-WindowsDriver -Path $mountDir -Driver $driversPath -Recurse
    }
    catch {
        Write-Host "`nAn error occurred while adding the drivers:"
        Write-Error $_.Exception.Message
    }
}

function Export-WimDriver {
    # Export drivers from a mounted WimImage
    #USAGE: Export-WimDriver -mountDir $mountDir -drvDestinationPath $drvDestinationPath
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # Folder Path to export drivers from mounted WimImage
        [Parameter(Mandatory = $true)] [string]$drvDestinationPath
    )
    try {
        if (-not (Test-Path -Path $drvDestinationPath -PathType Any)) { New-Item -Path $drvDestinationPath -ItemType Directory }
        Write-Host "`nExporting drivers from the mounted WimImage at $mountDir to $drvDestinationPath..."
        Export-WindowsDriver -Path $mountDir -Destination $drvDestinationPath
    }
    catch {
        Write-Host "`nAn error occurred while exporting the drivers:"
        Write-Error $_.Exception.Message
    }
}

function Remove-WimDriver {
    # Remove driver by specifying the OEM*.inf file name from a mounted WimImage
    #USAGE: Remove-WimDriver -mountDir $mountDir -driverFileName $driverFileName
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        # Filename of driver to remove (aka "oem2.inf")
        [Parameter(Mandatory = $true)] [string]$driverFileName
    )
    try {
        Write-Host "`nRemoving driver $driverFileName from the mounted WimImage at $mountDir..."
        Remove-WindowsDriver -Path $mountDir -Driver $mountDir\Windows\INF\$driverFileName
    }
    catch {
        Write-Host "`nAn error occurred while removing the driver:"
        Write-Error $_.Exception.Message
    }
}

function Remove-WimPackage {
    # Remove Optional Components by *.cab or updates by *.msu from a mounted WimImage by name
    # USAGE: Remove-WimPackage -mountDir $mountDir -wimPkgName $wimPkgName
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        [Parameter(Mandatory = $true)] [string]$wimPkgName
    )
    try {
        Write-Host "`nRemoving package $wimPkgName from the mounted WimImage at $mountDir..."
        Remove-WindowsPackage -Path $mountDir -PackageName $wimPkgName
    }
    catch {
        Write-Host "`nAn error occurred while removing the package:"
        Write-Error $_.Exception.Message
    }
}

function Disable-WimOptFeature {
    # Disable Features in mounted WimImage by name
    # USAGE: Disable-WimOptFeature -mountDir $mountDir -wimFeatureName $wimFeatureName
    [CmdletBinding()]
    param(
        # Folder Path to mounted WimImage
        [Parameter(Mandatory = $true)] [string]$mountDir,
        [Parameter(Mandatory = $true)] [string]$wimFeatureName
    )
    try {
        Write-Host "`nDisabling feature '$wimFeatureName' in mounted WimImage at '$mountDir'..."
        Disable-WindowsOptionalFeature -Path $mountDir -FeatureName $wimFeatureName
    }
    catch {
        Write-Host "`nAn error occurred while disabling the feature:"
        Write-Error $_.Exception.Message
    }
}
############################## COMPLETION ##############################
Write-Host "`nSuccessful dot-sourcing of ..."
Write-Host "    Script Name = $scriptName"
Write-Host "    Script Version = $scriptVer"

<########################## VARIABLE EXAMPLES ##########################
$wimImagePath = "C:\path\to\image.wim"
$mountDir = "C:\mount"
$optComp = @("WinPE-HTA", "WinPE-MDAC", "WinPE-Scripting")
$wimLang = "en-US"
$pkgPath = "C:\path\to\package.cab"
$wimIndex = 1
$exportWimImage = "C:\path\to\exported.wim"
$exportWimIndex = 1
$driverPath = "C:\path\to\driver.inf"
$featureName = "NetFx3"
$sourcePath = "C:\path\to\feature\source"
$cmBootWimRoot = "C:\path\to\cmboot"
$newCmBootFolder = "NewCmBoot"
$newCmBootName = "NewCmBoot.wim"
$sourceBootWim = "SourceBoot.wim"
$cmBootWimInfo = "NewCmBoot.wim"
$infoOutput = "C:\info"
#######################################################################>

<##########################  USAGE EXAMPLES  ###########################

Mount-WimImage -wimImagePath $wimImagePath -mountDir $mountDir -wimIndex $wimIndex
# -wimImagePath    :Full Path and File Name of the WimImage to be mounted.
# -mountDir        :Folder where the WimImage will be mounted for servicing.
# -wimIndex           :Index of the WimImage to be mounted.
###################################################################################

Add-WimPackage -mountDir $mountDir -packagePath $packagePath
# -mountDir        :Folder Path to the mounted WimImage.
# -PackagePath     :Full Path and File Name of the .msu or .cab package to be added.
###################################################################################

Dismount-WimImage -mountDir $mountDir
# -mountDir        :Folder Path to the mounted WimImage.
###################################################################################

Invoke-WimImageCleanup -mountDir $mountDir
# Invoke-WimImageCleanup
# -mountDir        :Path to the mounted WIM directory.
###################################################################################

Export-WimImage -exportWimImage $exportWimImage -exportWimIndex $exportWimIndex
# -exportWimImage  :Path to the exported WimImage.
# -exportWimIndex  :Index of the WimImage to export.
###################################################################################

Split-WimImage -wimImagePath $wimImagePath
# Split-WimImage
# -wimImagePath    :Path to the source WimImage to split.
###################################################################################

Add-WimDriver -mountDir $mountDir -driverPath $driverPath
# -mountDir        :Folder Path to mounted WimImage.
# -driverPath      :Full Path and File Name of the driver to be added.
###################################################################################

Remove-WimDriversAll -mountDir $mountDir
# -mountDir        :Folder Path to mounted WimImage.
###################################################################################

Enable-WimOptFeature -mountDir $mountDir -featureName $featureName -sourcePath $sourcePath
# -mountDir        :Folder Path to mounted WimImage.
# -featureName     :Name of the feature to enable.
# -sourcePath      :Path to feature Source file(s) - Optional.
###################################################################################

Get-WimImage -wimImagePath $wimImagePath
# -wimImagePath    :Full Path and File Name of WimImage to get info.
###################################################################################

Get-WimDrivers -mountDir $mountDir
# -mountDir        :Folder Path to mounted WimImage.
###################################################################################

Get-WimPackages -mountDir $mountDir
# -mountDir        :Folder Path to mounted WimImage.
###################################################################################

Get-WimOptFeature -mountDir $mountDir
# Get-WimOptFeature
# -mountDir        :Folder Path to mounted WimImage.
###################################################################################

New-CmBootWimImage -CmBootWimRoot $cmBootWimRoot -newCmBootFolder $newCmBootFolder -newCmBootName $newCmBootName -sourceBootWim $sourceBootWim
# -CmBootWimRoot   :Path to CM Boot Image content location.
# -newCmBootFolder :New CM Boot Image Folder Name.
# -newCmBootName   :New CM Boot Image name.
# -sourceBootWim   :Source WIM to copy.
###################################################################################

Get-CmBootWimImage -cmBootWimInfo $cmBootWimInfo -infoOutput $infoOutput
# -cmBootWimInfo   :Name of the CM Boot Wim to gather information from.
# -infoOutput      :Folder location to store gathered information.
###################################################################################

Remove-CmBootWimImage -remCmBootWim $remCmBootWim
# -remCmBootWim    :Name of the CM Boot Image to remove.
##################################################################################>
