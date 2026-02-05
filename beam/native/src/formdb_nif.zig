// SPDX-License-Identifier: PMPL-1.0-or-later
// FormDB BEAM NIF - Zig implementation
//
// This NIF connects BEAM (Erlang/Gleam/Elixir) to FormDB via the FormBD C ABI.
// Uses CBOR-encoded binaries for efficient data transfer.

const std = @import("std");
const beam = @import("beam.zig");

// Import FormDB C ABI (from formdb/database/core-forth/ffi/zig/src/abi.zig)
// M10 PoC: Stub implementations for testing (will use real libformbd.so later)
const formbd = struct {
    fn formbd_init() ?*anyopaque {
        // Return dummy handle for M10 PoC
        return @ptrFromInt(@as(usize, 0xDEADBEEF));
    }

    fn formbd_cleanup(handle: ?*anyopaque) void {
        _ = handle;
        // No-op for M10 PoC
    }

    fn formbd_parse_cbor(handle: ?*anyopaque, cbor_data: [*]const u8, cbor_len: usize) ?*anyopaque {
        _ = handle;
        _ = cbor_data;

        if (cbor_len == 0 or cbor_len > 1048576) {
            return null;
        }

        // Return dummy token for M10 PoC
        return @ptrFromInt(@as(usize, 0xCAFEBABE));
    }

    fn formbd_validate(token: ?*anyopaque) c_int {
        return if (token != null) 1 else 0;
    }

    fn formbd_persist(handle: ?*anyopaque, token: ?*anyopaque) u64 {
        _ = handle;
        _ = token;
        // Return dummy block ID for M10 PoC
        return 1;
    }

    fn formbd_load(handle: ?*anyopaque, block_id: u64) ?*anyopaque {
        _ = handle;
        _ = block_id;
        // Not implemented in M10 PoC
        return null;
    }
};

// Global allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Resource types (initialized in nif_init)
var db_handle_type: ?*beam.resource_type = undefined;
var txn_handle_type: ?*beam.resource_type = undefined;

// Database handle wrapper
const DbHandle = struct {
    formbd_handle: *anyopaque,
    path: []const u8,

    fn create(path: []const u8) !*DbHandle {
        const handle = formbd.formbd_init() orelse return error.InitFailed;

        const db = try allocator.create(DbHandle);
        db.* = .{
            .formbd_handle = handle,
            .path = try allocator.dupe(u8, path),
        };

        return db;
    }

    fn destroy(self: *DbHandle) void {
        formbd.formbd_cleanup(self.formbd_handle);
        allocator.free(self.path);
        allocator.destroy(self);
    }
};

// Transaction handle wrapper
const TxnHandle = struct {
    db: *DbHandle,
    mode: TransactionMode,

    const TransactionMode = enum {
        read_only,
        read_write,
    };
};

//==============================================================================
// NIF Functions
//==============================================================================

/// Get FormDB version
export fn version(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    _ = argc;
    _ = argv;
    // Return {1, 0, 0} for v1.0.0 (M10)
    return beam.make_tuple3(env,
        beam.make_int(env, 1),
        beam.make_int(env, 0),
        beam.make_int(env, 0)
    );
}

/// Open a FormDB database
/// Parameters: Path (binary)
/// Returns: {ok, DbRef} | {error, Reason}
export fn db_open(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    if (argc != 1) {
        return beam.make_badarg(env);
    }

    // Get path as binary
    var path_bin: beam.binary = undefined;
    if (beam.get_binary(env, argv[0], &path_bin) == 0) {
        return beam.make_badarg(env);
    }

    const path = path_bin.data[0..path_bin.size];

    // Create database handle
    const db = DbHandle.create(path) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "init_failed")
        );
    };

    // Create resource (opaque reference for Erlang)
    const db_res = beam.alloc_resource(env, db, db_handle_type) catch {
        db.destroy();
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "resource_alloc_failed")
        );
    };

    return beam.make_tuple2(env,
        beam.make_atom(env, "ok"),
        db_res
    );
}

