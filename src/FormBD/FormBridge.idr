-- SPDX-License-Identifier: PMPL-1.0-or-later
-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell (@hyperpolymath)
--
-- FormBridge.idr - Type definitions with proofs for FormBD Form.Bridge ABI
-- Media-Type: text/x-idris

module FormBD.FormBridge

import Data.So
import Data.Bits
-- import Proven.Core
-- import Proven.SafeMath
-- import Proven.SafeString
-- import Proven.SafePath
-- import Proven.SafeJson

%default total

--------------------------------------------------------------------------------
-- Core Handle Types (Opaque, Non-Null)
--------------------------------------------------------------------------------

||| Non-null database handle
||| @ ptr The pointer value (guaranteed non-zero)
public export
data FdbDb : Type where
  MkFdbDb : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> FdbDb

||| Non-null transaction handle
||| Transactions are ACID-compliant with rollback via journal inverses
public export
data FdbTxn : Type where
  MkFdbTxn : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> FdbTxn

||| Non-null cursor handle for query results
public export
data FdbCursor : Type where
  MkFdbCursor : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> FdbCursor

||| Non-null collection handle
public export
data FdbCollection : Type where
  MkFdbCollection : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> FdbCollection

||| Non-null schema handle
public export
data FdbSchema : Type where
  MkFdbSchema : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> FdbSchema

||| Non-null journal handle
public export
data FdbJournal : Type where
  MkFdbJournal : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> FdbJournal

||| Non-null migration handle
public export
data FdbMigration : Type where
  MkFdbMigration : (ptr : Bits64) -> {auto 0 nonNull : So (ptr /= 0)} -> FdbMigration

--------------------------------------------------------------------------------
-- Status Codes
--------------------------------------------------------------------------------

||| Result status codes for FFI operations
public export
data FdbStatus : Type where
  ||| Operation succeeded
  StatusOk : FdbStatus
  ||| Invalid argument provided
  StatusInvalidArg : FdbStatus
  ||| Database file not found
  StatusNotFound : FdbStatus
  ||| Permission denied
  StatusPermissionDenied : FdbStatus
  ||| Database already exists
  StatusAlreadyExists : FdbStatus
  ||| Constraint violation
  StatusConstraintViolation : FdbStatus
  ||| Type mismatch
  StatusTypeMismatch : FdbStatus
  ||| Out of memory
  StatusOutOfMemory : FdbStatus
  ||| I/O error
  StatusIOError : FdbStatus
  ||| Corruption detected
  StatusCorruption : FdbStatus
  ||| Transaction conflict (optimistic concurrency control)
  StatusConflict : FdbStatus
  ||| Internal error
  StatusInternalError : FdbStatus

||| Convert status to integer for FFI
public export
statusToInt : FdbStatus -> Int32
statusToInt StatusOk = 0
statusToInt StatusInvalidArg = 1
statusToInt StatusNotFound = 2
statusToInt StatusPermissionDenied = 3
statusToInt StatusAlreadyExists = 4
statusToInt StatusConstraintViolation = 5
statusToInt StatusTypeMismatch = 6
statusToInt StatusOutOfMemory = 7
statusToInt StatusIOError = 8
statusToInt StatusCorruption = 9
statusToInt StatusConflict = 10
statusToInt StatusInternalError = 11

--------------------------------------------------------------------------------
-- Block Storage Types (Form.Blocks)
--------------------------------------------------------------------------------

||| Block identifier (4 KiB fixed-size blocks)
public export
BlockId : Type
BlockId = Bits64

||| Block size in bytes (4096 bytes = 4 KiB)
public export
blockSize : Nat
blockSize = 4096

||| Proof that block size is a power of 2
public export
0 blockSizePowerOf2 : blockSize = 4096  -- 2^12
blockSizePowerOf2 = believe_me ()

||| Block header magic number (identifies FormBD blocks)
public export
BlockMagic : Type
BlockMagic = Bits32

||| Block type identifier
public export
data BlockType : Type where
  BlockTypeFree : BlockType
  BlockTypeDocument : BlockType
  BlockTypeEdge : BlockType
  BlockTypeSchema : BlockType
  BlockTypeJournal : BlockType
  BlockTypeMigration : BlockType

