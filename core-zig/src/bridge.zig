// SPDX-License-Identifier: AGPL-3.0-or-later
// Form.Bridge - C ABI Layer
//
// Provides stable C-compatible API for runtimes to interact with FormDB.
// All blob arguments and return values use CBOR encoding.

const std = @import("std");
pub const types = @import("types.zig");
pub const cbor = @import("cbor.zig");

// Re-export types for C consumers
pub const FdbBlob = types.FdbBlob;
pub const FdbStatus = types.FdbStatus;
pub const FdbResult = types.FdbResult;
pub const FdbTxnMode = types.FdbTxnMode;
pub const FdbRenderOpts = types.FdbRenderOpts;

// ============================================================
// Opaque Handles
// ============================================================

pub const FdbDb = opaque {};
pub const FdbTxn = opaque {};

// Internal state structures
const DbState = struct {
    allocator: std.mem.Allocator,
    path: []const u8,
    is_open: bool,
    journal_head: u64,
    next_block_id: u64,
    superblock_loaded: bool,
};

const TxnState = struct {
    db: *DbState,
    mode: FdbTxnMode,
    is_active: bool,
    sequence: u64,
};

// Global allocator for C ABI (can't pass allocator through C)
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const global_allocator = gpa.allocator();

// Active handles registry
var db_registry = std.AutoHashMap(*DbState, void).init(global_allocator);
var txn_registry = std.AutoHashMap(*TxnState, void).init(global_allocator);

// ============================================================
// Error Blob Creation
// ============================================================

fn createErrorBlob(status: FdbStatus, message: []const u8) FdbBlob {
    const err_data = cbor.encodeError(
        global_allocator,
        @intFromEnum(status),
        message,
    ) catch return FdbBlob.empty();

    return FdbBlob.fromSlice(err_data);
}

// ============================================================
// Database Lifecycle - C ABI Exports
// ============================================================

/// Open a FormDB database
///
/// @param path_ptr Path to database file
/// @param path_len Length of path
/// @param opts_ptr CBOR-encoded options (nullable)
/// @param opts_len Length of options
/// @param out_db Output parameter for database handle
/// @param out_err Output parameter for error blob
/// @return Status code
export fn fdb_db_open(
    path_ptr: [*]const u8,
    path_len: usize,
    opts_ptr: ?[*]const u8,
    opts_len: usize,
    out_db: *?*FdbDb,
    out_err: *FdbBlob,
) FdbStatus {
    _ = opts_ptr;
    _ = opts_len;

    const path = path_ptr[0..path_len];

    // Create database state
    const db = global_allocator.create(DbState) catch {
        out_err.* = createErrorBlob(.err_out_of_memory, "Failed to allocate database state");
        return .err_out_of_memory;
    };

    const path_copy = global_allocator.dupe(u8, path) catch {
        global_allocator.destroy(db);
        out_err.* = createErrorBlob(.err_out_of_memory, "Failed to allocate path");
        return .err_out_of_memory;
    };

    db.* = .{
        .allocator = global_allocator,
        .path = path_copy,
        .is_open = true,
        .journal_head = 0,
        .next_block_id = 1,
        .superblock_loaded = false,
    };

    // Register handle
    db_registry.put(db, {}) catch {
        global_allocator.free(path_copy);
        global_allocator.destroy(db);
        out_err.* = createErrorBlob(.err_internal, "Failed to register database handle");
        return .err_internal;
    };

    out_db.* = @ptrCast(db);
    out_err.* = FdbBlob.empty();
    return .ok;
}

/// Close a FormDB database
///
/// @param db Database handle
/// @return Status code
export fn fdb_db_close(db: ?*FdbDb) FdbStatus {
    const state: *DbState = @ptrCast(@alignCast(db orelse return .err_invalid_argument));

    if (!db_registry.contains(state)) {
        return .err_invalid_argument;
    }

    // Clean up any active transactions
    var txn_iter = txn_registry.keyIterator();
    while (txn_iter.next()) |txn| {
        if (txn.*.db == state) {
            _ = txn_registry.remove(txn.*);
            global_allocator.destroy(txn.*);
        }
    }

    // Clean up database state
    _ = db_registry.remove(state);
    global_allocator.free(state.path);
    global_allocator.destroy(state);

    return .ok;
}

// ============================================================
// Transaction Management - C ABI Exports
// ============================================================

