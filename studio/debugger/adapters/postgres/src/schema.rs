// SPDX-License-Identifier: PMPL-1.0-or-later
//! PostgreSQL schema introspection via pg_catalog and information_schema
//!
//! Provides complete schema extraction including tables, columns, constraints,
//! and functional dependencies.

use serde::{Deserialize, Serialize};
use tracing::{info, instrument};

use crate::{PostgresConnection, PostgresError};

/// A PostgreSQL table definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PgTable {
    /// Schema name (e.g., "public")
    pub schema: String,
    /// Table name
    pub name: String,
    /// Column definitions
    pub columns: Vec<PgColumn>,
    /// Primary key columns (if any)
    pub primary_key: Option<Vec<String>>,
    /// Table OID for further queries
    pub oid: i64,
}

/// A PostgreSQL column definition
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PgColumn {
    /// Column name
    pub name: String,
    /// PostgreSQL data type (e.g., "integer", "text", "timestamp with time zone")
    pub data_type: String,
    /// Whether the column allows NULL values
    pub nullable: bool,
    /// Default value expression (if any)
    pub default_value: Option<String>,
    /// Column position in table
    pub ordinal_position: i32,
}

/// A PostgreSQL constraint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PgConstraint {
    /// Constraint name
    pub name: String,
    /// Type of constraint
    pub constraint_type: ConstraintType,
    /// Table the constraint belongs to
    pub table_schema: String,
    pub table_name: String,
    /// Columns involved in the constraint
    pub columns: Vec<String>,
    /// For foreign keys: referenced table
    pub foreign_table_schema: Option<String>,
    pub foreign_table_name: Option<String>,
    /// For foreign keys: referenced columns
    pub foreign_columns: Option<Vec<String>>,
    /// For check constraints: the check expression
    pub check_expression: Option<String>,
}

/// Types of PostgreSQL constraints
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ConstraintType {
    PrimaryKey,
    ForeignKey,
    Unique,
    Check,
    Exclusion,
}

impl ConstraintType {
    fn from_pg_type(s: &str) -> Option<Self> {
        match s {
            "p" | "PRIMARY KEY" => Some(Self::PrimaryKey),
            "f" | "FOREIGN KEY" => Some(Self::ForeignKey),
            "u" | "UNIQUE" => Some(Self::Unique),
            "c" | "CHECK" => Some(Self::Check),
            "x" | "EXCLUSION" => Some(Self::Exclusion),
            _ => None,
        }
    }
}

/// Complete schema information for a database
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseSchema {
    /// Database name
    pub database_name: String,
    /// All tables in the database
    pub tables: Vec<PgTable>,
    /// All constraints
    pub constraints: Vec<PgConstraint>,
    /// Schema extraction timestamp
    pub extracted_at: chrono::DateTime<chrono::Utc>,
}

/// Introspect all tables from information_schema
#[instrument(skip(conn))]
pub async fn introspect_tables(conn: &PostgresConnection) -> Result<Vec<PgTable>, PostgresError> {
    info!("Introspecting database tables");

    let query = r#"
        SELECT
            t.table_schema,
            t.table_name,
            c.relid::bigint as oid
        FROM information_schema.tables t
        JOIN pg_catalog.pg_statio_user_tables c
            ON t.table_name = c.relname AND t.table_schema = c.schemaname
        WHERE t.table_type = 'BASE TABLE'
            AND t.table_schema NOT IN ('pg_catalog', 'information_schema')
        ORDER BY t.table_schema, t.table_name
    "#;

    let rows = conn.query(query).await?;
    let mut tables = Vec::new();

    for row in rows {
        let schema: String = row.get(0);
        let name: String = row.get(1);
        let oid: i64 = row.get(2);

        // Get columns for this table
        let columns = introspect_columns(conn, &schema, &name).await?;

        // Get primary key for this table
        let primary_key = get_primary_key(conn, &schema, &name).await?;

        tables.push(PgTable {
            schema,
            name,
            columns,
            primary_key,
            oid,
        });
    }

    info!(count = tables.len(), "Found tables");
    Ok(tables)
}

