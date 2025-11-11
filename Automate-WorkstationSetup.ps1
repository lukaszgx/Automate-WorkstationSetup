# This script automates the setup of PowerShell modules, WinGet applications,
# and VSCode extensions based on a 'setup-config.yaml' file.

# --------------------------------------------------------------------------
# Prerequisite Setup
# --------------------------------------------------------------------------

# Ensure PSGallery is trusted for module installations
$gallery = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
if (-not $gallery) {
    Write-Host "Registering PSGallery repository..." -ForegroundColor Yellow
    Register-PSRepository -Name 'PSGallery' -SourceLocation 'https://www.powershellgallery.com/api/v2' -InstallationPolicy Trusted -Force
} elseif ($gallery.InstallationPolicy -ne 'Trusted') {
    Write-Host "Trusting PSGallery repository..." -ForegroundColor Yellow
    Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted -Force
} else {
    Write-Host "PSGallery repository is already trusted." -ForegroundColor Green
}

# Ensure powershell-yaml module is available for parsing YAML configuration
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Write-Host "Installing powershell-yaml module..." -ForegroundColor Yellow
    try {
        Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber
        Write-Host "powershell-yaml installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to install powershell-yaml: $_" -ForegroundColor Red
        exit 1 # Exit if critical module can't be installed
    }
} else {
    Write-Host "powershell-yaml module is already installed." -ForegroundColor Green
}

Import-Module powershell-yaml

# --------------------------------------------------------------------------
# Load Configuration
# --------------------------------------------------------------------------

$yamlFilePath = ".\setup-config.yaml"

if (-not (Test-Path $yamlFilePath)) {
    Write-Host "ERROR: Configuration file not found: $yamlFilePath" -ForegroundColor Red
    Write-Host "Please create a 'setup-config.yaml' in the same directory as this script." -ForegroundColor Red
    exit 1
}

Write-Host "`nLoading configuration from '$yamlFilePath'..." -ForegroundColor White
try {
    $config = ConvertFrom-Yaml (Get-Content $yamlFilePath -Raw)
    Write-Host "Configuration loaded successfully." -ForegroundColor Green
} catch {
    Write-Host "ERROR: Failed to parse YAML configuration: $_" -ForegroundColor Red
    exit 1
}

$PSRequiredModules = $config.psModules
$WinGetApps = $config.WinGetApps
$VSCodeExtensions = $config.VSCodeExtensions

# --------------------------------------------------------------------------
# Install PowerShell Modules
# --------------------------------------------------------------------------

Write-Host "`n--- Installing PowerShell Modules ---" -ForegroundColor Cyan
foreach ($module in $PSRequiredModules) {
    if (Get-Module -ListAvailable -Name $module) {
        Write-Host "  '$module' is already installed." -ForegroundColor Green
    } else {
        Write-Host "  '$module' not found. Installing..." -ForegroundColor Yellow
        try {
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
            Write-Host "  '$module' installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "  Failed to install '$module': $_" -ForegroundColor Red
        }
    }
}

# --------------------------------------------------------------------------
# Install WinGet Applications
# --------------------------------------------------------------------------

Write-Host "`n--- Installing WinGet Applications ---" -ForegroundColor Cyan
foreach ($appObject in $WinGetApps) {
    $appName = $appObject.name
    $appId = $appObject.id

    Write-Host "Processing WinGet app: '$appName' (ID: $appId)" -ForegroundColor White

    # Check if the application is already installed using its ID
    $appCheck = Get-WinGetPackage -Id $appId -ErrorAction SilentlyContinue

    if ($appCheck) {
        Write-Host "  '$appName' ($appId) is already installed." -ForegroundColor Green
    } else {
        Write-Host "  '$appName' ($appId) not found. Installing..." -ForegroundColor Yellow
        try {
            Install-WinGetPackage -id $appId -Confirm:$false # Add -Confirm:$false for full automation
            Write-Host "  '$appName' ($appId) installed successfully." -ForegroundColor Green
        } catch {
            Write-Host "  Failed to install '$appName' ($appId): $_" -ForegroundColor Red
        }
    }
}

# --------------------------------------------------------------------------
# Install VSCode Extensions
# --------------------------------------------------------------------------

Write-Host "`n--- Installing VSCode Extensions ---" -ForegroundColor Cyan
foreach ($extension in $VSCodeExtensions) {
    $extensionName = $extension.name
    $extensionId = $extension.id

    Write-Host "Processing VSCode extension: '$extensionName'" -ForegroundColor White

    # Assuming 'code' is in the system PATH
    code --install-extension "$extensionId" --force

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Successfully installed/updated: '$extensionName'" -ForegroundColor Green
    } else {
        Write-Warning "  Failed or encountered issues installing: '$extensionName'. Exit code: $LASTEXITCODE"
    }
}

Write-Host "`n--- All installation tasks complete! ---" -ForegroundColor Green
Write-Host "Please restart PowerShell and/or VSCode for changes to take full effect." -ForegroundColor Yellow