/// Begin a new transaction
///
/// @param db Database handle
/// @param mode Transaction mode (read-only or read-write)
/// @param out_txn Output parameter for transaction handle
/// @param out_err Output parameter for error blob
/// @return Status code
export fn fdb_txn_begin(
    db: ?*FdbDb,
    mode: FdbTxnMode,
    out_txn: *?*FdbTxn,
    out_err: *FdbBlob,
) FdbStatus {
    const state: *DbState = @ptrCast(@alignCast(db orelse {
        out_err.* = createErrorBlob(.err_invalid_argument, "Invalid database handle");
        return .err_invalid_argument;
    }));

    if (!db_registry.contains(state)) {
        out_err.* = createErrorBlob(.err_invalid_argument, "Database handle not registered");
        return .err_invalid_argument;
    }

    // Create transaction state
    const txn = global_allocator.create(TxnState) catch {
        out_err.* = createErrorBlob(.err_out_of_memory, "Failed to allocate transaction");
        return .err_out_of_memory;
    };

    txn.* = .{
        .db = state,
        .mode = mode,
        .is_active = true,
        .sequence = state.journal_head + 1,
    };

    txn_registry.put(txn, {}) catch {
        global_allocator.destroy(txn);
        out_err.* = createErrorBlob(.err_internal, "Failed to register transaction");
        return .err_internal;
    };

    out_txn.* = @ptrCast(txn);
    out_err.* = FdbBlob.empty();
    return .ok;
}

/// Commit a transaction
///
/// @param txn Transaction handle
/// @param out_err Output parameter for error blob
/// @return Status code
export fn fdb_txn_commit(txn: ?*FdbTxn, out_err: *FdbBlob) FdbStatus {
    const state: *TxnState = @ptrCast(@alignCast(txn orelse {
        out_err.* = createErrorBlob(.err_invalid_argument, "Invalid transaction handle");
        return .err_invalid_argument;
    }));

    if (!txn_registry.contains(state)) {
        out_err.* = createErrorBlob(.err_invalid_argument, "Transaction handle not registered");
        return .err_invalid_argument;
    }

    if (!state.is_active) {
        out_err.* = createErrorBlob(.err_txn_already_committed, "Transaction already committed");
        return .err_txn_already_committed;
    }

    // Update journal head
    state.db.journal_head = state.sequence;
    state.is_active = false;

    // Clean up transaction
    _ = txn_registry.remove(state);
    global_allocator.destroy(state);

    out_err.* = FdbBlob.empty();
    return .ok;
}

/// Abort a transaction
///
/// @param txn Transaction handle
/// @return Status code
export fn fdb_txn_abort(txn: ?*FdbTxn) FdbStatus {
    const state: *TxnState = @ptrCast(@alignCast(txn orelse return .err_invalid_argument));

    if (!txn_registry.contains(state)) {
        return .err_invalid_argument;
    }

    state.is_active = false;

    // Clean up transaction
    _ = txn_registry.remove(state);
    global_allocator.destroy(state);

    return .ok;
}

// ============================================================
// Operations - C ABI Exports
// ============================================================

