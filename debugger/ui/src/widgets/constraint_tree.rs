// SPDX-License-Identifier: AGPL-3.0-or-later
//! Constraint tree visualization widget

use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::{Color, Modifier, Style},
    widgets::{Block, Borders, Widget},
};

/// A constraint with its status
#[derive(Debug, Clone)]
pub struct ConstraintNode {
    pub name: String,
    pub constraint_type: String,
    pub table_name: String,
    pub satisfied: bool,
    pub violation_count: Option<i64>,
    pub violation_message: Option<String>,
}

impl ConstraintNode {
    /// Create from a ConstraintCheckResult
    pub fn from_check_result(
        name: String,
        constraint_type: String,
        table_name: String,
        satisfied: bool,
        violation_count: Option<i64>,
        explanation: Option<String>,
    ) -> Self {
        Self {
            name,
            constraint_type,
            table_name,
            satisfied,
            violation_count,
            violation_message: explanation,
        }
    }
}

/// Constraint tree widget
pub struct ConstraintTreeWidget<'a> {
    constraints: &'a [ConstraintNode],
    block: Option<Block<'a>>,
    selected: Option<usize>,
}

impl<'a> ConstraintTreeWidget<'a> {
    pub fn new(constraints: &'a [ConstraintNode]) -> Self {
        Self {
            constraints,
            block: None,
            selected: None,
        }
    }

    pub fn block(mut self, block: Block<'a>) -> Self {
        self.block = Some(block);
        self
    }

    pub fn selected(mut self, index: Option<usize>) -> Self {
        self.selected = index;
        self
    }
}

impl<'a> Widget for ConstraintTreeWidget<'a> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        let block = self
            .block
            .unwrap_or_else(|| Block::default().borders(Borders::ALL).title("Constraints"));
        let inner = block.inner(area);
        block.render(area, buf);

        if self.constraints.is_empty() {
            let msg = "No constraints loaded. Run diagnostics (D)";
            buf.set_string(inner.x, inner.y, msg, Style::default().fg(Color::DarkGray));
            return;
        }

        // Summary line
        let satisfied = self.constraints.iter().filter(|c| c.satisfied).count();
        let total = self.constraints.len();
        let summary = format!(
            "{}/{} constraints satisfied",
            satisfied, total
        );
        let summary_style = if satisfied == total {
            Style::default().fg(Color::Green)
        } else {
            Style::default().fg(Color::Yellow)
        };
        buf.set_string(inner.x, inner.y, &summary, summary_style);

        // List constraints
        for (i, constraint) in self.constraints.iter().enumerate() {
            let row = i + 2; // Skip summary + blank line
            if row >= inner.height as usize {
                break;
            }

            let (icon, base_style) = if constraint.satisfied {
                ("✓", Style::default().fg(Color::Green))
            } else {
                ("✗", Style::default().fg(Color::Red))
            };

            let style = if self.selected == Some(i) {
                base_style.add_modifier(Modifier::REVERSED)
            } else {
                base_style
            };

            // Main line: icon name (type) on table
            let line = format!(
                "{} {} ({}) on {}",
                icon, constraint.name, constraint.constraint_type, constraint.table_name
            );
            buf.set_string(inner.x, inner.y + row as u16, &line, style);

            // Show violation details on next line if not satisfied
            if !constraint.satisfied && row + 1 < inner.height as usize {
                let detail = if let Some(count) = constraint.violation_count {
                    format!("    {} violations", count)
                } else if let Some(ref msg) = constraint.violation_message {
                    format!("    {}", msg)
                } else {
                    "    Violation detected".to_string()
                };
                buf.set_string(
                    inner.x,
                    inner.y + (row + 1) as u16,
                    &detail,
                    Style::default().fg(Color::DarkGray),
                );
            }
        }
    }
}
