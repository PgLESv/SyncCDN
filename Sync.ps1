# Configurações
$cdnUrl = "http://127.0.0.1:80/"
$localPath = "YourLocalPath"
$hashFileUrl = "$cdnUrl/file_hashes.json"

Write-Host "SyncCND!"
Write-Host "By PgLESv"
Write-Host "Sponsored by NasNuvem"

# Calc Local Hash
function Get-FileHash ($filePath) {
    if (-not (Test-Path $filePath)) {
        throw "File not found: $filePath"
    }
    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create('SHA256')
    $stream = $null
    try {
        $stream = [System.IO.File]::OpenRead($filePath)
        $hash = $hasher.ComputeHash($stream)
    } catch {
        throw "Error computing hash for $($filePath): $_"
    } finally {
        if ($stream) {
            $stream.Close()
        }
    }
    return [BitConverter]::ToString($hash) -replace '-', ''
}

# Function to load remote hashes from JSON file
function Get-RemoteHashes ($url) {
    try {
        $jsonContent = Invoke-RestMethod -Uri $url -UseBasicParsing
        return $jsonContent
    } catch {
        throw "Failed to retrieve remote hashes: $_"
    }
}

# Load remote hashes
try {
    Write-Host "Loading remote hashes from $hashFileUrl"
    $remoteHashes = Get-RemoteHashes $hashFileUrl
    Write-Host "Remote hashes loaded successfully"
} catch {
    Write-Host "Failed to retrieve remote hashes: $_"
    exit 1
}

# Function to load local hashes
function Get-LocalHashes ($directory) {
    $fileHashes = @{}
    $files = Get-ChildItem -Path $directory -Recurse -File
    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($directory.Length + 1).Replace('\', '/')
        $fileHashes[$relativePath] = Get-FileHash $file.FullName
    }
    return $fileHashes
}

# Load local hashes
try {
    Write-Host "Calculating local hashes for files in $localPath"
    $localHashes = Get-LocalHashes $localPath
    Write-Host "Local hashes calculated successfully"
} catch {
    Write-Host "Error calculating local hashes: $_"
    exit 1
}

# Check and update modified or new files
foreach ($remoteFile in $remoteHashes.PSObject.Properties.Name) {
    $remoteHash = $remoteHashes.$remoteFile
    $localFile = Join-Path $localPath $remoteFile.Replace('/', '\')

    if (-not (Test-Path $localFile) -or $localHashes[$remoteFile] -ne $remoteHash) {
        $remoteFileUrl = "$cdnUrl/$remoteFile"
        $localDir = Split-Path $localFile -Parent

        # Validate URL
        if (-not [System.Uri]::IsWellFormedUriString($remoteFileUrl, [System.UriKind]::Absolute)) {
            Write-Host "Invalid URL: $remoteFileUrl"
            continue
        }

        # Create directory if not exists
        if (-not (Test-Path $localDir)) {
            New-Item -Path $localDir -ItemType Directory | Out-Null
        }

        # Download or update file
        try {
            Invoke-WebRequest -Uri $remoteFileUrl -OutFile $localFile
            Write-Host "Downloaded/Updated: $localFile"
        } catch {
            Write-Host "Failed to download: $($remoteFileUrl)"
        }
    }
}

# Remove local files that are no longer present on the CDN
$localFiles = Get-ChildItem -Path $localPath -Recurse -File
foreach ($localFile in $localFiles) {
    $relativePath = $localFile.FullName.Substring($localPath.Length + 1).Replace('\', '/')
    if ($remoteHashes.PSObject.Properties.Name -notcontains $relativePath) {
        try {
            Remove-Item -Path $localFile.FullName -Force
            Write-Host "Removed: $($localFile.FullName)"
        } catch {
            Write-Host "Failed to remove: $($localFile.FullName)"
        }
    }
}

Write-Host "Script complete!"
