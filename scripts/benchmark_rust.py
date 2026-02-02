#!/usr/bin/env python3
"""
Benchmark chelper_rs performance

Compares Rust implementations against C baseline when both are available.
"""

import sys
import os
import time

# Add klippy to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'klippy'))

def benchmark(func, iterations=100000):
    """Simple benchmark helper"""
    start = time.perf_counter()
    for _ in range(iterations):
        func()
    elapsed = time.perf_counter() - start
    return elapsed, elapsed / iterations * 1e9  # ns per call

def main():
    # Import modules
    try:
        import chelper
        ffi, clib = chelper.get_ffi()
        c_available = True
    except Exception as e:
        print(f"C chelper not available: {e}")
        c_available = False
    
    try:
        import chelper_rs
        rust_lib = chelper_rs.get_ffi()
        rust_available = rust_lib is not None
    except Exception as e:
        print(f"Rust chelper_rs not available: {e}")
        rust_available = False
    
    if not rust_available:
        print("\nRust module not built. Run: cargo build --release -p chelper_rs")
        return 1
    
    print("\nBenchmarking chelper_rs functions:\n")
    
    # Benchmark available functions
    iterations = 100000
    
    if hasattr(rust_lib, 'get_monotonic_rs'):
        total, per_call = benchmark(rust_lib.get_monotonic_rs, iterations)
        print(f"get_monotonic_rs: {per_call:.2f}ns/call ({total:.4f}s total)")
        
        if c_available and hasattr(clib, 'get_monotonic'):
            c_total, c_per_call = benchmark(clib.get_monotonic, iterations)
            speedup = c_total / total
            print(f"  vs C get_monotonic: {c_per_call:.2f}ns/call ({speedup:.2f}x)")
    
    # Benchmark overhead function
    OVERHEAD_ITERATIONS = 1000
    if hasattr(rust_lib, 'benchmark_overhead'):
        result = rust_lib.benchmark_overhead(OVERHEAD_ITERATIONS)
        print(f"\nbenchmark_overhead({OVERHEAD_ITERATIONS}): {result*1e6:.2f}µs")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
