#!/usr/bin/env python3
"""
Performance comparison between C and Rust implementations

This script compares the performance of equivalent functions implemented
in C (chelper) and Rust (chelper_rs) to validate that the Rust implementation
meets or exceeds C performance.
"""

import sys
import os
import time
import statistics

# Add klipper to path
repo_root = os.path.join(os.path.dirname(__file__), '..')
sys.path.insert(0, os.path.join(repo_root, 'klippy'))
sys.path.insert(0, os.path.join(repo_root, 'klippy', 'chelper_rs'))

def benchmark_function(func, *args, iterations=1000000):
    """Benchmark a function call"""
    start = time.perf_counter()
    for _ in range(iterations):
        func(*args)
    end = time.perf_counter()
    return end - start

def main():
    print("=" * 60)
    print("Klipper C vs Rust Performance Comparison")
    print("=" * 60)
    print()
    
    # Try to import both implementations
    try:
        import chelper
        ffi, lib = chelper.get_ffi()
        c_available = True
        print("✓ C extensions (chelper) available")
    except Exception as e:
        c_available = False
        print(f"✗ C extensions not available: {e}")
    
    try:
        import chelper_rs
        rust_available = True
        print("✓ Rust extensions (chelper_rs) available")
    except Exception as e:
        rust_available = False
        print(f"✗ Rust extensions not available: {e}")
    
    print()
    
    if not (c_available and rust_available):
        print("Cannot run comparison without both implementations.")
        print("\nTo build C extensions:")
        print("  cd klippy/chelper && python3 __init__.py")
        print("\nTo build Rust extensions:")
        print("  python3 scripts/build_rust.py")
        return 1
    
    # Benchmark get_monotonic
    print("Benchmarking get_monotonic() equivalent:")
    print("-" * 60)
    
    iterations = 1000000
    trials = 5
    
    c_times = []
    rust_times = []
    
    for trial in range(trials):
        # Warm up
        for _ in range(1000):
            lib.get_monotonic()
            chelper_rs.get_monotonic_rs()
        
        # Benchmark C
        c_time = benchmark_function(lib.get_monotonic, iterations=iterations)
        c_times.append(c_time)
        
        # Benchmark Rust
        rust_time = benchmark_function(chelper_rs.get_monotonic_rs, iterations=iterations)
        rust_times.append(rust_time)
        
        print(f"Trial {trial + 1}: C={c_time:.4f}s, Rust={rust_time:.4f}s, "
              f"Ratio={rust_time/c_time:.2f}x")
    
    print()
    print("Summary Statistics:")
    print("-" * 60)
    
    c_mean = statistics.mean(c_times)
    rust_mean = statistics.mean(rust_times)
    c_stdev = statistics.stdev(c_times) if len(c_times) > 1 else 0
    rust_stdev = statistics.stdev(rust_times) if len(rust_times) > 1 else 0
    
    print(f"C implementation:")
    print(f"  Mean: {c_mean:.4f}s (±{c_stdev:.4f}s)")
    print(f"  Per call: {c_mean/iterations*1e9:.2f}ns")
    print()
    print(f"Rust implementation:")
    print(f"  Mean: {rust_mean:.4f}s (±{rust_stdev:.4f}s)")
    print(f"  Per call: {rust_mean/iterations*1e9:.2f}ns")
    print()
    
    ratio = rust_mean / c_mean
    if ratio < 1.0:
        print(f"🎉 Rust is {1/ratio:.2f}x FASTER than C")
    elif ratio < 1.05:
        print(f"✓ Rust performance is equivalent to C (within 5%)")
    elif ratio < 1.2:
        print(f"⚠ Rust is {ratio:.2f}x slower (acceptable for FFI overhead)")
    else:
        print(f"❌ Rust is {ratio:.2f}x slower (needs optimization)")
    
    print()
    print("=" * 60)
    print("Benchmark complete!")
    print("=" * 60)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
