-- SPDX-License-Identifier: AGPL-3.0-or-later
||| Recovery Verification - Proof checking for recovery operations
module Recovery.Verify

import Recovery.Plan

||| Verification result
public export
data VerifyResult
  = Verified String              -- Success with proof hash
  | Failed String                -- Failure with reason
  | Pending (List String)        -- Needs more information

||| Verify a recovery plan
public export
verifyPlan : RecoveryPlan -> IO VerifyResult
verifyPlan plan =
  if plan.allProofsValid
    then pure $ Verified "All proofs validated"
    else pure $ Failed "Some proofs could not be verified"

||| Verify a migration file
public export
verifyMigration : String -> IO VerifyResult
verifyMigration filepath = do
  putStrLn $ "Verifying migration: " ++ filepath
  pure $ Pending ["Migration file not yet parsed"]

||| Check if an operation is reversible
public export
checkReversibility : RecoveryStep -> Bool
checkReversibility step = Reversible `elem` step.proofs

||| Check if an operation is lossless
public export
checkLossless : RecoveryStep -> Bool
checkLossless step = Lossless `elem` step.proofs
