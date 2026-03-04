param(
    [string]$ProjectRoot = $PSScriptRoot,
    [switch]$SkipBuild,
    [switch]$NoInstall,
    [switch]$NoLaunch
)

$ErrorActionPreference = "Stop"

function Stop-TopNotifyProcesses {
    param(
        [int]$TimeoutSeconds = 15
    )

    # Stop regular processes first.
    Get-Process TopNotify -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # Kill process trees in case child processes are holding files.
    try {
        & taskkill /F /IM TopNotify.exe /T 2>$null | Out-Null
    }
    catch {
    }

    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt $TimeoutSeconds) {
        if (-not (Get-Process TopNotify -ErrorAction SilentlyContinue)) {
            return
        }

        Start-Sleep -Milliseconds 250
    }

    throw "Failed to stop TopNotify.exe within $TimeoutSeconds seconds."
}

function Remove-DirectoryWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$MaxAttempts = 5
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            if (Test-Path $Path) {
                Remove-Item $Path -Recurse -Force
            }

            return
        }
        catch {
            if ($attempt -eq $MaxAttempts) {
                throw
            }

            Stop-TopNotifyProcesses
            Start-Sleep -Milliseconds 300
        }
    }
}

function Get-PackageManifestInfo {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    [xml]$manifest = Get-Content $ManifestPath
    $packageName = $manifest.Package.Identity.Name
    $appId = $manifest.Package.Applications.Application.Id
    if (-not $packageName) {
        throw "Package name not found in AppxManifest.xml"
    }
    if (-not $appId) {
        throw "Application Id not found in AppxManifest.xml"
    }

    return [PSCustomObject]@{
        PackageName = $packageName
        AppId = $appId
    }
}

function Install-LooseMsixPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    Stop-TopNotifyProcesses

    $existing = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-AppxPackage -Package $existing.PackageFullName
    }

    Add-AppxPackage -Register $ManifestPath -ForceApplicationShutdown
}

function Start-InstalledPackageApp {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,
        [Parameter(Mandatory = $true)]
        [string]$AppId
    )

    $package = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending |
        Select-Object -First 1

    if (-not $package) {
        throw "Installed package not found: $PackageName"
    }

    $appUserModelId = "$($package.PackageFamilyName)!$AppId"
    Start-Process "explorer.exe" "shell:AppsFolder\$appUserModelId" | Out-Null
}

$resolvedProjectRoot = (Resolve-Path $ProjectRoot).Path
$projectFile = Join-Path $resolvedProjectRoot "TopNotify.csproj"
$stagingDir = Join-Path $resolvedProjectRoot "BUILD_MSIX"
$stagingManifestPath = Join-Path $stagingDir "AppxManifest.xml"
$msixTemplateDir = Join-Path $resolvedProjectRoot "MSIX"
$buildOutputRelative = "bin\production\x64\"
$buildOutputDir = Join-Path $resolvedProjectRoot $buildOutputRelative

if (-not (Test-Path $projectFile)) {
    throw "Project file not found: $projectFile"
}

if (-not (Test-Path $msixTemplateDir)) {
    throw "MSIX template folder not found: $msixTemplateDir"
}

Write-Host "[0/3] Stopping running TopNotify processes..."
Stop-TopNotifyProcesses

if (-not $SkipBuild) {
    Write-Host "[1/3] Building TopNotify (Release x64)..."
    $env:NODE_OPTIONS = "--dns-result-order=ipv4first"
    & dotnet build $projectFile -c Release -p:Platform=x64 "-p:OutputPath=$buildOutputRelative"
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed with exit code $LASTEXITCODE"
    }
}
else {
    Write-Host "[1/3] Build skipped."
}

Write-Host "[2/3] Staging loose-file package..."
Remove-DirectoryWithRetry -Path $stagingDir
New-Item -ItemType Directory -Path $stagingDir | Out-Null
Copy-Item (Join-Path $msixTemplateDir "*") $stagingDir -Recurse -Force

if (-not (Test-Path $buildOutputDir)) {
    throw "Build output not found: $buildOutputDir"
}

Copy-Item (Join-Path $buildOutputDir "*") $stagingDir -Recurse -Force

if ($NoInstall) {
    Write-Host "[3/3] Install skipped."
    Write-Host ""
    Write-Host "Done."
    Write-Host "Mode: stage-only"
    Write-Host "Staging: $stagingDir"
    return
}

Write-Host "[3/3] Registering app package..."
$manifestInfo = Get-PackageManifestInfo -ManifestPath $stagingManifestPath
Install-LooseMsixPackage -PackageName $manifestInfo.PackageName -ManifestPath $stagingManifestPath

if ($NoLaunch) {
    Write-Host "Launch skipped."
}
else {
    Write-Host "Launching TopNotify..."
    Start-InstalledPackageApp -PackageName $manifestInfo.PackageName -AppId $manifestInfo.AppId
}

Write-Host ""
Write-Host "Done."
Write-Host "Mode: manifest-register"
Write-Host "Staging: $stagingDir"
