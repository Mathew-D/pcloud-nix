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

## Autostart on NixOS

pCloud writes `~/.config/autostart/pcloud.desktop` itself and points `Exec=` at
the versioned `/nix/store/...-pcloud-X.Y.Z/app/pcloud.bin`, so it breaks after
every update. To use a stable entry instead:

1. In pCloud Settings, turn off its built-in launch-on-login/autostart option.
2. Remove the managed file: `rm -f ~/.config/autostart/pcloud.desktop`
3. Install a stable entry under a different name — pCloud only manages
   `pcloud.desktop`:

```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/pcloud-nix.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=pCloud Drive
Comment=Cloud storage service for your files
Exec=/run/current-system/sw/bin/pcloud
Icon=pcloud
Terminal=false
Categories=Network;FileTransfer;
StartupWMClass=pcloud
X-GNOME-Autostart-enabled=true
EOF
```

Use the path printed by `command -v pcloud` (the stable profile symlink), not
the resolved `/nix/store/...` path.
