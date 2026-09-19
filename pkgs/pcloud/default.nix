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
  version = "2.2.1";
  publinkCode = "XZopbc5ZpqOBs9mkVRk4zDHD7TjDJpQBcfzk";

  src = stdenvNoCC.mkDerivation {
    name = "pCloud.AppImage";

    nativeBuildInputs = [ curl ];

    outputHashAlgo = "sha256";
    outputHashMode = "flat";
    outputHash = "3fddf5e975ffb38b968f5814cd8d0f2db1473ba49c1b2072f02911b5755e1f42";

    buildCommand = ''
      export SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"

      apiResponse="$(curl -fsSL "https://api.pcloud.com/getpublinkdownload?code=${publinkCode}")"
      dlHost="$(printf '%s' "$apiResponse" | grep -E -o '[a-zA-Z0-9-]+\.pcloud\.com' | head -n 1)"
      dlPath="$(printf '%s' "$apiResponse" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's#\\/#/#g')"

      if [ -z "$dlHost" ] || [ -z "$dlPath" ]; then
        echo "Failed to parse pCloud download API response" >&2
        echo "$apiResponse" >&2
        exit 1
      fi

      curl -fL "https://$dlHost$dlPath" -o "$out"
    '';
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
