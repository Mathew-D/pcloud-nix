{ lib
, appimageTools
, fetchurl
, makeDesktopItem
, libappindicator-gtk3
, fuse
, zlib
, hicolor-icon-theme
}:

let
  pname = "pcloud-drive";
  version = "2.1.1";

  src = fetchurl {
    # pCloud serves the AppImage behind a time-bound publink; refresh this URL
    # and hash when upstream rotates the published artifact.
    url = "https://def1.pcloud.com/cBZeyCak57Ztkt7yq7ZZZbs6E5kZ2ZZxIVZkZ9KHBHZJgZCzZrLZeFZ94ZkLZ5LZjgZr4Z6YZrFZmLZyQZoTZtwII5ZNdCm1yfsy2R4JIc8FyRvwzoi9lwk/pCloud.AppImage";
    hash = "sha256-WzZUDU4zvgxEGPpB362ceRARJBPMIYe+BTfDsaQkU2Q=";
  };

  extracted = appimageTools.extractType2 {
    inherit pname version src;
  };

  desktopItem = makeDesktopItem {
    name = "pcloud";
    desktopName = "pCloud";
    exec = "env DESKTOPINTEGRATION=false pcloud";
    terminal = false;
    categories = [ "Network" "FileTransfer" "Utility" ];
    icon = "pcloud";
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraPkgs = pkgs: [
    fuse
    zlib
    hicolor-icon-theme
    libappindicator-gtk3
  ];

  extraInstallCommands = ''
    install -Dm644 ${desktopItem}/share/applications/pcloud.desktop \
      $out/share/applications/pcloud.desktop

    if [ -d ${extracted}/usr/share/icons/hicolor ]; then
      mkdir -p $out/share/icons
      cp -r ${extracted}/usr/share/icons/hicolor $out/share/icons/
    fi

    ln -sf $out/bin/${pname} $out/bin/pcloud
  '';

  meta = with lib; {
    description = "pCloud Drive desktop client packaged from the upstream AppImage";
    homepage = "https://www.pcloud.com/";
    license = licenses.unfree;
    mainProgram = "pcloud";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
