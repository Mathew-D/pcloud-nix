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

The upstream AppImage is published behind a rotating pCloud download URL. If
the fetch stops working, update the URL and hash in `pkgs/pcloud/default.nix`.
