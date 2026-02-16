// Copyright (C) 2016-2024  Kevin O'Connor <kevin@koconnor.net>
// Copyright (C) 2026 Cameron Bytheway
//
// This file may be distributed under the terms of the GNU GPLv3 license.

use anyhow::{Context, Result};
use clap::Parser;
use pyo3::prelude::*;
use pyo3::types::{PyAnyMethods, PyDict};
use std::path::PathBuf;
use tracing::{debug, info};
use tracing_subscriber::layer::SubscriberExt;
use tracing_subscriber::util::SubscriberInitExt;
use tracing_subscriber::Layer;

mod queuelogger;

/// Main Klippy host software
#[derive(Parser, Debug)]
#[command(name = "klippy")]
#[command(about = "Klipper host software", long_about = None)]
struct Args {
    /// Configuration file
    config_file: PathBuf,

    /// Read commands from file instead of from tty port
    #[arg(short = 'i', long)]
    debuginput: Option<PathBuf>,

    /// Input tty name (default is /tmp/printer)
    #[arg(short = 'I', long, default_value = "/tmp/printer")]
    input_tty: String,

    /// API server unix domain socket filename
    #[arg(short = 'a', long)]
    api_server: Option<String>,

    /// Write log to file instead of stderr (use "/var/log/journald" to send to journald)
    #[arg(short = 'l', long)]
    logfile: Option<String>,

    /// Enable debug messages
    #[arg(short = 'v', long)]
    verbose: bool,

    /// Write output to file instead of to serial port
    #[arg(short = 'o', long)]
    debugoutput: Option<PathBuf>,

    /// File to read for mcu protocol dictionary
    #[arg(short = 'd', long)]
    dictionary: Option<Vec<String>>,

    /// Perform an import module test
    #[arg(long)]
    import_test: bool,
}

