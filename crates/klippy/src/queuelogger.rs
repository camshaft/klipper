// Rust replacement for klippy/queuelogger.py
//
// Installs a Python logging.Handler that forwards all log records through
// a tokio mpsc channel to a background thread, which emits them as tracing
// events. This avoids blocking the GIL on tracing I/O.
//
// The returned `TracingBridge` implements the same interface as the Python
// `QueueListener` (set_rollover_info, clear_rollover_info, stop) so it can
// be passed as the `bglogger` argument to `klippy.Printer`.

use pyo3::prelude::*;
use pyo3::types::PyDict;
use std::sync::mpsc;

struct LogRecord {
    level: u32,
    message: String,
    logger_name: String,
}

#[pyclass]
pub struct TracingBridge {
    sender: mpsc::Sender<LogRecord>,
}

#[pymethods]
impl TracingBridge {
    /// Send a log record to the background tracing thread.
    /// Called from the Python TracingHandler.emit().
    fn send_log(&self, level: u32, message: String, logger_name: String) {
        let _ = self.sender.send(LogRecord {
            level,
            message,
            logger_name,
        });
    }

    /// Store rollover info (compat with QueueListener interface).
    fn set_rollover_info(&self, name: String, info: Option<String>) {
        let _ = name;
        let _ = info;
    }

    /// Clear all rollover info.
    fn clear_rollover_info(&self) {
        // No-op since we're not actually storing rollover info.
    }

    /// Stop the background thread and drain remaining records.
    fn stop(&self) {
        // Dropping the sender will close the channel and cause the background
        // thread to exit after processing all pending records.
    }
}

// ── Background consumer ────────────────────────────────────────────

fn run_consumer(rx: mpsc::Receiver<LogRecord>) {
    while let Ok(record) = rx.recv() {
        emit_tracing_event(&record);
    }
}

fn emit_tracing_event(record: &LogRecord) {
    // Map Python log levels to tracing levels:
    //   CRITICAL=50, ERROR=40, WARNING=30, INFO=20, DEBUG=10
    match record.level {
        40.. => {
            tracing::error!(
                target: "klippy",
                logger = %record.logger_name,
                "{}",
                record.message
            );
        }
        30..40 => {
            tracing::warn!(
                target: "klippy",
                logger = %record.logger_name,
                "{}",
                record.message
            );
        }
        20..30 => {
            tracing::info!(
                target: "klippy",
                logger = %record.logger_name,
                "{}",
                record.message
            );
        }
        10..20 => {
            tracing::debug!(
                target: "klippy",
                logger = %record.logger_name,
                "{}",
                record.message
            );
        }
        _ => {
            tracing::trace!(
                target: "klippy",
                logger = %record.logger_name,
                "{}",
                record.message
            );
        }
    }
}

// ── Public setup function ──────────────────────────────────────────

/// Create a `TracingBridge`, install a Python `logging.Handler` on the
/// root logger that forwards records through the bridge, and return the
/// bridge (to be used as `bglogger`).
pub fn setup_tracing_logger(py: Python<'_>, debuglevel: i32) -> PyResult<Bound<'_, TracingBridge>> {
    let (tx, rx) = mpsc::channel();

    // Spawn background consumer thread
    std::thread::Builder::new()
        .name("tracing-logger".into())
        .spawn(move || run_consumer(rx))
        .expect("failed to spawn tracing-logger thread");

    let bridge = Bound::new(
        py,
        TracingBridge {
            sender: tx,
        },
    )?;

    // Create a Python logging.Handler subclass that delegates to the bridge.
    // Defined inline so there's no separate .py file to ship.
    let locals = PyDict::new(py);
    locals.set_item("logging", py.import("logging")?)?;
    locals.set_item("bridge", &bridge)?;
    locals.set_item("debuglevel", debuglevel)?;

    py.run(
        c"
class _TracingHandler(logging.Handler):
    '''logging.Handler that forwards records to a Rust tracing bridge.'''

    def __init__(self, bridge):
        super().__init__()
        self._bridge = bridge

    def emit(self, record):
        try:
            self.format(record)
            msg = record.message
        except Exception:
            msg = record.getMessage()
        self._bridge.send_log(record.levelno, msg, record.name)

_handler = _TracingHandler(bridge)
root = logging.getLogger()
# Remove any existing handlers (e.g. the default stderr handler)
# so messages only flow through the tracing bridge.
for h in root.handlers[:]:
    root.removeHandler(h)
root.addHandler(_handler)
root.setLevel(debuglevel)
",
        None,
        Some(&locals),
    )?;

    Ok(bridge)
}
