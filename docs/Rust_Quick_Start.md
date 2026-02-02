# Quick Start Guide: Rust Integration

This guide shows how to build and use the Rust extensions in Klipper.

## Prerequisites

1. **Rust toolchain** (install from https://rustup.rs/):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

2. **Python dependencies**:
   ```bash
   pip install cffi greenlet
   ```

3. **GCC** for existing C extensions:
   ```bash
   sudo apt-get install gcc  # Ubuntu/Debian
   ```

## Building

### Quick Build (Recommended)
```bash
# From the klipper root directory
python3 scripts/build_rust.py
```

This will:
- Compile Rust code with `cargo build --release`
- Copy the resulting library to `klippy/chelper_rs/chelper_rs.so`
- Handle platform-specific file names automatically

### Manual Build
```bash
# Build Rust extensions
cargo build --release

# Copy library manually (Linux)
cp target/release/libchelper_rs.so klippy/chelper_rs/chelper_rs.so

# Copy library manually (macOS)
cp target/release/libchelper_rs.dylib klippy/chelper_rs/chelper_rs.so

# Copy library manually (Windows)
copy target\release\chelper_rs.pyd klippy\chelper_rs\chelper_rs.pyd
```

## Testing

### Run Example
```bash
python3 scripts/example_rust.py
```

Expected output:
- Both C and Rust implementations load successfully
- Functional equivalence demonstrated (within microseconds)
- Performance comparison showing Rust is faster

### Run Benchmarks
```bash
python3 scripts/benchmark_rust.py
```

Expected results:
- 5 benchmark trials comparing C and Rust
- Per-call timing in nanoseconds
- Overall speedup ratio (typically 2-3x for simple functions)

### Use in Python Code
```python
import sys
sys.path.insert(0, 'klippy/chelper_rs')
import chelper_rs

# Call Rust functions from Python
time = chelper_rs.get_monotonic_rs()
print(f"Current time: {time}")

# Benchmark overhead
duration = chelper_rs.benchmark_overhead(1000)
print(f"1000 iterations took {duration}s")
```

## Development Workflow

### Adding New Functions

1. **Define in Rust** (`klippy/chelper_rs/src/your_module.rs`):
   ```rust
   use pyo3::prelude::*;
   
   #[pyfunction]
   pub fn your_function(x: f64) -> PyResult<f64> {
       Ok(x * 2.0)
   }
   ```

2. **Export in lib.rs**:
   ```rust
   pub mod your_module;
   
   #[pymodule]
   fn chelper_rs(m: &Bound<'_, PyModule>) -> PyResult<()> {
       m.add_function(wrap_pyfunction!(your_module::your_function, m)?)?;
       Ok(())
   }
   ```

3. **Rebuild**:
   ```bash
   python3 scripts/build_rust.py
   ```

4. **Test**:
   ```python
   import chelper_rs
   result = chelper_rs.your_function(21.0)
   print(result)  # Should print 42.0
   ```

### Running Rust Unit Tests
```bash
cargo test
```

### Checking Code Quality
```bash
# Format code
cargo fmt

# Run linter
cargo clippy

# Check for common issues
cargo check
```

## Continuous Integration

To skip Rust builds in CI (useful if Rust toolchain isn't available):
```bash
export SKIP_RUST_BUILD=1
python3 scripts/build_rust.py  # Will exit gracefully
```

## Troubleshooting

### Rust not found
```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### Library not loading
```bash
# Check if library exists
ls -la klippy/chelper_rs/chelper_rs.so

# If not, rebuild
python3 scripts/build_rust.py
```

### Import error in Python
```python
# Make sure path is in sys.path
import sys
sys.path.insert(0, 'klippy/chelper_rs')
import chelper_rs
```

### Performance not as expected
- Make sure you built with `--release` flag
- Check that you're testing with sufficient iterations
- Verify PyO3 ABI3 settings are correct

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Python (klippy)                         │
│  - High-level control logic                                 │
│  - G-code parsing                                           │
│  - Configuration management                                 │
└──────────────────┬─────────────────┬────────────────────────┘
                   │                 │
         ┌─────────▼─────────┐  ┌───▼──────────────┐
         │  C Extensions      │  │ Rust Extensions  │
         │  (chelper/)        │  │ (chelper_rs/)    │
         │                    │  │                  │
         │  - Legacy code     │  │ - New code       │
         │  - Being phased    │  │ - Performance    │
         │    out gradually   │  │ - Safety         │
         └────────────────────┘  └──────────────────┘
                   │                 │
         ┌─────────▼─────────────────▼────────────────────────┐
         │            Microcontroller (src/)                   │
         │         - Real-time firmware                        │
         │         - Stepper control                           │
         └─────────────────────────────────────────────────────┘
```

## Next Steps

1. **Port trapq.c** - Motion queue management
2. **Port itersolve.c** - Kinematics solver (highest CPU usage)
3. **Add comprehensive tests** - Functional equivalence validation
4. **Optimize hot paths** - Use profiling to identify bottlenecks
5. **Benchmark thoroughly** - Ensure performance gains across board

## Resources

- [Rust Migration Strategy](../docs/Rust_Migration.md) - Full documentation
- [PyO3 Documentation](https://pyo3.rs/) - Python-Rust bindings
- [Rust Book](https://doc.rust-lang.org/book/) - Learn Rust
- [Klipper Documentation](https://www.klipper3d.org/) - Main project docs

## Support

For questions or issues:
1. Check the documentation in `docs/Rust_Migration.md`
2. Review examples in `scripts/example_rust.py`
3. Run benchmarks to verify your setup
4. Open an issue on GitHub with details
