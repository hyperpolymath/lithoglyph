// SPDX-License-Identifier: PMPL-1.0-or-later
//! Constraint violation detection via SQL queries
//!
//! Checks each constraint type against actual database data to find violations.

use serde::{Deserialize, Serialize};
use tracing::{info, instrument, warn};

use crate::schema::{ConstraintType, PgConstraint};
use crate::{PostgresConnection, PostgresError};

/// A constraint violation detected in the database
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstraintViolation {
    /// Name of the violated constraint
    pub constraint_name: String,
    /// Type of constraint
    pub constraint_type: String,
    /// Table containing the violation
    pub table_schema: String,
    pub table_name: String,
    /// Number of violating rows
    pub violation_count: i64,
    /// Sample of violating data (first few rows)
    pub sample_violations: Vec<String>,
    /// Explanation of the violation
    pub explanation: String,
    /// SQL to find all violations
    pub detection_query: String,
}

/// Result of checking a constraint
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstraintCheckResult {
    pub constraint_name: String,
    pub constraint_type: String,
    pub table_name: String,
    pub satisfied: bool,
    pub violation: Option<ConstraintViolation>,
}

/// Check all constraints in the database for violations
#[instrument(skip(conn, constraints))]
pub async fn check_all_constraints(
    conn: &PostgresConnection,
    constraints: &[PgConstraint],
) -> Result<Vec<ConstraintCheckResult>, PostgresError> {
    info!(count = constraints.len(), "Checking all constraints for violations");

    let mut results = Vec::new();

    for constraint in constraints {
        let result = check_constraint(conn, constraint).await?;
        results.push(result);
    }

    let violations: usize = results.iter().filter(|r| !r.satisfied).count();
    info!(total = results.len(), violations = violations, "Constraint check complete");

    Ok(results)
}

/// Check a single constraint for violations
#[instrument(skip(conn))]
pub async fn check_constraint(
    conn: &PostgresConnection,
    constraint: &PgConstraint,
) -> Result<ConstraintCheckResult, PostgresError> {
    match constraint.constraint_type {
        ConstraintType::ForeignKey => check_foreign_key(conn, constraint).await,
        ConstraintType::Unique => check_unique(conn, constraint).await,
        ConstraintType::Check => check_check_constraint(conn, constraint).await,
        ConstraintType::PrimaryKey => check_primary_key(conn, constraint).await,
        ConstraintType::Exclusion => check_exclusion(conn, constraint).await,
    }
}

/// Check a foreign key constraint for orphan rows
async fn check_foreign_key(
    conn: &PostgresConnection,
    constraint: &PgConstraint,
) -> Result<ConstraintCheckResult, PostgresError> {
    let foreign_table = match (&constraint.foreign_table_schema, &constraint.foreign_table_name) {
        (Some(schema), Some(table)) => format!("\"{}\".\"{}\"", schema, table),
        (None, Some(table)) => format!("\"{}\"", table),
        _ => {
            return Ok(ConstraintCheckResult {
                constraint_name: constraint.name.clone(),
                constraint_type: "FOREIGN KEY".to_string(),
                table_name: constraint.table_name.clone(),
                satisfied: true,
                violation: None,
            });
        }
    };

    let foreign_columns = match &constraint.foreign_columns {
        Some(cols) if !cols.is_empty() => cols.clone(),
        _ => constraint.columns.clone(), // Assume same column names if not specified
    };

    if constraint.columns.is_empty() || foreign_columns.is_empty() {
        return Ok(ConstraintCheckResult {
            constraint_name: constraint.name.clone(),
            constraint_type: "FOREIGN KEY".to_string(),
            table_name: constraint.table_name.clone(),
            satisfied: true,
            violation: None,
        });
    }

    // Build the check query
    let local_cols: Vec<String> = constraint.columns.iter()
        .map(|c| format!("t.\"{}\"", c))
        .collect();
    let foreign_cols: Vec<String> = foreign_columns.iter()
        .map(|c| format!("f.\"{}\"", c))
        .collect();

    let join_conditions: Vec<String> = local_cols.iter().zip(foreign_cols.iter())
        .map(|(l, f)| format!("{} = {}", l, f))
        .collect();

    let null_checks: Vec<String> = constraint.columns.iter()
        .map(|c| format!("t.\"{}\" IS NOT NULL", c))
        .collect();

    let query = format!(
        r#"
        SELECT COUNT(*) as violation_count
        FROM "{}"."{}" t
        LEFT JOIN {} f ON {}
        WHERE {} AND f.{} IS NULL
        "#,
        constraint.table_schema,
        constraint.table_name,
        foreign_table,
        join_conditions.join(" AND "),
        null_checks.join(" AND "),
        foreign_columns.first().map(|c| format!("\"{}\"", c)).unwrap_or_default()
    );

    let rows = conn.query(&query).await?;
    let count: i64 = rows.first().map(|r| r.get(0)).unwrap_or(0);

    if count > 0 {
        // Get sample violations
        let sample_query = format!(
            r#"
            SELECT {}
            FROM "{}"."{}" t
            LEFT JOIN {} f ON {}
            WHERE {} AND f.{} IS NULL
            LIMIT 5
            "#,
            local_cols.join(", "),
            constraint.table_schema,
            constraint.table_name,
            foreign_table,
            join_conditions.join(" AND "),
            null_checks.join(" AND "),
            foreign_columns.first().map(|c| format!("\"{}\"", c)).unwrap_or_default()
        );

        let sample_rows = conn.query(&sample_query).await.unwrap_or_default();
        let samples: Vec<String> = sample_rows.iter()
            .map(|r| {
                let vals: Vec<String> = (0..constraint.columns.len())
                    .filter_map(|i| {
                        // Try to get as string, fallback to debug
                        r.try_get::<_, String>(i).ok()
                            .or_else(|| r.try_get::<_, i64>(i).ok().map(|v| v.to_string()))
                            .or_else(|| r.try_get::<_, i32>(i).ok().map(|v| v.to_string()))
                    })
                    .collect();
                format!("({})", vals.join(", "))
            })
            .collect();

        Ok(ConstraintCheckResult {
            constraint_name: constraint.name.clone(),
            constraint_type: "FOREIGN KEY".to_string(),
            table_name: constraint.table_name.clone(),
            satisfied: false,
            violation: Some(ConstraintViolation {
                constraint_name: constraint.name.clone(),
                constraint_type: "FOREIGN KEY".to_string(),
                table_schema: constraint.table_schema.clone(),
                table_name: constraint.table_name.clone(),
                violation_count: count,
                sample_violations: samples,
                explanation: format!(
                    "{} rows in {}.{} reference non-existent rows in {}",
                    count,
                    constraint.table_schema,
                    constraint.table_name,
                    foreign_table
                ),
                detection_query: query,
            }),
        })
    } else {
        Ok(ConstraintCheckResult {
            constraint_name: constraint.name.clone(),
            constraint_type: "FOREIGN KEY".to_string(),
            table_name: constraint.table_name.clone(),
            satisfied: true,
            violation: None,
        })
    }
}

