param(
    [switch]$DryRun,
    [string[]]$Sections  # e.g. -Sections PsModules,Packages  (skip menu when provided)
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
Function Import-Configuration {
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

# Function to install packages from multiple sources (winget, npm)
Function Install-Packages {
    param(
        [System.Collections.IEnumerable]$Packages
    )

    Write-Host "`n--- Installing Packages ---" -ForegroundColor Cyan

    $npmAvailable = [bool](Get-Command "npm" -ErrorAction SilentlyContinue)

    foreach ($pkg in $Packages) {
        $pkgName   = $pkg.name
        $pkgSource = $pkg.source

        switch ($pkgSource) {
            'winget' {
                $pkgId = $pkg.id
                Write-Host "Processing [winget] '$pkgName' ($pkgId)" -ForegroundColor White

                winget list --id $pkgId --source winget --accept-source-agreements | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  '$pkgName' is already installed." -ForegroundColor Green
                } else {
                    if ($DryRun) {
                        Write-Host "  [DryRun] Would install '$pkgName' ($pkgId)." -ForegroundColor Magenta
                    } else {
                        Write-Host "  Installing '$pkgName'..." -ForegroundColor Yellow
                        winget install --id $pkgId --accept-package-agreements --accept-source-agreements
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  '$pkgName' installed successfully." -ForegroundColor Green
                        } else {
                            Write-Host "  Failed to install '$pkgName'. Exit code: $LASTEXITCODE" -ForegroundColor Red
                        }
                    }
                }
            }
            'npm' {
                $pkgPackage = $pkg.package
                Write-Host "Processing [npm]    '$pkgName' ($pkgPackage)" -ForegroundColor White

                if (-not $npmAvailable) {
                    Write-Host "  NPM not found in PATH. Skipping '$pkgName'." -ForegroundColor Yellow
                    continue
                }

                npm list -g --depth=0 $pkgPackage 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  '$pkgName' is already installed globally." -ForegroundColor Green
                } else {
                    if ($DryRun) {
                        Write-Host "  [DryRun] Would install '$pkgName' ($pkgPackage) globally." -ForegroundColor Magenta
                    } else {
                        Write-Host "  Installing '$pkgName'..." -ForegroundColor Yellow
                        npm install -g $pkgPackage
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  '$pkgName' installed successfully." -ForegroundColor Green
                        } else {
                            Write-Host "  Failed to install '$pkgName'. Exit code: $LASTEXITCODE" -ForegroundColor Red
                        }
                    }
                }
            }
            default {
                Write-Host "  Unknown source '$pkgSource' for '$pkgName'. Skipping." -ForegroundColor Red
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

# Function to set up PowerShell profile
Function Initialize-PowerShellProfile {
    param(
        [string]$OhMyPoshTheme
    )

    Write-Host "`n--- Setting up PowerShell profile ---" -ForegroundColor Cyan

    $profilePath = $PROFILE
    $profileDir = Split-Path -Path $profilePath -Parent

    if (-not (Test-Path -Path $profileDir)) {
        if ($DryRun) {
            Write-Host "[DryRun] Would create profile directory at '$profileDir'." -ForegroundColor Magenta
        } else {
            New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
            Write-Host "Created profile directory at '$profileDir'." -ForegroundColor Green
        }
    }

    if (-not (Test-Path -Path $OhMyPoshTheme)) {
        Write-Warning "Oh My Posh theme file not found at '$OhMyPoshTheme'. Skipping profile setup."
        return
    }

    $themeDestPath = Join-Path -Path $profileDir -ChildPath (Split-Path -Path $OhMyPoshTheme -Leaf)
    if ($DryRun) {
        Write-Host "[DryRun] Would copy Oh My Posh theme from '$OhMyPoshTheme' to '$themeDestPath'." -ForegroundColor Magenta
    } else {
        Copy-Item -Path $OhMyPoshTheme -Destination $themeDestPath -Force
        Write-Host "Successfully copied Oh My Posh theme to '$themeDestPath'." -ForegroundColor Green
    }

    $profileContent = @"
Import-Module -Name Terminal-Icons
oh-my-posh --init --shell pwsh --config "$themeDestPath" | Invoke-Expression
"@

    $existingContent = if (Test-Path $profilePath) { Get-Content $profilePath -Raw } else { "" }
    
    if ($existingContent -match "oh-my-posh --init") {
        Write-Host "PowerShell profile already seems to be configured for Oh My Posh. Skipping." -ForegroundColor Green
        return
    }

    if ($DryRun) {
        Write-Host "[DryRun] Would append the following to '$profilePath':" -ForegroundColor Magenta
        Write-Host $profileContent -ForegroundColor Magenta
    } else {
        Add-Content -Path $profilePath -Value $profileContent
        Write-Host "Successfully configured PowerShell profile for Oh My Posh." -ForegroundColor Green
    }
}



# Function to display an interactive section selection menu
Function Show-SectionMenu {
    $options = [ordered]@{
        '1' = @{ Label = 'PS Modules';           Key = 'PsModules' }
        '2' = @{ Label = 'Packages (winget/npm)'; Key = 'Packages'  }
        '3' = @{ Label = 'VSCode Extensions';    Key = 'VSCode'    }
        '4' = @{ Label = 'Registry Settings';    Key = 'Registry'  }
        '5' = @{ Label = 'PowerShell Profile';   Key = 'PsProfile' }
        'A' = @{ Label = 'All sections';         Key = 'All'       }
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "    Workstation Setup - Section Menu"     -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Select sections to run (comma-separated):" -ForegroundColor White
    Write-Host ""
    foreach ($key in $options.Keys) {
        Write-Host "  [$key] $($options[$key].Label)" -ForegroundColor White
    }
    Write-Host ""

    do {
        $raw     = (Read-Host "Enter selection").Trim().ToUpper()
        $choices = $raw -split '[,\s]+' | Where-Object { $_ -ne '' }
        $invalid = $choices | Where-Object { -not $options.Contains($_) }
        if ($invalid) {
            Write-Host "Invalid option(s): $($invalid -join ', '). Please try again." -ForegroundColor Red
        }
    } while ($invalid)

    if ($choices -contains 'A') {
        return @('PsModules', 'Packages', 'VSCode', 'Registry', 'PsProfile')
    }
    return $choices | ForEach-Object { $options[$_].Key }
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

        $config = Import-Configuration -YamlFilePath (Join-Path -Path $PSScriptRoot -ChildPath "setup-config.yaml")
        if ($null -eq $config) {
            exit 1
        }

        # Determine which sections to run
        $sectionsToRun = if ($Sections -and $Sections.Count -gt 0) {
            Write-Host "Sections provided via parameter: $($Sections -join ', ')" -ForegroundColor White
            if ('All' -in $Sections) {
                @('PsModules', 'Packages', 'VSCode', 'Registry', 'PsProfile')
            } else {
                $Sections
            }
        } else {
            Show-SectionMenu
        }

        if ('PsModules' -in $sectionsToRun -and $config.psModules) {
            Install-PsModules -PSRequiredModules $config.psModules
        }
        if ('Packages' -in $sectionsToRun -and $config.Packages) {
            Install-Packages -Packages $config.Packages
        }
        if ('VSCode' -in $sectionsToRun -and $config.VSCodeExtensions) {
            Install-VscodeExtensions -VSCodeExtensions $config.VSCodeExtensions
        }
        if ('Registry' -in $sectionsToRun -and $config.RegistrySettings) {
            Set-RegistrySettings -RegistrySettings $config.RegistrySettings
        }
        if ('PsProfile' -in $sectionsToRun -and $config.PowerShell) {
            if ($config.PowerShell.OhMyPosh.theme) {
                $themePath = Join-Path -Path $PSScriptRoot -ChildPath $config.PowerShell.OhMyPosh.theme
                Initialize-PowerShellProfile -OhMyPoshTheme $themePath
            }
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
