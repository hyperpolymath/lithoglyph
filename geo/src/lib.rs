// SPDX-License-Identifier: AGPL-3.0-or-later
//! FormBD-Geo library
//!
//! Geospatial extension for FormBD providing spatial indexing
//! and queries while preserving auditability guarantees.

pub mod api;
pub mod config;
pub mod lithoglyph;
pub mod index;

pub use config::Config;
pub use index::SpatialIndex;