/// Apply an operation within a transaction
///
/// @param txn Transaction handle
/// @param op_ptr CBOR-encoded operation
/// @param op_len Length of operation
/// @return Result containing result blob, provenance, status, and error
export fn fdb_apply(
    txn: ?*FdbTxn,
    op_ptr: [*]const u8,
    op_len: usize,
) FdbResult {
    const state: *TxnState = @ptrCast(@alignCast(txn orelse {
        return FdbResult.err(.err_invalid_argument, createErrorBlob(.err_invalid_argument, "Invalid transaction"));
    }));

    if (!txn_registry.contains(state)) {
        return FdbResult.err(.err_invalid_argument, createErrorBlob(.err_invalid_argument, "Transaction not registered"));
    }

    if (!state.is_active) {
        return FdbResult.err(.err_txn_not_active, createErrorBlob(.err_txn_not_active, "Transaction not active"));
    }

    if (state.mode != .read_write) {
        return FdbResult.err(.err_invalid_argument, createErrorBlob(.err_invalid_argument, "Read-only transaction"));
    }

    // Parse the operation
    const op_data = op_ptr[0..op_len];
    var decoder = cbor.Decoder.init(global_allocator, op_data);

    // Read operation type (expect map with "op" key)
    const map_len = decoder.decodeMapLen() catch {
        return FdbResult.err(.err_invalid_argument, createErrorBlob(.err_invalid_argument, "Invalid operation format"));
    };

    var op_type: ?[]const u8 = null;
    var i: usize = 0;
    while (i < map_len) : (i += 1) {
        const key = decoder.decodeText() catch {
            return FdbResult.err(.err_invalid_argument, createErrorBlob(.err_invalid_argument, "Invalid operation key"));
        };

        if (std.mem.eql(u8, key, "op")) {
            op_type = decoder.decodeText() catch {
                return FdbResult.err(.err_invalid_argument, createErrorBlob(.err_invalid_argument, "Invalid operation type"));
            };
        } else {
            decoder.skip() catch {
                return FdbResult.err(.err_invalid_argument, createErrorBlob(.err_invalid_argument, "Failed to skip value"));
            };
        }
    }

    // Dispatch operation (placeholder for PoC)
    if (op_type) |op| {
        if (std.mem.eql(u8, op, "insert")) {
            // Create result blob
            var encoder = cbor.Encoder.init(global_allocator);
            encoder.beginMap(2) catch return FdbResult.err(.err_internal, FdbBlob.empty());
            encoder.encodeText("status") catch return FdbResult.err(.err_internal, FdbBlob.empty());
            encoder.encodeText("ok") catch return FdbResult.err(.err_internal, FdbBlob.empty());
            encoder.encodeText("doc_id") catch return FdbResult.err(.err_internal, FdbBlob.empty());

            // Generate doc ID
            state.db.next_block_id += 1;
            encoder.encodeUint(state.db.next_block_id) catch return FdbResult.err(.err_internal, FdbBlob.empty());

            const result_data = global_allocator.dupe(u8, encoder.finish()) catch {
                return FdbResult.err(.err_out_of_memory, FdbBlob.empty());
            };
            encoder.deinit();

            // Create provenance
            const prov = cbor.encodeProvenance(
                global_allocator,
                "bridge",
                "system",
                "Document inserted via bridge",
                "2026-01-11T12:00:00Z",
            ) catch return FdbResult.ok(FdbBlob.fromSlice(result_data));

            return FdbResult.okWithProvenance(
                FdbBlob.fromSlice(result_data),
                FdbBlob.fromSlice(prov),
            );
        }
    }

    return FdbResult.err(.err_not_implemented, createErrorBlob(.err_not_implemented, "Operation not implemented"));
}

// ============================================================
// Introspection - C ABI Exports
// ============================================================

/// Render a block as canonical text
///
/// @param db Database handle
/// @param block_id Block ID to render
/// @param opts Render options
/// @param out_text Output parameter for text blob
/// @param out_err Output parameter for error blob
/// @return Status code
export fn fdb_render_block(
    db: ?*FdbDb,
    block_id: u64,
    opts: FdbRenderOpts,
    out_text: *FdbBlob,
    out_err: *FdbBlob,
) FdbStatus {
    _ = opts;

    const state: *DbState = @ptrCast(@alignCast(db orelse {
        out_err.* = createErrorBlob(.err_invalid_argument, "Invalid database handle");
        return .err_invalid_argument;
    }));

    if (!db_registry.contains(state)) {
        out_err.* = createErrorBlob(.err_invalid_argument, "Database handle not registered");
        return .err_invalid_argument;
    }

    // Generate canonical block rendering (placeholder)
    var encoder = cbor.Encoder.init(global_allocator);
    encoder.beginMap(3) catch {
        out_err.* = createErrorBlob(.err_internal, "Encoding failed");
        return .err_internal;
    };
    encoder.encodeText("block_id") catch return .err_internal;
    encoder.encodeUint(block_id) catch return .err_internal;
    encoder.encodeText("type") catch return .err_internal;
    encoder.encodeText("document") catch return .err_internal;
    encoder.encodeText("status") catch return .err_internal;
    encoder.encodeText("rendered") catch return .err_internal;

    const text_data = global_allocator.dupe(u8, encoder.finish()) catch {
        out_err.* = createErrorBlob(.err_out_of_memory, "Failed to allocate result");
        return .err_out_of_memory;
    };
    encoder.deinit();

    out_text.* = FdbBlob.fromSlice(text_data);
    out_err.* = FdbBlob.empty();
    return .ok;
}

