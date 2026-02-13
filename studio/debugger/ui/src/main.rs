// SPDX-License-Identifier: PMPL-1.0-or-later
//! FormBD Debugger Terminal UI
//!
//! A Ratatui-based terminal interface for database debugging,
//! recovery plan generation, and proof verification.

use clap::Parser;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph, Wrap},
    Frame, Terminal,
};
use std::io;
use std::time::Duration;

mod app;
mod proofs;
mod widgets;

use app::{App, SchemaSelection, View};
use widgets::constraint_tree::{ConstraintNode, ConstraintTreeWidget};
use widgets::recovery_plan::RecoveryPlanWidget;
use widgets::timeline::{TimelineEntry, TimelineWidget};

/// FormBD Debugger - Proof-carrying database recovery
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Database connection string
    #[arg(short, long)]
    connect: Option<String>,

    /// Database type (postgres, lithoglyph, sqlite)
    #[arg(short = 't', long, default_value = "postgres")]
    db_type: String,

    /// Run in non-interactive mode
    #[arg(long)]
    batch: bool,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    if args.batch {
        // Batch mode - just run commands
        println!("FormBD Debugger v0.1.0 (batch mode)");
        if let Some(conn) = &args.connect {
            println!("Connecting to: {}", conn);
            // Connect and dump schema
            let mut pg = lithoglyph_debugger_postgres::PostgresConnection::new(conn);
            pg.connect().await?;
            let schema = pg.introspect_schema().await?;
            println!("Database: {}", schema.database_name);
            println!("Tables: {}", schema.tables.len());
            for t in &schema.tables {
                println!("  - {}.{} ({} columns)", t.schema_name, t.name, t.columns.len());
            }
        }
        return Ok(());
    }

    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create app with initial connection if provided
    let mut app = App::new();
    if let Some(conn) = &args.connect {
        app.status_message = format!("Connecting to {}...", conn);
        app.input_buffer = conn.clone();
    }

    // Run app
    let res = run_app(&mut terminal, &mut app).await;

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        println!("Error: {:?}", err);
    }

    Ok(())
}

async fn run_app<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut App,
) -> io::Result<()> {
    // Handle initial connection if provided
    if !app.input_buffer.is_empty() && !app.connected {
        let conn_str = app.input_buffer.clone();
        app.input_buffer.clear();
        connect_to_database(app, &conn_str).await;
    }

    loop {
        terminal.draw(|f| ui(f, app))?;

        // Poll for events with timeout to allow async operations
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                if key.kind == KeyEventKind::Press {
                    match key.code {
                        KeyCode::Char(c) => {
                            // Handle refresh separately
                            if c == 'R' && !app.input_mode {
                                handle_refresh(app).await;
                                continue;
                            }

                            let was_input_mode = app.input_mode;
                            app.on_key(c);

                            // Check if we just finished input mode (connection request)
                            if was_input_mode && !app.input_mode && !app.input_buffer.is_empty() {
                                let conn_str = app.input_buffer.clone();
                                app.input_buffer.clear();
                                connect_to_database(app, &conn_str).await;
                            }
                        }
                        KeyCode::Enter => {
                            if app.input_mode {
                                app.input_mode = false;
                                let conn_str = app.input_buffer.clone();
                                app.input_buffer.clear();
                                connect_to_database(app, &conn_str).await;
                            } else {
                                // Handle enter in views
                                handle_enter(app).await;
                            }
                        }
                        KeyCode::Esc => {
                            if app.input_mode {
                                app.input_mode = false;
                                app.input_buffer.clear();
                                app.status_message = "Connection cancelled".to_string();
                            }
                        }
                        KeyCode::Backspace => {
                            if app.input_mode {
                                app.input_buffer.pop();
                            }
                        }
                        KeyCode::Up => app.on_key('k'),
                        KeyCode::Down => app.on_key('j'),
                        _ => {}
                    }
                }
            }
        }

        if !app.running {
            return Ok(());
        }
    }
}

async fn connect_to_database(app: &mut App, conn_str: &str) {
    app.status_message = format!("Connecting to {}...", conn_str);

    let mut conn = lithoglyph_debugger_postgres::PostgresConnection::new(conn_str);
    match conn.connect().await {
        Ok(()) => {
            match conn.introspect_schema().await {
                Ok(schema) => {
                    app.set_connected(conn_str.to_string(), schema);

                    // Also load timeline events
                    match lithoglyph_debugger_postgres::get_recent_events(&conn).await {
                        Ok(events) => {
                            app.load_timeline_events(events);
                        }
                        Err(e) => {
                            // Non-fatal - just log it
                            app.status_message = format!(
                                "Connected: {} tables (timeline error: {})",
                                app.schema.as_ref().map(|s| s.tables.len()).unwrap_or(0),
                                e
                            );
                        }
                    }
                }
                Err(e) => {
                    app.status_message = format!("Schema error: {}", e);
                }
            }
        }
        Err(e) => {
            app.status_message = format!("Connection failed: {}", e);
        }
    }
}