/// Introspect columns for a specific table
#[instrument(skip(conn))]
async fn introspect_columns(
    conn: &PostgresConnection,
    schema: &str,
    table: &str,
) -> Result<Vec<PgColumn>, PostgresError> {
    let query = r#"
        SELECT
            column_name,
            data_type,
            is_nullable,
            column_default,
            ordinal_position
        FROM information_schema.columns
        WHERE table_schema = $1 AND table_name = $2
        ORDER BY ordinal_position
    "#;

    let client = conn.client()?;
    let rows = client
        .query(query, &[&schema, &table])
        .await
        .map_err(|e| PostgresError::SchemaError(e.to_string()))?;

    let columns = rows
        .iter()
        .map(|row| {
            let is_nullable: String = row.get(2);
            PgColumn {
                name: row.get(0),
                data_type: row.get(1),
                nullable: is_nullable == "YES",
                default_value: row.get(3),
                ordinal_position: row.get(4),
            }
        })
        .collect();

    Ok(columns)
}

/// Get primary key columns for a table
#[instrument(skip(conn))]
async fn get_primary_key(
    conn: &PostgresConnection,
    schema: &str,
    table: &str,
) -> Result<Option<Vec<String>>, PostgresError> {
    let query = r#"
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        JOIN pg_class c ON c.oid = i.indrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE i.indisprimary
            AND n.nspname = $1
            AND c.relname = $2
        ORDER BY array_position(i.indkey, a.attnum)
    "#;

    let client = conn.client()?;
    let rows = client
        .query(query, &[&schema, &table])
        .await
        .map_err(|e| PostgresError::SchemaError(e.to_string()))?;

    if rows.is_empty() {
        Ok(None)
    } else {
        let columns: Vec<String> = rows.iter().map(|r| r.get(0)).collect();
        Ok(Some(columns))
    }
}

/// Introspect all constraints
#[instrument(skip(conn))]
pub async fn introspect_constraints(
    conn: &PostgresConnection,
) -> Result<Vec<PgConstraint>, PostgresError> {
    info!("Introspecting database constraints");

    // Query for all constraints except NOT NULL (handled via columns)
    let query = r#"
        SELECT
            tc.constraint_name,
            tc.constraint_type,
            tc.table_schema,
            tc.table_name,
            kcu.column_name,
            ccu.table_schema AS foreign_table_schema,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name,
            cc.check_clause
        FROM information_schema.table_constraints tc
        LEFT JOIN information_schema.key_column_usage kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
        LEFT JOIN information_schema.constraint_column_usage ccu
            ON tc.constraint_name = ccu.constraint_name
            AND tc.table_schema = ccu.table_schema
            AND tc.constraint_type = 'FOREIGN KEY'
        LEFT JOIN information_schema.check_constraints cc
            ON tc.constraint_name = cc.constraint_name
            AND tc.constraint_schema = cc.constraint_schema
        WHERE tc.table_schema NOT IN ('pg_catalog', 'information_schema')
        ORDER BY tc.table_schema, tc.table_name, tc.constraint_name, kcu.ordinal_position
    "#;

    let rows = conn.query(query).await?;

    // Group by constraint name to collect all columns
    let mut constraint_map: std::collections::HashMap<String, PgConstraint> =
        std::collections::HashMap::new();

    for row in rows {
        let constraint_name: String = row.get(0);
        let constraint_type_str: String = row.get(1);
        let table_schema: String = row.get(2);
        let table_name: String = row.get(3);
        let column_name: Option<String> = row.get(4);
        let foreign_schema: Option<String> = row.get(5);
        let foreign_table: Option<String> = row.get(6);
        let foreign_column: Option<String> = row.get(7);
        let check_clause: Option<String> = row.get(8);

        let key = format!("{}.{}.{}", table_schema, table_name, constraint_name);

        let constraint = constraint_map.entry(key).or_insert_with(|| PgConstraint {
            name: constraint_name.clone(),
            constraint_type: ConstraintType::from_pg_type(&constraint_type_str)
                .unwrap_or(ConstraintType::Check),
            table_schema: table_schema.clone(),
            table_name: table_name.clone(),
            columns: Vec::new(),
            foreign_table_schema: foreign_schema.clone(),
            foreign_table_name: foreign_table.clone(),
            foreign_columns: if foreign_column.is_some() {
                Some(Vec::new())
            } else {
                None
            },
            check_expression: check_clause,
        });

        if let Some(col) = column_name {
            if !constraint.columns.contains(&col) {
                constraint.columns.push(col);
            }
        }

        if let Some(fcol) = foreign_column {
            if let Some(ref mut fcols) = constraint.foreign_columns {
                if !fcols.contains(&fcol) {
                    fcols.push(fcol);
                }
            }
        }
    }

    let constraints: Vec<PgConstraint> = constraint_map.into_values().collect();
    info!(count = constraints.len(), "Found constraints");
    Ok(constraints)
}

