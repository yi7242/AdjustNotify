param(
    [string]$ProjectRoot = $PSScriptRoot,
    [switch]$SkipBuild,
    [switch]$NoInstall
)

$ErrorActionPreference = "Stop"

function Get-PackageNameFromManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    [xml]$manifest = Get-Content $ManifestPath
    $packageName = $manifest.Package.Identity.Name
    if (-not $packageName) {
        throw "Package name not found in AppxManifest.xml"
    }

    return $packageName
}

function Install-LooseMsixPackage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    Get-Process TopNotify -ErrorAction SilentlyContinue | Stop-Process -Force

    $existing = Get-AppxPackage -Name $PackageName -ErrorAction SilentlyContinue
    if ($existing) {
        Remove-AppxPackage -Package $existing.PackageFullName
    }

    Add-AppxPackage -Register $ManifestPath -ForceApplicationShutdown
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
if (Test-Path $stagingDir) {
    Remove-Item $stagingDir -Recurse -Force
}
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
$packageName = Get-PackageNameFromManifest -ManifestPath $stagingManifestPath
Install-LooseMsixPackage -PackageName $packageName -ManifestPath $stagingManifestPath

Write-Host ""
Write-Host "Done."
Write-Host "Mode: manifest-register"
Write-Host "Staging: $stagingDir"
