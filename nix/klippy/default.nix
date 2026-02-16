# Klippy - Klipper host software (assembled)
#
# Combines the Rust binary, chelper, and Python sources into a working
# klippy installation. Does NOT include plugins - use withPlugins for that.
#
# This derivation is fast since it just combines pre-built components.
{
  lib,
  stdenv,
  makeWrapper,
  writeShellScript,
  runCommand,
  python3,
  klippy-bin,
  klippy-chelper,
  klippy-python,
  extraPythonPackages ? ps: [],
}: let
  # Python environment with all runtime dependencies
  pythonEnv = python3.withPackages (ps:
    with ps;
      [
        cffi
        greenlet
        jinja2
        markupsafe
        numpy
        pyserial
        python-can
      ]
      ++ lib.optionals (lib.versionAtLeast python3.version "3.9") [
        msgspec
      ]
      ++ lib.optionals (lib.versionAtLeast python3.version "3.12") [
        setuptools
      ]
      ++ (extraPythonPackages ps));

  # Script wrapper template for klipper Python scripts
  pythonInterpreter =
    (python3.withPackages (ps:
      with ps; [
        numpy
        matplotlib
      ])).interpreter;

  pythonScriptWrapper = writeShellScript "klippy-script" ''
    ${pythonInterpreter} "@out@/lib/scripts/@script@" "$@"
  '';

  # Python env for klipper utility scripts (canbus_query, flash_can, etc.)
  scriptsEnv = python3.withPackages (ps: [
    ps.pyserial
    ps.python-can
    ps.packaging
  ]);

  # Helper to install a plugin
  installPlugin = plugin:
    if builtins.isAttrs plugin && plugin ? files
    then let
      patches = plugin.patches or [];
      patchedFiles = map (p: p.file) patches;
      filesToPatch = builtins.filter (f: builtins.elem (baseNameOf f) patchedFiles) plugin.files;
      filesToLink = builtins.filter (f: !(builtins.elem (baseNameOf f) patchedFiles)) plugin.files;
    in
      ''
        echo "Installing plugin: ${plugin.name}"
      ''
      + lib.concatMapStringsSep "\n" (file: ''
        echo "Linking plugin file: ${plugin.name}/${file}"
        ln -sfv "${plugin.src}/${file}" "$out/lib/klippy/extras/"
      '')
      filesToLink
      + lib.concatMapStringsSep "\n" (file: let
        basename = baseNameOf file;
        patch = lib.findFirst (p: p.file == basename) null patches;
      in ''
        echo "Copying and patching plugin file: ${plugin.name}/${file}"
        cp "${plugin.src}/${file}" "$out/lib/klippy/extras/${basename}"
        chmod +w "$out/lib/klippy/extras/${basename}"
        sed -i '${patch.sed}' "$out/lib/klippy/extras/${basename}"
      '')
      filesToPatch
    else ''
      echo "Linking plugin: ${plugin}"
      for f in ${plugin}/*.py ${plugin}/*.cfg; do
        if [ -f "$f" ]; then
          ln -sfv "$f" "$out/lib/klippy/extras/"
        fi
      done
    '';

  # Base klippy without plugins
  klippy-base = stdenv.mkDerivation {
    pname = "klippy";
    version = "camshaft";

    # No source - we're just assembling pre-built components
    dontUnpack = true;

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      # Create output structure
      mkdir -p $out/bin $out/lib

      # Link Python sources
      ln -s ${klippy-python}/lib/klippy $out/lib/klippy
      ln -s ${klippy-python}/lib/docs $out/lib/docs
      ln -s ${klippy-python}/lib/config $out/lib/config
      ln -s ${klippy-python}/lib/scripts $out/lib/scripts

      # The chelper needs to be in klippy/chelper, but we symlinked klippy/
      # So we need to make klippy/ a real dir with chelper linked in
      rm $out/lib/klippy
      mkdir -p $out/lib/klippy
      for f in ${klippy-python}/lib/klippy/*; do
        ln -s "$f" $out/lib/klippy/
      done
      # Link chelper from the chelper package
      rm -f $out/lib/klippy/chelper 2>/dev/null || true
      ln -s ${klippy-chelper}/chelper $out/lib/klippy/chelper

      # Install the Rust binary
      install -Dm755 ${klippy-bin}/bin/klippy $out/bin/klippy-unwrapped

      # Wrap binary with Python environment
      makeWrapper $out/bin/klippy-unwrapped $out/bin/klippy \
        --set PYTHONHOME "${pythonEnv}" \
        --prefix PYTHONPATH : "$out/lib/klippy" \
        --prefix LD_LIBRARY_PATH : "${python3}/lib" \
        --chdir "$out/lib/klippy"

      # Install klipper-calibrate-shaper script
      substitute "${pythonScriptWrapper}" "$out/bin/klipper-calibrate-shaper" \
        --subst-var "out" \
        --subst-var-by "script" "calibrate_shaper.py"
      chmod 755 "$out/bin/klipper-calibrate-shaper"

      # Install klipper utility scripts
      makeWrapper ${scriptsEnv}/bin/python3 $out/bin/klipper-canbus-query \
        --add-flags "$out/lib/scripts/canbus_query.py"

      makeWrapper ${scriptsEnv}/bin/python3 $out/bin/klipper-flash-can \
        --add-flags "$out/lib/scripts/flash_can.py"

      runHook postInstall
    '';

    passthru = {
      inherit pythonEnv klippy-bin klippy-chelper klippy-python;
      src = klippy-python.src or klippy-python;
      inherit extraPythonPackages;

      # withPlugins: Create a new klippy with plugins installed
      # This uses runCommand so it's very fast - no rebuilding!
      withPlugins = plugins:
        runCommand "klippy-with-plugins" {
          nativeBuildInputs = [makeWrapper];
        } ''
          # Copy the base klippy structure (not symlink, we need to modify lib/klippy/extras)
          mkdir -p $out/bin $out/lib

          # Link bin directory contents
          for f in ${klippy-base}/bin/*; do
            ln -s "$f" $out/bin/
          done

          # Link most of lib/
          ln -s ${klippy-base}/lib/docs $out/lib/docs
          ln -s ${klippy-base}/lib/config $out/lib/config
          ln -s ${klippy-base}/lib/scripts $out/lib/scripts

          # For klippy/, we need to be able to add to extras/
          mkdir -p $out/lib/klippy
          for f in ${klippy-base}/lib/klippy/*; do
            name=$(basename "$f")
            if [ "$name" != "extras" ]; then
              ln -s "$f" "$out/lib/klippy/$name"
            fi
          done

          # Copy extras/ so we can add plugins
          mkdir -p $out/lib/klippy/extras
          for f in ${klippy-base}/lib/klippy/extras/*; do
            ln -s "$f" "$out/lib/klippy/extras/"
          done

          # Install plugins
          ${lib.concatMapStringsSep "\n" installPlugin plugins}

          # Re-wrap the binary to point to our new lib/klippy
          rm $out/bin/klipper
          makeWrapper ${klippy-base}/bin/klipper-unwrapped $out/bin/klipper \
            --set PYTHONHOME "${pythonEnv}" \
            --prefix PYTHONPATH : "$out/lib/klippy" \
            --prefix LD_LIBRARY_PATH : "${python3}/lib" \
            --chdir "$out/lib/klippy"
        '';
    };

    meta = {
      description = "Klipper host software (Rust + Python)";
      mainProgram = "klipper";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  };
in
  klippy-base
