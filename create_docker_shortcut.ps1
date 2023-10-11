# Function to log messages with levels
function Log-Message {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Level,

        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$currentDateTime [$Level] - $Message" | Out-File "docker-installation-log.txt" -Append

    # Display messages in color based on their level
    switch ($Level) {
        "INFO" { Write-Host $Message -ForegroundColor Green }
        "WARN" { Write-Host $Message -ForegroundColor Yellow }
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        default { Write-Host $Message }
    }
}

# Function to determine if Docker Desktop is installed via Chocolatey
function IsDockerInstalledViaChoco {
    $installedPackages = choco list 2>&1
    Log-Message "INFO" "Installed packages via Chocolatey: $installedPackages"
    return $installedPackages -like "*docker-desktop*"
}

function Create-DockerDesktopShortcut {
    param (
        [Parameter(Mandatory=$true)]
        [string]$dockerPath
    )

    $shortcutPath = "$env:USERPROFILE\Desktop\Docker Desktop.lnk"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = $dockerPath
    $Shortcut.Save()
    Log-Message "INFO" "Docker Desktop shortcut created on the Desktop."
}

function Pin-DockerToTaskbar {
    param (
        [Parameter(Mandatory=$true)]
        [string]$dockerPath
    )

    $verb = "pin to taskbar"
    $shell = New-Object -ComObject "Shell.Application"
    $folder = $shell.Namespace((Get-Item $dockerPath).DirectoryName)
    $item = $folder.ParseName((Get-Item $dockerPath).Name)
    $item.InvokeVerb($verb)
    Log-Message "INFO" "Docker Desktop pinned to the taskbar."
}

function Install-DockerDesktop {
    try {
        choco install docker-desktop -y
        Log-Message "INFO" "Docker Desktop installation initiated via Chocolatey."
        Start-Sleep -s 30
        $chocoInstalled = choco list docker-desktop --local-only 2>&1
        if ($chocoInstalled -like "*docker-desktop*") {
            Log-Message "INFO" "Docker Desktop installation verified through Chocolatey."
            # Search entire system for Docker Desktop post-installation
            $result = Get-ChildItem -Path "C:\" -Recurse -Filter "Docker Desktop.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
            if ($result) {
                Log-Message "INFO" "Docker Desktop found at: $result"
            } else {
                Log-Message "ERROR" "Unable to locate Docker Desktop after installation attempt."
            }
            return $true
        }
        else {
            Log-Message "ERROR" "Docker Desktop installation failed or is incomplete."
            return $false
        }
    }
    catch {
        Log-Message "ERROR" "Failed to initiate Docker Desktop installation via Chocolatey."
        return $false
    }
}

function Search-ForDockerDesktop {
    # Attempt to find Docker Desktop installation across potential paths
    $possiblePaths = @(
        "C:\Program Files\Docker\Docker\Docker Desktop.exe",
        "C:\Program Files (x86)\Docker\Docker\Docker Desktop.exe",
        "C:\Program Files\Docker\Docker Desktop.exe"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    # If not found in standard paths, search the entire C:\Program Files directory
    $result = Get-ChildItem -Path "C:\Program Files" -Recurse -Filter "Docker Desktop.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    if ($result) {
        return $result[0]
    }

    return $null
}
# ... [Previous functions remain unchanged]

# Main script execution starts here
Write-Host "Checking for Chocolatey..." -ForegroundColor Cyan
$chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
if (Test-Path $chocoPath) {
    Log-Message "INFO" "Chocolatey is already installed at $chocoPath."
} else {
    Log-Message "WARN" "Chocolatey not found. Attempting installation..."
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Log-Message "INFO" "Chocolatey installed successfully!"
    }
    catch {
        Log-Message "ERROR" "Failed to install Chocolatey."
        return
    }
}

# Check if Docker Desktop is installed via Chocolatey
if (IsDockerInstalledViaChoco) {
    Log-Message "INFO" "Docker Desktop is installed via Chocolatey."
} else {
    Log-Message "WARN" "Docker Desktop not found on the system via Chocolatey."
    Log-Message "INFO" "Docker Desktop installation initiated via Chocolatey."
    Install-DockerDesktop
}

# After installation, verify if Docker Desktop is installed via Chocolatey
if (IsDockerInstalledViaChoco) {
    Log-Message "INFO" "Docker Desktop is installed via Chocolatey after installation attempt."
    $dockerPath = Search-ForDockerDesktop
    if ($dockerPath) {
        Log-Message "INFO" "Docker Desktop found at: $dockerPath"
        Create-DockerDesktopShortcut -dockerPath $dockerPath
        Pin-DockerToTaskbar -dockerPath $dockerPath
    } else {
        Log-Message "ERROR" "Unable to locate Docker Desktop executable after installation attempt."
    }
} else {
    Log-Message "ERROR" "Unable to determine the installation of Docker Desktop via Chocolatey after installation attempt."
}

Log-Message "INFO" "Script execution completed!"
Write-Host "Script execution completed!"