/// Close a FormDB database
/// Parameters: DbRef (resource)
/// Returns: ok | {error, Reason}
export fn db_close(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    if (argc != 1) {
        return beam.make_badarg(env);
    }

    // Get database handle
    const db_ptr = beam.get_resource(env, argv[0], DbHandle, db_handle_type) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "invalid_handle")
        );
    };

    const db: *DbHandle = @ptrCast(@alignCast(db_ptr));
    db.destroy();

    return beam.make_atom(env, "ok");
}

/// Begin a transaction
/// Parameters: DbRef, Mode (read_only | read_write)
/// Returns: {ok, TxnRef} | {error, Reason}
export fn txn_begin(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    if (argc != 2) {
        return beam.make_badarg(env);
    }

    // Get database handle
    const db_ptr = beam.get_resource(env, argv[0], DbHandle, db_handle_type) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "invalid_handle")
        );
    };

    const db: *DbHandle = @ptrCast(@alignCast(db_ptr));

    // Get transaction mode
    var mode_atom: [32]u8 = undefined;
    const mode_len = beam.get_atom(env, argv[1], &mode_atom);
    if (mode_len == 0) {
        return beam.make_badarg(env);
    }

    const mode_str = mode_atom[0..mode_len];
    const mode: TxnHandle.TransactionMode = if (std.mem.eql(u8, mode_str, "read_only"))
        .read_only
    else if (std.mem.eql(u8, mode_str, "read_write"))
        .read_write
    else
        return beam.make_badarg(env);

    // Create transaction handle
    const txn = allocator.create(TxnHandle) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "alloc_failed")
        );
    };

    txn.* = .{
        .db = db,
        .mode = mode,
    };

    // Create resource
    const txn_res = beam.alloc_resource(env, txn, txn_handle_type) catch {
        allocator.destroy(txn);
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "resource_alloc_failed")
        );
    };

    return beam.make_tuple2(env,
        beam.make_atom(env, "ok"),
        txn_res
    );
}

/// Commit a transaction
/// Parameters: TxnRef
/// Returns: ok | {error, Reason}
export fn txn_commit(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    if (argc != 1) {
        return beam.make_badarg(env);
    }

    // Get transaction handle
    const txn_ptr = beam.get_resource(env, argv[0], TxnHandle, txn_handle_type) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "invalid_handle")
        );
    };

    const txn: *TxnHandle = @ptrCast(@alignCast(txn_ptr));

    // TODO: Implement actual transaction commit
    // For M10 PoC, just cleanup
    allocator.destroy(txn);

    return beam.make_atom(env, "ok");
}

/// Abort a transaction
/// Parameters: TxnRef
/// Returns: ok
export fn txn_abort(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    if (argc != 1) {
        return beam.make_badarg(env);
    }

    // Get transaction handle
    const txn_ptr = beam.get_resource(env, argv[0], TxnHandle, txn_handle_type) catch {
        return beam.make_atom(env, "ok"); // Already aborted/invalid
    };

    const txn: *TxnHandle = @ptrCast(@alignCast(txn_ptr));
    allocator.destroy(txn);

    return beam.make_atom(env, "ok");
}

/// Apply an operation within a transaction
/// Parameters: TxnRef, OpCbor (binary)
/// Returns: {ok, ResultCbor} | {ok, ResultCbor, ProvenanceCbor} | {error, Reason}
export fn apply(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    if (argc != 2) {
        return beam.make_badarg(env);
    }

    // Get transaction handle
    const txn_ptr = beam.get_resource(env, argv[0], TxnHandle, txn_handle_type) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "invalid_handle")
        );
    };

    const txn: *TxnHandle = @ptrCast(@alignCast(txn_ptr));

    // Get CBOR operation
    var cbor_bin: beam.binary = undefined;
    if (beam.get_binary(env, argv[1], &cbor_bin) == 0) {
        return beam.make_badarg(env);
    }

    const cbor_data = cbor_bin.data[0..cbor_bin.size];

    // Parse CBOR using FormBD C ABI
    const token = formbd.formbd_parse_cbor(
        txn.db.formbd_handle,
        cbor_data.ptr,
        cbor_data.len
    ) orelse {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "parse_failed")
        );
    };

    // Validate token
    if (formbd.formbd_validate(token) != 1) {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "validation_failed")
        );
    }

    // Persist token
    const block_id = formbd.formbd_persist(txn.db.formbd_handle, token);
    if (block_id == 0) {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "persist_failed")
        );
    }

    // Return success with block ID as result
    // For M10 PoC, return block ID as binary
    var result_buf: [8]u8 = undefined;
    std.mem.writeInt(u64, &result_buf, block_id, .big);

    const result_bin = beam.make_binary(env, &result_buf) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "result_alloc_failed")
        );
    };

    // TODO: Include provenance token in response
    // For now, just return result
    return beam.make_tuple2(env,
        beam.make_atom(env, "ok"),
        result_bin
    );
}

