# Klippy chelper - C extension modules
#
# Pre-compiles the chelper .so files with architecture-specific optimizations.
# Only rebuilds when chelper C code changes (~1min build).
#
# Expects klipper-src to be the filtered chelper source (klipper-src.chelper).
{
  lib,
  stdenv,
  python3,
  klipper-src,
}: let
  # Architecture-specific optimization flags
  chelperCflags =
    if stdenv.hostPlatform.isAarch64
    then "-march=armv8-a -mtune=cortex-a76 -ftree-vectorize"
    else if stdenv.hostPlatform.isAarch32
    then "-march=armv7-a -mfpu=neon-vfpv4 -ftree-vectorize"
    else if stdenv.hostPlatform.isx86_64
    then "-mfpmath=sse -msse2"
    else "";

  pythonWithCffi = python3.withPackages (ps: [ps.cffi]);
in
  stdenv.mkDerivation {
    pname = "klippy-chelper";
    version = "camshaft";
    src = klipper-src;

    nativeBuildInputs = [pythonWithCffi];

    # Patch chelper for cross-compilation and optimization
    postPatch = ''
      substituteInPlace klippy/chelper/__init__.py \
        --replace-quiet 'GCC_CMD = "gcc"' 'GCC_CMD = "${stdenv.cc.targetPrefix}cc"' \
        --replace-quiet \
          'COMPILE_ARGS = ("-Wall -g -O2 -shared -fPIC"' \
          'COMPILE_ARGS = ("-Wall -g -O3 -shared -fPIC ${chelperCflags}"'
    '';

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
      mkdir -p $out/lib
      # Copy the compiled .so file(s)
      cp klippy/chelper/*.so $out/lib/ 2>/dev/null || true
      # Also copy the Python interface
      mkdir -p $out/chelper
      cp klippy/chelper/*.py $out/chelper/
      cp klippy/chelper/*.so $out/chelper/ 2>/dev/null || true
      runHook postInstall
    '';

    meta = {
      description = "Klipper chelper C extension modules";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  }
