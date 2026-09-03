# Technical details

## Target

```text
C:\Program Files (x86)\Creative\Sound Blaster Command\Package\Hardcodet.Wpf.TaskbarNotification.dll
```

Known supported assembly:

```text
Assembly name:    Hardcodet.Wpf.TaskbarNotification
Assembly version: 1.0.5.0
PublicKeyToken:   null
Original SHA-256: 4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E
Patched SHA-256:  72CDC5A4A5841158915D6B8ED414758E39B6C5A9871274BB90B2F23EC7FA4117
```

## Patch

The affected method is:

```text
Hardcodet.Wpf.TaskbarNotification.TaskbarIcon.OnToolTipChange(bool)
```

The first IL instruction of the method body is at file offset `0x13A8`.

Original:

```text
offset 0x13A8
02    ldarg.0
```

Patched:

```text
offset 0x13A8
2A    ret
```

No other byte is intentionally modified.

The result is that the WPF tray tooltip lifecycle handler returns immediately. The Sound Blaster Command tray hover tooltip is disabled, preventing that tooltip window from becoming stranded on the desktop.

## Why not replace the whole library?

The installed component is very old, but replacing an application dependency with a newer major version is a much broader compatibility change than necessary.

This project deliberately keeps:

- the original assembly identity
- the original file structure
- the rest of the original implementation
- Creative's application behavior outside the tooltip callback

The patch is therefore narrower than a library upgrade.

## Verification model

The installer requires all of the following before installation:

1. exact target path
2. exact original SHA-256
3. exact expected byte at offset `0x13A8`
4. verified original backup
5. exact expected SHA-256 after constructing the local patched file

After installation, the target is hashed again.

The verifier independently checks the patched target and original backup.

The uninstaller restores only a backup with the exact known original SHA-256.

## Distribution model

No Creative binary and no pre-patched Hardcodet binary is distributed in this repository.

Only the patching logic, known hashes, and documentation are published.
