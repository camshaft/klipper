# Klippy - Klipper host software with Rust entry point
#
# Builds the Rust klippy binary (via pyo3) and combines it with the
# klippy Python sources. Plugins are symlinked into extras/.
#
# The chelper C modules are pre-built during the nix build with native
# optimizations for the target architecture.
{
  lib,
  stdenv,
  makeWrapper,
  writeShellScript,
  python3,
  craneLib,
  klipper-src,
  plugins ? [],
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

  # Architecture-specific optimization flags for chelper compilation
  chelperCflags =
    if stdenv.hostPlatform.isAarch64
    then "-march=armv8-a -mtune=cortex-a76 -ftree-vectorize"
    else if stdenv.hostPlatform.isAarch32
    then "-march=armv7-a -mfpu=neon-vfpv4 -ftree-vectorize"
    else if stdenv.hostPlatform.isx86_64
    then "-mfpmath=sse -msse2"
    else "";

  # Filter to just the Rust sources for crane
  rustSrc = lib.cleanSourceWith {
    src = klipper-src;
    filter = path: type:
      (craneLib.filterCargoSources path type)
      || lib.hasSuffix "Cargo.toml" path
      || lib.hasSuffix "Cargo.lock" path;
  };

  # Build the Rust binary with crane
  klippyBin = craneLib.buildPackage {
    pname = "klippy";
    version = "0.0.0";
    src = rustSrc;

    nativeBuildInputs = [python3];
    buildInputs = [python3];

    # pyo3 needs to find Python
    PYO3_PYTHON = "${pythonEnv.interpreter}";

    # Ensure we link against the right libpython
    LD_LIBRARY_PATH = "${python3}/lib";
  };

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
in
  stdenv.mkDerivation {
    pname = "klippy";
    version = "camshaft";
    src = klipper-src;

    nativeBuildInputs = [
      makeWrapper
      (python3.withPackages (ps: [ps.cffi]))
    ];

    buildInputs = [pythonEnv];

    # Patch chelper for cross-compilation and optimization
    postPatch = ''
      for file in klippy/klippy.py klippy/console.py klippy/parsedump.py; do
        if [ -f "$file" ]; then
          substituteInPlace "$file" \
            --replace-quiet '/usr/bin/env python2' '/usr/bin/env python'
        fi
      done

      substituteInPlace klippy/chelper/__init__.py \
        --replace-quiet 'GCC_CMD = "gcc"' 'GCC_CMD = "${stdenv.cc.targetPrefix}cc"' \
        --replace-quiet \
          'COMPILE_ARGS = ("-Wall -g -O2 -shared -fPIC"' \
          'COMPILE_ARGS = ("-Wall -g -O3 -shared -fPIC ${chelperCflags}"'
    '';

    # Pre-build chelper C modules
    buildPhase = ''
      runHook preBuild
      echo "Building chelper with optimizations: ${chelperCflags}"
      cd klippy
      python ./chelper/__init__.py
      cd ..
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      # Install klippy Python sources
      mkdir -p $out/lib/klippy
      cp -r klippy/* $out/lib/klippy/

      # Install supporting files (for moonraker compatibility)
      cp -r docs $out/lib/docs
      cp -r config $out/lib/config
      cp -r scripts $out/lib/scripts

      # Write version
      echo "camshaft-NixOS" > $out/lib/klippy/.version

      # Install the Rust binary
      mkdir -p $out/bin
      install -Dm755 ${klippyBin}/bin/klippy $out/bin/klipper-unwrapped

      # Wrap binary with Python environment
      # --chdir ensures relative path lookups work (e.g. for .version file)
      makeWrapper $out/bin/klipper-unwrapped $out/bin/klipper \
        --set PYTHONHOME "${pythonEnv}" \
        --prefix PYTHONPATH : "$out/lib/klippy" \
        --prefix LD_LIBRARY_PATH : "${python3}/lib" \
        --chdir "$out/lib/klippy"

      # Install klipper-calibrate-shaper script (from nixpkgs pattern)
      substitute "${pythonScriptWrapper}" "$out/bin/klipper-calibrate-shaper" \
        --subst-var "out" \
        --subst-var-by "script" "calibrate_shaper.py"
      chmod 755 "$out/bin/klipper-calibrate-shaper"

      # Install klipper utility scripts with proper Python deps
      makeWrapper ${scriptsEnv}/bin/python3 $out/bin/klipper-canbus-query \
        --add-flags "$out/lib/scripts/canbus_query.py"

      makeWrapper ${scriptsEnv}/bin/python3 $out/bin/klipper-flash-can \
        --add-flags "$out/lib/scripts/flash_can.py"

      # Link plugins into extras/
      ${lib.concatMapStringsSep "\n" (
          plugin:
            if builtins.isAttrs plugin && plugin ? files
            then
              # Plugin with explicit file list: { name, src, files }
              lib.concatMapStringsSep "\n" (file: ''
                echo "Linking plugin file: ${plugin.name}/${file}"
                ln -sfv "${plugin.src}/${file}" "$out/lib/klippy/extras/"
              '')
              plugin.files
            else
              # Plugin as a path - link all .py and .cfg files
              ''
                echo "Linking plugin: ${plugin}"
                for f in ${plugin}/*.py ${plugin}/*.cfg; do
                  if [ -f "$f" ]; then
                    ln -sfv "$f" "$out/lib/klippy/extras/"
                  fi
                done
              ''
        )
        plugins}

      runHook postInstall
    '';

    passthru = {
      inherit pythonEnv klippyBin klipper-src;
      # Expose src for compatibility with nixpkgs klipper-genconf
      src = klipper-src;
      # Expose extraPythonPackages for downstream overriding
      inherit extraPythonPackages;
    };

    meta = {
      description = "Klipper host software (Rust + Python)";
      mainProgram = "klippy";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  }
