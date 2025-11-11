# Automate-WorkstationSetup

This project is designed to drastically simplify and standardize the provisioning of Windows workstations. Leveraging PowerShell, it automatically installs a predefined set of crucial development tools, productivity applications, and VSCode extensions. By using a central `setup-config.yaml` file, it ensures consistency across multiple machines, reduces manual setup time, and minimizes configuration drift.

## Table of Contents

*   [Features](#features)
*   [Prerequisites](#prerequisites)
*   [Usage](#usage)
    *   [1. Configuration (`setup-config.yaml`)](#1-configuration-setup-configyaml)
    *   [2. Running the Script](#2-running-the-script)
*   [Configuration Details](#configuration-details)
    *   [PowerShell Modules (`psModules`)](#powershell-modules-psmodules)
    *   [WinGet Applications (`WinGetApps`)](#winget-applications-wingetapps)
    *   [VSCode Extensions (`VSCodeExtensions`)](#vscode-extensions-vscodeextensions)

---

## Features

*   **Automated PowerShell Module Installation:** Installs required PowerShell modules from PSGallery.
*   **WinGet Application Deployment:** Automatically installs applications specified by their WinGet IDs.
*   **VSCode Extension Setup:** Installs a predefined list of Visual Studio Code extensions.
*   **YAML-based Configuration:** All installations are driven by a simple and readable `setup-config.yaml` file.

## Prerequisites

*   **Windows 10/11:** The script is designed for Windows operating systems.
*   **PowerShell 5.1 or PowerShell Core (pwsh):** The script uses modern PowerShell features.
*   **WinGet (Windows Package Manager):** Ensure WinGet is installed and up-to-date on your system. It's usually pre-installed on modern Windows versions or available via the Microsoft Store.
*   **Visual Studio Code:** While the script can install extensions, VSCode itself needs to be present for the `code --install-extension` command to work. The `setup-config.yaml` includes an entry for `Microsoft.VisualStudioCode` under `WinGetApps`.

## Usage
### 1. Configuration (`setup-config.yaml`)

Edit the `setup-config.yaml` file to specify the PowerShell modules, WinGet applications, and VSCode extensions you want to install.

### 2. Running the Script

1.  **Download/Clone:** Get the `Automate-WorkstationSetup.ps1` script and the `setup-config.yaml` file into the same directory.
2.  **Open PowerShell:** Launch a PowerShell console (e.g., PowerShell 5.1 or PowerShell Core).
3.  **Navigate to Script Directory:** Use `cd` to go to the directory where you saved the files.
    ```powershell
    cd C:\Path\To\Your\SetupProject
    ```
4.  **Check Execution Policy (if needed):** If you encounter an error running the script, your PowerShell Execution Policy might be too restrictive. You can temporarily allow local script execution:
    ```powershell
    Set-ExecutionPolicy Unrestricted -Scope CurrentUser -Force
    ```
    *(You can revert this later with `Set-ExecutionPolicy Restricted -Scope CurrentUser`)*
5.  **Execute the Script:**
    ```powershell
    .\Automate-WorkstationSetup.ps1
    ```
    The script will output its progress, indicating successful installations or any failures.

## Configuration Details
### PowerShell Modules (`psModules`)

A simple list of PowerShell module names to be installed from the PowerShell Gallery. The script will automatically install the `powershell-yaml` module if it's not present and ensure `PSGallery` is trusted.

**Example:**
```yaml
psModules:
  - Microsoft.WinGet.Client
```

### WinGet Applications (`WinGetApps`)

A list of objects, each representing an application to be installed via WinGet. Each object must have a name (for logging) and an id (the WinGet package ID).
To find WinGet package IDs, you can use winget search "App Name" in your terminal or browse the WinGet Community Repository.


**Example:**
```yaml
WinGetApps:
  - name: GitHub Desktop
    id: GitHub.GitHubDesktop
  - name: Docker Desktop
    id: Docker.DockerDesktop
```

### VSCode Extensions (`VSCodeExtensions`)

A simple list of Visual Studio Code extension IDs. The script will use code --install-extension --force to install or update each specified extension.
To find VSCode extension IDs, search for the extension in the VSCode Marketplace (the ID is typically in the URL, e.g., publisher.extension-name).

**Example:**
```yaml
VSCodeExtensions:
  - esbenp.prettier-vscode
  - ms-python.python
  - hashicorp.terraform
```
