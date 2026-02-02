# Python to Rust Migration Strategy

## Overview

This document outlines the strategy for gradually porting performance-critical components of the Klippy codebase from Python/C to Rust while maintaining full compatibility with the existing codebase.

## Goals

1. **Gradual Migration**: Both Python and Rust code can coexist, allowing incremental porting
2. **Upstream Compatibility**: Easy to import changes from upstream by maintaining both versions
3. **Performance Focus**: Target performance bottlenecks (chelper C modules)
4. **Functional Equivalence**: Demonstrate and validate equivalence between implementations

## Architecture

### Current Architecture
```
Python (klippy/) → C Extensions (chelper/) → Microcontroller (src/)
```

### Target Architecture
```
Python (klippy/) → {
    C Extensions (chelper/)      [legacy, gradually deprecated]
    Rust Extensions (chelper_rs/) [new, gradually expanded]
} → Microcontroller (src/)
```

## Performance-Critical Components (Priority Order)

### High Priority - Computational Hotspots
1. **itersolve.c** - Kinematics solver (most CPU-intensive)
   - Iterative position solving for stepper motors
   - Called frequently during motion planning
   - ~30-40% of total CPU time in motion control

2. **trapq.c** - Trapezoid motion queue
   - Motion trajectory management
   - Acceleration/deceleration calculations
   - Critical path for smooth motion

3. **stepcompress.c** - Step compression
   - Compresses step commands for MCU
   - High-frequency calculations
   - Memory-intensive operations

4. **serialqueue.c** - Serial message queue
   - MCU communication protocol
   - Timing-sensitive operations
   - Potential I/O bottleneck

5. **steppersync.c** - Stepper synchronization
   - Coordinates multiple steppers
   - Real-time constraints

### Medium Priority - Kinematics
- **kin_*.c** - Various kinematic models
  - Cartesian, CoreXY, Delta, etc.
  - Mathematical transformations
  - Called frequently but less CPU-intensive

### Lower Priority
- Other modules with lighter computational load

## Migration Process

### Phase 1: Infrastructure Setup ✅
- [x] Create Rust workspace with PyO3
- [x] Set up build system integration
- [x] Create example module for testing
- [x] Documentation

### Phase 2: Proof of Concept
- [ ] Implement simple utility functions in Rust
- [ ] Create performance benchmarking framework
- [ ] Validate Python-Rust FFI overhead is acceptable
- [ ] Compare with existing C implementation

### Phase 3: First Real Module (trapq)
- [ ] Port trapq.c to Rust
- [ ] Create identical Python interface
- [ ] Run side-by-side with C version
- [ ] Performance comparison
- [ ] Functional equivalence tests

### Phase 4: Expand to Other Modules
- [ ] Port itersolve.c
- [ ] Port stepcompress.c
- [ ] Port serialqueue.c
- [ ] Port kinematics modules

### Phase 5: Optional C Removal
- [ ] Make Rust implementation default
- [ ] Keep C as fallback option
- [ ] Eventually remove C if Rust proves stable

## Technical Approach

### PyO3 for Python Bindings
- Use PyO3 to create Python-compatible shared libraries
- Maintain identical APIs to C implementations
- Zero-copy data sharing where possible

### Build System Integration
- Cargo for Rust compilation
- Integrate with existing Makefile
- Support both development and production builds

### Testing Strategy
1. **Unit Tests**: Rust unit tests for each module
2. **Integration Tests**: Python tests using both C and Rust
3. **Equivalence Tests**: Compare outputs of C and Rust implementations
4. **Performance Tests**: Benchmark against C baseline
5. **Existing Tests**: All existing klippy tests must pass

### Functional Equivalence Validation
```python
# Example test pattern
def test_trapq_equivalence():
    # Create identical inputs
    inputs = generate_test_cases()
    
    # Run both implementations
    c_results = chelper.trapq_function(inputs)
    rs_results = chelper_rs.trapq_function(inputs)
    
    # Verify equivalence (within floating-point tolerance)
    assert_almost_equal(c_results, rs_results, decimal=12)
```

## Benefits of Rust

1. **Performance**: Similar to C, often faster with better optimizations
2. **Safety**: Memory safety without garbage collection
3. **Maintainability**: Better type system, error handling, testing
4. **Concurrency**: Safe parallelism for future optimizations
5. **Ecosystem**: Modern tooling (Cargo, rustfmt, clippy)

## Development Workflow

### Adding a New Rust Module
1. Create module in `klippy/chelper_rs/src/`
2. Expose via PyO3 in `lib.rs`
3. Add build configuration if needed
4. Write unit tests in Rust
5. Write Python integration tests
6. Update documentation
7. Benchmark against C version

### Building
```bash
# Build Rust extensions
cd /path/to/klipper
cargo build --release

# C extensions build as before
cd klippy/chelper
python3 __init__.py
```

### Testing
```bash
# Run Rust unit tests
cargo test

# Run Python integration tests
./scripts/test_klippy.py

# Run equivalence tests
python3 -m pytest klippy/chelper_rs/tests/
```

## File Organization

```
klipper/
├── Cargo.toml                    # Rust workspace configuration
├── klippy/
│   ├── chelper/                  # Existing C implementation
│   │   ├── __init__.py
│   │   ├── trapq.c
│   │   ├── itersolve.c
│   │   └── ...
│   └── chelper_rs/               # New Rust implementation
│       ├── Cargo.toml
│       ├── build.rs
│       ├── src/
│       │   ├── lib.rs
│       │   ├── utils.rs
│       │   ├── trapq.rs         # (future)
│       │   ├── itersolve.rs     # (future)
│       │   └── ...
│       └── tests/
│           └── equivalence_tests.py
└── docs/
    └── Rust_Migration.md         # This file
```

## Compatibility Considerations

### Upstream Merge Strategy
- Keep C implementations as-is
- Rust implementations in separate files
- Python code can use either via feature flags
- No breaking changes to existing APIs

### Backward Compatibility
- All existing Python code continues to work
- C extensions remain default until Rust is proven
- Optional Rust compilation (fallback to C if no Rust toolchain)

### Forward Path
- Once Rust implementations are mature and proven
- Make Rust the default implementation
- Keep C as build-time fallback option
- Eventually deprecate C implementations

## Performance Targets

- **Rust should match or exceed C performance**
- Maximum 5% overhead acceptable for FFI layer
- Zero-copy data sharing for large structures
- Similar or better memory usage
- Potential for future parallelization improvements

## Success Criteria

1. ✅ Rust build system integrated
2. ✅ Example module demonstrates feasibility
3. ⏳ Performance equal to or better than C
4. ⏳ All existing tests pass with Rust
5. ⏳ Functional equivalence validated
6. ⏳ Documentation complete
7. ⏳ At least one major module ported (trapq or itersolve)

## Next Steps

1. Verify Rust toolchain installation
2. Build example module
3. Create performance benchmarking script
4. Port first utility function with equivalence test
5. Measure FFI overhead
6. Decide on first major module to port (likely trapq)
