
### WORK-IN-PROGRESS ###

############################## PARAMETER ###############################
[CmdletBinding()]
param (
    # [path\file] Path to the source WIM (default is '%ADK%\...\amd64\en-us\winpe.wim')
    [Parameter(Mandatory=$false)] [string]$sourceWim, 
    # [unc path] Root directory for the boot image (default is '\\$cmSiteServer\d$\OSD')
    [Parameter(Mandatory=$false)] [string]$bootImageRoot, 
    # [folder name] Name of the boot image folder (default is the OS version of the source WIM)
    [Parameter(Mandatory=$false)] [string]$bootImageFolderName, 
    # [name] Name of the new boot image in CM (default is the OS version and build of the source WIM)
    [Parameter(Mandatory=$false)] [string]$bootImageName 
)

############################## DOTSOURCE ###############################
. .\Use-WimImageFunctions.ps1

############################## VARIABLES ###############################
$sourceWim = "C:\Path\to\image.wim"        # Source path of the WIM image for export
$sourceWimInxex = 1                              # Index of the WIM image ()
$wimImagePath = "C:\Path\to\image.wim"     # Path to the WIM image
$mountDir = "C:\Mount"                     # Directory where the image is mounted
$driverPath = "C:\Path\to\driver.inf"      # Path to the driver to be added
$wimImageOc = "C:\Path\to\osd_packages"    # Path to the OSD packages
$wimImageLang = "en-US"                    # Language of the OSD packages

############################### GENERATED ###############################


############################### EXECUTION ###############################

