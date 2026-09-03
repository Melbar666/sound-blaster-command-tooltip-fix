# Security

This project modifies a DLL inside `Program Files (x86)`, so installation and removal require administrator privileges.

The design is intentionally fail-closed:

- no wildcard file discovery
- no patching by version string alone
- no downloading executable code
- no network access during install
- no bundled third-party DLL
- no modification when the installed SHA-256 is unknown
- no rollback from an unverified backup

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

## Reporting a problem

Please open a GitHub issue and include the verifier result and relevant version/hash information. Do not include personal paths, usernames, account data, or unrelated diagnostic dumps.
