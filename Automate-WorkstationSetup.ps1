param(
    [switch]$DryRun
)

# Function to check for administrator privileges
Function Test-Administrator {
    Write-Host "Checking for administrator privileges..." -ForegroundColor White
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Administrator privileges are required. Please run the script as an administrator." -ForegroundColor Red
        exit 1
    }
    Write-Host "Administrator privileges confirmed." -ForegroundColor Green
}

# Function to initialize prerequisites
Function Initialize-Prerequisites {
    Write-Host "`n--- Initializing Prerequisites ---" -ForegroundColor Cyan

    # Ensure PSGallery is trusted
    $gallery = Get-PSRepository -Name 'PSGallery' -ErrorAction SilentlyContinue
    if (-not $gallery) {
        if ($DryRun) {
            Write-Host "[DryRun] Would register PSGallery repository." -ForegroundColor Magenta
        } else {
            Write-Host "Registering PSGallery repository..." -ForegroundColor Yellow
            Register-PSRepository -Name 'PSGallery' -SourceLocation 'https://www.powershellgallery.com/api/v2' -InstallationPolicy Trusted -Force
        }
    }
    elseif ($gallery.InstallationPolicy -ne 'Trusted') {
        if ($DryRun) {
            Write-Host "[DryRun] Would trust PSGallery repository." -ForegroundColor Magenta
        } else {
            Write-Host "Trusting PSGallery repository..." -ForegroundColor Yellow
            Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
        }
    }
    else {
        Write-Host "PSGallery repository is already trusted." -ForegroundColor Green
    }

    # Ensure powershell-yaml module is available
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        if ($DryRun) {
            Write-Host "[DryRun] Would install powershell-yaml module." -ForegroundColor Magenta
            Write-Host "CRITICAL: Cannot proceed with DryRun configuration check because 'powershell-yaml' is missing." -ForegroundColor Red
            exit 1
        } else {
            Write-Host "Installing powershell-yaml module..." -ForegroundColor Yellow
            try {
                Install-Module powershell-yaml -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                Write-Host "powershell-yaml installed successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to install powershell-yaml: $_" -ForegroundColor Red
                exit 1
            }
        }
    }
    else {
        Write-Host "powershell-yaml module is already installed." -ForegroundColor Green
    }
    Import-Module powershell-yaml
}

# Function to load configuration
Function Load-Configuration {
    param(
        [Parameter(Mandatory=$true)]
        [string]$YamlFilePath
    )

    Write-Host "`n--- Loading Configuration ---" -ForegroundColor Cyan

    if (-not (Test-Path $YamlFilePath)) {
        Write-Host "ERROR: Configuration file not found: $YamlFilePath" -ForegroundColor Red
        Write-Host "Please create a 'setup-config.yaml' in the same directory as this script." -ForegroundColor Red
        exit 1
    }

    Write-Host "Loading configuration from '$YamlFilePath'..." -ForegroundColor White
    try {
        $config = ConvertFrom-Yaml (Get-Content $YamlFilePath -Raw)
        Write-Host "Configuration loaded successfully." -ForegroundColor Green
        return $config
    }
    catch {
        Write-Host "ERROR: Failed to parse YAML configuration: $_" -ForegroundColor Red
        exit 1
    }
}

# Function to install PowerShell modules
Function Install-PsModules {
    param(
        [System.Collections.IEnumerable]$PSRequiredModules
    )

    Write-Host "`n--- Installing PowerShell Modules ---" -ForegroundColor Cyan
    foreach ($module in $PSRequiredModules) {
        if (Get-Module -ListAvailable -Name $module) {
            Write-Host "  '$module' is already installed." -ForegroundColor Green
        }
        else {
            if ($DryRun) {
                Write-Host "  [DryRun] Would install module '$module'." -ForegroundColor Magenta
            } else {
                Write-Host "  '$module' not found. Installing..." -ForegroundColor Yellow
                try {
                    Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                    Write-Host "  '$module' installed successfully." -ForegroundColor Green
                }
                catch {
                    Write-Host "  Failed to install '$module': $_" -ForegroundColor Red
                }
            }
        }
    }
}

# Function to install WinGet apps
Function Install-WinGetApps {
    param(
        [System.Collections.IEnumerable]$WinGetApps
    )

    Write-Host "`n--- Installing WinGet Applications ---" -ForegroundColor Cyan
    foreach ($appObject in $WinGetApps) {
        $appName = $appObject.name
        $appId = $appObject.id
        Write-Host "Processing WinGet app: '$appName' ($appId)" -ForegroundColor White

        winget list --id $appId --source winget --accept-source-agreements | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  '$appName' ($appId) is already installed." -ForegroundColor Green
        }
        else {
            if ($DryRun) {
                Write-Host "  [DryRun] Would install '$appName' ($appId)." -ForegroundColor Magenta
            } else {
                Write-Host "  '$appName' ($appId) not found. Installing..." -ForegroundColor Yellow
                winget install --id $appId --accept-package-agreements --accept-source-agreements
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  '$appName' ($appId) installed successfully." -ForegroundColor Green
                } else {
                    Write-Host "  Failed to install '$appName' ($appId). Exit code: $LASTEXITCODE" -ForegroundColor Red
                }
            }
        }
    }
}



