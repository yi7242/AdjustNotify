param(
    [string]$ProjectRoot = $PSScriptRoot,
    [switch]$SkipBuild,
    [switch]$NoInstall,
    [switch]$NoLaunch,
    [switch]$SkipCertificateSetup,
    [switch]$UseUpstreamIdentity,
    [string]$DevPublisher = "CN=TopNotify.Dev",
    [string]$DevPackageNameSuffix = ".Dev",
    [string]$DevDisplayNameSuffix = " Dev"
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

function Add-SuffixIfMissing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Suffix
    )

    if ([string]::IsNullOrWhiteSpace($Suffix)) {
        return $Value
    }

    if ($Value.EndsWith($Suffix, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $Value
    }

    return "$Value$Suffix"
}

function Apply-ManifestIdentityOverrides {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath,
        [Parameter(Mandatory = $true)]
        [string]$Publisher,
        [Parameter(Mandatory = $true)]
        [string]$PackageNameSuffix,
        [Parameter(Mandatory = $true)]
        [string]$DisplayNameSuffix
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    [xml]$manifest = Get-Content $ManifestPath
    $ns = [System.Xml.XmlNamespaceManager]::new($manifest.NameTable)
    $ns.AddNamespace("m", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
    $ns.AddNamespace("uap", "http://schemas.microsoft.com/appx/manifest/uap/windows10")

    $identityNode = $manifest.SelectSingleNode("/m:Package/m:Identity", $ns)
    if (-not $identityNode) {
        throw "Manifest identity node not found: $ManifestPath"
    }

    $basePackageName = $identityNode.Attributes["Name"].Value
    if (-not $basePackageName) {
        throw "Package name not found in identity node: $ManifestPath"
    }

    $packageName = Add-SuffixIfMissing -Value $basePackageName -Suffix $PackageNameSuffix
    $identityNode.SetAttribute("Name", $packageName)
    $identityNode.SetAttribute("Publisher", $Publisher)

    $displayNameNode = $manifest.SelectSingleNode("/m:Package/m:Properties/m:DisplayName", $ns)
    if ($displayNameNode -and $displayNameNode.InnerText) {
        $displayNameNode.InnerText = Add-SuffixIfMissing -Value $displayNameNode.InnerText -Suffix $DisplayNameSuffix
    }

    $visualElementsNode = $manifest.SelectSingleNode("/m:Package/m:Applications/m:Application/uap:VisualElements", $ns)
    if ($visualElementsNode -and $visualElementsNode.Attributes["DisplayName"]) {
        $visualDisplayName = $visualElementsNode.Attributes["DisplayName"].Value
        if ($visualDisplayName) {
            $visualElementsNode.SetAttribute("DisplayName", (Add-SuffixIfMissing -Value $visualDisplayName -Suffix $DisplayNameSuffix))
        }
    }

    $manifest.Save($ManifestPath)

    return [PSCustomObject]@{
        PackageName = $packageName
        Publisher = $Publisher
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
$stagingManifestRelativePath = "BUILD_MSIX\AppxManifest.xml"
$msixTemplateDir = Join-Path $resolvedProjectRoot "MSIX"
$msixTemplateManifestPath = Join-Path $msixTemplateDir "AppxManifest.xml"
$buildOutputRelative = "bin\production\x64\"
$buildOutputDir = Join-Path $resolvedProjectRoot $buildOutputRelative
$certSetupScript = Join-Path $resolvedProjectRoot "EnsureLocalDevCertificate.ps1"
$totalSteps = if ($NoInstall) { 3 } else { 4 }

if (-not (Test-Path $projectFile)) {
    throw "Project file not found: $projectFile"
}

if (-not (Test-Path $msixTemplateDir)) {
    throw "MSIX template folder not found: $msixTemplateDir"
}

if (-not (Test-Path $msixTemplateManifestPath)) {
    throw "MSIX manifest not found: $msixTemplateManifestPath"
}

Write-Host "[0/$totalSteps] Stopping running TopNotify processes..."
Stop-TopNotifyProcesses

if (-not $SkipBuild) {
    Write-Host "[1/$totalSteps] Building TopNotify (Release x64)..."
    $env:NODE_OPTIONS = "--dns-result-order=ipv4first"
    & dotnet build $projectFile -c Release -p:Platform=x64 "-p:OutputPath=$buildOutputRelative"
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet build failed with exit code $LASTEXITCODE"
    }
}
else {
    Write-Host "[1/$totalSteps] Build skipped."
}

Write-Host "[2/$totalSteps] Staging loose-file package..."
Remove-DirectoryWithRetry -Path $stagingDir
New-Item -ItemType Directory -Path $stagingDir | Out-Null
Copy-Item (Join-Path $msixTemplateDir "*") $stagingDir -Recurse -Force

if (-not (Test-Path $buildOutputDir)) {
    throw "Build output not found: $buildOutputDir"
}

Copy-Item (Join-Path $buildOutputDir "*") $stagingDir -Recurse -Force

if (-not $UseUpstreamIdentity) {
    Write-Host "[2/$totalSteps] Applying local dev package identity..."
    $devIdentity = Apply-ManifestIdentityOverrides `
        -ManifestPath $stagingManifestPath `
        -Publisher $DevPublisher `
        -PackageNameSuffix $DevPackageNameSuffix `
        -DisplayNameSuffix $DevDisplayNameSuffix
    Write-Host "Local package identity: $($devIdentity.PackageName)"
    Write-Host "Local package publisher: $($devIdentity.Publisher)"
}
else {
    Write-Host "[2/$totalSteps] Using upstream package identity."
}

if ($NoInstall) {
    Write-Host "[3/$totalSteps] Install skipped."
    Write-Host ""
    Write-Host "Done."
    Write-Host "Mode: stage-only"
    Write-Host "Staging: $stagingDir"
    return
}

if ($SkipCertificateSetup) {
    Write-Host "[3/$totalSteps] Certificate setup skipped."
}
else {
    if (-not (Test-Path $certSetupScript)) {
        throw "Certificate setup script not found: $certSetupScript"
    }

    Write-Host "[3/$totalSteps] Ensuring local package certificate..."
    & $certSetupScript -ProjectRoot $resolvedProjectRoot -ManifestRelativePath $stagingManifestRelativePath | Out-Null
}

Write-Host "[4/$totalSteps] Registering app package..."
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
