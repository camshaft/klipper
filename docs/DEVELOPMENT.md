# Klipper Development Guide

This guide explains how to set up a development environment for Klipper using the new `pyproject.toml` configuration.

## Prerequisites

- Python 3.7 or higher
- pip (Python package installer)

## Installation Methods

### Standard Development Installation

To install Klipper in development mode with all core dependencies:

```bash
pip install -e .
```

This will install:
- All core runtime dependencies (greenlet, cffi, Jinja2, pyserial, python-can, etc.)
- Make the `klippy` command available in your environment
- Allow you to modify the code and see changes immediately without reinstalling

### Installing with Optional Dependencies

Klipper provides several optional dependency groups for different use cases:

#### Testing Dependencies
For running regression tests:
```bash
pip install -e ".[test]"
```

#### Graphing and Analysis Tools
For calibration and debugging scripts (includes numpy and matplotlib):
```bash
pip install -e ".[graphing]"
```

#### Documentation Building
For building the documentation with mkdocs:
```bash
pip install -e ".[docs]"
```

#### All Development Dependencies
To install everything (core + all optional dependencies):
```bash
pip install -e ".[dev]"
```

## Using Virtual Environments (Recommended)

It's recommended to use a Python virtual environment to avoid conflicts with system packages:

```bash
# Create a virtual environment
python3 -m venv ~/klippy-env

# Activate the virtual environment
source ~/klippy-env/bin/activate

# Install Klipper in development mode
pip install -e ".[dev]"
```

## Legacy Installation Method

The traditional installation method using requirements files still works:

```bash
# Core dependencies
pip install -r scripts/klippy-requirements.txt

# Testing dependencies
pip install -r scripts/tests-requirements.txt

# Documentation dependencies
pip install -r docs/_klipper3d/mkdocs-requirements.txt
```

## Dependency Management

All dependencies are now managed in `pyproject.toml`. The legacy requirements files (`scripts/klippy-requirements.txt`, etc.) are maintained for backward compatibility but the source of truth is now `pyproject.toml`.

### Updating Dependencies

To update a dependency:
1. Modify the version in `pyproject.toml`
2. Test the changes
3. Update the corresponding requirements file if needed for backward compatibility

## Building the Package

To build distribution packages:

```bash
pip install build
python -m build
```

This will create both wheel and source distributions in the `dist/` directory.

## Running Klippy

Klipper is designed to be run directly from the repository rather than as an installed package. After installation in development mode, run klippy using:

```bash
python klippy/klippy.py /path/to/config.cfg
```

Or use the traditional method if you have the scripts set up:

```bash
~/klippy-env/bin/python ~/klipper/klippy/klippy.py /path/to/config.cfg
```

## Running Tests

```bash
# After installing with test dependencies
python scripts/test_klippy.py test/klippy/*.test
```

## Running Analysis Scripts

After installing with graphing dependencies, you can use the analysis scripts:

```bash
# Calibrate input shaper
python scripts/calibrate_shaper.py /tmp/resonances_x_*.csv -o /tmp/shaper_calibrate_x.png

# Graph accelerometer data
python scripts/graph_accelerometer.py /tmp/adxl345-*.csv -o /tmp/accel.png

# Other graphing tools
python scripts/graph_extruder.py
python scripts/graph_motion.py
python scripts/graphstats.py
```

## Troubleshooting

### Import Errors
If you encounter import errors after installation, ensure:
1. Your virtual environment is activated (if using one)
2. You've installed the package in editable mode: `pip install -e .`
3. The required optional dependencies are installed for the script you're running

### Build Errors
If you encounter build errors for cffi or greenlet:
- Ensure you have the required system packages (gcc, python-dev, libffi-dev)
- On Debian/Ubuntu: `sudo apt-get install build-essential python3-dev libffi-dev`
- On other systems, refer to `scripts/install-*.sh` for system-specific packages

## Security Note

The dependency versions in `pyproject.toml` match those in the existing requirements files to maintain compatibility. Some dependencies (like MarkupSafe 1.1.1 and mkdocs 1.2.4) are older versions. If you're concerned about security:

- For production use, follow the official installation guide which uses tested versions
- For development, consider updating dependencies after thorough testing
- Documentation dependencies (mkdocs) are only needed for building docs, not for runtime

When updating dependencies, test thoroughly and update both `pyproject.toml` and the corresponding requirements files in `scripts/`.

## More Information

For detailed installation instructions and system setup, see:
- [Installation Guide](https://www.klipper3d.org/Installation.html)
- [Overview](https://www.klipper3d.org/Overview.html)
