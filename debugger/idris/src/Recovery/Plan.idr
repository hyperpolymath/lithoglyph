-- SPDX-License-Identifier: PMPL-1.0-or-later
||| Recovery Plan - Verified recovery operations
module Recovery.Plan

import REPL.Core

||| A proof that accompanies a recovery step
public export
data ProofType
  = FKSatisfied         -- Foreign key constraint satisfied
  | Lossless            -- No data lost
  | Reversible          -- Operation can be undone
  | ConstraintsSatisfied -- All constraints satisfied
  | Minimal             -- Smallest change possible

||| A recovery step with its proof
public export
record RecoveryStep where
  constructor MkRecoveryStep
  description : String
  sql : String
  proofs : List ProofType

||| A complete recovery plan
public export
record RecoveryPlan where
  constructor MkRecoveryPlan
  name : String
  steps : List RecoveryStep
  allProofsValid : Bool

||| Strategy for recovery
public export
data RecoveryStrategy
  = RestoreReferent    -- Re-insert deleted data
  | UpdateReference    -- Point to existing data
  | DeleteOrphan       -- Remove orphaned data
  | Custom String      -- User-defined strategy

||| Generate a recovery plan for FK violation
public export
generateFKRecovery : String -> String -> IO (List RecoveryPlan)
generateFKRecovery table constraint = do
  pure [MkRecoveryPlan "Restore referent" [] True]
