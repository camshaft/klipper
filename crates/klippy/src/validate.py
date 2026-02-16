#!/usr/bin/env python3
"""Klipper configuration validation helper.

This module validates Klipper configuration files without connecting to MCUs.
It's used by the Rust klippy binary for the --validate-config flag and can be
invoked directly for Nix build-time validation.

Usage:
    python validate.py <config_file>
"""

import sys
import os
import logging
import site

# Ensure site-packages are loaded (needed when running via pyo3)
# This handles cases where Python is initialized without going through
# the normal interpreter startup sequence
site.main()

def validate_config(config_file):
    """Validate configuration file without connecting to MCUs.

    This function parses the config file, loads all referenced modules,
    and validates that all config options are recognized. It does NOT
    attempt to connect to any MCUs or start the printer.

    Returns True on success, raises an exception on failure.
    """
    # Debug: print sys.path
    logging.debug("sys.path: %s", sys.path)

    # Import klipper modules (requires PYTHONPATH to include klippy directory)
    import reactor
    import configfile
    import pins
    import mcu
    import toolhead

    logging.getLogger().setLevel(logging.INFO)
    logging.info("Validating configuration: %s", config_file)

    # Create a dummy file for gcode_fd (needed by GCodeIO initialization)
    # We use /dev/null since we won't actually process any gcode
    devnull = open(os.devnull, 'r')

    # Minimal start_args needed for config validation
    start_args = {
        'config_file': config_file,
        'start_reason': 'validate',
        'software_version': 'validation',
        'cpu_info': '',
        'device': '',
        'linux_version': '',
        'gcode_fd': devnull.fileno(),
        # Mark as file input so GCodeIO doesn't try to set up real I/O handlers
        'debuginput': '/dev/null',
        # Set debugoutput to skip hardware access in sensors like temperature_host
        'debugoutput': '/dev/null',
    }

    # Import Printer class
    from klippy import Printer

    # Create a validation-only printer
    main_reactor = reactor.Reactor(gc_checking=False)
    printer = Printer(main_reactor, None, start_args)

    try:
        # Read and validate config (this is the key validation step)
        printer.objects['configfile'] = pconfig = configfile.PrinterConfig(printer)
        config = pconfig.read_main_config()
        pconfig.log_config(config)

        # Create printer components (validates section names and options)
        for m in [pins, mcu]:
            m.add_printer_objects(config)
        for section_config in config.get_prefix_sections(''):
            printer.load_object(config, section_config.get_name(), None)
        for m in [toolhead]:
            m.add_printer_objects(config)

        # Check for undefined parameters
        pconfig.check_unused_options(config)

        logging.info("Configuration validation successful")
        return True
    except (configfile.error, pins.error) as e:
        logging.error("Config validation error: %s", str(e))
        raise
    except Exception as e:
        logging.error("Unexpected error during validation: %s", str(e))
        raise
    finally:
        main_reactor.finalize()
        devnull.close()


def main():
    """CLI entry point for direct invocation."""
    if len(sys.argv) != 2:
        print("Usage: python validate.py <config_file>", file=sys.stderr)
        sys.exit(2)

    config_file = sys.argv[1]

    if not os.path.exists(config_file):
        print(f"Error: Config file not found: {config_file}", file=sys.stderr)
        sys.exit(1)

    try:
        validate_config(config_file)
        sys.exit(0)
    except Exception as e:
        print(f"Validation failed: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