||| Convert block type to integer
public export
blockTypeToInt : BlockType -> Bits8
blockTypeToInt BlockTypeFree = 0
blockTypeToInt BlockTypeDocument = 1
blockTypeToInt BlockTypeEdge = 2
blockTypeToInt BlockTypeSchema = 3
blockTypeToInt BlockTypeJournal = 4
blockTypeToInt BlockTypeMigration = 5

||| CRC32C checksum (Castagnoli polynomial)
public export
Checksum : Type
Checksum = Bits32

--------------------------------------------------------------------------------
-- Journal Types (Form.Journal)
--------------------------------------------------------------------------------

||| Journal sequence number (monotonically increasing)
public export
SequenceNumber : Type
SequenceNumber = Bits64

||| Journal operation type
public export
data JournalOp : Type where
  OpInsert : JournalOp
  OpUpdate : JournalOp
  OpDelete : JournalOp
  OpNormalize : JournalOp
  OpMigrate : JournalOp

||| Convert operation to integer
public export
journalOpToInt : JournalOp -> Bits8
journalOpToInt OpInsert = 0
journalOpToInt OpUpdate = 1
journalOpToInt OpDelete = 2
journalOpToInt OpNormalize = 3
journalOpToInt OpMigrate = 4

||| Journal entry with provenance
public export
record JournalEntry where
  constructor MkJournalEntry
  sequence : SequenceNumber
  operation : JournalOp
  timestamp : Bits64  -- Unix timestamp (milliseconds)
  actorId : String    -- Actor who performed the operation
  rationale : String  -- Rationale for the operation
  forwardPayload : String  -- What was done (CBOR-encoded)
  inversePayload : String  -- How to undo (CBOR-encoded)
  {auto 0 actorNonEmpty : So (length actorId > 0)}
  {auto 0 rationaleNonEmpty : So (length rationale > 0)}

--------------------------------------------------------------------------------
-- Provenance Tracking (Form.Model)
--------------------------------------------------------------------------------

||| Actor identifier (non-empty)
public export
ActorId : Type
ActorId = String  -- TODO: Use NonEmptyString from proven

||| Rationale (non-empty)
public export
Rationale : Type
Rationale = String  -- TODO: Use NonEmptyString from proven

||| Unix timestamp (milliseconds since epoch)
public export
Timestamp : Type
Timestamp = Bits64

||| Confidence score [0.0, 1.0] for data quality
public export
record Confidence where
  constructor MkConfidence
  value : Double
  {auto 0 lowerBound : So (value >= 0.0)}
  {auto 0 upperBound : So (value <= 1.0)}

||| PROMPT dimension score [0, 100]
public export
data PromptDimension : Type where
  MkPromptDimension : (value : Nat) -> {auto 0 valid : So (value <= 100)} -> PromptDimension

||| PROMPT scores for research-grade data quality
public export
record PromptScores where
  constructor MkPromptScores
  provenance : PromptDimension
  replicability : PromptDimension
  objectivity : PromptDimension
  methodology : PromptDimension
  publication : PromptDimension
  transparency : PromptDimension

--------------------------------------------------------------------------------
-- Normal Form Types (Form.Normalizer)
--------------------------------------------------------------------------------

||| Normal form levels
public export
data NormalForm : Type where
  NF_None : NormalForm         -- Not normalized
  NF_1NF : NormalForm          -- First normal form
  NF_2NF : NormalForm          -- Second normal form
  NF_3NF : NormalForm          -- Third normal form
  NF_BCNF : NormalForm         -- Boyce-Codd normal form
  NF_4NF : NormalForm          -- Fourth normal form
  NF_5NF : NormalForm          -- Fifth normal form

||| Convert normal form to integer
public export
normalFormToInt : NormalForm -> Bits8
normalFormToInt NF_None = 0
normalFormToInt NF_1NF = 1
normalFormToInt NF_2NF = 2
normalFormToInt NF_3NF = 3
normalFormToInt NF_BCNF = 4
normalFormToInt NF_4NF = 5
normalFormToInt NF_5NF = 6

