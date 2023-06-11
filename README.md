# WinPE/WinRE Customization Scripts

This repository contains a collection of PowerShell scripts for customizing Windows Preinstallation Environment (WinPE) and Windows Recovery Environment (WinRE) images. These scripts leverage the DISM (Deployment Image Servicing and Management) module to perform various operations on WIM (Windows Imaging) files.

## Scripts

- **Use-WimImageFunctions.ps1**: This script provides functions for working with WIM files using DISM cmdlets. It includes functions to export, split, add drivers, perform cleanup, and add OSD packages to WIM images.

## Usage

1. Clone or download the repository to your local machine.
2. Open PowerShell and navigate to the repository's directory.
3. Dot-source the required scripts to load the functions into your current PowerShell session.
   Example: `. .\Use-WimImageFunctions.ps1`
4. You can now use the functions provided by the scripts in your own scripts or execute them directly in the PowerShell session.

Please note that these scripts are intended to be used as a reference and may require modifications to suit your specific customization needs. Make sure to review and understand the scripts before using them in a production environment.

## Requirements

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


