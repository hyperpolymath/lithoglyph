// SPDX-License-Identifier: PMPL-1.0-or-later
//! FormBD-Geo: Geospatial extension for FormBD
//!
//! Provides spatial indexing and queries while preserving FormBD's
//! auditability guarantees. All spatial data is projected from FormBD,
//! which remains the source of truth.

use anyhow::Result;
use clap::Parser;
use std::path::PathBuf;
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod api;
mod config;
mod lithoglyph;
mod index;

pub use config::Config;

/// FormBD-Geo: Geospatial extension for FormBD
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Path to configuration file
    #[arg(short, long, default_value = "lithoglyph-geo.toml")]
    config: PathBuf,

    /// Override FormBD API URL
    #[arg(long)]
    lithoglyph_url: Option<String>,

    /// Override server port
    #[arg(short, long)]
    port: Option<u16>,
}

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "lithoglyph_geo=info,tower_http=debug".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    let args = Args::parse();

    // Load configuration
    let mut config = Config::load(&args.config)?;

    // Apply CLI overrides
    if let Some(url) = args.lithoglyph_url {
        config.lithoglyph.api_url = url;
    }
    if let Some(port) = args.port {
        config.server.port = port;
    }

    info!("FormBD-Geo starting");
    info!("FormBD API: {}", config.lithoglyph.api_url);
    info!("Listening on {}:{}", config.server.host, config.server.port);

    // Create FormBD client
    let lithoglyph_client = lithoglyph::Client::new(&config.lithoglyph.api_url)?;

    // Create spatial index
    let spatial_index = index::SpatialIndex::new(config.index.max_memory_mb);

    // Create application state
    let app_state = api::AppState::new(lithoglyph_client, spatial_index, config.clone());

    // Start HTTP server
    api::serve(app_state).await?;

    Ok(())
}
