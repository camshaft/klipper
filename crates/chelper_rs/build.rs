// Build script for chelper_rs
//
// This ensures PyO3 is properly configured for the Python version
// available in the build environment.

fn main() {
    pyo3_build_config::use_pyo3_cfgs();
}
