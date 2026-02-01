-- SPDX-License-Identifier: PMPL-1.0-or-later
-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell (@hyperpolymath)
--
-- FormForeign.idr - FFI declarations for FormBD Form.Bridge ABI
-- Media-Type: text/x-idris

module FormBD.FormForeign

import FormBD.FormBridge
import FormBD.FormLayout
import Data.Bits
import Data.Buffer

%default total

--------------------------------------------------------------------------------
-- FFI Function Signatures - Database Lifecycle
--------------------------------------------------------------------------------

||| Initialize FormBD library
||| Returns: Status code
%foreign "C:fdb_init,libformbd"
prim__init : PrimIO Int32

||| Cleanup FormBD library
%foreign "C:fdb_cleanup,libformbd"
prim__cleanup : PrimIO ()

||| Open database
||| @ path Database file path (null-terminated C string)
||| @ path_len Path length in bytes
||| @ db_out Output parameter for database handle
||| Returns: Status code
%foreign "C:fdb_open,libformbd"
prim__db_open : (path : String) -> (path_len : Bits64) -> (db_out : AnyPtr) -> PrimIO Int32

||| Close database
||| @ db Database handle to close
||| Returns: Status code
%foreign "C:fdb_close,libformbd"
prim__db_close : (db : AnyPtr) -> PrimIO Int32

||| Create new database file
||| @ path Database file path
||| @ path_len Path length
||| @ block_count Initial block allocation count
||| @ db_out Output parameter for database handle
||| Returns: Status code
%foreign "C:fdb_create,libformbd"
prim__db_create : (path : String) -> (path_len : Bits64) -> (block_count : Bits64) -> (db_out : AnyPtr) -> PrimIO Int32

--------------------------------------------------------------------------------
-- FFI Function Signatures - Transactions
--------------------------------------------------------------------------------

||| Begin transaction
||| @ db Database handle
||| @ txn_out Output parameter for transaction handle
||| Returns: Status code
%foreign "C:fdb_txn_begin,libformbd"
prim__txn_begin : (db : AnyPtr) -> (txn_out : AnyPtr) -> PrimIO Int32

||| Commit transaction
||| @ txn Transaction handle
||| Returns: Status code
%foreign "C:fdb_txn_commit,libformbd"
prim__txn_commit : (txn : AnyPtr) -> PrimIO Int32

||| Rollback transaction (uses journal inverses)
||| @ txn Transaction handle
||| Returns: Status code
%foreign "C:fdb_txn_rollback,libformbd"
prim__txn_rollback : (txn : AnyPtr) -> PrimIO Int32

--------------------------------------------------------------------------------
-- FFI Function Signatures - Collections
--------------------------------------------------------------------------------

||| Create collection
||| @ db Database handle
||| @ name Collection name
||| @ name_len Name length
||| @ schema_json Schema definition (JSON)
||| @ schema_len Schema length
||| Returns: Status code
%foreign "C:fdb_collection_create,libformbd"
prim__collection_create : (db : AnyPtr) -> (name : String) -> (name_len : Bits64) -> (schema_json : String) -> (schema_len : Bits64) -> PrimIO Int32

||| Drop collection
||| @ db Database handle
||| @ name Collection name
||| @ name_len Name length
||| Returns: Status code
%foreign "C:fdb_collection_drop,libformbd"
prim__collection_drop : (db : AnyPtr) -> (name : String) -> (name_len : Bits64) -> PrimIO Int32

||| Get collection schema
||| @ db Database handle
||| @ name Collection name
||| @ schema_out Output parameter for schema handle
||| Returns: Status code
%foreign "C:fdb_collection_schema,libformbd"
prim__collection_schema : (db : AnyPtr) -> (name : String) -> (schema_out : AnyPtr) -> PrimIO Int32

--------------------------------------------------------------------------------
-- FFI Function Signatures - FQL Query Execution
--------------------------------------------------------------------------------

||| Execute FQL query
||| @ db Database handle
||| @ query_str FQL query string
||| @ query_len Query length
||| @ provenance_json Provenance metadata (actor, rationale, timestamp)
||| @ provenance_len Provenance length
||| @ cursor_out Output parameter for cursor handle
||| Returns: Status code
%foreign "C:fdb_query_execute,libformbd"
prim__query_execute : (db : AnyPtr) -> (query_str : String) -> (query_len : Bits64) -> (provenance_json : String) -> (provenance_len : Bits64) -> (cursor_out : AnyPtr) -> PrimIO Int32

||| Explain FQL query (get execution plan)
||| @ db Database handle
||| @ query_str FQL query string
||| @ query_len Query length
||| @ explain_json_out Buffer for JSON explain output
||| @ buffer_len Buffer capacity
||| @ written_out Bytes written
||| Returns: Status code
%foreign "C:fdb_query_explain,libformbd"
prim__query_explain : (db : AnyPtr) -> (query_str : String) -> (query_len : Bits64) -> (explain_json_out : AnyPtr) -> (buffer_len : Bits64) -> (written_out : AnyPtr) -> PrimIO Int32