/// Get database schema
/// Parameters: DbRef
/// Returns: {ok, SchemaCbor} | {error, Reason}
export fn schema(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    if (argc != 1) {
        return beam.make_badarg(env);
    }

    // TODO: Get database handle from argv[0] and retrieve schema
    _ = argv; // Unused for M10 PoC

    // TODO: Implement schema retrieval
    // For M10 PoC, return empty CBOR map
    const empty_map = [_]u8{0xa0}; // CBOR: {}

    const schema_bin = beam.make_binary(env, &empty_map) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "alloc_failed")
        );
    };

    return beam.make_tuple2(env,
        beam.make_atom(env, "ok"),
        schema_bin
    );
}

/// Get journal entries since a sequence number
/// Parameters: DbRef, Since (integer)
/// Returns: {ok, JournalCbor} | {error, Reason}
export fn journal(env: ?*beam.env, argc: c_int, argv: [*c]const beam.term) beam.term {
    if (argc != 2) {
        return beam.make_badarg(env);
    }

    // TODO: Get database handle from argv[0] and since from argv[1]
    _ = argv; // Unused for M10 PoC

    // TODO: Implement journal retrieval
    // For M10 PoC, return empty CBOR array
    const empty_array = [_]u8{0x80}; // CBOR: []

    const journal_bin = beam.make_binary(env, &empty_array) catch {
        return beam.make_tuple2(env,
            beam.make_atom(env, "error"),
            beam.make_atom(env, "alloc_failed")
        );
    };

    return beam.make_tuple2(env,
        beam.make_atom(env, "ok"),
        journal_bin
    );
}

//==============================================================================
// NIF Initialization
//==============================================================================

const nif_funcs = [_]beam.ErlNifFunc{
    .{ .name = "version", .arity = 0, .fptr = version, .flags = 0 },
    .{ .name = "db_open", .arity = 1, .fptr = db_open, .flags = 0 },
    .{ .name = "db_close", .arity = 1, .fptr = db_close, .flags = 0 },
    .{ .name = "txn_begin", .arity = 2, .fptr = txn_begin, .flags = 0 },
    .{ .name = "txn_commit", .arity = 1, .fptr = txn_commit, .flags = 0 },
    .{ .name = "txn_abort", .arity = 1, .fptr = txn_abort, .flags = 0 },
    .{ .name = "apply", .arity = 2, .fptr = apply, .flags = 0 },
    .{ .name = "schema", .arity = 1, .fptr = schema, .flags = 0 },
    .{ .name = "journal", .arity = 2, .fptr = journal, .flags = 0 },
};

export fn nif_init(env: ?*beam.env, priv_data: [*c]?*anyopaque, load_info: beam.term) c_int {
    _ = priv_data;
    _ = load_info;

    // Check env is valid
    if (env == null) {
        return 1;
    }

    // Register resource types
    db_handle_type = beam.open_resource_type(env, "db_handle", null) catch {
        return 1;
    };

    txn_handle_type = beam.open_resource_type(env, "txn_handle", null) catch {
        return 1;
    };

    return 0;
}

export const nif_entry = beam.ErlNifEntry{
    .major = beam.ERL_NIF_MAJOR_VERSION,
    .minor = beam.ERL_NIF_MINOR_VERSION,
    .name = "formdb_nif",
    .num_of_funcs = nif_funcs.len,
    .funcs = @ptrCast(@constCast(&nif_funcs)),
    .load = nif_init,
    .reload = null,
    .upgrade = null,
    .unload = null,
    .vm_variant = "beam.vanilla",
    .options = 1,
    .sizeof_ErlNifResourceTypeInit = @sizeOf(beam.ErlNifResourceTypeInit),
};
