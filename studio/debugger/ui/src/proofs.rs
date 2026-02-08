// SPDX-License-Identifier: AGPL-3.0-or-later
//! Lean 4 proof integration for recovery plans
//!
//! Maps recovery operations to their formal proofs in the Lean 4 core library.

use std::path::Path;
use std::process::Command;

/// A reference to a Lean 4 proof that verifies a property
#[derive(Debug, Clone)]
pub struct ProofReference {
    /// The Lean module containing the proof
    pub module: String,
    /// The theorem name
    pub theorem: String,
    /// Human-readable description of what is proven
    pub description: String,
    /// Whether the proof has been verified (lake build succeeded)
    pub verified: Option<bool>,
}

impl ProofReference {
    pub fn new(module: &str, theorem: &str, description: &str) -> Self {
        Self {
            module: module.to_string(),
            theorem: theorem.to_string(),
            description: description.to_string(),
            verified: None,
        }
    }

    /// Format as a proof annotation string
    pub fn annotation(&self) -> String {
        format!("{}.{}", self.module, self.theorem)
    }
}

/// Types of recovery operations with their proof requirements
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecoveryOperationType {
    Insert,
    Delete,
    Update,
    Rollback,
    Migration,
}

/// Get the applicable proofs for a recovery operation
pub fn proofs_for_operation(op: RecoveryOperationType) -> Vec<ProofReference> {
    match op {
        RecoveryOperationType::Insert => vec![
            ProofReference::new(
                "FormBDDebugger.Proofs.Lossless",
                "insert_is_lossless",
                "INSERT preserves all existing rows"
            ),
            ProofReference::new(
                "FormBDDebugger.Proofs.Lossless",
                "insert_is_reversible",
                "INSERT can be undone via DELETE"
            ),
            ProofReference::new(
                "FormBDDebugger.Proofs.FDPreserving",
                "insert_preserves_fds_if_compatible",
                "INSERT preserves functional dependencies when row is compatible"
            ),
        ],
        RecoveryOperationType::Delete => vec![
            ProofReference::new(
                "FormBDDebugger.Proofs.Lossless",
                "delete_with_archive_is_lossless",
                "DELETE with archive preserves data (rows are archived, not lost)"
            ),
            ProofReference::new(
                "FormBDDebugger.Proofs.FDPreserving",
                "delete_preserves_fds",
                "DELETE always preserves functional dependencies"
            ),
            ProofReference::new(
                "FormBDDebugger.Proofs.FDPreserving",
                "delete_snapshot_preserves_fds",
                "DELETE at snapshot level preserves all FDs"
            ),
        ],
        RecoveryOperationType::Update => vec![
            // UPDATE = DELETE + INSERT
            ProofReference::new(
                "FormBDDebugger.Proofs.Lossless",
                "delete_with_archive_is_lossless",
                "UPDATE's DELETE phase preserves data in archive"
            ),
            ProofReference::new(
                "FormBDDebugger.Proofs.Lossless",
                "insert_is_lossless",
                "UPDATE's INSERT phase preserves existing rows"
            ),
            ProofReference::new(
                "FormBDDebugger.Proofs.Lossless",
                "lossless_compose",
                "Composed operations (DELETE+INSERT) are lossless"
            ),
        ],
        RecoveryOperationType::Rollback => vec![
            ProofReference::new(
                "FormBDDebugger.Proofs.Rollback",
                "transaction_rollback_correct",
                "Transaction rollback restores previous state"
            ),
            ProofReference::new(
                "FormBDDebugger.Proofs.Rollback",
                "migration_reversible",
                "Migration with inverse is reversible"
            ),
        ],
        RecoveryOperationType::Migration => vec![
            ProofReference::new(
                "FormBDDebugger.Proofs.Lossless",
                "lossless_compose",
                "Multi-step migration preserves data"
            ),
            ProofReference::new(
                "FormBDDebugger.Proofs.FDPreserving",
                "FDPreservingTransformation",
                "Migration preserves all functional dependencies"
            ),
        ],
    }
}

