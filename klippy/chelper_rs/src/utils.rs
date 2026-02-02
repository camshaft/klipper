// Utility functions for Rust chelper
//
// Copyright (C) 2024 Klipper Contributors <kevin@koconnor.net>
//
// This file may be distributed under the terms of the GNU GPLv3 license.

use pyo3::prelude::*;

/// Get monotonic time in seconds (Rust implementation)
///
/// This is a Rust equivalent of the C get_monotonic() function.
/// Uses CLOCK_MONOTONIC_RAW for consistency with the C implementation.
#[pyfunction]
pub fn get_monotonic_rs() -> PyResult<f64> {
    #[cfg(target_os = "linux")]
    {
        use libc::{clock_gettime, timespec, CLOCK_MONOTONIC_RAW};
        use std::mem::MaybeUninit;
        
        unsafe {
            let mut ts = MaybeUninit::<timespec>::uninit();
            let ret = clock_gettime(CLOCK_MONOTONIC_RAW, ts.as_mut_ptr());
            if ret != 0 {
                return Err(PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
                    "clock_gettime failed"
                ));
            }
            let ts = ts.assume_init();
            Ok(ts.tv_sec as f64 + ts.tv_nsec as f64 * 1e-9)
        }
    }
    #[cfg(not(target_os = "linux"))]
    {
        // Fallback for non-Linux systems
        use std::time::{SystemTime, UNIX_EPOCH};
        let duration = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| PyErr::new::<pyo3::exceptions::PyRuntimeError, _>(
                format!("Time error: {}", e)
            ))?;
        Ok(duration.as_secs() as f64 + duration.subsec_nanos() as f64 * 1e-9)
    }
}

/// Benchmark function call overhead
///
/// This function helps measure the overhead of calling into Rust from Python
/// compared to calling into C. Useful for performance comparisons.
#[pyfunction]
pub fn benchmark_overhead(iterations: usize) -> PyResult<f64> {
    let start = get_monotonic_rs()?;
    for _ in 0..iterations {
        // Minimal work to measure overhead
        std::hint::black_box(1 + 1);
    }
    let end = get_monotonic_rs()?;
    Ok(end - start)
}
