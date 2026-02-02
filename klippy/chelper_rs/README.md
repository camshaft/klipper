# Rust Integration for Klipper

This directory contains Rust implementations of performance-critical components from the Klipper chelper library.

## Overview

The goal is to gradually port performance-critical C code to Rust while maintaining:
- Full compatibility with existing Python code
- Easy merging of upstream changes
- Functional equivalence between C and Rust implementations
- Performance equal to or better than the C version

## Quick Start

### Prerequisites

- Rust toolchain (install from https://rustup.rs/)
- Python 3.7 or later
- GCC (for existing C extensions)

### Building

```bash
# Build Rust extensions
python3 scripts/build_rust.py

# Or use cargo directly
cargo build --release
```

### Testing

```bash
# Run Rust unit tests
cargo test

# Run Python integration tests (if existing tests pass with Rust)
./scripts/test_klippy.py

# Benchmark C vs Rust performance
python3 scripts/benchmark_rust.py
```

## Architecture

### Current State
```
klippy/
├── chelper/          # C implementations (existing)
│   ├── trapq.c
│   ├── itersolve.c
│   ├── stepcompress.c
│   └── ...
└── chelper_rs/       # Rust implementations (new)
    ├── Cargo.toml
    ├── src/
    │   ├── lib.rs
    │   └── utils.rs
    └── __init__.py   # Python integration
```

### Module Organization

- **lib.rs** - PyO3 bindings and module initialization
- **utils.rs** - Utility functions (example/benchmarking)
- Future modules will mirror C implementations:
  - trapq.rs (motion queue)
  - itersolve.rs (kinematics solver)
  - stepcompress.rs (step compression)
  - etc.

## Performance-Critical Targets

Priority order for porting:

1. **itersolve.c** - Kinematics solver (~30-40% CPU in motion control)
2. **trapq.c** - Trapezoid motion queue
3. **stepcompress.c** - Step rate compression
4. **serialqueue.c** - MCU communication protocol
5. **steppersync.c** - Stepper synchronization
6. **kin_*.c** - Kinematics models

## Development Workflow

### Adding a New Module

1. **Create Rust module**: Add `my_module.rs` in `src/`
2. **Implement functionality**: Match C API and behavior
3. **Add PyO3 bindings**: Expose to Python in `lib.rs`
4. **Write tests**: Rust unit tests + Python integration tests
5. **Benchmark**: Compare with C implementation
6. **Document**: Update this README and main docs

### Example: Adding a Function

```rust
// In src/my_module.rs
use pyo3::prelude::*;

#[pyfunction]
pub fn my_function(x: f64, y: f64) -> PyResult<f64> {
    Ok(x + y)
}

// In src/lib.rs
pub mod my_module;

#[pymodule]
fn chelper_rs(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(my_module::my_function, m)?)?;
    Ok(())
}
```

### Testing for Equivalence

```python
# Test C and Rust give same results
import chelper
import chelper_rs

ffi, lib = chelper.get_ffi()

# Test inputs
x, y = 1.5, 2.5

# Compare outputs
c_result = lib.my_function(x, y)
rust_result = chelper_rs.my_function(x, y)

assert abs(c_result - rust_result) < 1e-10
```

## Current Implementation Status

- ✅ Build system integration
- ✅ PyO3 Python bindings
- ✅ Example utility functions
- ✅ Benchmarking framework
- ⏳ Trapezoid motion queue (trapq)
- ⏳ Kinematics solver (itersolve)
- ⏳ Step compression (stepcompress)
- ⏳ Other performance-critical modules

## Benefits of Rust

1. **Performance**: Zero-cost abstractions, similar to C
2. **Safety**: Memory safety without garbage collection
3. **Maintainability**: Better type system and error handling
4. **Tooling**: Excellent development tools (cargo, clippy, rustfmt)
5. **Future-proof**: Safe concurrency for future optimizations

## Integration with Python

Uses PyO3 to create Python extension modules:
- Native Python types (no FFI hassle)
- Automatic reference counting
- Python exceptions
- Similar performance to C extensions

## Documentation

See [docs/Rust_Migration.md](../docs/Rust_Migration.md) for detailed migration strategy.

## Contributing

When porting a module:
1. Keep C implementation unchanged (for upstream compatibility)
2. Create equivalent Rust implementation
3. Maintain identical Python API
4. Add comprehensive tests
5. Benchmark against C version
6. Document any differences or improvements

## License

Same as Klipper: GNU GPLv3
