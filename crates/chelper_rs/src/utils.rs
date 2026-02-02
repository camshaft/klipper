// Utility functions for Rust chelper
//
// Copyright (C) 2024 Klipper Contributors <kevin@koconnor.net>
//
// This file may be distributed under the terms of the GNU GPLv3 license.

use pyo3::prelude::*;
use std::time::Instant;

/// Get monotonic time in seconds
///
/// Drop-in replacement for C get_monotonic() function.
/// Uses std::time::Instant for idiomatic Rust timing.
#[pyfunction]
pub fn get_monotonic() -> PyResult<f64> {
    static START: std::sync::OnceLock<Instant> = std::sync::OnceLock::new();
    let start = START.get_or_init(Instant::now);
    let elapsed = start.elapsed();
    Ok(elapsed.as_secs_f64())
}
