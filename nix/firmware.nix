# Klipper MCU firmware builder
#
# Builds Klipper firmware for MCU boards. Uses `make olddefconfig` to
# properly preserve choice options (like clock reference settings) from
# the provided firmware config.
#
# Usage:
#   klipper-firmware { mcu = "leviathan"; firmwareConfig = ./klipper.config; }
{
  stdenv,
  lib,
  python3,
  pkgsCross,
  gcc-arm-embedded,
  bintools-unwrapped,
  libffi,
  libusb1,
  pkg-config,
  klipper-src,
}: {
  mcu ? "mcu",
  firmwareConfig ? null,
}:
assert firmwareConfig != null;
  stdenv.mkDerivation {
    pname = "klipper-firmware-${mcu}";
    version = "camshaft";
    src = klipper-src;

    nativeBuildInputs = [
      python3
      pkgsCross.avr.stdenv.cc
      gcc-arm-embedded
      bintools-unwrapped
      libffi
      libusb1
      pkg-config
    ];

    postPatch = ''
      patchShebangs .
    '';

    configurePhase = ''
      runHook preConfigure
      cp ${firmwareConfig} ./.config
      chmod +w ./.config
      # olddefconfig fills in missing values without overriding choices
      make olddefconfig
      runHook postConfigure
    '';

    makeFlags = ["V=1"];

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp ./.config $out/config
      cp out/klipper.bin $out/ || true
      cp out/klipper.elf $out/ || true
      cp out/klipper.uf2 $out/ || true
      runHook postInstall
    '';

    dontFixup = true;

    meta = {
      description = "Klipper firmware for ${mcu}";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  }