/// Render journal entries since a sequence number
///
/// @param db Database handle
/// @param since Sequence number to start from
/// @param opts Render options
/// @param out_text Output parameter for text blob
/// @param out_err Output parameter for error blob
/// @return Status code
export fn fdb_render_journal(
    db: ?*FdbDb,
    since: u64,
    opts: FdbRenderOpts,
    out_text: *FdbBlob,
    out_err: *FdbBlob,
) FdbStatus {
    _ = opts;

    const state: *DbState = @ptrCast(@alignCast(db orelse {
        out_err.* = createErrorBlob(.err_invalid_argument, "Invalid database handle");
        return .err_invalid_argument;
    }));

    if (!db_registry.contains(state)) {
        out_err.* = createErrorBlob(.err_invalid_argument, "Database handle not registered");
        return .err_invalid_argument;
    }

    // Generate journal rendering (placeholder)
    var encoder = cbor.Encoder.init(global_allocator);
    encoder.beginMap(3) catch {
        out_err.* = createErrorBlob(.err_internal, "Encoding failed");
        return .err_internal;
    };
    encoder.encodeText("since") catch return .err_internal;
    encoder.encodeUint(since) catch return .err_internal;
    encoder.encodeText("head") catch return .err_internal;
    encoder.encodeUint(state.journal_head) catch return .err_internal;
    encoder.encodeText("entries") catch return .err_internal;
    encoder.beginArray(0) catch return .err_internal;

    const text_data = global_allocator.dupe(u8, encoder.finish()) catch {
        out_err.* = createErrorBlob(.err_out_of_memory, "Failed to allocate result");
        return .err_out_of_memory;
    };
    encoder.deinit();

    out_text.* = FdbBlob.fromSlice(text_data);
    out_err.* = FdbBlob.empty();
    return .ok;
}

/// Get database schema information
///
/// @param db Database handle
/// @param out_schema Output parameter for schema blob
/// @param out_err Output parameter for error blob
/// @return Status code
export fn fdb_introspect_schema(
    db: ?*FdbDb,
    out_schema: *FdbBlob,
    out_err: *FdbBlob,
) FdbStatus {
    const state: *DbState = @ptrCast(@alignCast(db orelse {
        out_err.* = createErrorBlob(.err_invalid_argument, "Invalid database handle");
        return .err_invalid_argument;
    }));

    if (!db_registry.contains(state)) {
        out_err.* = createErrorBlob(.err_invalid_argument, "Database handle not registered");
        return .err_invalid_argument;
    }

    // Generate schema introspection (placeholder - no schema yet)
    var encoder = cbor.Encoder.init(global_allocator);
    encoder.beginMap(2) catch {
        out_err.* = createErrorBlob(.err_internal, "Encoding failed");
        return .err_internal;
    };
    encoder.encodeText("collections") catch return .err_internal;
    encoder.beginArray(0) catch return .err_internal;
    encoder.encodeText("version") catch return .err_internal;
    encoder.encodeUint(1) catch return .err_internal;

    const schema_data = global_allocator.dupe(u8, encoder.finish()) catch {
        out_err.* = createErrorBlob(.err_out_of_memory, "Failed to allocate result");
        return .err_out_of_memory;
    };
    encoder.deinit();

    out_schema.* = FdbBlob.fromSlice(schema_data);
    out_err.* = FdbBlob.empty();
    return .ok;
}

/// Get constraint information
///
/// @param db Database handle
/// @param out_constraints Output parameter for constraints blob
/// @param out_err Output parameter for error blob
/// @return Status code
export fn fdb_introspect_constraints(
    db: ?*FdbDb,
    out_constraints: *FdbBlob,
    out_err: *FdbBlob,
) FdbStatus {
    const state: *DbState = @ptrCast(@alignCast(db orelse {
        out_err.* = createErrorBlob(.err_invalid_argument, "Invalid database handle");
        return .err_invalid_argument;
    }));

    if (!db_registry.contains(state)) {
        out_err.* = createErrorBlob(.err_invalid_argument, "Database handle not registered");
        return .err_invalid_argument;
    }

    // Generate constraint introspection (placeholder - no constraints yet)
    var encoder = cbor.Encoder.init(global_allocator);
    encoder.beginMap(2) catch {
        out_err.* = createErrorBlob(.err_internal, "Encoding failed");
        return .err_internal;
    };
    encoder.encodeText("constraints") catch return .err_internal;
    encoder.beginArray(0) catch return .err_internal;
    encoder.encodeText("functional_dependencies") catch return .err_internal;
    encoder.beginArray(0) catch return .err_internal;

    const constraint_data = global_allocator.dupe(u8, encoder.finish()) catch {
        out_err.* = createErrorBlob(.err_out_of_memory, "Failed to allocate result");
        return .err_out_of_memory;
    };
    encoder.deinit();

    out_constraints.* = FdbBlob.fromSlice(constraint_data);
    out_err.* = FdbBlob.empty();
    return .ok;
}

