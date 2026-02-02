// Utility functions for Rust chelper
//
// Copyright (C) 2024 Klipper Contributors <kevin@koconnor.net>
//
// This file may be distributed under the terms of the GNU GPLv3 license.

use pyo3::prelude::*;
use std::time::Instant;

/// Get monotonic time in seconds (Rust implementation)
///
/// Uses std::time::Instant for idiomatic Rust timing.
/// Returns seconds since an arbitrary starting point (monotonic).
#[pyfunction]
pub fn get_monotonic_rs() -> PyResult<f64> {
    // Note: Instant doesn't provide absolute time, only elapsed
    // For absolute monotonic time, we'd need to track a reference point
    // This is a simplified version for benchmarking purposes
    static START: std::sync::OnceLock<Instant> = std::sync::OnceLock::new();
    let start = START.get_or_init(Instant::now);
    let elapsed = start.elapsed();
    Ok(elapsed.as_secs() as f64 + elapsed.subsec_nanos() as f64 * 1e-9)
}

/// Benchmark function call overhead
///
/// Measures the overhead of calling Rust functions from Python.
#[pyfunction]
pub fn benchmark_overhead(iterations: usize) -> PyResult<f64> {
    let start = Instant::now();
    for _ in 0..iterations {
        std::hint::black_box(1 + 1);
    }
    let elapsed = start.elapsed();
    Ok(elapsed.as_secs() as f64 + elapsed.subsec_nanos() as f64 * 1e-9)
}
