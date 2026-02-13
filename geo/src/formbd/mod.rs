// SPDX-License-Identifier: PMPL-1.0-or-later
//! FormBD HTTP client
//!
//! Client for communicating with FormBD's HTTP API to fetch
//! documents for spatial indexing.

use anyhow::{Context, Result};
use reqwest::Client as HttpClient;
use serde::{Deserialize, Serialize};
use tracing::{debug, info};

/// Client for FormBD HTTP API
pub struct Client {
    http: HttpClient,
    base_url: String,
}

/// A document from FormBD
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Document {
    /// Document ID
    pub id: String,
    /// Document data (arbitrary JSON)
    pub data: serde_json::Value,
    /// Provenance information
    pub provenance: Option<Provenance>,
}

/// Provenance metadata for a document
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Provenance {
    /// Who created this document
    pub created_by: Option<String>,
    /// When it was created
    pub created_at: Option<String>,
    /// Rationale for creation
    pub rationale: Option<String>,
}

/// Location data extracted from a document
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Location {
    pub lat: f64,
    pub lon: f64,
}

impl Client {
    /// Create a new FormBD client
    pub fn new(base_url: &str) -> Result<Self> {
        let http = HttpClient::builder()
            .timeout(std::time::Duration::from_secs(30))
            .build()
            .context("Failed to create HTTP client")?;

        Ok(Self {
            http,
            base_url: base_url.trim_end_matches('/').to_string(),
        })
    }

    /// Fetch all documents from a collection
    pub async fn fetch_collection(&self, collection: &str) -> Result<Vec<Document>> {
        let url = format!("{}/collections/{}/documents", self.base_url, collection);

        info!("Fetching documents from {}", url);

        let response = self
            .http
            .get(&url)
            .send()
            .await
            .context("Failed to fetch collection")?;

        if !response.status().is_success() {
            anyhow::bail!(
                "FormBD API error: {} - {}",
                response.status(),
                response.text().await.unwrap_or_default()
            );
        }

        let documents: Vec<Document> = response
            .json()
            .await
            .context("Failed to parse documents")?;

        info!("Fetched {} documents", documents.len());

        Ok(documents)
    }

    /// Fetch a single document by ID
    pub async fn fetch_document(&self, collection: &str, id: &str) -> Result<Document> {
        let url = format!(
            "{}/collections/{}/documents/{}",
            self.base_url, collection, id
        );

        debug!("Fetching document {}", id);

        let response = self
            .http
            .get(&url)
            .send()
            .await
            .context("Failed to fetch document")?;

        if !response.status().is_success() {
            anyhow::bail!("Document not found: {}", id);
        }

        response.json().await.context("Failed to parse document")
    }

    /// Extract location from a document
    pub fn extract_location(document: &Document, location_field: &str) -> Option<Location> {
        let data = &document.data;

        // Try to find the location field
        let location = data.get(location_field)?;

        // Handle different location formats
        if let Some(obj) = location.as_object() {
            // Format: { "lat": 51.5, "lon": -0.1 }
            let lat = obj.get("lat").or_else(|| obj.get("latitude"))?.as_f64()?;
            let lon = obj
                .get("lon")
                .or_else(|| obj.get("lng"))
                .or_else(|| obj.get("longitude"))?
                .as_f64()?;
            return Some(Location { lat, lon });
        }

        if let Some(arr) = location.as_array() {
            if arr.len() >= 2 {
                // Format: [lon, lat] (GeoJSON order) or [lat, lon]
                // We'll assume GeoJSON order: [lon, lat]
                let lon = arr[0].as_f64()?;
                let lat = arr[1].as_f64()?;
                return Some(Location { lat, lon });
            }
        }

        // Try to find nested coordinates (GeoJSON format)
        if let Some(coords) = location.get("coordinates").and_then(|c| c.as_array()) {
            if coords.len() >= 2 {
                let lon = coords[0].as_f64()?;
                let lat = coords[1].as_f64()?;
                return Some(Location { lat, lon });
            }
        }

        None
    }

    /// Check if FormBD API is reachable
    pub async fn health_check(&self) -> Result<bool> {
        let url = format!("{}/health", self.base_url);

        match self.http.get(&url).send().await {
            Ok(response) => Ok(response.status().is_success()),
            Err(_) => Ok(false),
        }
    }

    /// Get the base URL
    pub fn base_url(&self) -> &str {
        &self.base_url
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn test_extract_location_object_format() {
        let doc = Document {
            id: "test".to_string(),
            data: json!({
                "location": { "lat": 51.5, "lon": -0.1 }
            }),
            provenance: None,
        };

        let loc = Client::extract_location(&doc, "location").unwrap();
        assert!((loc.lat - 51.5).abs() < 0.001);
        assert!((loc.lon - (-0.1)).abs() < 0.001);
    }

    #[test]
    fn test_extract_location_array_format() {
        let doc = Document {
            id: "test".to_string(),
            data: json!({
                "location": [-0.1, 51.5]  // GeoJSON order: [lon, lat]
            }),
            provenance: None,
        };

        let loc = Client::extract_location(&doc, "location").unwrap();
        assert!((loc.lat - 51.5).abs() < 0.001);
        assert!((loc.lon - (-0.1)).abs() < 0.001);
    }

    #[test]
    fn test_extract_location_geojson_format() {
        let doc = Document {
            id: "test".to_string(),
            data: json!({
                "location": {
                    "type": "Point",
                    "coordinates": [-0.1, 51.5]
                }
            }),
            provenance: None,
        };

        let loc = Client::extract_location(&doc, "location").unwrap();
        assert!((loc.lat - 51.5).abs() < 0.001);
        assert!((loc.lon - (-0.1)).abs() < 0.001);
    }
}