async fn refresh_timeline(app: &mut App) {
    if let Some(conn_str) = &app.connection_string.clone() {
        let mut conn = lithoglyph_debugger_postgres::PostgresConnection::new(conn_str);
        if conn.connect().await.is_ok() {
            if let Ok(events) = lithoglyph_debugger_postgres::get_recent_events(&conn).await {
                app.load_timeline_events(events);
            }
        }
    }
}

async fn handle_enter(app: &mut App) {
    match app.view {
        View::Diagnose => {
            run_diagnostics(app).await;
        }
        View::Recover => {
            if app.recovery_plan.is_none() {
                app.generate_recovery_plan();
            }
        }
        _ => {}
    }
}

async fn run_diagnostics(app: &mut App) {
    if !app.connected {
        app.status_message = "Connect to a database first".to_string();
        return;
    }

    let Some(conn_str) = &app.connection_string.clone() else {
        app.status_message = "No connection string available".to_string();
        return;
    };

    if app.schema.is_none() {
        app.status_message = "No schema loaded".to_string();
        return;
    }

    app.start_diagnostics();

    // Connect and run constraint checks
    let mut conn = lithoglyph_debugger_postgres::PostgresConnection::new(conn_str);
    match conn.connect().await {
        Ok(()) => {
            // Get the full schema with PgConstraint type for checking
            match lithoglyph_debugger_postgres::schema::introspect_constraints(&conn).await {
                Ok(constraints) => {
                    match lithoglyph_debugger_postgres::check_all_constraints(&conn, &constraints).await {
                        Ok(results) => {
                            app.load_constraint_results(results);
                        }
                        Err(e) => {
                            app.status_message = format!("Constraint check failed: {}", e);
                        }
                    }
                }
                Err(e) => {
                    app.status_message = format!("Failed to load constraints: {}", e);
                }
            }
        }
        Err(e) => {
            app.status_message = format!("Connection failed: {}", e);
        }
    }
}

async fn handle_refresh(app: &mut App) {
    match app.view {
        View::Timeline => {
            app.status_message = "Refreshing timeline...".to_string();
            refresh_timeline(app).await;
        }
        View::Schema => {
            // Reload schema
            if let Some(conn_str) = &app.connection_string.clone() {
                app.status_message = "Refreshing schema...".to_string();
                connect_to_database(app, conn_str).await;
            }
        }
        _ => {}
    }
}

fn ui(f: &mut Frame, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .margin(1)
        .constraints([
            Constraint::Length(3),  // Header
            Constraint::Min(0),     // Main content
            Constraint::Length(3),  // Footer/status
        ])
        .split(f.area());

    // Header
    render_header(f, app, chunks[0]);

    // Main content based on view
    match app.view {
        View::Home => render_home(f, app, chunks[1]),
        View::Schema => render_schema(f, app, chunks[1]),
        View::Timeline => render_timeline(f, app, chunks[1]),
        View::Diagnose => render_diagnose(f, app, chunks[1]),
        View::Recover => render_recover(f, app, chunks[1]),
        View::Help => render_help(f, chunks[1]),
    }

    // Footer/status
    render_footer(f, app, chunks[2]);
}

