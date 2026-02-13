// SPDX-License-Identifier: PMPL-1.0-or-later
//! FormBD snapshot management

use serde::{Deserialize, Serialize};

/// A database snapshot at a point in time
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Snapshot {
    pub timestamp: u64,
    pub entry_index: u64,
    pub entry_hash: [u8; 32],
    pub schema_version: String,
    pub table_count: usize,
    pub total_rows: usize,
}

/// Load a checkpoint snapshot
pub fn load_checkpoint(
    path: impl AsRef<std::path::Path>,
) -> Result<Snapshot, super::FormBDError> {
    let _ = path;
    // TODO: Load checkpoint file
    Err(super::FormBDError::SnapshotError(
        "Not implemented".to_string(),
    ))
}

/// Create a snapshot at the current journal position
pub fn create_snapshot(
    conn: &super::FormBDConnection,
) -> Result<Snapshot, super::FormBDError> {
    let _ = conn;
    // TODO: Create snapshot from current state
    Err(super::FormBDError::SnapshotError(
        "Not implemented".to_string(),
    ))
}
