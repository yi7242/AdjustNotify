param(
    [string]$ProjectRoot = $PSScriptRoot,
    [string]$ManifestRelativePath = "MSIX\AppxManifest.xml",
    [string]$ArtifactsDirName = "Artifacts",
    [switch]$CurrentUserOnly
)

$ErrorActionPreference = "Stop"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PublisherSubjectFromManifest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    [xml]$manifest = Get-Content $ManifestPath
    $publisher = $manifest.Package.Identity.Publisher
    if (-not $publisher) {
        throw "Publisher not found in AppxManifest.xml"
    }

    return $publisher
}

function Test-CodeSigningEku {
    param(
        [Parameter(Mandatory = $true)]
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate
    )

    foreach ($extension in $Certificate.Extensions) {
        if ($extension -is [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]) {
            foreach ($usage in $extension.EnhancedKeyUsages) {
                if ($usage.Value -eq "1.3.6.1.5.5.7.3.3") {
                    return $true
                }
            }
        }
    }

    return $false
}

function Get-ExistingCodeSigningCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Subject
    )

    $stores = @(
        "Cert:\CurrentUser\My",
        "Cert:\LocalMachine\My"
    )

    $certificates = foreach ($store in $stores) {
        Get-ChildItem $store -ErrorAction SilentlyContinue | Where-Object {
            $_.Subject -eq $Subject -and
            $_.NotAfter -gt (Get-Date).AddDays(14) -and
            $_.HasPrivateKey -and
            (Test-CodeSigningEku -Certificate $_)
        }
    }

    return $certificates |
        Sort-Object NotAfter -Descending |
        Select-Object -First 1
}

function New-CodeSigningCertificate {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Subject
    )

    return New-SelfSignedCertificate `
        -Type Custom `
        -Subject $Subject `
        -FriendlyName "TopNotify Local Dev Code Signing" `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -KeyExportPolicy Exportable `
        -KeyUsage DigitalSignature `
        -TextExtension @(
            "2.5.29.37={text}1.3.6.1.5.5.7.3.3",
            "2.5.29.19={text}"
        ) `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(3)
}

function Test-CertificateThumbprintInStore {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StorePath,
        [Parameter(Mandatory = $true)]
        [string]$Thumbprint
    )

    return [bool](Get-ChildItem $StorePath -ErrorAction SilentlyContinue |
        Where-Object Thumbprint -eq $Thumbprint)
}

function Import-CertificateIfMissing {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CerPath,
        [Parameter(Mandatory = $true)]
        [string]$StorePath,
        [Parameter(Mandatory = $true)]
        [string]$Thumbprint
    )

    if (Test-CertificateThumbprintInStore -StorePath $StorePath -Thumbprint $Thumbprint) {
        return $false
    }

    Import-Certificate -FilePath $CerPath -CertStoreLocation $StorePath | Out-Null
    return $true
}

$resolvedProjectRoot = (Resolve-Path $ProjectRoot).Path
$manifestPath = Join-Path $resolvedProjectRoot $ManifestRelativePath
$artifactsDir = Join-Path $resolvedProjectRoot $ArtifactsDirName
$cerPath = Join-Path $artifactsDir "TopNotifyPublisher.cer"
$thumbprintPath = Join-Path $artifactsDir "TopNotifyPublisher.thumbprint.txt"

$subject = Get-PublisherSubjectFromManifest -ManifestPath $manifestPath
$certificate = Get-ExistingCodeSigningCertificate -Subject $subject
$created = $false
if (-not $certificate) {
    Write-Host "Creating self-signed code-signing certificate for $subject ..."
    $certificate = New-CodeSigningCertificate -Subject $subject
    $created = $true
}
else {
    Write-Host "Using existing code-signing certificate for $subject"
}

New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null
Export-Certificate -Cert $certificate -FilePath $cerPath -Force | Out-Null
Set-Content -Path $thumbprintPath -Value $certificate.Thumbprint

$trustedCurrentUser = Import-CertificateIfMissing `
    -CerPath $cerPath `
    -StorePath "Cert:\CurrentUser\TrustedPeople" `
    -Thumbprint $certificate.Thumbprint

$trustedLocalMachine = $false
if (-not $CurrentUserOnly) {
    if (Test-IsAdministrator) {
        $trustedLocalMachine = Import-CertificateIfMissing `
            -CerPath $cerPath `
            -StorePath "Cert:\LocalMachine\TrustedPeople" `
            -Thumbprint $certificate.Thumbprint
    }
    else {
        Write-Host "Not running as Administrator. Skipping LocalMachine\\TrustedPeople import."
    }
}

Write-Host "Certificate subject: $($certificate.Subject)"
Write-Host "Certificate thumbprint: $($certificate.Thumbprint)"
Write-Host "CER exported to: $cerPath"

return [PSCustomObject]@{
    Subject = $certificate.Subject
    Thumbprint = $certificate.Thumbprint
    Created = $created
    ImportedToCurrentUserTrustedPeople = $trustedCurrentUser
    ImportedToLocalMachineTrustedPeople = $trustedLocalMachine
    CerPath = $cerPath
}