/// Full schema introspection
#[instrument(skip(conn))]
pub async fn introspect_schema(
    conn: &PostgresConnection,
) -> Result<DatabaseSchema, PostgresError> {
    info!(database = %conn.database_name(), "Starting full schema introspection");

    let tables = introspect_tables(conn).await?;
    let constraints = introspect_constraints(conn).await?;

    Ok(DatabaseSchema {
        database_name: conn.database_name().to_string(),
        tables,
        constraints,
        extracted_at: chrono::Utc::now(),
    })
}

/// Detect functional dependencies by analyzing unique constraints and indexes
#[instrument(skip(conn))]
pub async fn detect_functional_dependencies(
    conn: &PostgresConnection,
    table_schema: &str,
    table_name: &str,
) -> Result<Vec<FunctionalDependency>, PostgresError> {
    info!(schema = %table_schema, table = %table_name, "Detecting functional dependencies");

    let mut fds = Vec::new();

    // Every unique constraint implies an FD: unique_cols -> all_cols
    let query = r#"
        SELECT
            array_agg(a.attname ORDER BY array_position(i.indkey, a.attnum)) as columns
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        JOIN pg_class c ON c.oid = i.indrelid
        JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE i.indisunique
            AND n.nspname = $1
            AND c.relname = $2
    "#;

    let client = conn.client()?;
    let rows = client
        .query(query, &[&table_schema, &table_name])
        .await
        .map_err(|e| PostgresError::SchemaError(e.to_string()))?;

    // Get all column names for this table
    let all_columns = introspect_columns(conn, table_schema, table_name)
        .await?
        .into_iter()
        .map(|c| c.name)
        .collect::<Vec<_>>();

    for row in rows {
        let unique_cols: Vec<String> = row.get(0);

        // FD: unique_cols -> (all_cols - unique_cols)
        let dependent_cols: Vec<String> = all_columns
            .iter()
            .filter(|c| !unique_cols.contains(c))
            .cloned()
            .collect();

        if !dependent_cols.is_empty() {
            fds.push(FunctionalDependency {
                table_schema: table_schema.to_string(),
                table_name: table_name.to_string(),
                determinant: unique_cols,
                dependent: dependent_cols,
                confidence: 1.0, // From unique constraint, so 100% confidence
                source: FDSource::UniqueConstraint,
            });
        }
    }

    info!(count = fds.len(), "Detected functional dependencies");
    Ok(fds)
}

/// A functional dependency X -> Y
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionalDependency {
    pub table_schema: String,
    pub table_name: String,
    /// Determinant columns (X)
    pub determinant: Vec<String>,
    /// Dependent columns (Y)
    pub dependent: Vec<String>,
    /// Confidence (1.0 for exact FDs from constraints)
    pub confidence: f64,
    /// How the FD was discovered
    pub source: FDSource,
}

/// How a functional dependency was discovered
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FDSource {
    /// Derived from a unique constraint
    UniqueConstraint,
    /// Derived from a primary key
    PrimaryKey,
    /// Discovered via data analysis
    DataAnalysis,
    /// User-declared
    UserDeclared,
}

// Add chrono to Cargo.toml if not present
// chrono = { version = "0.4", features = ["serde"] }
