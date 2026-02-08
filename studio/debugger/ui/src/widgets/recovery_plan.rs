// SPDX-License-Identifier: AGPL-3.0-or-later
//! Recovery plan display widget

use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::{Color, Modifier, Style},
    widgets::{Block, Borders, Widget},
};

/// A recovery step
pub struct RecoveryStep {
    pub number: usize,
    pub description: String,
    pub sql: String,
    pub proofs: Vec<String>,
}

/// A complete recovery plan
pub struct RecoveryPlan {
    pub name: String,
    pub steps: Vec<RecoveryStep>,
    pub all_verified: bool,
}

/// Recovery plan widget
pub struct RecoveryPlanWidget<'a> {
    plan: &'a RecoveryPlan,
    block: Option<Block<'a>>,
}

impl<'a> RecoveryPlanWidget<'a> {
    pub fn new(plan: &'a RecoveryPlan) -> Self {
        Self { plan, block: None }
    }

    pub fn block(mut self, block: Block<'a>) -> Self {
        self.block = Some(block);
        self
    }
}

impl<'a> Widget for RecoveryPlanWidget<'a> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        let title = format!(
            "Recovery Plan: {} {}",
            self.plan.name,
            if self.plan.all_verified { "✓" } else { "⚠" }
        );
        let block = self
            .block
            .unwrap_or_else(|| Block::default().borders(Borders::ALL).title(title));
        let inner = block.inner(area);
        block.render(area, buf);

        let mut y = inner.y;
        for step in &self.plan.steps {
            if y >= inner.y + inner.height {
                break;
            }

            // Step number and description
            let step_line = format!("{}. {}", step.number, step.description);
            buf.set_string(
                inner.x,
                y,
                &step_line,
                Style::default().add_modifier(Modifier::BOLD),
            );
            y += 1;

            // Proofs
            for proof in &step.proofs {
                if y >= inner.y + inner.height {
                    break;
                }
                let proof_line = format!("   ✓ {}", proof);
                buf.set_string(inner.x, y, &proof_line, Style::default().fg(Color::Green));
                y += 1;
            }
        }
    }
}