/// Determine the operation type from a recovery step description
pub fn classify_recovery_step(description: &str) -> RecoveryOperationType {
    let lower = description.to_lowercase();
    if lower.contains("insert") || lower.contains("add") {
        RecoveryOperationType::Insert
    } else if lower.contains("delete") || lower.contains("remove") {
        RecoveryOperationType::Delete
    } else if lower.contains("update") || lower.contains("modify") || lower.contains("fix") {
        RecoveryOperationType::Update
    } else if lower.contains("rollback") || lower.contains("revert") {
        RecoveryOperationType::Rollback
    } else {
        RecoveryOperationType::Migration
    }
}

/// Get all proofs applicable to a recovery step
pub fn proofs_for_step(step_description: &str) -> Vec<ProofReference> {
    let op_type = classify_recovery_step(step_description);
    proofs_for_operation(op_type)
}

/// Verify Lean proofs by running lake build
pub fn verify_proofs(core_path: &Path) -> Result<bool, String> {
    if !core_path.exists() {
        return Err(format!("Core path does not exist: {:?}", core_path));
    }

    let lakefile = core_path.join("lakefile.lean");
    if !lakefile.exists() {
        return Err("lakefile.lean not found in core directory".to_string());
    }

    let output = Command::new("lake")
        .arg("build")
        .current_dir(core_path)
        .output()
        .map_err(|e| format!("Failed to run lake: {}", e))?;

    Ok(output.status.success())
}

/// Summary of proof coverage for a recovery plan
#[derive(Debug, Clone)]
pub struct ProofCoverage {
    /// Total number of recovery steps
    pub total_steps: usize,
    /// Steps with at least one applicable proof
    pub steps_with_proofs: usize,
    /// Total unique proofs referenced
    pub unique_proofs: usize,
    /// Key properties proven
    pub proven_properties: Vec<String>,
}

impl ProofCoverage {
    /// Generate coverage summary from step descriptions
    pub fn from_steps(step_descriptions: &[String]) -> Self {
        let mut all_proofs: Vec<String> = Vec::new();
        let mut steps_with_proofs = 0;
        let mut properties: std::collections::HashSet<&str> = std::collections::HashSet::new();

        for desc in step_descriptions {
            let proofs = proofs_for_step(desc);
            if !proofs.is_empty() {
                steps_with_proofs += 1;
            }
            for proof in &proofs {
                let annotation = proof.annotation();
                if !all_proofs.contains(&annotation) {
                    all_proofs.push(annotation);
                }
                // Track key properties
                if proof.description.contains("lossless") || proof.description.contains("preserves") {
                    properties.insert("Data Preservation");
                }
                if proof.description.contains("functional dependencies") || proof.description.contains("FD") {
                    properties.insert("FD Preservation");
                }
                if proof.description.contains("reversible") || proof.description.contains("undone") {
                    properties.insert("Reversibility");
                }
            }
        }

        Self {
            total_steps: step_descriptions.len(),
            steps_with_proofs,
            unique_proofs: all_proofs.len(),
            proven_properties: properties.into_iter().map(String::from).collect(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_classify_step() {
        assert_eq!(classify_recovery_step("Insert new row"), RecoveryOperationType::Insert);
        assert_eq!(classify_recovery_step("Delete orphan"), RecoveryOperationType::Delete);
        assert_eq!(classify_recovery_step("Fix constraint"), RecoveryOperationType::Update);
        assert_eq!(classify_recovery_step("Rollback transaction"), RecoveryOperationType::Rollback);
    }

    #[test]
    fn test_proofs_for_insert() {
        let proofs = proofs_for_operation(RecoveryOperationType::Insert);
        assert!(proofs.len() >= 2);
        assert!(proofs.iter().any(|p| p.theorem == "insert_is_lossless"));
    }

    #[test]
    fn test_proof_coverage() {
        let steps = vec![
            "Delete orphan foreign keys".to_string(),
            "Insert missing reference".to_string(),
        ];
        let coverage = ProofCoverage::from_steps(&steps);
        assert_eq!(coverage.total_steps, 2);
        assert_eq!(coverage.steps_with_proofs, 2);
        assert!(coverage.unique_proofs > 0);
    }
}
