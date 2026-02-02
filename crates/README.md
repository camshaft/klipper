# Klipper Rust Crates

This directory contains Rust implementations of performance-critical components from `klippy/chelper/`.

## Structure

- `chelper_rs/` - Rust port of C helper modules with PyO3 bindings

## Building

```bash
cargo build --release -p chelper_rs
```

## Usage

The modules auto-build on first import in Python:

```python
import chelper_rs
lib = chelper_rs.get_ffi()
if lib:
    time = lib.get_monotonic_rs()
```

## Benchmarking

```bash
python3 scripts/benchmark_rust.py
```
