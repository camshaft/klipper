# Klippy Python sources
#
# Just copies the Python source files. Very fast, only changes when
# Python code in klippy/ changes.
#
# Expects klipper-src to be the filtered Python source (klipper-src.python).
# Patches are already applied by the filtered source derivation.
{
  lib,
  stdenv,
  klipper-src,
}:
stdenv.mkDerivation {
  pname = "klippy-python";
  version = "camshaft";
  src = klipper-src;

  # Patch shebang lines (patches to klippy code are in klipper-src.python)
  postPatch = ''
    for file in klippy/klippy.py klippy/console.py klippy/parsedump.py; do
      if [ -f "$file" ]; then
        substituteInPlace "$file" \
          --replace-quiet '/usr/bin/env python2' '/usr/bin/env python'
      fi
    done
  '';

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Install klippy Python sources (excluding chelper - that's separate)
    mkdir -p $out/lib/klippy
    cp -r klippy/* $out/lib/klippy/
    # Remove chelper dir if it exists - we'll link it from klippy-chelper
    rm -rf $out/lib/klippy/chelper 2>/dev/null || true

    # Install supporting files (for moonraker compatibility)
    cp -r docs $out/lib/docs
    cp -r config $out/lib/config
    cp -r scripts $out/lib/scripts

    # Write version
    echo "camshaft-NixOS" > $out/lib/klippy/.version

    runHook postInstall
  '';

  meta = {
    description = "Klipper Python sources";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