/// Check a unique constraint for duplicates
async fn check_unique(
    conn: &PostgresConnection,
    constraint: &PgConstraint,
) -> Result<ConstraintCheckResult, PostgresError> {
    if constraint.columns.is_empty() {
        return Ok(ConstraintCheckResult {
            constraint_name: constraint.name.clone(),
            constraint_type: "UNIQUE".to_string(),
            table_name: constraint.table_name.clone(),
            satisfied: true,
            violation: None,
        });
    }

    let cols: Vec<String> = constraint.columns.iter()
        .map(|c| format!("\"{}\"", c))
        .collect();
    let col_list = cols.join(", ");

    let query = format!(
        r#"
        SELECT {}, COUNT(*) as dup_count
        FROM "{}"."{}"
        GROUP BY {}
        HAVING COUNT(*) > 1
        "#,
        col_list,
        constraint.table_schema,
        constraint.table_name,
        col_list
    );

    let rows = conn.query(&query).await?;

    if !rows.is_empty() {
        let total_dups: i64 = rows.iter()
            .map(|r| r.get::<_, i64>(constraint.columns.len()))
            .sum();

        let samples: Vec<String> = rows.iter()
            .take(5)
            .map(|r| {
                let vals: Vec<String> = (0..constraint.columns.len())
                    .filter_map(|i| {
                        r.try_get::<_, String>(i).ok()
                            .or_else(|| r.try_get::<_, i64>(i).ok().map(|v| v.to_string()))
                            .or_else(|| r.try_get::<_, i32>(i).ok().map(|v| v.to_string()))
                    })
                    .collect();
                let count: i64 = r.get(constraint.columns.len());
                format!("({}) × {}", vals.join(", "), count)
            })
            .collect();

        Ok(ConstraintCheckResult {
            constraint_name: constraint.name.clone(),
            constraint_type: "UNIQUE".to_string(),
            table_name: constraint.table_name.clone(),
            satisfied: false,
            violation: Some(ConstraintViolation {
                constraint_name: constraint.name.clone(),
                constraint_type: "UNIQUE".to_string(),
                table_schema: constraint.table_schema.clone(),
                table_name: constraint.table_name.clone(),
                violation_count: total_dups,
                sample_violations: samples,
                explanation: format!(
                    "{} duplicate groups found on columns ({}) in {}.{}",
                    rows.len(),
                    constraint.columns.join(", "),
                    constraint.table_schema,
                    constraint.table_name
                ),
                detection_query: query,
            }),
        })
    } else {
        Ok(ConstraintCheckResult {
            constraint_name: constraint.name.clone(),
            constraint_type: "UNIQUE".to_string(),
            table_name: constraint.table_name.clone(),
            satisfied: true,
            violation: None,
        })
    }
}

