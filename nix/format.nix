# Klipper INI format
#
# The standard pkgs.formats.ini is broken for Klipper because:
#   1. Booleans are formatted as lowercase "true"/"false" but Klipper's
#      Python configparser expects Python-style "True"/"False"
#   2. Multiline gcode values need special indentation handling
#   3. The separator must be ":" not "="
#
# This module provides a drop-in replacement for pkgs.formats.ini
# that correctly handles all of Klipper's config requirements.
#
# Usage from a NixOS module:
#   format = klipper.lib.mkKlipperFormat pkgs;
#   # or via overlay:
#   format = pkgs.klipperFormat;
{
  lib,
  pkgs,
}: let
  # Format a value the way Klipper expects it
  mkKlipperValue = v:
    if v == true
    then "True"
    else if v == false
    then "False"
    else lib.generators.mkValueStringDefault {} v;

  # Handle multiline values (e.g. gcode macros) by indenting continuation lines
  formatMultilineValue = str: let
    lines = lib.splitString "\n" str;
    # Indent continuation lines with 2 spaces for Klipper's configparser
    indentedLines =
      map (
        line:
          if line == ""
          then ""
          else "  ${line}"
      )
      lines;
  in
    "\n" + lib.concatStringsSep "\n" indentedLines;
in
  pkgs.formats.ini {
    # Handle list values (e.g. pin lists)
    listToValue = l:
      if builtins.length l == 1
      then mkKlipperValue (lib.head l)
      else lib.concatMapStrings (s: "\n  ${mkKlipperValue s}") l;

    # Use ":" separator and handle booleans + multiline values
    mkKeyValue = lib.generators.mkKeyValueDefault {
      mkValueString = v: let
        str = mkKlipperValue v;
      in
        if lib.hasInfix "\n" str
        then formatMultilineValue str
        else str;
    } ":";
  }
