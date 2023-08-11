### Overview

This PowerShell script, **Use-WimImageFunctions.ps1**, is designed to provide a set of functions that facilitate customization of Windows Preinstallation Environment (WinPE) and Windows Recovery Environment (WinRE) images. The script utilizes the DISM (Deployment Image Servicing and Management) module to perform various operations on WIM (Windows Imaging) files.

### Setup the Environment

- Configure the optional components to be added to the WIM image.

    ```powershell
    $OsdOptComp = @(
        "WinPE-HTA",
        "WinPE-MDAC",
        ...
        "WinPE-PlatformId"
    )
    ```

- Set the location of the Assessment and Deployment Kit (ADK). Default is shown below:

    ```powershell
    $wimImageOc = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\WinPE_OCs"
    ```

### Sample of Functions

- `Invoke-WimImageCleanup`: Performs cleanup operations on a mounted WIM file.
- `Export-WimImage`: Exports a specific index of a WIM file.
- `Add-WimImageOsdPackages`: Adds OSD packages to a mounted WIM image.
- `Split-WimImage`: Splits a WIM image into smaller files.
- `Add-WimDriver`: Adds a single driver to a mounted WIM file.
- `Enable-WimOptFeature`: Enables features in a mounted WimImage by name.
- `Get-WimImage`: Lists details of a WIM Image using DISM.exe.
- `Get-WimDrivers`: Lists drivers from a mounted image (logging).
- `Get-WimPackages`: Lists packages from a mounted image (logging).
- `Get-WimOptFeature`: Lists optional features from a mounted image (logging).

### Sample of Advanced Functions
- `Get-WimImageCmBoot`: Gets information and settings from an active CM Boot Image.

### Usage Guidelines

1. Clone or download the repository to your local machine.
2. Open PowerShell and navigate to the repository's directory.
3. Dot-source the script to load the functions into your current PowerShell session.

   Example: `. .\Use-WimImageFunctions.ps1`
5. Utilize the loaded functions in your scripts or directly execute them in the PowerShell session.

**Note:** These functions are provided as reference tools and might require adaptations to suit your specific customization needs. 
Always ensure a thorough understanding of the functions before using them in a production environment.

## Examples

Tested functions provided will contain a `# USAGE:...` comment basic usage instructions. 
For instance:
- To cleanup a mounted WIM:
    ```powershell
    Invoke-WimImageCleanup -mountDir "path_to_mounted_WIM"
    ```
- To add OSD packages:
    ```powershell
    Add-WimImageOsdPackages -mountDir "path_to_mounted_WIM" -OsdOptComp $OsdOptComp -wimImageLang 'en-us'
    ```

### Requirements
- Windows operating system with PowerShell installed.
- Windows Assessment and Deployment Kit (ADK) installed.
- Windows ADK Preinstallation Environment
- Some Functions require `ConfigurationManager.psd1` - if you do not know what that is, don't use them! :->

## Contributions
Contributions are welcome. Please open an issue or submit a pull request.

### GNU General Public License
This script is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this script.  If not, see <https://www.gnu.org/licenses/>.
