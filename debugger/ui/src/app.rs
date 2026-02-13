// SPDX-License-Identifier: PMPL-1.0-or-later
//! Application state management

use crate::proofs;
use crate::widgets::constraint_tree::ConstraintNode;
use crate::widgets::recovery_plan::{RecoveryPlan, RecoveryStep};
use crate::widgets::timeline::TimelineEntry;
use lithoglyph_debugger_postgres::{DatabaseEvent, EventType, SchemaInfo, ConstraintCheckResult};

/// Current view in the debugger
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum View {
    Home,
    Schema,
    Timeline,
    Diagnose,
    Recover,
    Help,
}

/// Selected item in schema view
#[derive(Debug, Clone)]
pub enum SchemaSelection {
    Tables,
    Table(usize),
    Constraints,
    Constraint(usize),
}

/// Application state
pub struct App {
    pub running: bool,
    pub view: View,
    pub connected: bool,
    pub connection_string: Option<String>,
    pub db_type: String,
    pub status_message: String,
    // Schema data from database
    pub schema: Option<SchemaInfo>,
    pub schema_selection: SchemaSelection,
    // Timeline data
    pub timeline_entries: Vec<TimelineEntry>,
    // Constraint check results
    pub constraint_nodes: Vec<ConstraintNode>,
    // Recovery plan
    pub recovery_plan: Option<RecoveryPlan>,
    // Input buffer for connection string
    pub input_mode: bool,
    pub input_buffer: String,
}

impl Default for App {
    fn default() -> Self {
        Self {
            running: true,
            view: View::Home,
            connected: false,
            connection_string: None,
            db_type: "postgres".to_string(),
            status_message: "Press 'c' to connect, '?' for help".to_string(),
            schema: None,
            schema_selection: SchemaSelection::Tables,
            timeline_entries: Vec::new(),
            constraint_nodes: Vec::new(),
            recovery_plan: None,
            input_mode: false,
            input_buffer: String::new(),
        }
    }
}

impl App {
    /// Create a new app instance
    pub fn new() -> Self {
        Self::default()
    }

    /// Handle keyboard input
    pub fn on_key(&mut self, key: char) {
        if self.input_mode {
            match key {
                '\n' => {
                    self.input_mode = false;
                    // Connection will be handled by main loop
                }
                '\x1b' => {
                    // Escape - cancel input
                    self.input_mode = false;
                    self.input_buffer.clear();
                    self.status_message = "Connection cancelled".to_string();
                }
                '\x7f' | '\x08' => {
                    // Backspace
                    self.input_buffer.pop();
                }
                c => {
                    self.input_buffer.push(c);
                }
            }
            return;
        }

        match key {
            'q' => self.running = false,
            'h' => self.view = View::Home,
            's' => {
                if self.schema.is_some() {
                    self.view = View::Schema;
                } else {
                    self.status_message = "No schema loaded. Connect first.".to_string();
                }
            }
            't' => self.view = View::Timeline,
            'd' => self.view = View::Diagnose,
            'r' => self.view = View::Recover,
            '?' => self.view = View::Help,
            'c' => {
                if !self.connected {
                    self.input_mode = true;
                    self.input_buffer = "postgres://lithoglyph:lithoglyph_dev@localhost/lithoglyph_demo".to_string();
                    self.status_message = "Enter connection string (Enter to confirm, Esc to cancel)".to_string();
                }
            }
            'D' => {
                if self.connected {
                    self.disconnect();
                }
            }
            'j' | 'J' => self.navigate_down(),
            'k' | 'K' => self.navigate_up(),
            _ => {}
        }
    }

    /// Navigate down in current view
    fn navigate_down(&mut self) {
        if let View::Schema = self.view {
            if let Some(schema) = &self.schema {
                match &self.schema_selection {
                    SchemaSelection::Tables => {
                        if !schema.tables.is_empty() {
                            self.schema_selection = SchemaSelection::Table(0);
                        }
                    }
                    SchemaSelection::Table(i) => {
                        if *i + 1 < schema.tables.len() {
                            self.schema_selection = SchemaSelection::Table(i + 1);
                        }
                    }
                    SchemaSelection::Constraints => {
                        if !schema.constraints.is_empty() {
                            self.schema_selection = SchemaSelection::Constraint(0);
                        }
                    }
                    SchemaSelection::Constraint(i) => {
                        if *i + 1 < schema.constraints.len() {
                            self.schema_selection = SchemaSelection::Constraint(i + 1);
                        }
                    }
                }
            }
        }
    }

    /// Navigate up in current view
    fn navigate_up(&mut self) {
        if let View::Schema = self.view {
            match &self.schema_selection {
                SchemaSelection::Table(i) => {
                    if *i > 0 {
                        self.schema_selection = SchemaSelection::Table(i - 1);
                    } else {
                        self.schema_selection = SchemaSelection::Tables;
                    }
                }
                SchemaSelection::Constraint(i) => {
                    if *i > 0 {
                        self.schema_selection = SchemaSelection::Constraint(i - 1);
                    } else {
                        self.schema_selection = SchemaSelection::Constraints;
                    }
                }
                _ => {}
            }
        }
    }