// ============================================================
// Proof Verification (per D-NORM-004)
// ============================================================

/// Proof verifier callback type
pub const FdbProofVerifier = *const fn (
    proof_ptr: [*]const u8,
    proof_len: usize,
    context_ptr: ?*anyopaque,
) callconv(.C) FdbStatus;

/// Proof verifier registration entry
const VerifierEntry = struct {
    verifier_type: []const u8,
    callback: FdbProofVerifier,
    context: ?*anyopaque,
};

// Registry of proof verifiers
var verifier_registry = std.StringHashMap(VerifierEntry).init(global_allocator);

/// Register a proof verifier for a specific proof type
///
/// @param type_ptr Proof type identifier (e.g., "normalization", "fd-holds")
/// @param type_len Length of type identifier
/// @param callback Verification function
/// @param context Optional context passed to callback
/// @return Status code
export fn fdb_proof_register_verifier(
    type_ptr: [*]const u8,
    type_len: usize,
    callback: FdbProofVerifier,
    context: ?*anyopaque,
) FdbStatus {
    const verifier_type = type_ptr[0..type_len];

    const type_copy = global_allocator.dupe(u8, verifier_type) catch {
        return .err_out_of_memory;
    };

    const entry = VerifierEntry{
        .verifier_type = type_copy,
        .callback = callback,
        .context = context,
    };

    verifier_registry.put(type_copy, entry) catch {
        global_allocator.free(type_copy);
        return .err_internal;
    };

    return .ok;
}

/// Unregister a proof verifier
///
/// @param type_ptr Proof type identifier
/// @param type_len Length of type identifier
/// @return Status code
export fn fdb_proof_unregister_verifier(
    type_ptr: [*]const u8,
    type_len: usize,
) FdbStatus {
    const verifier_type = type_ptr[0..type_len];

    if (verifier_registry.fetchRemove(verifier_type)) |entry| {
        global_allocator.free(@constCast(entry.value.verifier_type));
        return .ok;
    }

    return .err_not_found;
}

/// Verify a proof using registered verifiers
///
/// @param proof_ptr CBOR-encoded proof blob
/// @param proof_len Length of proof
/// @param out_valid Output: true if proof is valid
/// @param out_err Output parameter for error blob
/// @return Status code
export fn fdb_proof_verify(
    proof_ptr: [*]const u8,
    proof_len: usize,
    out_valid: *bool,
    out_err: *FdbBlob,
) FdbStatus {
    const proof_data = proof_ptr[0..proof_len];

    // Parse proof to extract type
    var decoder = cbor.Decoder.init(global_allocator, proof_data);

    // Expect map with "type" and "data" keys
    const map_len = decoder.decodeMapLen() catch {
        out_err.* = createErrorBlob(.err_invalid_argument, "Invalid proof format: expected map");
        return .err_invalid_argument;
    };

    var proof_type: ?[]const u8 = null;
    var proof_data_start: usize = 0;
    var proof_data_end: usize = 0;

    var i: usize = 0;
    while (i < map_len) : (i += 1) {
        const key = decoder.decodeText() catch {
            out_err.* = createErrorBlob(.err_invalid_argument, "Invalid proof key");
            return .err_invalid_argument;
        };

        if (std.mem.eql(u8, key, "type")) {
            proof_type = decoder.decodeText() catch {
                out_err.* = createErrorBlob(.err_invalid_argument, "Invalid proof type");
                return .err_invalid_argument;
            };
        } else if (std.mem.eql(u8, key, "data")) {
            proof_data_start = decoder.position;
            decoder.skip() catch {
                out_err.* = createErrorBlob(.err_invalid_argument, "Failed to read proof data");
                return .err_invalid_argument;
            };
            proof_data_end = decoder.position;
        } else {
            decoder.skip() catch {
                out_err.* = createErrorBlob(.err_invalid_argument, "Failed to skip value");
                return .err_invalid_argument;
            };
        }
    }

    // Look up verifier
    const ptype = proof_type orelse {
        out_err.* = createErrorBlob(.err_invalid_argument, "Proof missing type field");
        return .err_invalid_argument;
    };

    const entry = verifier_registry.get(ptype) orelse {
        out_err.* = createErrorBlob(.err_not_found, "No verifier registered for proof type");
        return .err_not_found;
    };

    // Call verifier with proof data
    const verify_data = proof_data[proof_data_start..proof_data_end];
    const status = entry.callback(verify_data.ptr, verify_data.len, entry.context);

    out_valid.* = (status == .ok);
    out_err.* = FdbBlob.empty();
    return .ok;
}

