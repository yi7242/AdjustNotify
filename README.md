<a id="readme-top"></a>

<br />
<div align="center">
  <a href="https://github.com/SamsidParty/TopNotify">
    <img src="./TopNotify/src-vite/public/Image/Icon.png" alt="TopNotify Logo" width="160" height="160">
  </a>

  <h3 align="center">AdjustNotify Fork</h3>
  <p align="center">
    A TopNotify fork focused on notification timing and animation control
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
- Added slide-out animation support on close
- Added guards against duplicate slide-in triggers
- Added local dev script: `TopNotify/BuildInstallRunLocal.ps1`
  - Stops running TopNotify
  - Builds (or `-SkipBuild`)
  - Stages and registers loose-file MSIX
  - Launches TopNotify (unless `-NoLaunch`)

# Features 🔥

- Move notification popups anywhere on your screen
- Make notifications show on another monitor
- Change transparency of notifications
- Adjust notification display time (1s to 10s)
- Slide animation toggle with speed and distance controls
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
