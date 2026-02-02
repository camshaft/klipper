# pyproject.toml for Modern Python Dependency Management

## Overview

This patch adds a PEP 517/518-compliant `pyproject.toml` file to Klipper, providing modern Python dependency management and easier development setup.

## Problem

Klipper currently manages dependencies through multiple `requirements.txt` files scattered across the repository:
- `scripts/klippy-requirements.txt` - Core runtime dependencies
- `scripts/tests-requirements.txt` - Testing dependencies  
- `docs/_klipper3d/mkdocs-requirements.txt` - Documentation dependencies

While functional, this approach:
- Lacks standardization for Python project metadata
- Makes it harder to install optional dependency groups
- Doesn't integrate well with modern Python tooling (pip, build, etc.)
- Requires manual management of different requirement files

## Solution

This patch adds a `pyproject.toml` file that:
- Consolidates all dependency information in one standard location
- Defines project metadata (name, version, description, license, etc.)
- Organizes dependencies into logical groups (core, test, graphing, docs, dev)
- Enables easy installation with `pip install -e .` or `pip install -e ".[dev]"`
- Maintains full backward compatibility with existing requirements files

## Configuration

### Installation Methods

**Core dependencies only:**
```bash
pip install -e .
```

**With testing dependencies:**
```bash
pip install -e ".[test]"
```

**With graphing tools (for calibration scripts):**
```bash
pip install -e ".[graphing]"
```

**With documentation tools:**
```bash
pip install -e ".[docs]"
```

**Everything for development:**
```bash
pip install -e ".[dev]"
```

### Dependency Groups

- **Core**: Runtime dependencies (greenlet, cffi, Jinja2, pyserial, python-can, msgspec)
- **test**: scipy for regression tests
- **graphing**: numpy and matplotlib for analysis/calibration scripts
- **docs**: mkdocs and related tools for documentation building
- **dev**: All of the above combined

## Use Cases

### Developer Setup

Quick development environment setup:
```bash
cd ~/klipper
python3 -m venv ~/klippy-env
source ~/klippy-env/bin/activate
pip install -e ".[dev]"
```

### Analysis Scripts

Install dependencies for running calibration/analysis scripts:
```bash
pip install -e ".[graphing]"
python scripts/calibrate_shaper.py /tmp/resonances_x_*.csv -o /tmp/shaper.png
python scripts/graph_accelerometer.py /tmp/adxl345-*.csv -o /tmp/accel.png
```

### Continuous Integration

Install only what's needed for testing:
```bash
pip install -e ".[test]"
python scripts/test_klippy.py test/klippy/*.test
```

## Benefits

1. **Standardization**: Uses PEP 517/518 standards recognized by the Python ecosystem
2. **Simplified Setup**: Single command to install all or specific dependency groups
3. **Better Tooling**: Works seamlessly with pip, build, and other modern tools
4. **Flexibility**: Install only the dependencies you need
5. **Backward Compatible**: Existing requirements files remain functional
6. **Clear Documentation**: All dependencies documented in one place

## Technical Details

- Uses setuptools as the build backend (PEP 517)
- Automatically discovers packages under `klippy/`
- Specifies Python >=3.7 requirement
- Includes proper classifiers for PyPI compatibility
- Maintains exact version pins from original requirements files
- Uses environment markers for Python version-specific dependencies

## Files Modified

- `.gitignore`: Added Python packaging artifacts (*.egg-info, dist/, build/, __pycache__/)
- `pyproject.toml`: New file with complete project configuration

## Backward Compatibility

The existing requirements files in `scripts/` remain unchanged and fully functional. Users can continue using:
```bash
pip install -r scripts/klippy-requirements.txt
```

The `pyproject.toml` provides an additional, more convenient option without breaking existing workflows.

## Reference

This follows modern Python packaging best practices as documented in:
- PEP 517: A build-system independent format for source trees
- PEP 518: Specifying Minimum Build System Requirements for Python Projects
- Python Packaging User Guide: https://packaging.python.org/
