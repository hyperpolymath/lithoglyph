// SPDX-License-Identifier: PMPL-1.0-or-later
//! Lithoglyph Debugger CLI - IPC Bridge
//!
//! Provides JSON-based IPC for the Idris 2 REPL to communicate with database adapters.

use clap::{Parser, Subcommand};
use lithoglyph_debugger_postgres::{
    PostgresConnection, PostgresError,
    constraint_check::{check_all_constraints, ConstraintCheckResult, ConstraintViolation},
};
use serde::{Deserialize, Serialize};
use std::io::{self, BufRead, Write};

/// Lithoglyph Debugger CLI
#[derive(Parser)]
#[command(name = "fdb-debug")]
#[command(about = "Lithoglyph Debugger IPC Bridge", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Connect to a PostgreSQL database and introspect schema
    Schema {
        /// PostgreSQL connection string
        #[arg(short, long)]
        connection: String,
    },
    /// Run constraint diagnostics on database
    Diagnose {
        /// PostgreSQL connection string
        #[arg(short, long)]
        connection: String,
    },
    /// Run in interactive JSON-RPC mode (for IPC)
    Ipc,
    /// Check connection to database
    Ping {
        /// PostgreSQL connection string
        #[arg(short, long)]
        connection: String,
    },
}

/// JSON response wrapper
#[derive(Serialize)]
struct JsonResponse<T: Serialize> {
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    data: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

impl<T: Serialize> JsonResponse<T> {
    fn ok(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
        }
    }

    fn err(msg: impl Into<String>) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(msg.into()),
        }
    }
}

/// Schema output format
#[derive(Serialize)]
struct SchemaOutput {
    database_name: String,
    tables: Vec<TableOutput>,
    constraints: Vec<ConstraintOutput>,
    functional_deps: Vec<FunctionalDepOutput>,
}

#[derive(Serialize)]
struct TableOutput {
    schema_name: String,
    name: String,
    columns: Vec<ColumnOutput>,
    primary_key: Vec<String>,
}

#[derive(Serialize)]
struct ColumnOutput {
    name: String,
    data_type: String,
    nullable: bool,
}

#[derive(Serialize)]
struct ConstraintOutput {
    name: String,
    constraint_type: String,
    table_name: String,
    columns: Vec<String>,
    foreign_table: Option<String>,
    foreign_columns: Option<Vec<String>>,
}

#[derive(Serialize)]
struct FunctionalDepOutput {
    table_name: String,
    determinant: Vec<String>,
    dependent: Vec<String>,
    confidence: f64,
}

/// Diagnostic results output format
#[derive(Serialize)]
struct DiagnoseOutput {
    total_constraints: usize,
    satisfied: usize,
    violations: usize,
    results: Vec<ConstraintCheckOutput>,
}

#[derive(Serialize)]
struct ConstraintCheckOutput {
    constraint_name: String,
    constraint_type: String,
    table_name: String,
    satisfied: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    violation_count: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    explanation: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    sample_violations: Option<Vec<String>>,
}

/// IPC request format
#[derive(Deserialize)]
struct IpcRequest {
    id: u64,
    method: String,
    #[serde(default)]
    params: serde_json::Value,
}

/// IPC response format
#[derive(Serialize)]
struct IpcResponse {
    id: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<IpcError>,
}

#[derive(Serialize)]
struct IpcError {
    code: i32,
    message: String,
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    match cli.command {
        Commands::Schema { connection } => {
            match fetch_schema(&connection).await {
                Ok(schema) => {
                    let response = JsonResponse::ok(schema);
                    println!("{}", serde_json::to_string_pretty(&response).unwrap());
                }
                Err(e) => {
                    let response: JsonResponse<()> = JsonResponse::err(e.to_string());
                    println!("{}", serde_json::to_string_pretty(&response).unwrap());
                    std::process::exit(1);
                }
            }
        }
        Commands::Ping { connection } => {
            match ping_database(&connection).await {
                Ok(()) => {
                    let response = JsonResponse::ok("connected");
                    println!("{}", serde_json::to_string(&response).unwrap());
                }
                Err(e) => {
                    let response: JsonResponse<()> = JsonResponse::err(e.to_string());
                    println!("{}", serde_json::to_string(&response).unwrap());
                    std::process::exit(1);
                }
            }
        }
        Commands::Diagnose { connection } => {
            match run_diagnose(&connection).await {
                Ok(output) => {
                    let response = JsonResponse::ok(output);
                    println!("{}", serde_json::to_string_pretty(&response).unwrap());
                }
                Err(e) => {
                    let response: JsonResponse<()> = JsonResponse::err(e.to_string());
                    println!("{}", serde_json::to_string_pretty(&response).unwrap());
                    std::process::exit(1);
                }
            }
        }
        Commands::Ipc => {
            run_ipc_loop().await;
        }
    }
}

