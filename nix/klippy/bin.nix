# Klippy Rust binary
#
# Builds just the Rust entry point (via pyo3). This is the most expensive
# part of the build (~2min) but only changes when Rust code changes.
#
# Expects klipper-src to be the filtered Rust source (klipper-src.rust).
{
  lib,
  python3,
  craneLib,
  klipper-src,
}:
craneLib.buildPackage {
  pname = "klippy-bin";
  version = "0.0.0";
  src = klipper-src;

  nativeBuildInputs = [python3];
  buildInputs = [python3];

  # pyo3 needs to find Python
  PYO3_PYTHON = "${python3}/bin/python3";

  # Ensure we link against the right libpython
  LD_LIBRARY_PATH = "${python3}/lib";

  meta = {
    description = "Klipper host software - Rust binary";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
