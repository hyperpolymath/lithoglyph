// SPDX-License-Identifier: PMPL-1.0-or-later
//! PostgreSQL adapter for FormBD Debugger
//!
//! Provides schema introspection, WAL parsing, and transaction log extraction
//! for PostgreSQL databases.

use thiserror::Error;
use tokio_postgres::{Client, NoTls, Config};
use tracing::{info, warn, instrument};

pub mod schema;
pub mod wal;
pub mod transaction;
pub mod constraint_check;

/// Errors that can occur when interacting with PostgreSQL
#[derive(Error, Debug)]
pub enum PostgresError {
    #[error("Connection failed: {0}")]
    ConnectionFailed(String),

    #[error("Query failed: {0}")]
    QueryFailed(String),

    #[error("Schema introspection failed: {0}")]
    SchemaError(String),

    #[error("WAL parsing failed: {0}")]
    WalError(String),

    #[error("Configuration error: {0}")]
    ConfigError(String),
}

impl From<tokio_postgres::Error> for PostgresError {
    fn from(err: tokio_postgres::Error) -> Self {
        PostgresError::ConnectionFailed(err.to_string())
    }
}

// Re-export schema types for CLI
pub use schema::{DatabaseSchema, PgTable, PgColumn, PgConstraint, ConstraintType, FunctionalDependency};

// Re-export transaction/event types for TUI
pub use transaction::{DatabaseEvent, EventType, TableStats, ActivityEntry, get_recent_events, get_table_stats};

// Re-export constraint checking types
pub use constraint_check::{ConstraintViolation, ConstraintCheckResult, check_all_constraints, check_constraint};

