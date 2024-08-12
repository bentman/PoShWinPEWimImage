### NEW! Added functions to module!
`.\WimImageTools\WimImageTools.psm1`

### Overview

This PowerShell script, **Use-WimImageFunctions.ps1**, is designed to provide a set of functions that facilitate customization of Windows Preinstallation Environment (WinPE) and Windows Recovery Environment (WinRE) images. The script utilizes the DISM (Deployment Image Servicing and Management) module to perform various operations on WIM (Windows Imaging) files.

### Setup the Environment

- Configure the optional components to be added to the WIM image.

    ```powershell
    $OsdOptComps = @(
        "WinPE-HTA",
        "WinPE-MDAC",
        ...
        "WinPE-PlatformId"
    )
    ```

- Set the architecture &location of the Assessment and Deployment Kit (ADK). Defaults shown below:

    ```powershell
    $adkArch = "amd64"
    $adkRoot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
    ```

### Sample of Functions

- `Add-WimDriver`: Adds a single driver to a mounted WIM file.
- `Add-WimDrivers`: Adds multiple drivers to a mounted WIM file.
- `Add-WimImageOsdOptComps`: Adds ADK OptionalComponents to a mounted WIM image.
- `Add-WimImageUpdate`: Add Updates by *.msu or Packages by *.cab to a mounted WimImage
- `Invoke-WimImageCleanup`: Performs cleanup operations on a mounted WIM file.
- `Export-WimImage`: Exports a specific index of a WIM file.
- `Enable-WimOptFeature`: Enables Optional Features to a mounted WimImage by name.
- `Get-WimImage`: Lists details of a WIM Image using DISM.exe (logging).
- `Get-WimDrivers`: Lists drivers from a mounted image using DISM.exe (logging).
- `Get-WimPackages`: Lists packages from a mounted image using DISM.exe (logging).
- `Get-WimOptFeature`: Lists optional features from a mounted image using DISM.exe (logging).

### Sample of Advanced Functions (requires `ConfigurationManager.psd1` loaded from Site PSDrive)
- `Get-CmBootWimImage`: Get information and settings from an active CM Boot Image.
- `Remove-CmBootWimImage`: Remove a CM Boot Image by name and its associated files.

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
    Add-WimImageOsdOptComps -mountDir "path_to_mounted_WIM" -OsdOptComp $OsdOptComp -wimImageLang 'en-us'
    ```

### Requirements
- Windows operating system with PowerShell installed.
- Windows Assessment and Deployment Kit (ADK) installed.
- Windows ADK Preinstallation Environment
- Some Functions require `ConfigurationManager.psd1` - if you do not know what that is, don't use them! :->

## Contributions
Contributions are welcome. Please open an issue or submit a pull request if you have any suggestions, questions, or would like to contribute to the project.

### GNU General Public License
This script is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This script is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this script.  If not, see <https://www.gnu.org/licenses/>.