||| Fetch next result from cursor
||| @ cursor Cursor handle
||| @ document_json_out Buffer for JSON document
||| @ buffer_len Buffer capacity
||| @ written_out Bytes written
||| Returns: Status code (StatusOk if row fetched, StatusNotFound if end)
%foreign "C:fdb_cursor_next,libformbd"
prim__cursor_next : (cursor : AnyPtr) -> (document_json_out : AnyPtr) -> (buffer_len : Bits64) -> (written_out : AnyPtr) -> PrimIO Int32

||| Close cursor
%foreign "C:fdb_cursor_close,libformbd"
prim__cursor_close : (cursor : AnyPtr) -> PrimIO ()

--------------------------------------------------------------------------------
-- FFI Function Signatures - Journal Operations
--------------------------------------------------------------------------------

||| Get journal handle
||| @ db Database handle
||| @ journal_out Output parameter for journal handle
||| Returns: Status code
%foreign "C:fdb_journal_get,libformbd"
prim__journal_get : (db : AnyPtr) -> (journal_out : AnyPtr) -> PrimIO Int32

||| Read journal entries
||| @ journal Journal handle
||| @ start_seq Starting sequence number (0 = from beginning)
||| @ count Number of entries to read
||| @ entries_json_out Buffer for JSON array of entries
||| @ buffer_len Buffer capacity
||| @ written_out Bytes written
||| Returns: Status code
%foreign "C:fdb_journal_read,libformbd"
prim__journal_read : (journal : AnyPtr) -> (start_seq : Bits64) -> (count : Bits64) -> (entries_json_out : AnyPtr) -> (buffer_len : Bits64) -> (written_out : AnyPtr) -> PrimIO Int32

||| Replay journal from sequence number (crash recovery)
||| @ db Database handle
||| @ from_seq Sequence number to replay from
||| Returns: Status code
%foreign "C:fdb_journal_replay,libformbd"
prim__journal_replay : (db : AnyPtr) -> (from_seq : Bits64) -> PrimIO Int32

--------------------------------------------------------------------------------
-- FFI Function Signatures - Normalization
--------------------------------------------------------------------------------

||| Discover functional dependencies for collection
||| @ db Database handle
||| @ collection Collection name
||| @ fds_json_out Buffer for JSON array of FDs
||| @ buffer_len Buffer capacity
||| @ written_out Bytes written
||| Returns: Status code
%foreign "C:fdb_normalize_discover,libformbd"
prim__normalize_discover : (db : AnyPtr) -> (collection : String) -> (fds_json_out : AnyPtr) -> (buffer_len : Bits64) -> (written_out : AnyPtr) -> PrimIO Int32

||| Analyze normal form of collection
||| @ db Database handle
||| @ collection Collection name
||| @ normal_form_out Output parameter for normal form level (0-6)
||| Returns: Status code
%foreign "C:fdb_normalize_analyze,libformbd"
prim__normalize_analyze : (db : AnyPtr) -> (collection : String) -> (normal_form_out : AnyPtr) -> PrimIO Int32

||| Start migration to higher normal form
||| @ db Database handle
||| @ collection Collection name
||| @ target_nf Target normal form (1-6)
||| @ proof_blob CBOR-encoded Lean 4 proof of lossless transformation
||| @ proof_len Proof length
||| @ migration_out Output parameter for migration handle
||| Returns: Status code
%foreign "C:fdb_migrate_start,libformbd"
prim__migrate_start : (db : AnyPtr) -> (collection : String) -> (target_nf : Bits8) -> (proof_blob : AnyPtr) -> (proof_len : Bits64) -> (migration_out : AnyPtr) -> PrimIO Int32

||| Commit migration (three-phase: Announce → Shadow → Commit)
||| @ migration Migration handle
||| @ phase Migration phase (0=Announce, 1=Shadow, 2=Commit)
||| Returns: Status code
%foreign "C:fdb_migrate_commit,libformbd"
prim__migrate_commit : (migration : AnyPtr) -> (phase : Bits8) -> PrimIO Int32

--------------------------------------------------------------------------------
-- FFI Function Signatures - CBOR Serialization
--------------------------------------------------------------------------------

||| Serialize document to CBOR
||| @ document_json JSON document
||| @ document_len JSON length
||| @ cbor_out CBOR output buffer
||| @ buffer_len Buffer capacity
||| @ written_out Bytes written
||| Returns: Status code
%foreign "C:fdb_serialize_cbor,libformbd"
prim__serialize_cbor : (document_json : String) -> (document_len : Bits64) -> (cbor_out : AnyPtr) -> (buffer_len : Bits64) -> (written_out : AnyPtr) -> PrimIO Int32

||| Deserialize CBOR to JSON
%foreign "C:fdb_deserialize_cbor,libformbd"
prim__deserialize_cbor : (cbor_in : AnyPtr) -> (cbor_len : Bits64) -> (json_out : AnyPtr) -> (buffer_len : Bits64) -> (written_out : AnyPtr) -> PrimIO Int32

--------------------------------------------------------------------------------
-- FFI Function Signatures - Integrity Checks
--------------------------------------------------------------------------------

