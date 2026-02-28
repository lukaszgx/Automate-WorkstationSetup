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
    *   [Packages (`Packages`)](#packages-packages)
    *   [VSCode Extensions (`VSCodeExtensions`)](#vscode-extensions-vscodeextensions)
    *   [Registry Settings (`RegistrySettings`)](#registry-settings-registrysettings)
    *   [PowerShell Configuration (`PowerShell`)](#powershell-configuration-powershell)

---

## Features

*   **Interactive Section Menu:** On startup, the script presents a numbered menu letting you choose which sections to run — individually or all at once.
*   **Selective Execution via Parameter:** Pass `-Sections` on the command line to skip the menu and run specific sections directly (useful for scripting/automation).
*   **Automated PowerShell Module Installation:** Installs required PowerShell modules from PSGallery.
*   **Multi-source Package Deployment:** Installs applications via **WinGet** or **npm** from a single unified `Packages` list.
*   **VSCode Extension Setup:** Installs a predefined list of Visual Studio Code extensions.
*   **Registry Configuration:** Applies custom registry settings from the configuration file.
*   **PowerShell Profile & Theme Setup:** Creates a PowerShell profile and configures it, including setting up an Oh My Posh theme.
*   **YAML-based Configuration:** All installations are driven by a simple and readable `setup-config.yaml` file.
*   **Idempotent:** The script can be run multiple times without causing issues. It checks if modules, apps, and extensions are already installed.
*   **Dry Run Mode:** Supports a `-DryRun` switch to preview changes without applying them.
*   **Automated Logging:** Creates a timestamped log file for each execution, useful for troubleshooting.

## Prerequisites

*   **Windows 10/11:** The script is designed for Windows operating systems.
*   **Administrator Privileges:** The script must be run in an elevated PowerShell session.
*   **PowerShell 5.1 or PowerShell Core (pwsh):** The script uses modern PowerShell features.
*   **WinGet (Windows Package Manager):** Required for `source: winget` packages. Pre-installed on modern Windows, or available via the Microsoft Store.
*   **Node.js / npm** *(optional):* Required only for `source: npm` packages. The script will skip npm packages gracefully if npm is not found in PATH.

## Usage

### 1. Configuration (`setup-config.yaml`)

Edit the `setup-config.yaml` file to specify the PowerShell modules, packages, VSCode extensions, registry settings, and PowerShell profile options you want to apply.

### 2. Running the Script

1.  **Download/Clone:** Get the `Automate-WorkstationSetup.ps1` script and the `setup-config.yaml` file into the same directory.
2.  **Open PowerShell as Administrator:** Launch a PowerShell console with administrator privileges.
3.  **Navigate to the script directory:**
    ```powershell
    cd C:\Path\To\Your\SetupProject
    ```
4.  **Execute the script:**
    ```powershell
    Set-ExecutionPolicy Unrestricted -Scope Process
    .\Automate-WorkstationSetup.ps1
    ```
    When run without parameters, an interactive menu is displayed:
    ```
    ========================================
        Workstation Setup - Section Menu
    ========================================
    Select sections to run (comma-separated):

      [1] PS Modules
      [2] Packages (winget/npm)
      [3] VSCode Extensions
      [4] Registry Settings
      [5] PowerShell Profile
      [A] All sections

    Enter selection:
    ```
    Enter one or more numbers separated by commas (e.g. `1,3`) or `A` to run everything.

**Run specific sections non-interactively (`-Sections`):**
```powershell
.\Automate-WorkstationSetup.ps1 -Sections Packages,VSCode
```

Valid section names: `PsModules`, `Packages`, `VSCode`, `Registry`, `PsProfile`, `All`

**Dry Run Mode:**
Preview what the script *would* do without making any changes:
```powershell
.\Automate-WorkstationSetup.ps1 -DryRun
```

Both flags can be combined:
```powershell
.\Automate-WorkstationSetup.ps1 -DryRun -Sections Registry,PsProfile
```

## Logging

The script automatically creates a `logs` directory alongside the script. For each execution, a timestamped log file is created (e.g., `Workstation-Setup-2026-01-15_10-30-00.log`) containing a full transcript of the script's output.

## Configuration Details

### PowerShell Modules (`psModules`)

A simple list of PowerShell module names to install from the PowerShell Gallery. The script will automatically install the `powershell-yaml` module if it's not present and ensure `PSGallery` is trusted.

**Example:**
```yaml
psModules:
  - Terminal-Icons
```

---

### Packages (`Packages`)

A list of packages to install from multiple sources. Each entry requires a `name` and `source`. Additional fields depend on the source.

#### WinGet packages

Requires `id` — the WinGet package ID. Find IDs with `winget search "App Name"` or browse the [WinGet Community Repository](https://github.com/microsoft/winget-pkgs).

```yaml
Packages:
  - name: Git
    id: Git.Git
    source: winget

  - name: Docker Desktop
    id: Docker.DockerDesktop
    source: winget
```

#### npm packages

Requires `package` — the npm package name (installed globally). npm must be available in PATH.

```yaml
Packages:
  - name: Gemini CLI
    package: "@google/gemini-cli"
    source: npm
```

---

### VSCode Extensions (`VSCodeExtensions`)

A list of Visual Studio Code extensions to install. Each entry requires a `name` and an `id`. Find extension IDs in the VSCode Marketplace (format: `publisher.extension-name`).

**Example:**
```yaml
VSCodeExtensions:
  - name: Prettier - Code Formatter
    id: esbenp.prettier-vscode
  - name: HashiCorp Terraform
    id: hashicorp.terraform
```

---

### Registry Settings (`RegistrySettings`)

A list of registry values to set. Each entry requires a `description`, `path`, `key`, and `value`.

**Example:**
```yaml
RegistrySettings:
  - description: Display full path in the title bar - Enable
    path: HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced
    key: ShowFullPath
    value: 1
```

---

### PowerShell Configuration (`PowerShell`)

Configures the PowerShell profile with Oh My Posh. Specify a theme file path relative to the script directory. The theme file is copied to the profile directory and the profile is updated to initialise Oh My Posh on startup.

**Example:**
```yaml
PowerShell:
  OhMyPosh:
    theme: 'assets/honukai.omp.json'
```

The script will:
1. Copy the theme file to the PowerShell profile directory
2. Append the Oh My Posh initialisation and `Terminal-Icons` import to `$PROFILE` (only if not already present)
