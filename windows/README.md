# ToCreate for Windows

This is a prototype Windows shell for `https://api.lihe.chat`.

It uses WPF plus Microsoft Edge WebView2, so it is intentionally separate from the macOS `AppKit` and `WKWebView` implementation.

## Local build on Windows

```powershell
.\scripts\publish_windows.ps1
```

The published files are written to:

```text
dist/windows/ToCreate-Windows
```

## GitHub Actions

Run the `Build Windows Prototype` workflow manually from GitHub Actions. It publishes the Windows client and uploads a `ToCreate-Windows` artifact.

This first pass is a buildable prototype, not a signed installer. Before public release, add a branded icon, code signing, an installer, and Windows-specific update logic.
