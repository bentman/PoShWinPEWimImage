# Wim Image Tools

### Overview

This PowerShell script, **Use-WimImageFunctions.ps1**, provides a comprehensive set of functions for customizing Windows Preinstallation Environment (WinPE) and Windows Recovery Environment (WinRE) images using the DISM module. It is designed to be dot-sourced and integrated into larger automation workflows.

### Setup

Configure the optional components and ADK settings (default values shown):

```powershell
$OsdOptComps = @(
    "WinPE-HTA",
    "WinPE-MDAC",
    "WinPE-Scripting",
    "WinPE-WMI",
    "WinPE-NetFX",
    "WinPE-PowerShell",
    "WinPE-PlatformId"
)

$adkArch = "amd64"
$adkRoot = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"
```

### Key Functions

- `Mount-Wim`: Mounts a Wim image for servicing.
- `Dismount-Wim`: Dismounts a mounted Wim image and saves changes.
- `Add-WimDriver`: Adds a single driver to a mounted Wim image.
- `Add-WimDrivers`: Adds multiple drivers to a mounted Wim image recursively.
- `Add-WimUpdate`: Adds updates (.msu) or packages (.cab) to a mounted Wim image.
- `Invoke-WimCleanup`: Performs cleanup on a mounted Wim image.
- `Export-WimImage`: Exports a specific index from a Wim image.
- `Split-Wim`: Splits a Wim image into smaller .swm files.
- `Enable-WimOptionalFeature`: Enables optional features in a mounted Wim image.
- `Disable-WimOptionalFeature`: Disables optional features in a mounted Wim image.
- `Get-WimImage`: Retrieves details of a Wim image using DISM.
- `Remove-WimDriversAll`: Removes all OEM drivers from a mounted Wim image.

### Advanced Functions (requires `ConfigurationManager.psd1`)

- `Get-CmBootWimImage`: Retrieves information from an active CM Boot Image.
- `Remove-CmBootWimImage`: Removes a CM Boot Image and its associated files.

### Usage

1. Clone the repository to your local machine.
2. Open PowerShell and navigate to the script directory.
3. Dot-source the script to load the functions:
    ```powershell
    . .\Use-WimImageFunctions.ps1
    ```

4. Use the loaded functions in your scripts or execute them directly in the PowerShell session.

### Examples

- Clean up a mounted Wim image:
    ```powershell
    Invoke-WimCleanup -mountDir "C:\mount"
    ```

- Add optional components:
    ```powershell
    Add-WimOptionalComponents -mountDir "C:\mount" -optComp $OsdOptComps -wimLang 'en-US'
    ```

- Export a specific index from a Wim image:
    ```powershell
    Export-WimImage -sourceWim "C:\path\to\image.wim" -destWim "C:\path\to\exported.wim" -index 1
    ```

### Requirements

- PowerShell 5.1 or later
- Windows Assessment and Deployment Kit (ADK)
- Administrative privileges

### Contributions

Contributions are welcome! Please open an issue or submit a pull request if you have suggestions or enhancements.

### License

This project is licensed under the GNU General Public License v3. See [GNU GPL v3](https://www.gnu.org/licenses/gpl-3.0.html) for details.
This script is distributed without any warranty; use at your own risk.
