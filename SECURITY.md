# Security

This project modifies a DLL inside `Program Files (x86)`, so installation and removal require administrator privileges.

The install and uninstall launchers intentionally use a **visible** elevated PowerShell process because the target is inside `Program Files (x86)`. The scripts are not code-signed, so Windows or third-party security software may display a warning depending on local policy.

The design is intentionally fail-closed:

- no wildcard file discovery
- no patching by version string alone
- no downloading executable code
- no network access during install
- no bundled third-party DLL
- no modification when the installed SHA-256 is unknown
- no rollback from an unverified backup
- exact exit codes are propagated by the CMD launchers
- a graceful Sound Blaster Command shutdown is attempted for up to five seconds before force-stop fallback

## Supported hash only

The current release supports exactly:

```text
Original SHA-256:
4A2438ECFCAD3E6E7BB942ACF2C40FBE2C0D72E4982DF303AB5828AF26CA753E
```

If a future Sound Blaster Command update changes the DLL, open an issue with:

- Sound Blaster Command version
- `Hardcodet.Wpf.TaskbarNotification.dll` file version
- SHA-256 of that DLL
- whether the sticky top-left tooltip still occurs

Do not upload Creative DLLs to an issue.

## Local diagnostic logs

The scripts append diagnostic logs under `%TEMP%\SoundBlasterCommand-TooltipFix`. These logs contain patch/verification steps, hashes, and error messages. They are local only and are never uploaded automatically.

Pre-public versions of this fix used an earlier backup filename. The current scripts keep hash-verified compatibility with that filename so existing local installations can still be verified and removed safely.

## Reporting a problem

Please open a GitHub issue and include the verifier result and relevant version/hash information. Do not include personal paths, usernames, account data, or unrelated diagnostic dumps.