/// Built-in verifier for FD-holds proofs (always accepts for PoC)
fn builtin_fd_verifier(
    _: [*]const u8,
    _: usize,
    _: ?*anyopaque,
) callconv(.C) FdbStatus {
    // In production, this would actually verify the proof
    // For PoC, we accept all well-formed proofs
    return .ok;
}

/// Built-in verifier for normalization proofs
fn builtin_normalization_verifier(
    _: [*]const u8,
    _: usize,
    _: ?*anyopaque,
) callconv(.C) FdbStatus {
    // In production, this would verify losslessness and dependency preservation
    // For PoC, we accept all well-formed proofs
    return .ok;
}

/// Initialize built-in proof verifiers
export fn fdb_proof_init_builtins() FdbStatus {
    // Register FD-holds verifier
    const fd_type = "fd-holds";
    var status = fdb_proof_register_verifier(fd_type.ptr, fd_type.len, builtin_fd_verifier, null);
    if (status != .ok) return status;

    // Register normalization verifier
    const norm_type = "normalization";
    status = fdb_proof_register_verifier(norm_type.ptr, norm_type.len, builtin_normalization_verifier, null);
    if (status != .ok) return status;

    // Register denormalization verifier (same logic)
    const denorm_type = "denormalization";
    status = fdb_proof_register_verifier(denorm_type.ptr, denorm_type.len, builtin_normalization_verifier, null);

    return status;
}

// ============================================================
// Utility Functions - C ABI Exports
// ============================================================

/// Free a blob allocated by the bridge
///
/// @param blob Blob to free
export fn fdb_blob_free(blob: *FdbBlob) void {
    if (blob.toSlice()) |slice| {
        global_allocator.free(@constCast(slice));
    }
    blob.* = FdbBlob.empty();
}

/// Get FormDB version
///
/// @return Version as encoded integer (major * 10000 + minor * 100 + patch)
export fn fdb_version() u32 {
    return 0 * 10000 + 1 * 100 + 0; // 0.1.0
}

// ============================================================
// Tests
// ============================================================

test "database lifecycle" {
    var db: ?*FdbDb = null;
    var err_blob: FdbBlob = undefined;

    const path = "test.fdb";
    const status = fdb_db_open(path.ptr, path.len, null, 0, &db, &err_blob);

    try std.testing.expectEqual(FdbStatus.ok, status);
    try std.testing.expect(db != null);

    const close_status = fdb_db_close(db);
    try std.testing.expectEqual(FdbStatus.ok, close_status);
}

test "transaction lifecycle" {
    var db: ?*FdbDb = null;
    var err_blob: FdbBlob = undefined;

    const path = "test_txn.fdb";
    _ = fdb_db_open(path.ptr, path.len, null, 0, &db, &err_blob);
    defer _ = fdb_db_close(db);

    var txn: ?*FdbTxn = null;
    var txn_err: FdbBlob = undefined;

    const begin_status = fdb_txn_begin(db, .read_write, &txn, &txn_err);
    try std.testing.expectEqual(FdbStatus.ok, begin_status);
    try std.testing.expect(txn != null);

    var commit_err: FdbBlob = undefined;
    const commit_status = fdb_txn_commit(txn, &commit_err);
    try std.testing.expectEqual(FdbStatus.ok, commit_status);
}

test "version" {
    const version = fdb_version();
    try std.testing.expectEqual(@as(u32, 100), version); // 0.1.0
}
