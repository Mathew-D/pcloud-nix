{ appimageTools
, alsa-lib
, autoPatchelfHook
, bashInteractive
, cacert
, curl
, dbus-glib
, fuse
, gsettings-desktop-schemas
, gtk3
, jq
, lib
, libdbusmenu-gtk3
, libgbm
, libglvnd
, libxdamage
, nss
, patchelfUnstable
, stdenv
, stdenvNoCC
, udev
}:

let
  pname = "pcloud";
  version = "2.4.0";
  # Use the same update feed as the pCloud desktop app. The AppImage URL in
  # the response is short-lived, so resolve it at build time.
  updateFeedUrl = "https://api.pcloud.com/getlastversion?os=ELECTRONV2";

  src = stdenvNoCC.mkDerivation {
    name = "pCloud.AppImage";

    nativeBuildInputs = [ curl jq ];

    outputHashAlgo = "sha256";
    outputHashMode = "flat";
    outputHash = "3c4f0201e06433f86ff6c7bf20d3fb8fd95a5ff6cf4114018ce1aec65292af44";

    buildCommand = ''
      export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"

      json="$(curl -fsSL "${updateFeedUrl}")"
      url="$(printf '%s\n' "$json" | jq -r '[.files[] | select(.url | endswith("/pCloud.AppImage")) | .url][0]')"

      if [ -z "$url" ] || [ "$url" = "null" ]; then
        echo "Failed to find pCloud.AppImage URL in update feed" >&2
        exit 1
      fi

      curl -fL "$url" -o "$out"
    '';
  };
in
stdenv.mkDerivation {
  inherit pname version;

  src = appimageTools.extract {
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

    rm -f app/resources/app.asar.unpacked/node_modules/koffi/build/koffi/musl_x64/koffi.node
    rm -f app/resources/app.asar.unpacked/node_modules/koffi/build/koffi/openbsd_x64/koffi.node
    rm -rf app/resources/app.asar.unpacked/node_modules/@koromix/koffi-linux-x64/musl_x64

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
