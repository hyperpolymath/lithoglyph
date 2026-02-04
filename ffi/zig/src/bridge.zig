// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell (@hyperpolymath)
//
// bridge.zig - Zig FFI implementation for FormBD Form.Bridge ABI
// CRITICAL: Pure ABI bridge - all safety logic in Idris2

const std = @import("std");
const types = @import("types.zig");
const cbor = @import("cbor.zig");
const query_executor = @import("query_executor.zig");

// Status codes (matches Idris2 FdbStatus exactly)
pub const Status = enum(i32) {
    ok = 0,
    invalid_arg = 1,
    not_found = 2,
    permission_denied = 3,
    already_exists = 4,
    constraint_violation = 5,
    type_mismatch = 6,
    out_of_memory = 7,
    io_error = 8,
    corruption = 9,
    conflict = 10,
    internal_error = 11,
};

// Opaque handle types (matches Idris2 handle types)
pub const FdbDb = opaque {};
pub const FdbTxn = opaque {};
pub const FdbCursor = opaque {};
pub const FdbCollection = opaque {};
pub const FdbSchema = opaque {};
pub const FdbJournal = opaque {};
pub const FdbMigration = opaque {};

// Global state
var initialized: bool = false;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var global_executor: ?query_executor.SimpleExecutor = null;

////////////////////////////////////////////////////////////////////////////////
// Library Lifecycle
////////////////////////////////////////////////////////////////////////////////

/// Initialize FormBD library
/// CRITICAL: Pure ABI bridge - delegates to Idris2 for actual initialization
export fn fdb_init() callconv(.c) i32 {
    if (initialized) return @intFromEnum(Status.ok);

    // Initialize query executor (M5 implementation)
    const allocator = gpa.allocator();
    global_executor = query_executor.SimpleExecutor.init(allocator) catch {
        return @intFromEnum(Status.out_of_memory);
    };

    // TODO: Call Idris2 initialization function
    // const idris_status = idris2_fdb_init();
    // if (idris_status != 0) return @intFromEnum(Status.internal_error);

    initialized = true;
    return @intFromEnum(Status.ok);
}

/// Cleanup FormBD library
export fn fdb_cleanup() callconv(.c) void {
    if (!initialized) return;

    // TODO: Call Idris2 cleanup function
    // idris2_fdb_cleanup();

    _ = gpa.deinit();
    initialized = false;
}

////////////////////////////////////////////////////////////////////////////////
// Database Operations
////////////////////////////////////////////////////////////////////////////////

/// Open database
/// CRITICAL: Path validation in Idris2 via Proven.SafePath
export fn fdb_open(
    path: [*:0]const u8,
    path_len: u64,
    db_out: *?*FdbDb,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);
    if (path_len == 0) return @intFromEnum(Status.invalid_arg);
    if (path_len > 4096) return @intFromEnum(Status.invalid_arg);

    // TODO: Call Idris2 fdb_open function
    // Path validation MUST happen in Idris2 via Proven.SafePath
    // - No directory traversal
    // - No symlink attacks
    // - Permission checks
    // const idris_db = idris2_fdb_open(path, path_len);

    _ = path;
    _ = db_out;
    return @intFromEnum(Status.internal_error);
}

/// Close database
export fn fdb_close(db: *FdbDb) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);

    // Clean up query executor
    if (global_executor) |*executor| {
        executor.deinit();
        global_executor = null;
    }

    // TODO: Call Idris2 fdb_close function
    // Flush pending writes, close file descriptors

    _ = db;
    return @intFromEnum(Status.ok);
}

/// Create new database
export fn fdb_create(
    path: [*:0]const u8,
    path_len: u64,
    block_count: u64,
    db_out: *?*FdbDb,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);
    if (path_len == 0) return @intFromEnum(Status.invalid_arg);
    if (block_count == 0) return @intFromEnum(Status.invalid_arg);
    if (block_count > 1_000_000) return @intFromEnum(Status.invalid_arg); // 4GB limit

    // TODO: Call Idris2 fdb_create function
    // Path validation + file creation in Idris2

    _ = path;
    _ = db_out;
    return @intFromEnum(Status.internal_error);
}

////////////////////////////////////////////////////////////////////////////////
// Transaction Operations
////////////////////////////////////////////////////////////////////////////////