/// Check a CHECK constraint for violations
async fn check_check_constraint(
    conn: &PostgresConnection,
    constraint: &PgConstraint,
) -> Result<ConstraintCheckResult, PostgresError> {
    let check_expr = match &constraint.check_expression {
        Some(expr) => expr,
        None => {
            return Ok(ConstraintCheckResult {
                constraint_name: constraint.name.clone(),
                constraint_type: "CHECK".to_string(),
                table_name: constraint.table_name.clone(),
                satisfied: true,
                violation: None,
            });
        }
    };

    // The check expression is usually stored as "((column > 0))" - we need to negate it
    let query = format!(
        r#"
        SELECT COUNT(*) as violation_count
        FROM "{}"."{}"
        WHERE NOT ({})
        "#,
        constraint.table_schema,
        constraint.table_name,
        check_expr.trim_start_matches('(').trim_end_matches(')')
    );

    let rows = match conn.query(&query).await {
        Ok(r) => r,
        Err(e) => {
            warn!(constraint = %constraint.name, error = %e, "Failed to check CHECK constraint");
            return Ok(ConstraintCheckResult {
                constraint_name: constraint.name.clone(),
                constraint_type: "CHECK".to_string(),
                table_name: constraint.table_name.clone(),
                satisfied: true, // Assume satisfied if we can't check
                violation: None,
            });
        }
    };

    let count: i64 = rows.first().map(|r| r.get(0)).unwrap_or(0);

    if count > 0 {
        Ok(ConstraintCheckResult {
            constraint_name: constraint.name.clone(),
            constraint_type: "CHECK".to_string(),
            table_name: constraint.table_name.clone(),
            satisfied: false,
            violation: Some(ConstraintViolation {
                constraint_name: constraint.name.clone(),
                constraint_type: "CHECK".to_string(),
                table_schema: constraint.table_schema.clone(),
                table_name: constraint.table_name.clone(),
                violation_count: count,
                sample_violations: vec![],
                explanation: format!(
                    "{} rows in {}.{} violate check: {}",
                    count,
                    constraint.table_schema,
                    constraint.table_name,
                    check_expr
                ),
                detection_query: query,
            }),
        })
    } else {
        Ok(ConstraintCheckResult {
            constraint_name: constraint.name.clone(),
            constraint_type: "CHECK".to_string(),
            table_name: constraint.table_name.clone(),
            satisfied: true,
            violation: None,
        })
    }
}

/// Check primary key for NULL values or duplicates
async fn check_primary_key(
    conn: &PostgresConnection,
    constraint: &PgConstraint,
) -> Result<ConstraintCheckResult, PostgresError> {
    // Primary key = UNIQUE + NOT NULL, but PostgreSQL enforces this
    // We check anyway for data integrity after potential corruption
    check_unique(conn, constraint).await.map(|mut r| {
        r.constraint_type = "PRIMARY KEY".to_string();
        if let Some(ref mut v) = r.violation {
            v.constraint_type = "PRIMARY KEY".to_string();
        }
        r
    })
}

/// Check exclusion constraints (complex - requires GiST/btree_gist)
async fn check_exclusion(
    _conn: &PostgresConnection,
    constraint: &PgConstraint,
) -> Result<ConstraintCheckResult, PostgresError> {
    // Exclusion constraints are complex and typically enforced by PostgreSQL
    // Would need to parse the exclusion operator and check for overlaps
    Ok(ConstraintCheckResult {
        constraint_name: constraint.name.clone(),
        constraint_type: "EXCLUSION".to_string(),
        table_name: constraint.table_name.clone(),
        satisfied: true, // Assume satisfied - PG enforces these
        violation: None,
    })
}

/// Check for NULL values in NOT NULL columns
#[instrument(skip(conn))]
pub async fn check_not_null_columns(
    conn: &PostgresConnection,
    table_schema: &str,
    table_name: &str,
) -> Result<Vec<ConstraintViolation>, PostgresError> {
    info!(schema = %table_schema, table = %table_name, "Checking NOT NULL constraints");

    // Get NOT NULL columns
    let query = r#"
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = $1
          AND table_name = $2
          AND is_nullable = 'NO'
    "#;

    let client = conn.client()?;
    let rows = client
        .query(query, &[&table_schema, &table_name])
        .await
        .map_err(|e| PostgresError::QueryFailed(e.to_string()))?;

    let mut violations = Vec::new();

    for row in rows {
        let column_name: String = row.get(0);

        // Check for NULLs (shouldn't exist if enforced, but check for data corruption)
        let check_query = format!(
            r#"SELECT COUNT(*) FROM "{}"."{}" WHERE "{}" IS NULL"#,
            table_schema, table_name, column_name
        );

        if let Ok(check_rows) = conn.query(&check_query).await {
            let count: i64 = check_rows.first().map(|r| r.get(0)).unwrap_or(0);
            if count > 0 {
                violations.push(ConstraintViolation {
                    constraint_name: format!("{}_not_null", column_name),
                    constraint_type: "NOT NULL".to_string(),
                    table_schema: table_schema.to_string(),
                    table_name: table_name.to_string(),
                    violation_count: count,
                    sample_violations: vec![],
                    explanation: format!(
                        "{} NULL values found in NOT NULL column {}.{}.{}",
                        count, table_schema, table_name, column_name
                    ),
                    detection_query: check_query,
                });
            }
        }
    }

    Ok(violations)
}
