#!/usr/bin/env python3
"""
Build script for Rust chelper extensions

This script handles building the Rust chelper_rs module and making it
available to the Python code. It integrates with the existing build system.
"""

import os
import sys
import subprocess
import shutil
import logging

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
RUST_LIB_PATH = os.path.join(REPO_ROOT, "target", "release")
CHELPER_RS_DIR = os.path.join(REPO_ROOT, "klippy", "chelper_rs")

def check_rust_installed():
    """Check if Rust toolchain is installed"""
    try:
        result = subprocess.run(
            ["cargo", "--version"],
            capture_output=True,
            text=True,
            check=True
        )
        logging.info(f"Rust toolchain found: {result.stdout.strip()}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        logging.warning("Rust toolchain not found. Rust extensions will not be built.")
        logging.warning("Install Rust from: https://rustup.rs/")
        return False

def build_rust_extensions():
    """Build Rust extensions using Cargo"""
    if not check_rust_installed():
        return False
    
    logging.info("Building Rust extensions...")
    try:
        # Build in release mode for optimal performance
        result = subprocess.run(
            ["cargo", "build", "--release"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True
        )
        logging.info("Rust extensions built successfully")
        return True
    except subprocess.CalledProcessError as e:
        logging.error(f"Failed to build Rust extensions: {e}")
        logging.error(f"stdout: {e.stdout}")
        logging.error(f"stderr: {e.stderr}")
        return False

def find_rust_library():
    """Find the built Rust library"""
    # Library names vary by platform
    lib_patterns = [
        "libchelper_rs.so",      # Linux
        "chelper_rs.so",         # Linux (alternative)
        "libchelper_rs.dylib",   # macOS
        "chelper_rs.pyd",        # Windows
    ]
    
    for pattern in lib_patterns:
        lib_path = os.path.join(RUST_LIB_PATH, pattern)
        if os.path.exists(lib_path):
            return lib_path
    
    return None

def install_rust_library():
    """Copy the Rust library to the chelper_rs directory"""
    lib_path = find_rust_library()
    if not lib_path:
        logging.error(f"Could not find Rust library in {RUST_LIB_PATH}")
        return False
    
    # Destination should be chelper_rs.so (or .pyd on Windows)
    dest_name = "chelper_rs.so"
    if sys.platform == "win32":
        dest_name = "chelper_rs.pyd"
    elif sys.platform == "darwin":
        dest_name = "chelper_rs.so"  # PyO3 handles the extension
    
    dest_path = os.path.join(CHELPER_RS_DIR, dest_name)
    
    logging.info(f"Copying {lib_path} to {dest_path}")
    shutil.copy2(lib_path, dest_path)
    return True

def main():
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )
    
    # Check if we should skip Rust build (useful for CI/CD)
    if os.environ.get("SKIP_RUST_BUILD", "0") == "1":
        logging.info("SKIP_RUST_BUILD is set, skipping Rust extensions")
        return 0
    
    # Build and install
    if not build_rust_extensions():
        logging.warning("Rust extensions not available, falling back to C only")
        return 0  # Don't fail the build
    
    if not install_rust_library():
        logging.warning("Could not install Rust library")
        return 0  # Don't fail the build
    
    logging.info("Rust extensions ready!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
