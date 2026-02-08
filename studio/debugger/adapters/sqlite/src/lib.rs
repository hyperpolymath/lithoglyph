// SPDX-License-Identifier: AGPL-3.0-or-later
//! SQLite adapter for FormBD Debugger
//!
//! Provides a simple adapter for testing and development.
//! SQLite is not recommended for production use with FormBD.

use thiserror::Error;

/// Errors that can occur when interacting with SQLite
#[derive(Error, Debug)]
pub enum SqliteError {
    #[error("Connection failed: {0}")]
    ConnectionFailed(String),

    #[error("Query failed: {0}")]
    QueryFailed(String),

    #[error("Schema error: {0}")]
    SchemaError(String),
}

/// SQLite database connection
pub struct SqliteConnection {
    path: std::path::PathBuf,
    connected: bool,
}

impl SqliteConnection {
    /// Open a SQLite database
    pub fn open(path: impl AsRef<std::path::Path>) -> Result<Self, SqliteError> {
        Ok(Self {
            path: path.as_ref().to_path_buf(),
            connected: true,
        })
    }

    /// Get the database path
    pub fn path(&self) -> &std::path::Path {
        &self.path
    }

    /// Check if connected
    pub fn is_connected(&self) -> bool {
        self.connected
    }
}

/// List all tables in the database
pub fn list_tables(conn: &SqliteConnection) -> Result<Vec<String>, SqliteError> {
    let _ = conn;
    // TODO: Query sqlite_master
    Ok(vec![])
}

/// Get schema for a table
pub fn get_table_schema(
    conn: &SqliteConnection,
    table: &str,
) -> Result<Vec<(String, String)>, SqliteError> {
    let _ = (conn, table);
    // TODO: PRAGMA table_info
    Ok(vec![])
}