async fn fetch_schema(connection_string: &str) -> Result<SchemaOutput, PostgresError> {
    let mut conn = PostgresConnection::new(connection_string);
    conn.connect().await?;

    let schema = conn.introspect_schema().await?;

    let tables: Vec<TableOutput> = schema
        .tables
        .iter()
        .map(|t| TableOutput {
            schema_name: t.schema_name.clone(),
            name: t.name.clone(),
            columns: t
                .columns
                .iter()
                .map(|c| ColumnOutput {
                    name: c.name.clone(),
                    data_type: c.data_type.clone(),
                    nullable: c.nullable,
                })
                .collect(),
            primary_key: t.primary_key.clone(),
        })
        .collect();

    let constraints: Vec<ConstraintOutput> = schema
        .constraints
        .iter()
        .map(|c| ConstraintOutput {
            name: c.name.clone(),
            constraint_type: c.constraint_type.clone(),
            table_name: c.table_name.clone(),
            columns: c.columns.clone(),
            foreign_table: c.foreign_table.clone(),
            foreign_columns: c.foreign_columns.clone(),
        })
        .collect();

    // Infer functional dependencies from primary keys and unique constraints
    let mut functional_deps: Vec<FunctionalDepOutput> = Vec::new();
    for table in &schema.tables {
        if !table.primary_key.is_empty() {
            let dependent: Vec<String> = table
                .columns
                .iter()
                .map(|c| c.name.clone())
                .filter(|n| !table.primary_key.contains(n))
                .collect();
            if !dependent.is_empty() {
                functional_deps.push(FunctionalDepOutput {
                    table_name: table.name.clone(),
                    determinant: table.primary_key.clone(),
                    dependent,
                    confidence: 1.0,
                });
            }
        }
    }

    conn.close().await;

    Ok(SchemaOutput {
        database_name: schema.database_name,
        tables,
        constraints,
        functional_deps,
    })
}

async fn ping_database(connection_string: &str) -> Result<(), PostgresError> {
    let mut conn = PostgresConnection::new(connection_string);
    conn.connect().await?;
    conn.close().await;
    Ok(())
}

async fn run_diagnose(connection_string: &str) -> Result<DiagnoseOutput, PostgresError> {
    let mut conn = PostgresConnection::new(connection_string);
    conn.connect().await?;

    let schema = conn.introspect_schema().await?;

    // Convert schema constraints to PgConstraint format for checking
    let pg_constraints: Vec<_> = schema.constraints.iter().map(|c| {
        lithoglyph_debugger_postgres::schema::PgConstraint {
            name: c.name.clone(),
            constraint_type: match c.constraint_type.as_str() {
                "PRIMARY KEY" => lithoglyph_debugger_postgres::schema::ConstraintType::PrimaryKey,
                "FOREIGN KEY" => lithoglyph_debugger_postgres::schema::ConstraintType::ForeignKey,
                "UNIQUE" => lithoglyph_debugger_postgres::schema::ConstraintType::Unique,
                "CHECK" => lithoglyph_debugger_postgres::schema::ConstraintType::Check,
                _ => lithoglyph_debugger_postgres::schema::ConstraintType::Check,
            },
            table_schema: "public".to_string(), // Default
            table_name: c.table_name.clone(),
            columns: c.columns.clone(),
            foreign_table_schema: c.foreign_table.as_ref().map(|_| "public".to_string()),
            foreign_table_name: c.foreign_table.clone(),
            foreign_columns: c.foreign_columns.clone(),
            check_expression: None,
        }
    }).collect();

    let check_results = check_all_constraints(&conn, &pg_constraints).await?;

    let satisfied_count = check_results.iter().filter(|r| r.satisfied).count();
    let violation_count = check_results.iter().filter(|r| !r.satisfied).count();

    let results: Vec<ConstraintCheckOutput> = check_results.iter().map(|r| {
        ConstraintCheckOutput {
            constraint_name: r.constraint_name.clone(),
            constraint_type: r.constraint_type.clone(),
            table_name: r.table_name.clone(),
            satisfied: r.satisfied,
            violation_count: r.violation.as_ref().map(|v| v.violation_count),
            explanation: r.violation.as_ref().map(|v| v.explanation.clone()),
            sample_violations: r.violation.as_ref().map(|v| v.sample_violations.clone()),
        }
    }).collect();

    conn.close().await;

    Ok(DiagnoseOutput {
        total_constraints: check_results.len(),
        satisfied: satisfied_count,
        violations: violation_count,
        results,
    })
}

