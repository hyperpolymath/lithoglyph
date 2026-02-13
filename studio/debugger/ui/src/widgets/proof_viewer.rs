// SPDX-License-Identifier: PMPL-1.0-or-later
//! Proof viewer widget for displaying Lean 4 proofs

use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::{Color, Modifier, Style},
    widgets::{Block, Borders, Widget},
};

/// A proof step in the verification
pub struct ProofStep {
    pub tactic: String,
    pub goal_before: String,
    pub goal_after: Option<String>,
}

/// A complete proof
pub struct Proof {
    pub theorem_name: String,
    pub statement: String,
    pub steps: Vec<ProofStep>,
    pub qed: bool,
}

/// Proof viewer widget
pub struct ProofViewerWidget<'a> {
    proof: &'a Proof,
    block: Option<Block<'a>>,
}

impl<'a> ProofViewerWidget<'a> {
    pub fn new(proof: &'a Proof) -> Self {
        Self { proof, block: None }
    }

    pub fn block(mut self, block: Block<'a>) -> Self {
        self.block = Some(block);
        self
    }
}

impl<'a> Widget for ProofViewerWidget<'a> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        let status = if self.proof.qed { "QED" } else { "incomplete" };
        let title = format!("Proof: {} [{}]", self.proof.theorem_name, status);
        let block = self
            .block
            .unwrap_or_else(|| Block::default().borders(Borders::ALL).title(title));
        let inner = block.inner(area);
        block.render(area, buf);

        let mut y = inner.y;

        // Theorem statement
        buf.set_string(
            inner.x,
            y,
            &format!("theorem {}", self.proof.theorem_name),
            Style::default()
                .fg(Color::Cyan)
                .add_modifier(Modifier::BOLD),
        );
        y += 1;

        buf.set_string(
            inner.x + 2,
            y,
            &self.proof.statement,
            Style::default().fg(Color::White),
        );
        y += 2;

        // Proof steps
        for step in &self.proof.steps {
            if y >= inner.y + inner.height {
                break;
            }

            buf.set_string(
                inner.x,
                y,
                &format!("  {}", step.tactic),
                Style::default().fg(Color::Yellow),
            );
            y += 1;
        }

        // QED
        if self.proof.qed && y < inner.y + inner.height {
            buf.set_string(
                inner.x,
                y,
                "  done",
                Style::default()
                    .fg(Color::Green)
                    .add_modifier(Modifier::BOLD),
            );
        }
    }
}