fn render_header(f: &mut Frame, app: &App, area: Rect) {
    let conn_status = if app.connected {
        Span::styled(" CONNECTED ", Style::default().fg(Color::Black).bg(Color::Green))
    } else {
        Span::styled(" DISCONNECTED ", Style::default().fg(Color::Black).bg(Color::Red))
    };

    let db_name = app
        .schema
        .as_ref()
        .map(|s| s.database_name.as_str())
        .unwrap_or("none");

    let title = Line::from(vec![
        Span::styled("FormBD Debugger v0.1.0", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
        Span::raw(" │ "),
        conn_status,
        Span::raw(" │ "),
        Span::styled(format!("DB: {}", db_name), Style::default().fg(Color::Yellow)),
    ]);

    let header = Paragraph::new(title)
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(header, area);
}

fn render_footer(f: &mut Frame, app: &App, area: Rect) {
    let status = if app.input_mode {
        Line::from(vec![
            Span::styled("Connection: ", Style::default().fg(Color::Yellow)),
            Span::raw(&app.input_buffer),
            Span::styled("_", Style::default().add_modifier(Modifier::SLOW_BLINK)),
        ])
    } else {
        Line::from(vec![
            Span::styled(&app.status_message, Style::default().fg(Color::White)),
            Span::raw(" │ "),
            Span::styled("q", Style::default().fg(Color::Yellow)),
            Span::raw(":quit "),
            Span::styled("c", Style::default().fg(Color::Yellow)),
            Span::raw(":connect "),
            Span::styled("s", Style::default().fg(Color::Yellow)),
            Span::raw(":schema "),
            Span::styled("d", Style::default().fg(Color::Yellow)),
            Span::raw(":diagnose "),
            Span::styled("?", Style::default().fg(Color::Yellow)),
            Span::raw(":help"),
        ])
    };

    let footer = Paragraph::new(status)
        .block(Block::default().borders(Borders::ALL).title("Status"));
    f.render_widget(footer, area);
}

fn render_home(f: &mut Frame, app: &App, area: Rect) {
    let text = if app.connected {
        vec![
            Line::from(""),
            Line::from(Span::styled("Connected to database", Style::default().fg(Color::Green).add_modifier(Modifier::BOLD))),
            Line::from(""),
            Line::from("Press 's' to view schema"),
            Line::from("Press 'd' to run diagnostics"),
            Line::from("Press 'r' to view recovery options"),
            Line::from("Press 'D' to disconnect"),
        ]
    } else {
        vec![
            Line::from(""),
            Line::from(Span::styled("Welcome to FormBD Debugger", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))),
            Line::from(""),
            Line::from("A proof-carrying database recovery tool that ensures"),
            Line::from("lossless decomposition and constraint preservation."),
            Line::from(""),
            Line::from(Span::styled("Getting Started:", Style::default().add_modifier(Modifier::BOLD))),
            Line::from("  1. Press 'c' to connect to a PostgreSQL database"),
            Line::from("  2. View schema with 's'"),
            Line::from("  3. Run diagnostics with 'd'"),
            Line::from("  4. Generate recovery plan with 'r'"),
            Line::from(""),
            Line::from(Span::styled("Press '?' for help", Style::default().fg(Color::Yellow))),
        ]
    };

    let home = Paragraph::new(text)
        .block(Block::default().borders(Borders::ALL).title("Home"))
        .wrap(Wrap { trim: true });
    f.render_widget(home, area);
}

fn render_schema(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(40), Constraint::Percentage(60)])
        .split(area);

    // Tables list
    if let Some(schema) = &app.schema {
        let items: Vec<ListItem> = schema
            .tables
            .iter()
            .enumerate()
            .map(|(i, t)| {
                let style = match &app.schema_selection {
                    SchemaSelection::Table(idx) if *idx == i => {
                        Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD)
                    }
                    _ => Style::default(),
                };
                ListItem::new(format!("{}.{} ({} cols)", t.schema_name, t.name, t.columns.len()))
                    .style(style)
            })
            .collect();

        let tables = List::new(items)
            .block(Block::default().borders(Borders::ALL).title("Tables"))
            .highlight_style(Style::default().add_modifier(Modifier::REVERSED));
        f.render_widget(tables, chunks[0]);

        // Table details
        let detail = match &app.schema_selection {
            SchemaSelection::Table(idx) if *idx < schema.tables.len() => {
                let table = &schema.tables[*idx];
                let mut lines = vec![
                    Line::from(Span::styled(
                        format!("Table: {}.{}", table.schema_name, table.name),
                        Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
                    )),
                    Line::from(""),
                    Line::from(Span::styled("Columns:", Style::default().add_modifier(Modifier::BOLD))),
                ];
                for col in &table.columns {
                    let nullable = if col.nullable { "NULL" } else { "NOT NULL" };
                    lines.push(Line::from(format!("  {} {} {}", col.name, col.data_type, nullable)));
                }
                lines.push(Line::from(""));
                lines.push(Line::from(Span::styled("Primary Key:", Style::default().add_modifier(Modifier::BOLD))));
                lines.push(Line::from(format!("  {:?}", table.primary_key)));

                // Show related constraints
                let constraints: Vec<_> = schema
                    .constraints
                    .iter()
                    .filter(|c| c.table_name == table.name)
                    .collect();
                if !constraints.is_empty() {
                    lines.push(Line::from(""));
                    lines.push(Line::from(Span::styled("Constraints:", Style::default().add_modifier(Modifier::BOLD))));
                    for c in constraints {
                        lines.push(Line::from(format!("  {} ({})", c.name, c.constraint_type)));
                    }
                }
                lines
            }
            _ => vec![
                Line::from(""),
                Line::from("Select a table with j/k or arrow keys"),
            ],
        };

        let detail_widget = Paragraph::new(detail)
            .block(Block::default().borders(Borders::ALL).title("Details"))
            .wrap(Wrap { trim: true });
        f.render_widget(detail_widget, chunks[1]);
    } else {
        let no_schema = Paragraph::new("No schema loaded")
            .block(Block::default().borders(Borders::ALL).title("Schema"));
        f.render_widget(no_schema, area);
    }
}

