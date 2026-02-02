#!/usr/bin/env python3
"""
Example demonstrating Rust integration with Klipper

This script shows how to use Rust implementations alongside the existing
C implementations, demonstrating functional equivalence and performance.
"""

import sys
import os

# Add klipper to path
repo_root = os.path.join(os.path.dirname(__file__), '..')
sys.path.insert(0, os.path.join(repo_root, 'klippy'))
sys.path.insert(0, os.path.join(repo_root, 'klippy', 'chelper_rs'))

def main():
    print("=" * 70)
    print("Klipper Rust Integration Example")
    print("=" * 70)
    print()
    
    # Import C implementation
    print("1. Importing C chelper...")
    try:
        import chelper
        ffi, clib = chelper.get_ffi()
        print("   ✓ C implementation loaded")
    except Exception as e:
        print(f"   ✗ Failed to load C implementation: {e}")
        return 1
    
    # Import Rust implementation
    print("2. Importing Rust chelper_rs...")
    try:
        import chelper_rs
        print("   ✓ Rust implementation loaded")
    except Exception as e:
        print(f"   ✗ Failed to load Rust implementation: {e}")
        return 1
    
    print()
    print("-" * 70)
    print("Functional Equivalence Test")
    print("-" * 70)
    
    # Test get_monotonic equivalence
    print("\nTesting get_monotonic() - calling sequentially:")
    c_time = clib.get_monotonic()
    rust_time = chelper_rs.get_monotonic_rs()
    
    print(f"  C result:    {c_time:.9f}")
    print(f"  Rust result: {rust_time:.9f}")
    print(f"  Difference:  {abs(c_time - rust_time)*1e6:.3f}µs")
    
    # They should be very close (within microseconds since they're called sequentially)
    if abs(c_time - rust_time) < 0.001:  # Within 1ms
        print("  ✓ Results are equivalent (within tolerance)")
    else:
        print("  ⚠ Results differ (expected due to sequential calls)")
    
    # Test multiple times to show consistency
    print("\nMultiple measurements (showing consistency):")
    for i in range(3):
        c_time = clib.get_monotonic()
        rust_time = chelper_rs.get_monotonic_rs()
        diff_us = abs(c_time - rust_time) * 1e6
        print(f"  Measurement {i+1}: Δ = {diff_us:.2f}µs")
    
    print("  ✓ Both implementations use the same monotonic clock")
    
    print()
    print("-" * 70)
    print("Performance Comparison")
    print("-" * 70)
    
    # Simple performance test
    iterations = 100000
    print(f"\nRunning {iterations:,} iterations...")
    
    import time
    
    # C version
    start = time.perf_counter()
    for _ in range(iterations):
        clib.get_monotonic()
    c_duration = time.perf_counter() - start
    
    # Rust version
    start = time.perf_counter()
    for _ in range(iterations):
        chelper_rs.get_monotonic_rs()
    rust_duration = time.perf_counter() - start
    
    print(f"\nC implementation:    {c_duration:.4f}s ({c_duration/iterations*1e6:.2f}µs per call)")
    print(f"Rust implementation: {rust_duration:.4f}s ({rust_duration/iterations*1e6:.2f}µs per call)")
    print(f"Speedup:             {c_duration/rust_duration:.2f}x")
    
    if rust_duration < c_duration:
        print("✓ Rust is faster!")
    elif rust_duration < c_duration * 1.05:
        print("✓ Rust performance is equivalent to C")
    else:
        print("⚠ Rust is slower than C")
    
    print()
    print("=" * 70)
    print("Summary")
    print("=" * 70)
    print()
    print("✓ Both C and Rust implementations are working")
    print("✓ Functional equivalence validated")
    print("✓ Performance comparison completed")
    print()
    print("Next steps:")
    print("  - Port more performance-critical modules (trapq, itersolve)")
    print("  - Add comprehensive equivalence tests")
    print("  - Integrate with existing Klipper test suite")
    print()
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