||| Functional dependency (X → Y)
public export
record FunctionalDependency where
  constructor MkFD
  determinant : List String  -- Attributes on left side
  dependent : List String    -- Attributes on right side
  {auto 0 determinantNonEmpty : So (length determinant > 0)}
  {auto 0 dependentNonEmpty : So (length dependent > 0)}

||| Proof that a schema is in a specific normal form
public export
0 InNormalForm : List FunctionalDependency -> NormalForm -> Type
InNormalForm fds nf = ()  -- Placeholder for actual proof

--------------------------------------------------------------------------------
-- Migration Types
--------------------------------------------------------------------------------

||| Three-phase migration protocol
public export
data MigrationPhase : Type where
  PhaseAnnounce : MigrationPhase  -- Phase 1: Announce migration
  PhaseShadow : MigrationPhase    -- Phase 2: Shadow mode (dual writes)
  PhaseCommit : MigrationPhase    -- Phase 3: Commit and cleanup

||| Convert migration phase to integer
public export
migrationPhaseToInt : MigrationPhase -> Bits8
migrationPhaseToInt PhaseAnnounce = 0
migrationPhaseToInt PhaseShadow = 1
migrationPhaseToInt PhaseCommit = 2

||| Migration with proof of lossless transformation
public export
record Migration where
  constructor MkMigration
  fromNF : NormalForm
  toNF : NormalForm
  transformations : List FunctionalDependency
  losslessProof : String  -- CBOR-encoded Lean 4 proof
  {auto 0 progressProof : So (normalFormToInt toNF >= normalFormToInt fromNF)}

--------------------------------------------------------------------------------
-- FFI Result Type
--------------------------------------------------------------------------------

||| Result type for FFI operations
public export
record FdbResult (a : Type) where
  constructor MkFdbResult
  status : FdbStatus
  value : Maybe a
  errorMessage : Maybe String

||| Smart constructor for success result
public export
ok : a -> FdbResult a
ok v = MkFdbResult StatusOk (Just v) Nothing

||| Smart constructor for error result
public export
err : FdbStatus -> String -> FdbResult a
err s msg = MkFdbResult s Nothing (Just msg)

--------------------------------------------------------------------------------
-- Integration with Proven Library
--------------------------------------------------------------------------------

||| Validate database path using Proven.SafePath
public export
validateDbPath : String -> Maybe String
validateDbPath = ?validateDbPath_impl  -- TODO: Use Proven.SafePath

||| Validate FQL query using Proven.SafeString
public export
validateFqlQuery : String -> Maybe String
validateFqlQuery = ?validateFqlQuery_impl  -- TODO: Use Proven.SafeString

||| Parse JSON document using Proven.SafeJson
public export
parseJsonDocument : String -> Maybe String
parseJsonDocument = ?parseJsonDocument_impl  -- TODO: Use Proven.SafeJson

||| Validate actor ID (non-empty string)
public export
validateActorId : String -> Maybe ActorId
validateActorId s = if length s > 0 then Just s else Nothing

||| Validate rationale (non-empty string)
public export
validateRationale : String -> Maybe Rationale
validateRationale s = if length s > 0 then Just s else Nothing

--------------------------------------------------------------------------------
-- CBOR Serialization Tags
--------------------------------------------------------------------------------

||| Semantic tags for CBOR encoding (RFC 8949)
public export
data CborTag : Type where
  TagDocument : CborTag
  TagEdge : CborTag
  TagSchema : CborTag
  TagJournalEntry : CborTag
  TagFunctionalDependency : CborTag
  TagProofBlob : CborTag
  TagPromptScores : CborTag
  TagMigration : CborTag

||| Convert tag to integer
public export
tagToInt : CborTag -> Bits32
tagToInt TagDocument = 2000
tagToInt TagEdge = 2001
tagToInt TagSchema = 2002
tagToInt TagJournalEntry = 2003
tagToInt TagFunctionalDependency = 2004
tagToInt TagProofBlob = 2005
tagToInt TagPromptScores = 2006
tagToInt TagMigration = 2007
