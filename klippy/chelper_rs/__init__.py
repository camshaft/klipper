# Rust chelper module
#
# Copyright (C) 2024  Klipper Contributors
#
# This file may be distributed under the terms of the GNU GPLv3 license.
import os, sys, logging, subprocess, shutil

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
RUST_LIB_PATH = os.path.join(REPO_ROOT, "target", "release")
DEST_LIB = "chelper_rs.so"

def check_rust_available():
    """Check if Rust toolchain is available"""
    try:
        subprocess.run(["cargo", "--version"], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False

def get_lib_path():
    """Get expected library path after build"""
    if sys.platform == "win32":
        return os.path.join(RUST_LIB_PATH, "chelper_rs.pyd")
    elif sys.platform == "darwin":
        return os.path.join(RUST_LIB_PATH, "libchelper_rs.dylib")
    else:
        return os.path.join(RUST_LIB_PATH, "libchelper_rs.so")

def check_build_needed():
    """Check if Rust library needs to be built"""
    srcdir = os.path.dirname(os.path.realpath(__file__))
    destlib = os.path.join(srcdir, DEST_LIB)
    
    if not os.path.exists(destlib):
        return True
    
    # Check if source files are newer
    crate_dir = os.path.join(REPO_ROOT, "crates", "chelper_rs")
    cargo_toml = os.path.join(crate_dir, "Cargo.toml")
    
    if not os.path.exists(cargo_toml):
        return False
        
    dest_mtime = os.path.getmtime(destlib)
    
    # Check Cargo.toml
    if os.path.getmtime(cargo_toml) > dest_mtime:
        return True
    
    # Check source files
    src_dir = os.path.join(crate_dir, "src")
    if os.path.exists(src_dir):
        for root, dirs, files in os.walk(src_dir):
            for f in files:
                if f.endswith('.rs'):
                    if os.path.getmtime(os.path.join(root, f)) > dest_mtime:
                        return True
    
    return False

def build_rust_library():
    """Build the Rust library using cargo"""
    if not check_rust_available():
        return None
    
    if not check_build_needed():
        srcdir = os.path.dirname(os.path.realpath(__file__))
        return os.path.join(srcdir, DEST_LIB)
    
    logging.info("Building Rust chelper_rs module")
    try:
        subprocess.run(
            ["cargo", "build", "--release", "-p", "chelper_rs"],
            cwd=REPO_ROOT,
            check=True,
            capture_output=True
        )
    except subprocess.CalledProcessError as e:
        logging.warning("Failed to build Rust module: %s", e.stderr.decode())
        return None
    
    # Copy library to package directory
    lib_path = get_lib_path()
    if not os.path.exists(lib_path):
        logging.warning("Rust library not found at %s", lib_path)
        return None
    
    srcdir = os.path.dirname(os.path.realpath(__file__))
    destlib = os.path.join(srcdir, DEST_LIB)
    shutil.copy2(lib_path, destlib)
    
    logging.info("Rust chelper_rs module built successfully")
    return destlib

# Try to build and import the Rust module
_rust_lib = None
_lib_path = build_rust_library()

if _lib_path and os.path.exists(_lib_path):
    try:
        # Import the compiled extension
        import importlib.util
        spec = importlib.util.spec_from_file_location("chelper_rs", _lib_path)
        _rust_lib = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_rust_lib)
    except Exception as e:
        logging.warning("Failed to load Rust module: %s", e)
        _rust_lib = None

def get_ffi():
    """Get the Rust module if available, otherwise None"""
    return _rust_lib
