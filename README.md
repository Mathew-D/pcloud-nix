# pcloud-nix

Flake package for pCloud Drive on x86_64 Linux.

This packages the upstream AppImage and exposes:

- `packages.x86_64-linux.pcloud`
- `packages.x86_64-linux.default`
- `apps.x86_64-linux.default`

Usage:

```bash
nix run .
```

The upstream AppImage is published behind a rotating pCloud download URL. Run
`./update.py` to fetch the latest release from pCloud's update feed, refresh
the version and hash, and update `pkgs/pcloud/default.nix`. Use
`./update.py --force` to re-check the current release hash without waiting for
a new version.