/// Simplified schema output for IPC
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct SchemaInfo {
    pub database_name: String,
    pub tables: Vec<TableInfo>,
    pub constraints: Vec<ConstraintInfo>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct TableInfo {
    pub schema_name: String,
    pub name: String,
    pub columns: Vec<ColumnInfo>,
    pub primary_key: Vec<String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ColumnInfo {
    pub name: String,
    pub data_type: String,
    pub nullable: bool,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ConstraintInfo {
    pub name: String,
    pub constraint_type: String,
    pub table_name: String,
    pub columns: Vec<String>,
    pub foreign_table: Option<String>,
    pub foreign_columns: Option<Vec<String>>,
}

/// PostgreSQL database connection with actual tokio-postgres client
pub struct PostgresConnection {
    /// Connection string for reconnection
    connection_string: String,
    /// Active database client (None if disconnected)
    client: Option<Client>,
    /// Database name extracted from connection string
    database_name: String,
}

impl PostgresConnection {
    /// Create a new connection (not yet connected)
    /// Panics-free version that parses connection string
    pub fn new(connection_string: &str) -> Self {
        // Parse connection string to extract database name
        let database_name = connection_string
            .parse::<Config>()
            .ok()
            .and_then(|c| c.get_dbname().map(|s| s.to_string()))
            .unwrap_or_else(|| "postgres".to_string());

        Self {
            connection_string: connection_string.to_string(),
            client: None,
            database_name,
        }
    }

    /// Create a new connection with validation
    pub fn try_new(connection_string: &str) -> Result<Self, PostgresError> {
        // Parse connection string to extract database name
        let config: Config = connection_string
            .parse()
            .map_err(|e: tokio_postgres::Error| PostgresError::ConfigError(e.to_string()))?;

        let database_name = config
            .get_dbname()
            .map(|s| s.to_string())
            .unwrap_or_else(|| "postgres".to_string());

        Ok(Self {
            connection_string: connection_string.to_string(),
            client: None,
            database_name,
        })
    }

    /// Connect to the database
    #[instrument(skip(self))]
    pub async fn connect(&mut self) -> Result<(), PostgresError> {
        info!(database = %self.database_name, "Connecting to PostgreSQL");

        let (client, connection) = tokio_postgres::connect(&self.connection_string, NoTls).await?;

        // Spawn connection handler in background
        tokio::spawn(async move {
            if let Err(e) = connection.await {
                warn!(error = %e, "PostgreSQL connection error");
            }
        });

        self.client = Some(client);
        info!(database = %self.database_name, "Connected to PostgreSQL");
        Ok(())
    }

    /// Disconnect from the database
    pub fn disconnect(&mut self) {
        self.client = None;
        info!(database = %self.database_name, "Disconnected from PostgreSQL");
    }

    /// Check if connected
    pub fn is_connected(&self) -> bool {
        self.client.is_some()
    }

    /// Get the database name
    pub fn database_name(&self) -> &str {
        &self.database_name
    }

    /// Get a reference to the client (for executing queries)
    pub fn client(&self) -> Result<&Client, PostgresError> {
        self.client
            .as_ref()
            .ok_or_else(|| PostgresError::ConnectionFailed("Not connected".to_string()))
    }

    /// Execute a simple query and return row count
    #[instrument(skip(self, query))]
    pub async fn execute(&self, query: &str) -> Result<u64, PostgresError> {
        let client = self.client()?;
        let rows = client
            .execute(query, &[])
            .await
            .map_err(|e| PostgresError::QueryFailed(e.to_string()))?;
        Ok(rows)
    }

    /// Query and return rows
    pub async fn query(
        &self,
        query: &str,
    ) -> Result<Vec<tokio_postgres::Row>, PostgresError> {
        let client = self.client()?;
        let rows = client
            .query(query, &[])
            .await
            .map_err(|e| PostgresError::QueryFailed(e.to_string()))?;
        Ok(rows)
    }

    /// Introspect database schema (simplified interface)
    pub async fn introspect_schema(&self) -> Result<SchemaInfo, PostgresError> {
        let full_schema = schema::introspect_schema(self).await?;

        let tables = full_schema
            .tables
            .into_iter()
            .map(|t| TableInfo {
                schema_name: t.schema,
                name: t.name,
                columns: t
                    .columns
                    .into_iter()
                    .map(|c| ColumnInfo {
                        name: c.name,
                        data_type: c.data_type,
                        nullable: c.nullable,
                    })
                    .collect(),
                primary_key: t.primary_key.unwrap_or_default(),
            })
            .collect();

        let constraints = full_schema
            .constraints
            .into_iter()
            .map(|c| ConstraintInfo {
                name: c.name,
                constraint_type: format!("{:?}", c.constraint_type),
                table_name: c.table_name,
                columns: c.columns,
                foreign_table: c.foreign_table_name,
                foreign_columns: c.foreign_columns,
            })
            .collect();

        Ok(SchemaInfo {
            database_name: full_schema.database_name,
            tables,
            constraints,
        })
    }

    /// Close the connection
    pub async fn close(&mut self) {
        self.disconnect();
    }
}

/// Connection pool for multiple concurrent connections
pub struct ConnectionPool {
    connection_string: String,
    connections: Vec<PostgresConnection>,
}

impl ConnectionPool {
    /// Create a new connection pool
    pub fn new(connection_string: &str, pool_size: usize) -> Self {
        let connections = (0..pool_size)
            .map(|_| PostgresConnection::new(connection_string))
            .collect();

        Self {
            connection_string: connection_string.to_string(),
            connections,
        }
    }

    /// Initialize all connections
    pub async fn connect_all(&mut self) -> Result<(), PostgresError> {
        for conn in &mut self.connections {
            conn.connect().await?;
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_connection_new() {
        let conn = PostgresConnection::new("postgres://localhost/testdb");
        assert!(!conn.is_connected());
        assert_eq!(conn.database_name(), "testdb");
    }

    #[test]
    fn test_connection_try_new() {
        let conn = PostgresConnection::try_new("postgres://localhost/testdb");
        assert!(conn.is_ok());
        let conn = conn.unwrap();
        assert!(!conn.is_connected());
        assert_eq!(conn.database_name(), "testdb");
    }

    #[test]
    fn test_connection_default_database() {
        // Connection string without explicit database uses "postgres"
        let conn = PostgresConnection::new("postgres://localhost");
        assert_eq!(conn.database_name(), "postgres");
    }
}
