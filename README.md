<a id="readme-top"></a>

<br />
<div align="center">
  <a href="https://github.com/SamsidParty/TopNotify">
    <img src="./TopNotify/src-vite/public/Image/Icon.png" alt="TopNotify Logo" width="160" height="160">
  </a>

  <h3 align="center">AdjustNotify Fork</h3>
  <p align="center">
    A TopNotify fork focused on notification timing control
    <br />
    <br />
  </p>
  <div align="center">

  <a href="">![Download Count](https://img.shields.io/github/downloads/SamsidParty/TopNotify/total.svg?style=for-the-badge)</a>
  <a href="">![Stars Count](https://img.shields.io/github/stars/SamsidParty/TopNotify.svg?style=for-the-badge)</a>
  <a href="">![Code Size](https://img.shields.io/github/languages/code-size/SamsidParty/TopNotify?style=for-the-badge)</a>
  <a href="">![Repo Size](https://img.shields.io/github/repo-size/SamsidParty/TopNotify?style=for-the-badge)</a>
  <a href="https://apps.microsoft.com/detail/9pfmdk0qhkqj?hl=en-US&gl=US">![Get It From Microsoft](https://get.microsoft.com/images/en-us%20dark.svg)</a>
    
  </div>
</div>

# Fork Additions (This Fork)

This fork keeps the upstream TopNotify README structure and adds the following features/workflow:

- Added more aggressive notification lifetime control for short display times
- Keeps toast entry/exit animation behavior fully native to Windows
- Added local dev script: `TopNotify/BuildInstallRunLocal.ps1`
  - Stops running TopNotify
  - Builds (or `-SkipBuild`)
  - Stages and registers loose-file MSIX
  - Launches TopNotify (unless `-NoLaunch`)

# Local Setup (Install Certificate + Build + Launch)

Use this when running this fork directly from source.

1. Open PowerShell in the repository root.
2. Run the block below (one-time certificate import + build/install/run).

```powershell
$certPath = Join-Path $PWD "TopNotify\Artifacts\TopNotifyPublisher.cer"
if (-not (Test-Path $certPath)) {
    throw "Certificate not found: $certPath"
}

$publisher = "CN=68C2D20A-96CA-43CC-A323-A549C2786CDA"
$installedCert = Get-ChildItem Cert:\CurrentUser\TrustedPeople -ErrorAction SilentlyContinue |
    Where-Object Subject -eq $publisher

if (-not $installedCert) {
    Import-Certificate -FilePath $certPath -CertStoreLocation Cert:\CurrentUser\TrustedPeople | Out-Null
}

powershell -ExecutionPolicy Bypass -File .\TopNotify\BuildInstallRunLocal.ps1
```

3. After launch, find TopNotify in the system tray and double-click the icon to open the UI.

Notes:
- The script will stop running TopNotify, build `Release x64`, register from `TopNotify\BUILD_MSIX\AppxManifest.xml`, and launch it.
- For quick reruns without rebuilding: `.\TopNotify\BuildInstallRunLocal.ps1 -SkipBuild`
- If `Add-AppxPackage` fails with `0x80073CFF`, enable Developer Mode in Windows and run again.

# Features 🔥

- Move notification popups anywhere on your screen
- Make notifications show on another monitor
- Change transparency of notifications
- Adjust notification display time (0.1s to 10s)
- Click-Through notifications
- Customize notification sounds for each app
- Efficient performance with minimal CPU/RAM usage
- Native ARM64 Support

![TopNotify Header](/Docs/Screenshot3.png)

![TopNotify Screenshot](/Docs/Screenshot2.png)

![TopNotify Screenshot](/Docs/Screenshot1.png)

# Supported Windows Versions 🪟

- Windows 11 23H2+
- Windows 10 23H2+ (Requires WebView2 Runtime)

Earlier versions of Windows 10 may work, but are not officially supported.

# Download 📦

Download the latest MSIX/EXE release from the [releases](https://github.com/SamsidParty/TopNotify/releases) page

# Star History ⭐

<a href="https://www.star-history.com/#SamsidParty/TopNotify&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=SamsidParty/TopNotify&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=SamsidParty/TopNotify&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=SamsidParty/TopNotify&type=Date" />
 </picture>
</a>
