# Function to log messages
function Log-Message {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $currentDateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$currentDateTime - $Message" | Out-File "installation-log.txt" -Append
}

# Check for admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log-Message "ERROR: This script requires admin rights. Run with administrator privileges."
    exit 1
}

# Backup current PATH
$backupPath = $env:Path
Log-Message "Backed up current PATH."

# Install Chocolatey
Log-Message "Installing Chocolatey..."
try {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Log-Message "Chocolatey installed successfully!"
}
catch {
    Log-Message "ERROR: Failed to install Chocolatey. $_"
    exit 1
}

# Install software using Chocolatey
$softwareList = @('git', 'docker-desktop', 'vscode')
foreach ($software in $softwareList) {
    # Check if the software is already installed
    if (-not (choco list --local-only | Select-String -Pattern "^$software$")) {
        Log-Message "Installing $software..."
        try {
            choco install $software -y
            Log-Message "$software installed successfully!"
        }
        catch {
            Log-Message "ERROR: Failed to install $software. $_"
        }
    }
    else {
        Log-Message "$software is already installed."
    }
}

# Add Git to PATH
$gitPath = "C:\Program Files\Git\bin"
if (-not ($env:Path -like "*$gitPath*")) {
    Log-Message "Adding Git to system PATH..."
    $env:Path += ";$gitPath"
    Log-Message "Git added to system PATH!"
}

# Check if Docker is running
try {
    docker info > $null
    Log-Message "Docker is running!"
}
catch {
    Log-Message "ERROR: Docker isn't running. Please start Docker."
}

# Install VSCode extensions
$vsCodeExtensions = @('ms-python.python')
foreach ($extension in $vsCodeExtensions) {
    Log-Message "Installing VSCode extension: $extension..."
    try {
        code --install-extension $extension
        Log-Message "VSCode extension $extension installed successfully!"
    }
    catch {
        Log-Message "ERROR: Failed to install VSCode extension $extension. $_"
    }
}

Log-Message "Script execution completed!"