async fn run_ipc_loop() {
    let stdin = io::stdin();
    let mut stdout = io::stdout();
    let mut connection: Option<PostgresConnection> = None;

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(_) => break,
        };

        if line.trim().is_empty() {
            continue;
        }

        let request: IpcRequest = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                let response = IpcResponse {
                    id: 0,
                    result: None,
                    error: Some(IpcError {
                        code: -32700,
                        message: format!("Parse error: {}", e),
                    }),
                };
                writeln!(stdout, "{}", serde_json::to_string(&response).unwrap()).unwrap();
                stdout.flush().unwrap();
                continue;
            }
        };

        let response = match request.method.as_str() {
            "connect" => {
                let conn_str = request.params.as_str().unwrap_or("");
                let mut new_conn = PostgresConnection::new(conn_str);
                match new_conn.connect().await {
                    Ok(()) => {
                        connection = Some(new_conn);
                        IpcResponse {
                            id: request.id,
                            result: Some(serde_json::json!({"status": "connected"})),
                            error: None,
                        }
                    }
                    Err(e) => IpcResponse {
                        id: request.id,
                        result: None,
                        error: Some(IpcError {
                            code: -32000,
                            message: e.to_string(),
                        }),
                    },
                }
            }
            "schema" => {
                if let Some(ref mut conn) = connection {
                    match conn.introspect_schema().await {
                        Ok(schema) => {
                            let output = serde_json::to_value(SchemaOutput {
                                database_name: schema.database_name,
                                tables: schema
                                    .tables
                                    .iter()
                                    .map(|t| TableOutput {
                                        schema_name: t.schema_name.clone(),
                                        name: t.name.clone(),
                                        columns: t
                                            .columns
                                            .iter()
                                            .map(|c| ColumnOutput {
                                                name: c.name.clone(),
                                                data_type: c.data_type.clone(),
                                                nullable: c.nullable,
                                            })
                                            .collect(),
                                        primary_key: t.primary_key.clone(),
                                    })
                                    .collect(),
                                constraints: schema
                                    .constraints
                                    .iter()
                                    .map(|c| ConstraintOutput {
                                        name: c.name.clone(),
                                        constraint_type: c.constraint_type.clone(),
                                        table_name: c.table_name.clone(),
                                        columns: c.columns.clone(),
                                        foreign_table: c.foreign_table.clone(),
                                        foreign_columns: c.foreign_columns.clone(),
                                    })
                                    .collect(),
                                functional_deps: Vec::new(),
                            })
                            .unwrap();
                            IpcResponse {
                                id: request.id,
                                result: Some(output),
                                error: None,
                            }
                        }
                        Err(e) => IpcResponse {
                            id: request.id,
                            result: None,
                            error: Some(IpcError {
                                code: -32000,
                                message: e.to_string(),
                            }),
                        },
                    }
                } else {
                    IpcResponse {
                        id: request.id,
                        result: None,
                        error: Some(IpcError {
                            code: -32001,
                            message: "Not connected".to_string(),
                        }),
                    }
                }
            }
            "disconnect" => {
                if let Some(mut conn) = connection.take() {
                    conn.close().await;
                }
                IpcResponse {
                    id: request.id,
                    result: Some(serde_json::json!({"status": "disconnected"})),
                    error: None,
                }
            }
            "quit" => {
                if let Some(mut conn) = connection.take() {
                    conn.close().await;
                }
                break;
            }
            _ => IpcResponse {
                id: request.id,
                result: None,
                error: Some(IpcError {
                    code: -32601,
                    message: format!("Method not found: {}", request.method),
                }),
            },
        };

        writeln!(stdout, "{}", serde_json::to_string(&response).unwrap()).unwrap();
        stdout.flush().unwrap();
    }
}
