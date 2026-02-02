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
    
    # List of functions to benchmark (function_name, iterations)
    functions_to_test = [
        ('get_monotonic', 100000),
    ]
    
    for func_name, iterations in functions_to_test:
        rust_func = getattr(rust_lib, func_name, None)
        c_func = getattr(clib, func_name, None) if c_available else None
        
        if rust_func is None:
            print(f"{func_name}: Not implemented in Rust")
            continue
        
        # Benchmark Rust version
        total, per_call = benchmark(rust_func, iterations)
        print(f"{func_name}: {per_call:.2f}ns/call ({total:.4f}s total)")
        
        # Compare with C if available
        if c_func is not None:
            c_total, c_per_call = benchmark(c_func, iterations)
            speedup = c_total / total
            print(f"  vs C: {c_per_call:.2f}ns/call ({speedup:.2f}x)")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