||| Verify block checksums (CRC32C)
||| @ db Database handle
||| @ corrupted_blocks_out Buffer for array of corrupted block IDs
||| @ buffer_len Buffer capacity (in number of Bits64)
||| @ count_out Number of corrupted blocks found
||| Returns: Status code
%foreign "C:fdb_verify_checksums,libformbd"
prim__verify_checksums : (db : AnyPtr) -> (corrupted_blocks_out : AnyPtr) -> (buffer_len : Bits64) -> (count_out : AnyPtr) -> PrimIO Int32

||| Repair database (using journal replay)
||| @ db Database handle
||| @ repair_report_out Buffer for JSON repair report
||| @ buffer_len Buffer capacity
||| @ written_out Bytes written
||| Returns: Status code
%foreign "C:fdb_repair,libformbd"
prim__repair : (db : AnyPtr) -> (repair_report_out : AnyPtr) -> (buffer_len : Bits64) -> (written_out : AnyPtr) -> PrimIO Int32

--------------------------------------------------------------------------------
-- Safe High-Level Wrappers
--------------------------------------------------------------------------------

||| Safe initialization (IO effect)
export
init : IO (FdbResult ())
init = do
  status <- primIO prim__init
  pure $ if status == 0
    then ok ()
    else err StatusInternalError "Failed to initialize FormBD library"

||| Safe cleanup
export
cleanup : IO ()
cleanup = primIO prim__cleanup

||| Safe database open
export
dbOpen : (path : String) -> IO (FdbResult FdbDb)
dbOpen path = do
  -- TODO: Allocate pointer for db_out, call prim__db_open, wrap in FdbDb
  ?dbOpen_impl

||| Safe database close
export
dbClose : FdbDb -> IO (FdbResult ())
dbClose db = do
  -- TODO: Extract pointer, call prim__db_close
  ?dbClose_impl

||| Safe database create
export
dbCreate : (path : String) -> (blockCount : Nat) -> IO (FdbResult FdbDb)
dbCreate path blockCount = do
  -- TODO: Use Proven.SafePath to validate path
  ?dbCreate_impl

||| Safe transaction begin
export
txnBegin : FdbDb -> IO (FdbResult FdbTxn)
txnBegin db = do
  -- TODO: Call prim__txn_begin
  ?txnBegin_impl

||| Safe FQL query execution
export
queryExecute : FdbDb -> String -> ActorId -> Rationale -> IO (FdbResult FdbCursor)
queryExecute db queryStr actorId rationale = do
  -- TODO: Use Proven.SafeString to validate query
  -- TODO: Build provenance JSON with actor, rationale, timestamp
  ?queryExecute_impl

--------------------------------------------------------------------------------
-- Integration with Proven Library
--------------------------------------------------------------------------------

||| Open database with path validation via Proven.SafePath
export
dbOpenSafe : String -> IO (FdbResult FdbDb)
dbOpenSafe path = do
  -- TODO: Use Proven.SafePath.validatePath
  -- TODO: Check for directory traversal attacks
  ?dbOpenSafe_impl

||| Execute query with validation via Proven.SafeString and Proven.SafeSQL
export
queryExecuteSafe : FdbDb -> String -> ActorId -> Rationale -> IO (FdbResult FdbCursor)
queryExecuteSafe db queryStr actorId rationale = do
  -- TODO: Use Proven.SafeString to validate query string
  -- TODO: Use Proven.SafeSQL to check for SQL injection (if using SQL lowering)
  ?queryExecuteSafe_impl

||| Serialize document with Proven.SafeJson
export
serializeCborSafe : String -> IO (FdbResult (List Bits8))
serializeCborSafe jsonDoc = do
  -- TODO: Use Proven.SafeJson to validate JSON before serialization
  ?serializeCborSafe_impl

--------------------------------------------------------------------------------
-- Error Handling
--------------------------------------------------------------------------------

||| Convert status code to FdbStatus
export
intToStatus : Int32 -> FdbStatus
intToStatus 0 = StatusOk
intToStatus 1 = StatusInvalidArg
intToStatus 2 = StatusNotFound
intToStatus 3 = StatusPermissionDenied
intToStatus 4 = StatusAlreadyExists
intToStatus 5 = StatusConstraintViolation
intToStatus 6 = StatusTypeMismatch
intToStatus 7 = StatusOutOfMemory
intToStatus 8 = StatusIOError
intToStatus 9 = StatusCorruption
intToStatus 10 = StatusConflict
intToStatus _ = StatusInternalError

||| Get error message for status code
export
statusMessage : FdbStatus -> String
statusMessage StatusOk = "Success"
statusMessage StatusInvalidArg = "Invalid argument"
statusMessage StatusNotFound = "Not found"
statusMessage StatusPermissionDenied = "Permission denied"
statusMessage StatusAlreadyExists = "Already exists"
statusMessage StatusConstraintViolation = "Constraint violation"
statusMessage StatusTypeMismatch = "Type mismatch"
statusMessage StatusOutOfMemory = "Out of memory"
statusMessage StatusIOError = "I/O error"
statusMessage StatusCorruption = "Data corruption detected"
statusMessage StatusConflict = "Transaction conflict"
statusMessage StatusInternalError = "Internal error"
