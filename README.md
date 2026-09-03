# Sound Blaster Command Tooltip Fix

A small, reversible Windows fix for a long-standing Sound Blaster Command annoyance: the tray tooltip can occasionally get stuck at the top-left corner of the desktop and stay there until the tray icon is touched again.

This project disables only that problematic hover tooltip. Sound Blaster Command itself can stay running, the tray icon remains available, and all settings continue to work normally.

## Why this exists

The affected Sound Blaster Command build examined for this fix ships `Hardcodet.Wpf.TaskbarNotification.dll` 1.0.5.0. The 1.0.5 NuGet package dates back to 2013 and is now marked obsolete. The current upstream project also has an open report for a tooltip sometimes appearing at the top-left of the screen.

This fix does **not** replace Creative's DLL with a newer third-party build. Instead, it makes one tightly scoped IL change to the exact installed DLL after verifying its SHA-256.

## Download and one-click installation

For normal users, use the packaged ZIP from the latest GitHub Release:

**https://github.com/Melbar666/sound-blaster-command-tooltip-fix/releases/latest**

1. Download `SoundBlasterCommand-TooltipFix-v1.0.0.zip` from the release assets and extract it.
2. Double-click **`Install.cmd`**.
3. Approve the Windows UAC prompt.
4. Done.

Sound Blaster Command may already be running. The installer closes it briefly if necessary and starts it again afterwards.

To confirm the installation, double-click **`Verify.cmd`**.

To remove the fix, double-click **`Uninstall.cmd`** and approve the UAC prompt.

## Supported build

The installer is intentionally fail-closed and currently supports only this exact file:

```text
File:
C:\Program Files (x86)\Creative\Sound Blaster Command\Package\Hardcodet.Wpf.TaskbarNotification.dll

Assembly version:
1.0.5.0

Original SHA-256:
4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E

Patched SHA-256:
72CDC5A4A5841158915D6B8ED414758E39B6C5A9871274BB90B2F23EC7FA4117
```

If Creative updates or replaces that DLL, the installer refuses to modify it. No guessing, no wildcard patching.

## What is changed

The patch targets:

```text
Hardcodet.Wpf.TaskbarNotification.TaskbarIcon.OnToolTipChange(bool)
```

At file offset `0x13A8`, one IL opcode is changed:

```text
02  ldarg.0
```

to:

```text
2A  ret
```

That turns the tray-tooltip change handler into an immediate return. The defective WPF hover tooltip can therefore no longer be created or left behind on the desktop.

The patch does **not** alter:

- the Sound Blaster Command application UI
- the tray icon itself
- tray click handling
- context menus
- audio settings
- device settings
- balloon notifications
- drivers or Windows audio components

The only intentional trade-off is that hovering over the Sound Blaster Command tray icon no longer shows the text tooltip. That tooltip is not needed to open or operate the application.

## Binary-free distribution

This repository intentionally does **not** contain Creative binaries or a pre-patched copy of `Hardcodet.Wpf.TaskbarNotification.dll`.

The installer patches the DLL already present on the user's own system, and only after its exact original SHA-256 has been verified. Before changing anything, it creates a verified local backup for rollback.

That keeps the fix transparent, auditable, and much easier to trust than downloading an opaque replacement DLL.

## Safety and rollback

The installer:

- requires the exact known original SHA-256
- verifies the expected original byte before patching
- creates and verifies a local backup
- constructs the patched file locally
- verifies the full patched SHA-256 before installing it
- verifies the installed file afterwards
- restores the original if post-install verification fails
- refuses unknown or updated DLL versions

`Uninstall.cmd` restores the verified original backup.

`Verify.cmd` is read-only and does not require administrator privileges.

## Release and GitHub Package

The normal-user distribution is the ZIP attached to the GitHub Release. A NuGet package named `SoundBlasterCommand.TooltipFix` is also published to GitHub Packages as an immutable package-format mirror for automation and archival use.

The NuGet package is **not** required to install the fix. Normal users should use the release ZIP.

Each release also includes `SHA256SUMS.txt` for independent verification of the downloadable assets.

## Compatibility

This was tested with a Creative Sound Blaster AE-7 system using Sound Blaster Command containing the exact DLL listed above.

Other Sound Blaster products may use the same Sound Blaster Command component, but the installer deliberately makes no compatibility assumption. If the DLL hash differs, nothing is modified.

## Upstream context

- Hardcodet.Wpf.TaskbarNotification 1.0.5 on NuGet:  
  https://www.nuget.org/packages/Hardcodet.Wpf.TaskbarNotification/1.0.5
- Current Hardcodet WPF NotifyIcon issue #128, “Sometimes tooltip appears on top-left screen”:  
  https://github.com/hardcodet/wpf-notifyicon/issues/128

## Files

```text
Install.cmd             One-click installer launcher
Verify.cmd              Read-only installation verification
Uninstall.cmd           One-click rollback launcher
install.ps1             Hash-bound local patch installer
verify.ps1              Read-only verifier
uninstall.ps1           Verified rollback
TECHNICAL.md            Exact patch details
SECURITY.md             Safety model and reporting notes
LICENSE                 License for this repository's own scripts/documentation
```

## Disclaimer

This is an independent community fix and is not affiliated with or endorsed by Creative Technology Ltd. or the Hardcodet project.

Sound Blaster, Sound Blaster Command, and related names are trademarks of their respective owners.

The MIT license in this repository applies only to the original scripts and documentation in this repository. It does not grant rights to third-party software installed on your system.
