// SPDX-License-Identifier: AGPL-3.0-or-later
//! FormBD provenance tracking

use serde::{Deserialize, Serialize};

/// Provenance information for a piece of data
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Provenance {
    pub journal_entry: u64,
    pub added_by: String,
    pub added_at: u64,
    pub rationale: String,
    pub last_modified: Option<u64>,
    pub modification_count: u32,
}

/// Get provenance for a document
pub fn get_provenance(
    conn: &super::FormBDConnection,
    document_id: &str,
) -> Result<Provenance, super::FormBDError> {
    let _ = (conn, document_id);
    // TODO: Look up provenance from journal
    Err(super::FormBDError::ProvenanceError(
        "Not implemented".to_string(),
    ))
}

/// Get full provenance chain (all modifications)
pub fn get_provenance_chain(
    conn: &super::FormBDConnection,
    document_id: &str,
) -> Result<Vec<Provenance>, super::FormBDError> {
    let _ = (conn, document_id);
    // TODO: Trace all modifications in journal
    Err(super::FormBDError::ProvenanceError(
        "Not implemented".to_string(),
    ))
}