    /// Set connected state with schema
    pub fn set_connected(&mut self, conn_str: String, schema: SchemaInfo) {
        self.connected = true;
        self.connection_string = Some(conn_str);
        self.status_message = format!(
            "Connected: {} tables, {} constraints. Press 'D' to run diagnostics.",
            schema.tables.len(),
            schema.constraints.len()
        );
        // Build constraint nodes from schema (unchecked state)
        self.constraint_nodes = schema
            .constraints
            .iter()
            .map(|c| ConstraintNode {
                name: c.name.clone(),
                constraint_type: c.constraint_type.clone(),
                table_name: c.table_name.clone(),
                satisfied: true, // Assume satisfied until diagnosed
                violation_count: None,
                violation_message: Some("Not yet checked".to_string()),
            })
            .collect();
        self.schema = Some(schema);
        self.view = View::Schema;
    }

    /// Disconnect from database
    pub fn disconnect(&mut self) {
        self.connected = false;
        self.connection_string = None;
        self.schema = None;
        self.constraint_nodes.clear();
        self.timeline_entries.clear();
        self.recovery_plan = None;
        self.status_message = "Disconnected".to_string();
        self.view = View::Home;
    }

    /// Mark diagnostics as running (actual check happens in main loop)
    pub fn start_diagnostics(&mut self) {
        self.status_message = "Running constraint diagnostics...".to_string();
    }

    /// Load constraint check results from database
    pub fn load_constraint_results(&mut self, results: Vec<ConstraintCheckResult>) {
        self.constraint_nodes = results
            .into_iter()
            .map(|r| {
                let (violation_count, violation_message) = if let Some(ref v) = r.violation {
                    (Some(v.violation_count), Some(v.explanation.clone()))
                } else {
                    (None, None)
                };
                ConstraintNode {
                    name: r.constraint_name,
                    constraint_type: r.constraint_type,
                    table_name: r.table_name,
                    satisfied: r.satisfied,
                    violation_count,
                    violation_message,
                }
            })
            .collect();

        let violations: usize = self.constraint_nodes.iter().filter(|c| !c.satisfied).count();
        self.status_message = format!(
            "Diagnostics complete: {} constraint{} checked, {} violation{} found",
            self.constraint_nodes.len(),
            if self.constraint_nodes.len() == 1 { "" } else { "s" },
            violations,
            if violations == 1 { "" } else { "s" }
        );
        self.view = View::Diagnose;
    }

    /// Load timeline events from database events
    pub fn load_timeline_events(&mut self, events: Vec<DatabaseEvent>) {
        self.timeline_entries = events
            .into_iter()
            .map(|e| {
                let has_violation = matches!(e.event_type, EventType::Delete | EventType::SchemaChange);
                TimelineEntry {
                    timestamp: e.timestamp,
                    entry_type: e.event_type.to_string(),
                    description: e.description,
                    has_violation,
                }
            })
            .collect();
        self.status_message = format!("Timeline loaded: {} events", self.timeline_entries.len());
    }

    /// Generate a recovery plan with proof-carrying operations
    pub fn generate_recovery_plan(&mut self) {
        let violations: Vec<_> = self
            .constraint_nodes
            .iter()
            .filter(|c| !c.satisfied)
            .collect();

        if violations.is_empty() {
            self.status_message = "No violations to recover from".to_string();
            return;
        }

        let steps: Vec<RecoveryStep> = violations
            .iter()
            .enumerate()
            .map(|(i, v)| {
                // Determine recovery action based on constraint type
                let (description, sql) = match v.constraint_type.as_str() {
                    "FOREIGN KEY" => (
                        format!("Delete orphan rows violating {} on {}", v.name, v.table_name),
                        format!("DELETE FROM \"{}\" WHERE ... -- orphan FK rows", v.table_name),
                    ),
                    "UNIQUE" | "PRIMARY KEY" => (
                        format!("Remove duplicate rows violating {} on {}", v.name, v.table_name),
                        format!("DELETE FROM \"{}\" WHERE ctid NOT IN (...) -- keep first occurrence", v.table_name),
                    ),
                    "CHECK" => (
                        format!("Update rows to satisfy {} on {}", v.name, v.table_name),
                        format!("UPDATE \"{}\" SET ... WHERE NOT (check_expr)", v.table_name),
                    ),
                    _ => (
                        format!("Fix {} violation on {}", v.constraint_type, v.table_name),
                        format!("-- Recovery SQL for {}", v.name),
                    ),
                };

                // Get applicable Lean 4 proofs for this recovery step
                let proof_refs = proofs::proofs_for_step(&description);
                let proof_annotations: Vec<String> = proof_refs
                    .iter()
                    .map(|p| p.annotation())
                    .collect();

                RecoveryStep {
                    number: i + 1,
                    description,
                    sql,
                    proofs: proof_annotations,
                }
            })
            .collect();

        // Calculate proof coverage
        let step_descriptions: Vec<String> = steps.iter().map(|s| s.description.clone()).collect();
        let coverage = proofs::ProofCoverage::from_steps(&step_descriptions);

        self.recovery_plan = Some(RecoveryPlan {
            name: "Proof-Carrying Recovery".to_string(),
            steps,
            all_verified: coverage.steps_with_proofs == coverage.total_steps,
        });

        self.status_message = format!(
            "Recovery plan: {} steps, {} proofs, properties: {}",
            coverage.total_steps,
            coverage.unique_proofs,
            coverage.proven_properties.join(", ")
        );
        self.view = View::Recover;
    }
}
