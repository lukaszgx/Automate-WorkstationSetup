# Automate-WorkstationSetup

This project is designed to drastically simplify and standardize the provisioning of Windows workstations. Leveraging PowerShell, it automatically installs a predefined set of crucial development tools, productivity applications, and VSCode extensions. By using a central `setup-config.yaml` file, it ensures consistency across multiple machines, reduces manual setup time, and minimizes configuration drift.

## Table of Contents

*   [Features](#features)
*   [Prerequisites](#prerequisites)
*   [Usage](#usage)
    *   [1. Configuration (`setup-config.yaml`)](#1-configuration-setup-configyaml)
    *   [2. Running the Script](#2-running-the-script)
*   [Logging](#logging)
*   [Configuration Details](#configuration-details)
    *   [PowerShell Modules (`psModules`)](#powershell-modules-psmodules)
    *   [WinGet Applications (`WinGetApps`)](#winget-applications-wingetapps)
    *   [VSCode Extensions (`VSCodeExtensions`)](#vscode-extensions-vscodeextensions)
    *   [Registry Settings (`RegistrySettings`)](#registry-settings-registrysettings)

---

## Features

*   **Automated PowerShell Module Installation:** Installs required PowerShell modules from PSGallery.
*   **WinGet Application Deployment:** Automatically installs applications specified by their WinGet IDs.
*   **VSCode Extension Setup:** Installs a predefined list of Visual Studio Code extensions.
*   **Registry Configuration:** Applies custom registry settings from the configuration file.
*   **YAML-based Configuration:** All installations are driven by a simple and readable `setup-config.yaml` file.
*   **Idempotent:** The script can be run multiple times without causing issues. It checks if modules, apps, and extensions are already installed.
*   **Automated Logging:** The script creates a log file for each execution, which is useful for troubleshooting.

## Prerequisites

*   **Windows 10/11:** The script is designed for Windows operating systems.
*   **Administrator Privileges:** The script must be run in an elevated PowerShell session (as an administrator).
*   **PowerShell 5.1 or PowerShell Core (pwsh):** The script uses modern PowerShell features.
*   **WinGet (Windows Package Manager):** Ensure WinGet is installed and up-to-date on your system. It's usually pre-installed on modern Windows versions or available via the Microsoft Store.
*   **Visual Studio Code:** While the script can install extensions, VSCode itself needs to be present for the `code --install-extension` command to work. The `setup-config.yaml` includes an entry for `Microsoft.VisualStudioCode` under `WinGetApps`.

## Usage
### 1. Configuration (`setup-config.yaml`)

Edit the `setup-config.yaml` file to specify the PowerShell modules, WinGet applications, VSCode extensions, and registry settings you want to apply.

### 2. Running the Script

1.  **Download/Clone:** Get the `Automate-WorkstationSetup.ps1` script and the `setup-config.yaml` file into the same directory.
2.  **Open PowerShell as Administrator:** Launch a PowerShell console with administrator privileges.
3.  **Navigate to Script Directory:** Use `cd` to go to the directory where you saved the files.
    ```powershell
    cd C:\Path\To\Your\SetupProject
    ```
4.  **Execute the Script:**
    ```powershell
    Set-ExecutionPolicy Unrestricted -Scope Process
    .\Automate-WorkstationSetup.ps1
    ```
    The script will output its progress, indicating successful installations or any failures.

## Logging

The script automatically creates a `logs` directory in the same directory as the script. For each execution, a timestamped log file is created (e.g., `Workstation-Setup-2023-10-27_10-30-00.log`). This log file contains a complete transcript of the script's output, which is useful for troubleshooting and reviewing the installation process.

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
To find WinGet package IDs, you can use `winget search "App Name"` in your terminal or browse the [WinGet Community Repository](https://github.com/microsoft/winget-pkgs).

**Example:**
```yaml
WinGetApps:
  - name: GitHub Desktop
    id: GitHub.GitHubDesktop
  - name: Docker Desktop
    id: Docker.DockerDesktop
```

### VSCode Extensions (`VSCodeExtensions`)

A list of objects, each representing a Visual Studio Code extension. Each object must have a `name` and an `id`.
To find VSCode extension IDs, search for the extension in the VSCode Marketplace (the ID is typically in the URL, e.g., `publisher.extension-name`).

**Example:**
```yaml
VSCodeExtensions:
  - name: Prettier - Code formatter
    id: esbenp.prettier-vscode
  - name: Python
    id: ms-python.python
  - name: HashiCorp Terraform
    id: hashicorp.terraform
```

### Registry Settings (`RegistrySettings`)

A list of objects, each representing a registry setting to be applied. Each object must have a `description`, `path`, `key`, and `value`.

**Example:**
```yaml
RegistrySettings:
  - description: "Enable full path in title bar"
    path: "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    key: "ShowFullPath"
    value: 1
```
