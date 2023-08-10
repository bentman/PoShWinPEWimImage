### Overview

This PowerShell script, **Use-WimImageFunctions.ps1**, is designed to provide a set of functions that facilitate customization of Windows Preinstallation Environment (WinPE) and Windows Recovery Environment (WinRE) images. The script utilizes the DISM (Deployment Image Servicing and Management) module to perform various operations on WIM (Windows Imaging) files.

### Included Functions

The script includes the following functions:

- `Export-WimImage`: Exports a specific index of a Windows Imaging (WIM) file.
- `Split-WimImage`: Splits a Windows Imaging (WIM) image into smaller files.
- `Add-WimDriver`: Adds a single driver to a mounted WIM file.
- `Invoke-WimImageCleanup`: Performs cleanup operations on a mounted WIM file.
- `Add-WimImageOsdPackages`: Adds OSD packages to a mounted image.
- `Enable-WimOptFeature`: Enables features in a mounted WimImage by name.
- `Get-WimImage`: Lists details of a WIM Image using DISM.exe for logging.
- `Get-WimDrivers`: Lists drivers using DISM.exe from a mounted image for logging.
- `Get-WimPackage`: Lists packages using DISM.exe from a mounted image for logging.
- `Get-WimOptFeature`: Lists optional features using DISM.exe from a mounted image for logging.
- `Get-WimImageCmBoot`: Retrieves information and settings from an active CM Boot Image.
- `Remove-WimImageCmBoot`: Removes a CM Boot Image by name and its associated files.

### Usage Guidelines

1. Clone or download the repository to your local machine.
2. Open PowerShell and navigate to the repository's directory.
3. Dot-source the script to load the functions into your current PowerShell session.
   Example: `. .\Use-WimImageFunctions.ps1`
4. Utilize the loaded functions in your scripts or directly execute them in the PowerShell session.

**Note:** These functions are provided as reference tools and might require adaptations to suit your specific customization needs. Always ensure a thorough understanding of the functions before using them in a production environment.

### Requirements

- Windows operating system with PowerShell installed.
- Windows Assessment and Deployment Kit (ADK) installed.
- Windows ADK Preinstallation Environment

## Contributions

Contributions are welcome. Please open an issue or submit a pull request.

### GNU General Public License
This script is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This script is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this script.  If not, see <https://www.gnu.org/licenses/>.