/// Begin transaction
export fn fdb_txn_begin(
    db: *FdbDb,
    txn_out: *?*FdbTxn,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);

    // TODO: Call Idris2 fdb_txn_begin function
    // ACID transaction with journal logging

    _ = db;
    _ = txn_out;
    return @intFromEnum(Status.internal_error);
}

/// Commit transaction
export fn fdb_txn_commit(txn: *FdbTxn) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);

    // TODO: Call Idris2 fdb_txn_commit function
    // Write journal entries, flush to disk

    _ = txn;
    return @intFromEnum(Status.ok);
}

/// Rollback transaction (uses journal inverses)
export fn fdb_txn_rollback(txn: *FdbTxn) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);

    // TODO: Call Idris2 fdb_txn_rollback function
    // Apply journal inverses in reverse order

    _ = txn;
    return @intFromEnum(Status.ok);
}

////////////////////////////////////////////////////////////////////////////////
// Collection Operations
////////////////////////////////////////////////////////////////////////////////

/// Create collection with schema
export fn fdb_collection_create(
    db: *FdbDb,
    name: [*:0]const u8,
    name_len: u64,
    schema_json: [*:0]const u8,
    schema_len: u64,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);
    if (name_len == 0) return @intFromEnum(Status.invalid_arg);
    if (schema_len == 0) return @intFromEnum(Status.invalid_arg);

    // TODO: Call Idris2 fdb_collection_create function
    // JSON validation via Proven.SafeJson
    // Schema validation in Idris2

    _ = db;
    _ = name;
    _ = schema_json;
    return @intFromEnum(Status.internal_error);
}

/// Drop collection
export fn fdb_collection_drop(
    db: *FdbDb,
    name: [*:0]const u8,
    name_len: u64,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);
    if (name_len == 0) return @intFromEnum(Status.invalid_arg);

    // TODO: Call Idris2 fdb_collection_drop function

    _ = db;
    _ = name;
    return @intFromEnum(Status.internal_error);
}

/// Get collection schema
export fn fdb_collection_schema(
    db: *FdbDb,
    name: [*:0]const u8,
    schema_out: *?*FdbSchema,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);

    // TODO: Call Idris2 fdb_collection_schema function

    _ = db;
    _ = name;
    _ = schema_out;
    return @intFromEnum(Status.internal_error);
}

////////////////////////////////////////////////////////////////////////////////
// FQL Query Execution
////////////////////////////////////////////////////////////////////////////////

/// Execute FQL query with provenance
export fn fdb_query_execute(
    db: *FdbDb,
    query_str: [*:0]const u8,
    query_len: u64,
    provenance_json: [*:0]const u8,
    provenance_len: u64,
    cursor_out: *?*FdbCursor,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);
    if (query_len == 0) return @intFromEnum(Status.invalid_arg);
    if (query_len > 1_000_000) return @intFromEnum(Status.invalid_arg); // 1MB query limit
    if (provenance_len == 0) return @intFromEnum(Status.invalid_arg);

    _ = db;
    _ = provenance_json; // TODO: Use provenance for audit log

    // Get the global executor
    if (global_executor) |*executor| {
        // Convert C string to Zig slice
        const query = query_str[0..query_len];

        // Execute query (M5 implementation - will call Factor in M6)
        var result = executor.execute(query) catch {
            return @intFromEnum(Status.internal_error);
        };
        defer result.deinit();

        // For now, just return success
        // TODO: Create cursor from result.data
        _ = cursor_out;

        if (std.mem.eql(u8, result.status, "ok")) {
            return @intFromEnum(Status.ok);
        } else {
            return @intFromEnum(Status.internal_error);
        }
    }

    return @intFromEnum(Status.internal_error);
}

/// Explain FQL query (get execution plan)
export fn fdb_query_explain(
    db: *FdbDb,
    query_str: [*:0]const u8,
    query_len: u64,
    explain_json_out: [*]u8,
    buffer_len: u64,
    written_out: *u64,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);
    if (query_len == 0) return @intFromEnum(Status.invalid_arg);
    if (buffer_len == 0) return @intFromEnum(Status.invalid_arg);

    // TODO: Call Factor fdb_query_explain function
    // Returns JSON explain output with planner steps

    _ = db;
    _ = query_str;
    _ = explain_json_out;
    written_out.* = 0;
    return @intFromEnum(Status.internal_error);
}

