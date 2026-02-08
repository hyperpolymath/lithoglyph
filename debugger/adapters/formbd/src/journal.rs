// SPDX-License-Identifier: AGPL-3.0-or-later
//! FormBD journal parsing

use serde::{Deserialize, Serialize};

/// Magic number for FormBD journal entries
pub const MAGIC: [u8; 4] = *b"FMDB";

/// A journal entry header
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EntryHeader {
    pub magic: [u8; 4],
    pub version: u16,
    pub entry_type: EntryType,
    pub timestamp: u64,
    pub actor_id: [u8; 32],
    pub prev_hash: [u8; 32],
    pub payload_len: u32,
}

/// Types of journal entries
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[repr(u16)]
pub enum EntryType {
    Insert = 1,
    Update = 2,
    Delete = 3,
    Schema = 4,
    Merge = 5,
    Checkpoint = 6,
}

/// A complete journal entry
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JournalEntry {
    pub header: EntryHeader,
    pub payload: Vec<u8>,
    pub checksum: u32,
    pub entry_hash: [u8; 32],
}

/// Parse journal entries from a segment file
pub fn parse_segment(data: &[u8]) -> Result<Vec<JournalEntry>, super::FormBDError> {
    // TODO: Implement journal parsing
    if data.len() < 4 || &data[0..4] != MAGIC {
        return Err(super::FormBDError::JournalError(
            "Invalid magic number".to_string(),
        ));
    }
    Ok(vec![])
}

/// Verify the Merkle chain of a journal
pub fn verify_chain(entries: &[JournalEntry]) -> Result<bool, super::FormBDError> {
    // TODO: Verify prev_hash chain
    for window in entries.windows(2) {
        let _prev = &window[0];
        let _curr = &window[1];
        // Check that curr.header.prev_hash == prev.entry_hash
    }
    Ok(true)
}
