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

function Show-Progress {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Status,

        [Parameter(Mandatory=$true)]
        [int]$PercentComplete
    )

    Write-Progress -Activity "Docker Desktop Installation" -Status $Status -PercentComplete $PercentComplete
}

function Create-DockerDesktopShortcut {
    $shortcutPath = "$env:USERPROFILE\Desktop\Docker Desktop.lnk"
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    $Shortcut.Save()

    if (Test-Path $shortcutPath) {
        Log-Message "INFO" "Docker Desktop shortcut created on Desktop."
    } else {
        Log-Message "ERROR" "Failed to create Docker Desktop shortcut."
    }
}

function Pin-DockerToTaskbar {
    $verb = "pin to taskbar"
    $path = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    $shell = New-Object -ComObject "Shell.Application"
    $folder = $shell.Namespace((Get-Item $path).DirectoryName)
    $item = $folder.ParseName((Get-Item $path).Name)
    $item.InvokeVerb($verb)
    Log-Message "INFO" "Docker Desktop pinned to taskbar."
}

function Install-DockerDesktop {
    try {
        choco install docker-desktop -y
        Log-Message "INFO" "Docker Desktop installed."
        return $true
    }
    catch {
        Log-Message "ERROR" "Failed to install Docker Desktop. $_"
        return $false
    }
}

function Verify-DockerDesktop {
    return (Test-Path "C:\Program Files\Docker\Docker\Docker Desktop.exe")
}

Write-Host "Script started..." -ForegroundColor Cyan

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Admin rights required." -ForegroundColor Red
    Log-Message "ERROR" "This script requires admin rights. Run with administrator privileges."
    return
}

Log-Message "INFO" "Script has necessary permissions. Proceeding..."

# Check and Install Chocolatey if not present
Write-Host "Checking for Chocolatey..." -ForegroundColor Cyan
$chocoInstalled = $false
try {
    $chocoCheck = choco --version 2>&1
    if ($chocoCheck -match "Chocolatey v") {
        $chocoInstalled = $true
    }
}
catch {
    $chocoInstalled = $false
}

if (-not $chocoInstalled) {
    Write-Host "Chocolatey not found. Attempting installation..." -ForegroundColor Yellow
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
        Log-Message "INFO" "Chocolatey installed successfully!"
    }
    catch {
        Log-Message "ERROR" "Failed to install Chocolatey. $_"
        return
    }
} else {
    Log-Message "INFO" "Chocolatey is installed. Proceeding..."
}

# Install and verify Docker Desktop
Show-Progress "Checking and Installing Docker Desktop..." 0

$maxRetries = 3
$installationAttempts = 0
$installationSuccess = $false

while (-not $installationSuccess -and $installationAttempts -lt $maxRetries) {
    if (-not (choco list --local-only --exact 'docker-desktop' | Select-String -Pattern "^docker-desktop$")) {
        $installationSuccess = Install-DockerDesktop
        $installationAttempts++

        if (-not $installationSuccess) {
            Log-Message "WARN" "Attempt $installationAttempts of $maxRetries to install Docker Desktop failed. Retrying..."
            Start-Sleep -Seconds 10
        } else {
            $installationSuccess = Verify-DockerDesktop
        }
    } else {
        $installationSuccess = $true
    }
    Show-Progress "Installing Docker Desktop..." (($installationAttempts / $maxRetries) * 100)
}

if ($installationSuccess) {
    Write-Host "Docker Desktop installed successfully." -ForegroundColor Green
    Log-Message "INFO" "Docker Desktop installed successfully."
    Create-DockerDesktopShortcut
    Pin-DockerToTaskbar
} else {
    Write-Host "Failed to install Docker Desktop after $maxRetries attempts." -ForegroundColor Red
    Log-Message "ERROR" "Failed to install Docker Desktop after $maxRetries attempts."
}

Log-Message "INFO" "Script execution completed!"
Write-Host "Script execution"
