{ appimageTools
, alsa-lib
, autoPatchelfHook
, bashInteractive
, dbus-glib
, fetchurl
, fuse
, gsettings-desktop-schemas
, gtk3
, lib
, libdbusmenu-gtk3
, libgbm
, libglvnd
, libxdamage
, nss
, patchelfUnstable
, stdenv
, udev
}:

let
  pname = "pcloud";
  version = "2.1.1";

  src = fetchurl {
    # pCloud serves the AppImage behind a time-bound publink; refresh this URL
    # and hash when upstream rotates the published artifact.
    url = "https://def1.pcloud.com/cBZeyCak57Ztkt7yq7ZZZbs6E5kZ2ZZxIVZkZ9KHBHZJgZCzZrLZeFZ94ZkLZ5LZjgZr4Z6YZrFZmLZyQZoTZtwII5ZNdCm1yfsy2R4JIc8FyRvwzoi9lwk/pCloud.AppImage";
    hash = "sha256-WzZUDU4zvgxEGPpB362ceRARJBPMIYe+BTfDsaQkU2Q=";
  };
in
stdenv.mkDerivation {
  inherit pname version;

  src = appimageTools.extractType2 {
    inherit pname version src;
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    autoPatchelfHook
    patchelfUnstable
  ];

  buildInputs = [
    alsa-lib
    bashInteractive
    dbus-glib
    fuse
    gsettings-desktop-schemas
    gtk3
    libdbusmenu-gtk3
    libgbm
    libglvnd
    libxdamage
    nss
    udev
  ];

  installPhase = ''
    mkdir "$out"
    cp -ar . "$out/app"
    cd "$out"

    rm app/AppRun

    rm app/resources/app.asar.unpacked/node_modules/koffi/build/koffi/musl_x64/koffi.node
    rm app/resources/app.asar.unpacked/node_modules/koffi/build/koffi/openbsd_x64/koffi.node

    mkdir bin
    mv app/usr/share .
    mv app/usr/lib .

    mkdir share/applications
    substitute \
      app/pcloud.desktop \
      share/applications/pcloud.desktop \
      --replace 'Exec=AppRun' 'Exec=${pname}'

    ln -snf $out/share/icons/hicolor/512x512/apps/pcloud.png app/.DirIcon
    ln -snf $out/share/icons/hicolor/512x512/apps/pcloud.png app/pcloud.png

    cat > bin/pcloud <<EOF
    #! $SHELL -e

    # Required for the file picker dialog - otherwise pcloud crashes.
    export XDG_DATA_DIRS="${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:\$XDG_DATA_DIRS"

    # On NixOS, OpenGL/EGL lives in /run/opengl-driver at runtime.
    export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib:\$LD_LIBRARY_PATH"

    # fusermount3 is a SUID wrapper provided by NixOS at runtime; pCloud needs
    # it in PATH to perform FUSE mounts.
    export PATH="/run/wrappers/bin:\$PATH"

    # Disable the GPU/EGL process; Electron sanitises LD_LIBRARY_PATH before
    # passing it to subprocesses so the GPU renderer can't find libEGL.so.1.
    # Software rendering is sufficient for pCloud's UI.
    exec "$out/app/pcloud" --disable-gpu "\$@"
    EOF
    chmod +x bin/pcloud
  '';

  meta = with lib; {
    description = "Secure and simple to use cloud storage for your files; pCloud Drive, Electron Edition";
    homepage = "https://www.pcloud.com/";
    changelog = "https://www.pcloud.com/release-notes/linux.html";
    downloadPage = "https://www.pcloud.com/release-notes/linux.html";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    license = licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "pcloud";
  };
}
