# Patched Klipper source derivation
#
# Applies custom patches to the klipper source tree.
# Used by both klippy (host software) and klipper-firmware (MCU).
{
  stdenv,
  src,
}:

stdenv.mkDerivation {
  pname = "klipper-src";
  version = "camshaft";
  inherit src;

  patches = let
    patchesDir = ../patches;
  in [
    "${patchesDir}/001-non-critical-mcu/0001-non-critical-mcu.patch"
    "${patchesDir}/003-neopixel-chain-size/0001-neopixel-increase-MAX_MCU_SIZE-to-768.patch"
    "${patchesDir}/004-set-led-count/0001-led-add-COUNT-parameter-to-SET_LED-command.patch"
  ];

  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';
}