fn render_timeline(f: &mut Frame, app: &App, area: Rect) {
    if app.timeline_entries.is_empty() {
        let empty = Paragraph::new("No timeline entries.\n\nTimeline shows database changes over time.\nConnect to a database to see activity.")
            .block(Block::default().borders(Borders::ALL).title("Timeline"));
        f.render_widget(empty, area);
    } else {
        let widget = TimelineWidget::new(&app.timeline_entries)
            .block(Block::default().borders(Borders::ALL).title("Timeline"));
        f.render_widget(widget, area);
    }
}

fn render_diagnose(f: &mut Frame, app: &App, area: Rect) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(3), Constraint::Min(0)])
        .split(area);

    // Instructions
    let instructions = Paragraph::new("Press Enter to run diagnostics")
        .style(Style::default().fg(Color::Yellow))
        .block(Block::default().borders(Borders::ALL));
    f.render_widget(instructions, chunks[0]);

    // Constraint tree
    if app.constraint_nodes.is_empty() {
        let empty = Paragraph::new("No constraints loaded.\n\nConnect to a database and press Enter to run diagnostics.")
            .block(Block::default().borders(Borders::ALL).title("Constraints"));
        f.render_widget(empty, chunks[1]);
    } else {
        let widget = ConstraintTreeWidget::new(&app.constraint_nodes)
            .block(Block::default().borders(Borders::ALL).title("Constraint Status"));
        f.render_widget(widget, chunks[1]);
    }
}

fn render_recover(f: &mut Frame, app: &App, area: Rect) {
    if let Some(plan) = &app.recovery_plan {
        let widget = RecoveryPlanWidget::new(plan)
            .block(Block::default().borders(Borders::ALL));
        f.render_widget(widget, area);
    } else {
        let violations: usize = app.constraint_nodes.iter().filter(|c| !c.satisfied).count();
        let text = if violations > 0 {
            format!(
                "Found {} constraint violations.\n\nPress Enter to generate a recovery plan.",
                violations
            )
        } else {
            "No violations detected.\n\nRun diagnostics first (press 'd') to check for issues.".to_string()
        };
        let empty = Paragraph::new(text)
            .block(Block::default().borders(Borders::ALL).title("Recovery Plan"));
        f.render_widget(empty, area);
    }
}

fn render_help(f: &mut Frame, area: Rect) {
    let help_text = vec![
        Line::from(Span::styled("FormBD Debugger Help", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))),
        Line::from(""),
        Line::from(Span::styled("Navigation:", Style::default().add_modifier(Modifier::BOLD))),
        Line::from("  h       - Go to home view"),
        Line::from("  s       - View schema"),
        Line::from("  t       - View timeline"),
        Line::from("  d       - Run diagnostics"),
        Line::from("  r       - View recovery plan"),
        Line::from("  ?       - Show this help"),
        Line::from("  j/↓     - Navigate down"),
        Line::from("  k/↑     - Navigate up"),
        Line::from("  Enter   - Select/confirm"),
        Line::from("  R       - Refresh current view"),
        Line::from("  q       - Quit"),
        Line::from(""),
        Line::from(Span::styled("Connection:", Style::default().add_modifier(Modifier::BOLD))),
        Line::from("  c       - Connect to database"),
        Line::from("  D       - Disconnect"),
        Line::from(""),
        Line::from(Span::styled("Timeline:", Style::default().add_modifier(Modifier::BOLD))),
        Line::from("  Shows database activity from pg_stat_activity"),
        Line::from("  and table statistics from pg_stat_user_tables."),
        Line::from("  Press R to refresh."),
        Line::from(""),
        Line::from(Span::styled("About:", Style::default().add_modifier(Modifier::BOLD))),
        Line::from("  FormBD Debugger provides proof-carrying database"),
        Line::from("  recovery with Lean 4 verified decomposition."),
    ];

    let help = Paragraph::new(help_text)
        .block(Block::default().borders(Borders::ALL).title("Help"))
        .wrap(Wrap { trim: true });
    f.render_widget(help, area);
}
