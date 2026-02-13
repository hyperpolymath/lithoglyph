// SPDX-License-Identifier: PMPL-1.0-or-later
//! Timeline visualization widget

use ratatui::{
    buffer::Buffer,
    layout::Rect,
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Widget},
};

/// A timeline entry
pub struct TimelineEntry {
    pub timestamp: String,
    pub entry_type: String,
    pub description: String,
    pub has_violation: bool,
}

/// Timeline widget showing database history
pub struct TimelineWidget<'a> {
    entries: &'a [TimelineEntry],
    block: Option<Block<'a>>,
}

impl<'a> TimelineWidget<'a> {
    pub fn new(entries: &'a [TimelineEntry]) -> Self {
        Self {
            entries,
            block: None,
        }
    }

    pub fn block(mut self, block: Block<'a>) -> Self {
        self.block = Some(block);
        self
    }
}

impl<'a> Widget for TimelineWidget<'a> {
    fn render(self, area: Rect, buf: &mut Buffer) {
        let block = self
            .block
            .unwrap_or_else(|| Block::default().borders(Borders::ALL).title("Timeline"));
        let inner = block.inner(area);
        block.render(area, buf);

        for (i, entry) in self.entries.iter().enumerate() {
            if i >= inner.height as usize {
                break;
            }

            let style = if entry.has_violation {
                Style::default().fg(Color::Red)
            } else {
                Style::default().fg(Color::Green)
            };

            let line = format!(
                "[{}] {} - {}",
                entry.timestamp, entry.entry_type, entry.description
            );

            buf.set_string(inner.x, inner.y + i as u16, &line, style);
        }
    }
}
