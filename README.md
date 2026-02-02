Welcome to the Klipper project!

[![Klipper](docs/img/klipper-logo-small.png)](https://www.klipper3d.org/)

https://www.klipper3d.org/

The Klipper firmware controls 3d-Printers. It combines the power of a
general purpose computer with one or more micro-controllers. See the
[features document](https://www.klipper3d.org/Features.html) for more
information on why you should use the Klipper software.

Start by [installing Klipper software](https://www.klipper3d.org/Installation.html).

## Development

For developers looking to contribute or modify Klipper, we now provide a modern `pyproject.toml` configuration for easier dependency management. See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for detailed instructions on:

- Setting up a development environment
- Installing dependencies with pip
- Running tests and analysis scripts
- Building the package

Quick start for development:
```bash
# Install in development mode with all dependencies
pip install -e ".[dev]"

# Or install with only core dependencies
pip install -e .
```

Klipper software is Free Software. See the [license](COPYING) or read
the [documentation](https://www.klipper3d.org/Overview.html). We
depend on the generous support from our
[sponsors](https://www.klipper3d.org/Sponsors.html).
