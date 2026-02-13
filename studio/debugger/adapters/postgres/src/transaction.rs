// SPDX-License-Identifier: PMPL-1.0-or-later
//! PostgreSQL transaction log extraction

use serde::{Deserialize, Serialize};

/// A database transaction
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Transaction {
    pub xid: u64,
    pub start_time: u64,
    pub end_time: Option<u64>,
    pub status: TransactionStatus,
    pub operations: Vec<Operation>,
}

/// Transaction status
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TransactionStatus {
    Active,
    Committed,
    Aborted,
    InDoubt,
}

/// A database operation within a transaction
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Operation {
    pub table: String,
    pub operation_type: OperationType,
    pub row_data: Option<serde_json::Value>,
}

/// Types of operations
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum OperationType {
    Insert,
    Update,
    Delete,
    Truncate,
}

/// Activity entry from pg_stat_activity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActivityEntry {
    pub pid: i32,
    pub database: String,
    pub username: String,
    pub application: Option<String>,
    pub client_addr: Option<String>,
    pub state: String,
    pub query: Option<String>,
    pub query_start: Option<String>,
    pub xact_start: Option<String>,
    pub wait_event: Option<String>,
}

/// Table statistics from pg_stat_user_tables
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TableStats {
    pub schema_name: String,
    pub table_name: String,
    pub seq_scan: i64,
    pub seq_tup_read: i64,
    pub idx_scan: Option<i64>,
    pub idx_tup_fetch: Option<i64>,
    pub n_tup_ins: i64,
    pub n_tup_upd: i64,
    pub n_tup_del: i64,
    pub n_live_tup: i64,
    pub n_dead_tup: i64,
    pub last_vacuum: Option<String>,
    pub last_autovacuum: Option<String>,
    pub last_analyze: Option<String>,
}

/// Recent database event for timeline
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DatabaseEvent {
    pub timestamp: String,
    pub event_type: EventType,
    pub description: String,
    pub table_name: Option<String>,
    pub details: Option<String>,
}

/// Types of database events
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EventType {
    Query,
    Insert,
    Update,
    Delete,
    SchemaChange,
    Connection,
    Vacuum,
    Checkpoint,
}

impl std::fmt::Display for EventType {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            EventType::Query => write!(f, "QUERY"),
            EventType::Insert => write!(f, "INSERT"),
            EventType::Update => write!(f, "UPDATE"),
            EventType::Delete => write!(f, "DELETE"),
            EventType::SchemaChange => write!(f, "DDL"),
            EventType::Connection => write!(f, "CONNECT"),
            EventType::Vacuum => write!(f, "VACUUM"),
            EventType::Checkpoint => write!(f, "CHECKPOINT"),
        }
    }
}

/// Get current database activity from pg_stat_activity
pub async fn get_activity(
    conn: &super::PostgresConnection,
) -> Result<Vec<ActivityEntry>, super::PostgresError> {
    let query = r#"
        SELECT
            pid,
            COALESCE(datname, 'unknown') as database,
            COALESCE(usename, 'unknown') as username,
            application_name,
            client_addr::text,
            COALESCE(state, 'unknown') as state,
            query,
            query_start::text,
            xact_start::text,
            wait_event
        FROM pg_stat_activity
        WHERE pid != pg_backend_pid()
          AND datname IS NOT NULL
        ORDER BY query_start DESC NULLS LAST
        LIMIT 50
    "#;

    let rows = conn.query(query).await?;
    let mut entries = Vec::new();

    for row in rows {
        entries.push(ActivityEntry {
            pid: row.get(0),
            database: row.get(1),
            username: row.get(2),
            application: row.get(3),
            client_addr: row.get(4),
            state: row.get(5),
            query: row.get(6),
            query_start: row.get(7),
            xact_start: row.get(8),
            wait_event: row.get(9),
        });
    }

    Ok(entries)
}

/// Get table statistics from pg_stat_user_tables
pub async fn get_table_stats(
    conn: &super::PostgresConnection,
) -> Result<Vec<TableStats>, super::PostgresError> {
    let query = r#"
        SELECT
            schemaname,
            relname,
            seq_scan,
            seq_tup_read,
            idx_scan,
            idx_tup_fetch,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_live_tup,
            n_dead_tup,
            last_vacuum::text,
            last_autovacuum::text,
            last_analyze::text
        FROM pg_stat_user_tables
        ORDER BY n_tup_ins + n_tup_upd + n_tup_del DESC
        LIMIT 50
    "#;

    let rows = conn.query(query).await?;
    let mut stats = Vec::new();

    for row in rows {
        stats.push(TableStats {
            schema_name: row.get(0),
            table_name: row.get(1),
            seq_scan: row.get(2),
            seq_tup_read: row.get(3),
            idx_scan: row.get(4),
            idx_tup_fetch: row.get(5),
            n_tup_ins: row.get(6),
            n_tup_upd: row.get(7),
            n_tup_del: row.get(8),
            n_live_tup: row.get(9),
            n_dead_tup: row.get(10),
            last_vacuum: row.get(11),
            last_autovacuum: row.get(12),
            last_analyze: row.get(13),
        });
    }

    Ok(stats)
}

