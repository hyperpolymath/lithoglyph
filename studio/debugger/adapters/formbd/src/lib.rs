// SPDX-License-Identifier: PMPL-1.0-or-later
//! Native FormBD adapter for FormBD Debugger
//!
//! Provides direct access to FormBD's append-only journal,
//! provenance tracking, and Merkle-verified snapshots.

use thiserror::Error;

pub mod journal;
pub mod snapshot;
pub mod provenance;

/// Errors that can occur when interacting with FormBD
#[derive(Error, Debug)]
pub enum FormBDError {
    #[error("Journal read failed: {0}")]
    JournalError(String),

    #[error("Snapshot invalid: {0}")]
    SnapshotError(String),

    #[error("Merkle verification failed: {0}")]
    MerkleError(String),

    #[error("Provenance missing: {0}")]
    ProvenanceError(String),
}

/// FormBD database connection
pub struct FormBDConnection {
    path: std::path::PathBuf,
    opened: bool,
}

impl FormBDConnection {
    /// Open a FormBD database at the given path
    pub fn open(path: impl AsRef<std::path::Path>) -> Result<Self, FormBDError> {
        Ok(Self {
            path: path.as_ref().to_path_buf(),
            opened: true,
        })
    }

    /// Get the journal path
    pub fn journal_path(&self) -> std::path::PathBuf {
        self.path.join("journal")
    }

    /// Check if opened
    pub fn is_opened(&self) -> bool {
        self.opened
    }
}