/// Fetch next result from cursor
export fn fdb_cursor_next(
    cursor: *FdbCursor,
    document_json_out: [*]u8,
    buffer_len: u64,
    written_out: *u64,
) callconv(.c) i32 {
    if (!initialized) return @intFromEnum(Status.internal_error);
    if (buffer_len == 0) return @intFromEnum(Status.invalid_arg);

    // TODO: Call Factor/Forth fdb_cursor_next function
    // Returns StatusOk if row fetched, StatusNotFound if end of cursor

    _ = cursor;
    _ = document_json_out;
    written_out.* = 0;
    return @intFromEnum(Status.not_found);
}

/// Close cursor
export fn fdb_cursor_close(cursor: *FdbCursor) callconv(.c) void {
    if (!initialized) return;

    // TODO: Call Idris2 fdb_cursor_close function

    _ = cursor;
}

////////////////////////////////////////////////////////////////////////////////
// SEAM TESTING EXPORTS
// These functions are for testing integration boundaries
////////////////////////////////////////////////////////////////////////////////

/// SEAM TEST: Verify Idris2 → Zig boundary
export fn fdb_seam_test_idris_zig() callconv(.c) i32 {
    // TODO: Call Idris2 function and verify return value
    return @intFromEnum(Status.ok);
}

/// SEAM TEST: Verify Zig → Factor boundary
export fn fdb_seam_test_zig_factor() callconv(.c) i32 {
    // TODO: Call Factor function and verify return value
    return @intFromEnum(Status.ok);
}

/// SEAM TEST: Verify Factor → Forth boundary
export fn fdb_seam_test_factor_forth() callconv(.c) i32 {
    // TODO: Call Forth function and verify return value
    return @intFromEnum(Status.ok);
}

////////////////////////////////////////////////////////////////////////////////
// Helper Functions (ABI Bridge Only)
////////////////////////////////////////////////////////////////////////////////

/// Validate null-terminated C string (basic safety check)
/// NOTE: Full validation happens in Idris2 via Proven.SafeString
fn validate_c_string(ptr: [*:0]const u8, max_len: usize) bool {
    var len: usize = 0;
    while (ptr[len] != 0) : (len += 1) {
        if (len >= max_len) return false;
    }
    return len > 0;
}

////////////////////////////////////////////////////////////////////////////////
// Tests
////////////////////////////////////////////////////////////////////////////////

const testing = std.testing;

test "status codes match Idris2 ABI" {
    try testing.expectEqual(@as(i32, 0), @intFromEnum(Status.ok));
    try testing.expectEqual(@as(i32, 1), @intFromEnum(Status.invalid_arg));
    try testing.expectEqual(@as(i32, 2), @intFromEnum(Status.not_found));
    try testing.expectEqual(@as(i32, 3), @intFromEnum(Status.permission_denied));
    try testing.expectEqual(@as(i32, 4), @intFromEnum(Status.already_exists));
    try testing.expectEqual(@as(i32, 5), @intFromEnum(Status.constraint_violation));
    try testing.expectEqual(@as(i32, 6), @intFromEnum(Status.type_mismatch));
    try testing.expectEqual(@as(i32, 7), @intFromEnum(Status.out_of_memory));
    try testing.expectEqual(@as(i32, 8), @intFromEnum(Status.io_error));
    try testing.expectEqual(@as(i32, 9), @intFromEnum(Status.corruption));
    try testing.expectEqual(@as(i32, 10), @intFromEnum(Status.conflict));
    try testing.expectEqual(@as(i32, 11), @intFromEnum(Status.internal_error));
}

test "library initialization" {
    const status = fdb_init();
    try testing.expectEqual(@intFromEnum(Status.ok), status);
    fdb_cleanup();
}

test "validate_c_string rejects empty strings" {
    const empty_str: [*:0]const u8 = "";
    try testing.expect(!validate_c_string(empty_str, 100));
}

test "validate_c_string accepts valid strings" {
    const valid_str: [*:0]const u8 = "SELECT * FROM users";
    try testing.expect(validate_c_string(valid_str, 1000));
}

test "validate_c_string rejects oversized strings" {
    var buf: [200]u8 = undefined;
    @memset(&buf, 'A');
    buf[199] = 0;
    const long_str: [*:0]const u8 = @ptrCast(&buf);
    try testing.expect(!validate_c_string(long_str, 100));
}