/// Build timeline events from activity and stats
pub async fn get_recent_events(
    conn: &super::PostgresConnection,
) -> Result<Vec<DatabaseEvent>, super::PostgresError> {
    let mut events = Vec::new();

    // Get current activity
    let activity = get_activity(conn).await?;
    for entry in activity {
        if let Some(query) = &entry.query {
            let event_type = classify_query(query);
            let timestamp = entry.query_start.unwrap_or_else(|| "now".to_string());

            // Truncate long queries for display
            let short_query = if query.len() > 60 {
                format!("{}...", &query[..60])
            } else {
                query.clone()
            };

            events.push(DatabaseEvent {
                timestamp,
                event_type,
                description: short_query,
                table_name: extract_table_name(query),
                details: Some(format!("pid={} user={}", entry.pid, entry.username)),
            });
        }
    }

    // Get table stats and add significant events
    let stats = get_table_stats(conn).await?;
    for stat in stats {
        // Add vacuum events
        if let Some(ts) = &stat.last_autovacuum {
            events.push(DatabaseEvent {
                timestamp: ts.clone(),
                event_type: EventType::Vacuum,
                description: format!("Autovacuum on {}.{}", stat.schema_name, stat.table_name),
                table_name: Some(stat.table_name.clone()),
                details: Some(format!("dead_tuples={}", stat.n_dead_tup)),
            });
        }

        // Add recent DML summary
        let total_changes = stat.n_tup_ins + stat.n_tup_upd + stat.n_tup_del;
        if total_changes > 0 {
            events.push(DatabaseEvent {
                timestamp: "cumulative".to_string(),
                event_type: EventType::Query,
                description: format!(
                    "{}.{}: {} ins, {} upd, {} del",
                    stat.schema_name, stat.table_name,
                    stat.n_tup_ins, stat.n_tup_upd, stat.n_tup_del
                ),
                table_name: Some(stat.table_name),
                details: Some(format!("live={} dead={}", stat.n_live_tup, stat.n_dead_tup)),
            });
        }
    }

    // Sort by timestamp (most recent first)
    events.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));

    Ok(events)
}

/// Classify a SQL query into an event type
fn classify_query(query: &str) -> EventType {
    let upper = query.to_uppercase();
    if upper.starts_with("INSERT") {
        EventType::Insert
    } else if upper.starts_with("UPDATE") {
        EventType::Update
    } else if upper.starts_with("DELETE") {
        EventType::Delete
    } else if upper.starts_with("CREATE") || upper.starts_with("ALTER") || upper.starts_with("DROP") {
        EventType::SchemaChange
    } else if upper.starts_with("VACUUM") {
        EventType::Vacuum
    } else if upper.starts_with("CHECKPOINT") {
        EventType::Checkpoint
    } else {
        EventType::Query
    }
}

/// Extract table name from a SQL query (simple heuristic)
fn extract_table_name(query: &str) -> Option<String> {
    let upper = query.to_uppercase();
    let words: Vec<&str> = query.split_whitespace().collect();

    // Look for FROM, INTO, UPDATE, TABLE keywords
    for (i, word) in words.iter().enumerate() {
        let upper_word = word.to_uppercase();
        if (upper_word == "FROM" || upper_word == "INTO" || upper_word == "UPDATE" || upper_word == "TABLE")
            && i + 1 < words.len()
        {
            let table = words[i + 1].trim_matches(|c| c == '(' || c == ')' || c == ';' || c == ',');
            if !table.is_empty() && !table.to_uppercase().starts_with("SELECT") {
                return Some(table.to_string());
            }
        }
    }
    None
}

/// Extract transaction log from pg_stat_activity and related views
pub async fn get_recent_transactions(
    conn: &super::PostgresConnection,
    limit: usize,
) -> Result<Vec<Transaction>, super::PostgresError> {
    // Query for transactions with active backends
    let query = format!(
        r#"
        SELECT
            COALESCE(backend_xid::text, '0')::bigint as xid,
            EXTRACT(EPOCH FROM xact_start)::bigint as start_time,
            state,
            query
        FROM pg_stat_activity
        WHERE xact_start IS NOT NULL
          AND pid != pg_backend_pid()
        ORDER BY xact_start DESC
        LIMIT {}
        "#,
        limit
    );

    let rows = conn.query(&query).await?;
    let mut transactions = Vec::new();

    for row in rows {
        let xid: i64 = row.get(0);
        let start_time: i64 = row.get(1);
        let state: String = row.get(2);
        let query: Option<String> = row.get(3);

        let status = match state.as_str() {
            "active" => TransactionStatus::Active,
            "idle in transaction" => TransactionStatus::Active,
            "idle" => TransactionStatus::Committed,
            _ => TransactionStatus::InDoubt,
        };

        let operations = if let Some(q) = query {
            let op_type = match classify_query(&q) {
                EventType::Insert => OperationType::Insert,
                EventType::Update => OperationType::Update,
                EventType::Delete => OperationType::Delete,
                _ => OperationType::Insert, // Default
            };
            vec![Operation {
                table: extract_table_name(&q).unwrap_or_else(|| "unknown".to_string()),
                operation_type: op_type,
                row_data: None,
            }]
        } else {
            vec![]
        };

        transactions.push(Transaction {
            xid: xid as u64,
            start_time: start_time as u64,
            end_time: None,
            status,
            operations,
        });
    }

    Ok(transactions)
}
