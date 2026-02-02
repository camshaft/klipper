// Rust implementation of Klipper chelper modules
//
// Copyright (C) 2024 Klipper Contributors <kevin@koconnor.net>
//
// This file may be distributed under the terms of the GNU GPLv3 license.

use pyo3::prelude::*;

pub mod utils;

/// Python module initialization
///
/// This module provides Rust implementations of performance-critical components
/// from the C chelper library. It can be used alongside the C implementation
/// to gradually migrate code while maintaining compatibility.
#[pymodule]
fn chelper_rs(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(utils::get_monotonic_rs, m)?)?;
    m.add_function(wrap_pyfunction!(utils::benchmark_overhead, m)?)?;
    Ok(())
}