# Function to install VSCode extensions
Function Install-VscodeExtensions {
    param(
        [System.Collections.IEnumerable]$VSCodeExtensions
    )

    Write-Host "`n--- Installing VSCode Extensions ---" -ForegroundColor Cyan

    if (-not (Get-Command "code" -ErrorAction SilentlyContinue)) {
        Write-Host "VSCode command 'code' not found in PATH. Skipping VSCode extension installation." -ForegroundColor Yellow
        return
    }

    foreach ($extension in $VSCodeExtensions) {
        $extensionName = $extension.name
        $extensionId = $extension.id

        Write-Host "Processing VSCode extension: '$extensionName'" -ForegroundColor White

        if ($DryRun) {
            Write-Host "  [DryRun] Would install/update extension: '$extensionName'" -ForegroundColor Magenta
        } else {
            code --install-extension "$extensionId" --force
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Successfully installed/updated: '$extensionName'" -ForegroundColor Green
            }
            else {
                Write-Warning "  Failed or encountered issues installing: '$extensionName'. Exit code: $LASTEXITCODE"
            }
        }
    }
}

# Function to set registry settings
Function Set-RegistrySettings {
    param(
        [System.Collections.IEnumerable]$RegistrySettings
    )

    Write-Host "`n--- Configuring registry settings ---" -ForegroundColor Cyan
    foreach ($setting in $RegistrySettings) {
        $keyDescription = $setting.description
        $keyPath = $setting.path
        $keyName = $setting.key
        $keyValue = $setting.value

        Write-Host "Processing registry setting: '$keyDescription'" -ForegroundColor White

        try {
            # Check current value
            $needsUpdate = $true
            $currentValue = $null
            $propertyExists = $false
            
            if (Test-Path -Path $keyPath) {
                $existingProperty = Get-ItemProperty -Path $keyPath -Name $keyName -ErrorAction SilentlyContinue
                if ($null -ne $existingProperty) {
                    $propertyExists = $true
                    $currentValue = $existingProperty.$keyName
                    if ($currentValue -eq $keyValue) {
                        $needsUpdate = $false
                    }
                }
            }

            if (-not $needsUpdate) {
                Write-Host "  Registry key '$keyPath\$keyName' is already set to '$keyValue'." -ForegroundColor Green
            }
            elseif ($DryRun) {
                if (-not $propertyExists) {
                    Write-Host "  [DryRun] Would create registry value '$keyPath\$keyName' with '$keyValue'." -ForegroundColor Magenta
                } else {
                    Write-Host "  [DryRun] Would update registry value '$keyPath\$keyName' to '$keyValue' (Current: '$currentValue')." -ForegroundColor Magenta
                }
            } else {
                if (-not (Test-Path -Path $keyPath)) {
                    New-Item -Path $keyPath -Force | Out-Null
                }
                Set-ItemProperty -Path $keyPath -Name $keyName -Value $keyValue -Force -ErrorAction Stop
                Write-Host "  Successfully configured registry setting: '$keyDescription'" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "  Failed or encountered issues setting registry key: '$keyDescription'. Error: $_"
        }
    }
}

# Main function
Function Invoke-Main {
    $logDir = Join-Path -Path $PSScriptRoot -ChildPath "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory | Out-Null
    }
    $logFile = Join-Path -Path $logDir -ChildPath "Workstation-Setup-$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
    
    try {
        Start-Transcript -Path $logFile -Append
        Test-Administrator
        Initialize-Prerequisites

        $config = Load-Configuration -YamlFilePath (Join-Path -Path $PSScriptRoot -ChildPath "setup-config.yaml")
        if ($null -eq $config) {
            exit 1
        }

        if ($config.psModules) {
            Install-PsModules -PSRequiredModules $config.psModules
        }
        if ($config.WinGetApps) {
            Install-WinGetApps -WinGetApps $config.WinGetApps
        }
        if ($config.VSCodeExtensions) {
            Install-VscodeExtensions -VSCodeExtensions $config.VSCodeExtensions
        }
        if ($config.RegistrySettings) {
            Set-RegistrySettings -RegistrySettings $config.RegistrySettings
        }

        Write-Host "`n--- All installation/configuration tasks complete! ---" -ForegroundColor Green
        Write-Host "Please restart PowerShell and/or VSCode for changes to take full effect." -ForegroundColor Yellow
    }
    finally {
        Stop-Transcript
    }
}

# Run the main function
Invoke-Main