/// Main entry point
fn main() -> Result<()> {
    let args = Args::parse();

    // Setup tracing
    let log_level = if args.verbose {
        tracing::Level::DEBUG
    } else {
        tracing::Level::INFO
    };

    let filter = tracing_subscriber::filter::LevelFilter::from_level(log_level);

    let use_journald = args.logfile.as_deref() == Some("/var/log/journald");

    if use_journald {
        let journald_layer = tracing_journald::layer().context("Failed to connect to journald")?;
        tracing_subscriber::registry()
            .with(journald_layer.with_filter(filter))
            .init();
    } else {
        tracing_subscriber::registry()
            .with(tracing_subscriber::fmt::layer().with_filter(filter))
            .init();
    }

    // Handle import test
    if args.import_test {
        info!("Running import test...");
        Python::attach(|py| -> Result<()> {
            import_test(py)?;
            Ok(())
        })
        .context("Failed to run import test")?;

        return Ok(());
    }

    info!("Starting Klippy (Rust)...");

    Python::attach(|py| -> Result<()> {
        let sys = py.import("sys")?;
        let executable: String = sys.getattr("executable")?.extract()?;
        debug!("Using Python: {}", executable);

        // Import core modules
        let util = py.import("util")?;
        let reactor_mod = py.import("reactor")?;
        let klippy_mod = py.import("klippy")?;

        // Build start_args dict (Python Printer expects a dict)
        let start_args = PyDict::new(py);
        start_args.set_item("config_file", args.config_file.display().to_string())?;
        start_args.set_item("start_reason", "startup")?;

        if let Some(ref apiserver) = args.api_server {
            start_args.set_item("apiserver", apiserver)?;
        }

        if let Some(ref debuginput) = args.debuginput {
            start_args.set_item("debuginput", debuginput.display().to_string())?;
            let file = std::fs::File::open(debuginput)?;
            use std::os::fd::AsRawFd;
            start_args.set_item("gcode_fd", file.as_raw_fd())?;
            // Keep file open for the duration
            std::mem::forget(file);
        } else {
            let gcode_fd: i32 = util
                .call_method1("create_pty", (&args.input_tty,))?
                .extract()?;
            start_args.set_item("gcode_fd", gcode_fd)?;
        }

        if let Some(ref debugoutput) = args.debugoutput {
            start_args.set_item("debugoutput", debugoutput.display().to_string())?;
            if let Some(ref dicts) = args.dictionary {
                for d in dicts {
                    if let Some((mcu_name, fname)) = d.split_once('=') {
                        start_args.set_item(format!("dictionary_{mcu_name}"), fname)?;
                    } else {
                        start_args.set_item("dictionary", d)?;
                    }
                }
            }
        }

        // Gather version/system info (matches Python main())
        let git_info = util.call_method1("get_git_version", (true,))?;
        let git_vers: String = git_info.get_item("version")?.extract()?;
        start_args.set_item("software_version", &git_vers)?;

        let cpu_info: String = util.call_method0("get_cpu_info")?.extract()?;
        start_args.set_item("cpu_info", &cpu_info)?;

        let device_info: String = util.call_method0("get_device_info")?.extract()?;
        start_args.set_item("device", &device_info)?;

        let linux_version: String = util.call_method0("get_linux_version")?.extract()?;
        start_args.set_item("linux_version", &linux_version)?;

        // Setup bglogger — replace Python's queuelogger with a Rust
        // tracing bridge that forwards Python logging → tracing events
        // via a mpsc channel + background thread.
        let debuglevel: i32 = if args.verbose { 10 } else { 20 };
        let bridge = queuelogger::setup_tracing_logger(py, debuglevel)?;
        let bglogger: Option<Bound<'_, PyAny>> = Some(bridge.into_any());

        if !use_journald {
            if let Some(ref logfile) = args.logfile.as_deref() {
                start_args.set_item("log_file", logfile)?;
            } else if args.debugoutput.is_none() {
                tracing::warn!("No log file specified! Severe timing issues may result!");
            }
        }

        // Log version info
        let versions = format!(
            "Args: {:?}\nGit version: {}\nCPU: {}\nDevice: {}\nLinux: {}\nPython: {}",
            std::env::args().collect::<Vec<_>>(),
            git_vers,
            cpu_info,
            device_info,
            linux_version,
            executable,
        );
        info!("{}", versions);

        // Disable GC (matches Python version)
        let gc = py.import("gc")?;
        gc.call_method0("disable")?;

        // ── Main restart loop ──────────────────────────────────────
        // This mirrors the Python `while 1:` loop in klippy.main().
        // Each iteration creates a fresh Reactor + Printer, runs until
        // exit/restart, then tears down and loops.
        loop {
            gc.call_method0("collect")?;

            // Create reactor and printer (Python objects)
            let main_reactor = reactor_mod.call_method1("Reactor", (true,))?;
            let printer =
                klippy_mod
                    .getattr("Printer")?
                    .call1((&main_reactor, &bglogger, &start_args))?;

            info!("Printer created, entering reactor loop");

            // Run the printer — this blocks until exit or restart
            let res: Option<String> = printer.call_method0("run")?.extract()?;

            match res.as_deref() {
                Some("exit") | Some("error_exit") => {
                    info!("Exiting: {:?}", res);
                    if res.as_deref() == Some("error_exit") {
                        std::process::exit(1);
                    }
                    break;
                }
                Some(reason) => {
                    info!("Restarting printer: {}", reason);
                    main_reactor.call_method0("finalize")?;
                    std::thread::sleep(std::time::Duration::from_secs(1));
                    start_args.set_item("start_reason", reason)?;
                }
                None => {
                    info!("Printer run completed with no result");
                    break;
                }
            }
        }

        Ok(())
    })
    .context("Failed to attach to Python interpreter")?;

    Ok(())
}

/// Import all optional modules (used as a build test)
fn import_test(py: Python) -> Result<()> {
    let module_dirs = vec!["extras", "kinematics"];

    for mdir in module_dirs {
        let path = PathBuf::from("klippy").join(mdir);
        if !path.exists() {
            continue;
        }

        for entry in std::fs::read_dir(&path)? {
            let entry = entry?;
            let path = entry.path();

            let module_name = if path.is_file() && path.extension().is_some_and(|e| e == "py") {
                let filename = path.file_stem().unwrap().to_str().unwrap();
                if filename == "__init__" {
                    continue;
                }
                filename.to_string()
            } else if path.is_dir() {
                let init_path = path.join("__init__.py");
                if !init_path.exists() {
                    continue;
                }
                path.file_name().unwrap().to_str().unwrap().to_string()
            } else {
                continue;
            };

            let full_module = format!("{}.{}", mdir, module_name);
            info!("Importing test module: {}", full_module);

            py.import(&full_module)
                .with_context(|| format!("Failed to import test module: {}", full_module))?;
        }
    }

    info!("Import test completed successfully");
    Ok(())
}
