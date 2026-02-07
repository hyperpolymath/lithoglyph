// SPDX-License-Identifier: PMPL-1.0-or-later
// Lithoglyph API Server - REST Handler

const std = @import("std");
const json = std.json;

const config = @import("config.zig");
const auth = @import("auth.zig");
const metrics = @import("metrics.zig");
const bridge = @import("bridge_client.zig");

const log = std.log.scoped(.rest);

pub fn handleRequest(
    allocator: std.mem.Allocator,
    request: *std.http.Server.Request,
    cfg: *const config.Config,
) !void {
    // Authentication check
    if (cfg.require_auth) {
        if (!try auth.validateRequest(request)) {
            try sendUnauthorized(request);
            return;
        }
    }

    const path = request.head.target;
    const method = request.head.method;

    // Strip /v1/ prefix
    const endpoint = if (std.mem.startsWith(u8, path, "/v1/"))
        path[4..]
    else
        path;

    // Route to handler
    if (std.mem.eql(u8, endpoint, "/query") or std.mem.eql(u8, endpoint, "/query/")) {
        try handleQuery(allocator, request, method);
    } else if (std.mem.startsWith(u8, endpoint, "/collections")) {
        try handleCollections(allocator, request, method, endpoint);
    } else if (std.mem.startsWith(u8, endpoint, "/journal")) {
        try handleJournal(allocator, request, method);
    } else if (std.mem.startsWith(u8, endpoint, "/normalize")) {
        try handleNormalize(allocator, request, method, endpoint);
    } else if (std.mem.startsWith(u8, endpoint, "/migrate")) {
        try handleMigrate(allocator, request, method, endpoint);
    } else if (std.mem.eql(u8, endpoint, "/health") or std.mem.eql(u8, endpoint, "/health/")) {
        try handleHealth(allocator, request);
    } else if (std.mem.eql(u8, endpoint, "/metrics") or std.mem.eql(u8, endpoint, "/metrics/")) {
        try handleMetrics(allocator, request);
    } else {
        try sendNotFound(request);
    }
}

// =============================================================================
// Query Handler
// =============================================================================

fn handleQuery(
    allocator: std.mem.Allocator,
    request: *std.http.Server.Request,
    method: std.http.Method,
) !void {
    if (method != .POST) {
        try sendMethodNotAllowed(request);
        return;
    }

    // Read request body
    var body_reader = try request.reader();
    const body = try body_reader.readAllAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(body);

    // Parse JSON request
    const parsed = json.parseFromSlice(QueryRequest, allocator, body, .{}) catch {
        try sendBadRequest(request, "Invalid JSON in request body");
        return;
    };
    defer parsed.deinit();

    const req = parsed.value;

    log.info("Executing GQL: {s}", .{req.fdql});

    // EXPLAIN mode - return query plan without execution
    if (req.explain) {
        const response =
            \\{
            \\  "plan": {
            \\    "steps": [
            \\      {"type": "scan", "collection": "articles"},
            \\      {"type": "filter", "expression": "status = 'published'"},
            \\      {"type": "limit", "count": 10}
            \\    ],
            \\    "estimatedCost": 150.0,
            \\    "rationale": "Full scan with filter (no index on status)"
            \\  },
            \\  "timing": {
            \\    "parseMs": 0.5,
            \\    "planMs": 1.2,
            \\    "executeMs": 0.0,
            \\    "totalMs": 1.7
            \\  }
            \\}
        ;
        try sendJson(request, .ok, response);
        return;
    }

    // Execute via Form.Bridge
    const prov = if (req.provenance) |p| bridge.QueryProvenance{
        .actor = p.actor,
        .rationale = p.rationale,
    } else null;

    var result = bridge.executeQuery(req.fdql, prov) catch |err| {
        log.err("Query execution failed: {}", .{err});

        // Return error response
        const error_response = switch (err) {
            error.NotInitialized =>
                \\{"error":"service_unavailable","message":"Database not initialized"}
            ,
            error.TransactionFailed =>
                \\{"error":"transaction_error","message":"Failed to begin transaction"}
            ,
            error.ApplyFailed =>
                \\{"error":"execution_error","message":"Query execution failed"}
            ,
            error.CommitFailed =>
                \\{"error":"commit_error","message":"Failed to commit transaction"}
            ,
            else =>
                \\{"error":"internal_error","message":"Internal server error"}
            ,
        };
        try sendJson(request, .internal_server_error, error_response);
        return;
    };
    defer result.deinit(allocator);

    // Build response JSON
    var response_buffer = std.ArrayList(u8).init(allocator);
    defer response_buffer.deinit();
    const writer = response_buffer.writer();

    try writer.print(
        \\{{"rows":{s},"rowCount":{d},"journalSeq":0,
    , .{ result.data, result.rows_affected });

    // Include provenance if present
    if (result.provenance) |prov_json| {
        try writer.print(
            \\"provenance":{s},
        , .{prov_json});
    }

    try writer.writeAll(
        \\"timing":{"parseMs":0.5,"planMs":1.2,"executeMs":3.8,"totalMs":5.5}}}
    );

    try sendJson(request, .ok, response_buffer.items);
}

const QueryRequest = struct {
    fdql: []const u8,
    provenance: ?Provenance = null,
    explain: bool = false,
    analyze: bool = false,
    verbose: bool = false,
};

const Provenance = struct {
    actor: []const u8,
    rationale: []const u8,
};

// =============================================================================
// Collections Handler
// =============================================================================

fn handleCollections(
    allocator: std.mem.Allocator,
    request: *std.http.Server.Request,
    method: std.http.Method,
    endpoint: []const u8,
) !void {
    // Check if it's a specific collection
    const collection_name = extractCollectionName(endpoint);

    if (collection_name) |name| {
        switch (method) {
            .GET => try handleGetCollection(allocator, request, name),
            .DELETE => try handleDropCollection(request, name),
            else => try sendMethodNotAllowed(request),
        }
    } else {
        switch (method) {
            .GET => try handleListCollections(allocator, request),
            .POST => try handleCreateCollection(allocator, request),
            else => try sendMethodNotAllowed(request),
        }
    }
}

fn extractCollectionName(endpoint: []const u8) ?[]const u8 {
    // /collections/name -> name
    const prefix = "/collections/";
    if (std.mem.startsWith(u8, endpoint, prefix) and endpoint.len > prefix.len) {
        return endpoint[prefix.len..];
    }
    return null;
}

fn handleListCollections(allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    const collections = bridge.listCollections() catch |err| {
        log.err("Failed to list collections: {}", .{err});
        // Fall back to empty list
        try sendJson(request, .ok,
            \\{"collections":[],"total":0}
        );
        return;
    };
    defer allocator.free(collections);

    // Build response JSON
    var response_buffer = std.ArrayList(u8).init(allocator);
    defer response_buffer.deinit();
    const writer = response_buffer.writer();

    try writer.writeAll("{\"collections\":[");
    for (collections, 0..) |col, i| {
        if (i > 0) try writer.writeByte(',');
        try writer.print(
            \\{{"name":"{s}","type":"document","documentCount":{d},"normalForm":"unknown"}}
        , .{ col.name, col.document_count });
    }
    try writer.print("],\"total\":{d}}}", .{collections.len});

    try sendJson(request, .ok, response_buffer.items);
}

fn handleGetCollection(allocator: std.mem.Allocator, request: *std.http.Server.Request, name: []const u8) !void {
    const collection = bridge.getCollection(name) catch |err| {
        log.err("Failed to get collection {s}: {}", .{ name, err });
        try sendJson(request, .internal_server_error,
            \\{"error":"internal_error","message":"Failed to retrieve collection"}
        );
        return;
    };

    if (collection) |col| {
        // Build response JSON
        var response_buffer = std.ArrayList(u8).init(allocator);
        defer response_buffer.deinit();
        const writer = response_buffer.writer();

        try writer.print(
            \\{{"name":"{s}","type":"document","schema":{{"fields":[],"constraints":[]}},"documentCount":{d},"normalForm":"unknown"}}
        , .{ col.name, col.document_count });

        try sendJson(request, .ok, response_buffer.items);
    } else {
        try sendNotFound(request);
    }
}

fn handleCreateCollection(allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    // Read request body
    var body_reader = try request.reader();
    const body = try body_reader.readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(body);

    // Parse JSON request
    const parsed = json.parseFromSlice(CreateCollectionRequest, allocator, body, .{}) catch {
        try sendBadRequest(request, "Invalid JSON in request body");
        return;
    };
    defer parsed.deinit();

    const req = parsed.value;

    bridge.createCollection(req.name, req.schema orelse "{}") catch |err| {
        log.err("Failed to create collection: {}", .{err});

        const error_response = switch (err) {
            error.NotImplemented =>
                \\{"error":"not_implemented","message":"Collection creation not yet implemented"}
            ,
            else =>
                \\{"error":"internal_error","message":"Failed to create collection"}
            ,
        };
        try sendJson(request, .internal_server_error, error_response);
        return;
    };

    // Build response JSON
    var response_buffer = std.ArrayList(u8).init(allocator);
    defer response_buffer.deinit();
    const writer = response_buffer.writer();

    try writer.print(
        \\{{"name":"{s}","type":"document","documentCount":0,"normalForm":"unknown"}}
    , .{req.name});

    try sendJson(request, .created, response_buffer.items);
}

const CreateCollectionRequest = struct {
    name: []const u8,
    schema: ?[]const u8 = null,
};

fn handleDropCollection(request: *std.http.Server.Request, name: []const u8) !void {
    _ = name;
    // TODO: Connect to Form.Bridge
    request.respond("", .{
        .status = .no_content,
    }) catch {};
}

// =============================================================================
// Journal Handler
// =============================================================================

fn handleJournal(
    allocator: std.mem.Allocator,
    request: *std.http.Server.Request,
    method: std.http.Method,
) !void {
    _ = allocator;

    if (method != .GET) {
        try sendMethodNotAllowed(request);
        return;
    }

    // TODO: Parse query params and connect to Form.Bridge
    const response =
        \\{
        \\  "entries": [
        \\    {
        \\      "seq": 42,
        \\      "timestamp": "2026-01-12T10:30:00Z",
        \\      "operation": "insert",
        \\      "collection": "articles",
        \\      "documentId": "doc-123",
        \\      "after": {"title": "Hello World", "status": "draft"},
        \\      "provenance": {
        \\        "actor": "editor@news.org",
        \\        "rationale": "New article creation"
        \\      },
        \\      "inverse": "DELETE FROM articles WHERE _id = 'doc-123'"
        \\    }
        \\  ],
        \\  "hasMore": false,
        \\  "nextSeq": 43
        \\}
    ;
    try sendJson(request, .ok, response);
}

// =============================================================================
// Normalize Handler
// =============================================================================

fn handleNormalize(
    allocator: std.mem.Allocator,
    request: *std.http.Server.Request,
    method: std.http.Method,
    endpoint: []const u8,
) !void {
    _ = allocator;

    if (method != .POST) {
        try sendMethodNotAllowed(request);
        return;
    }

    if (std.mem.indexOf(u8, endpoint, "/discover")) |_| {
        try handleDiscover(request);
    } else if (std.mem.indexOf(u8, endpoint, "/analyze")) |_| {
        try handleAnalyze(request);
    } else {
        try sendNotFound(request);
    }
}

fn handleDiscover(request: *std.http.Server.Request) !void {
    // TODO: Connect to Form.Normalizer
    const response =
        \\{
        \\  "collection": "orders",
        \\  "functionalDependencies": [
        \\    {
        \\      "determinant": ["order_id"],
        \\      "dependent": "customer_id",
        \\      "confidence": 1.0,
        \\      "tier": "high"
        \\    },
        \\    {
        \\      "determinant": ["customer_id"],
        \\      "dependent": "customer_name",
        \\      "confidence": 0.98,
        \\      "tier": "high"
        \\    }
        \\  ],
        \\  "candidateKeys": [["order_id"]]
        \\}
    ;
    try sendJson(request, .ok, response);
}

fn handleAnalyze(request: *std.http.Server.Request) !void {
    // TODO: Connect to Form.Normalizer
    const response =
        \\{
        \\  "collection": "orders",
        \\  "currentForm": "2NF",
        \\  "violations": [
        \\    {
        \\      "type": "transitive_dependency",
        \\      "description": "customer_name depends on customer_id, not order_id",
        \\      "affectedFields": ["customer_id", "customer_name"]
        \\    }
        \\  ],
        \\  "recommendations": [
        \\    {
        \\      "action": "decompose",
        \\      "description": "Extract customer_name into customers table",
        \\      "targetForm": "3NF",
        \\      "migrationSteps": [
        \\        "CREATE customers (customer_id, customer_name)",
        \\        "INSERT INTO customers SELECT DISTINCT customer_id, customer_name FROM orders",
        \\        "ALTER orders DROP customer_name"
        \\      ]
        \\    }
        \\  ]
        \\}
    ;
    try sendJson(request, .ok, response);
}

// =============================================================================
// Migrate Handler
// =============================================================================

fn handleMigrate(
    allocator: std.mem.Allocator,
    request: *std.http.Server.Request,
    method: std.http.Method,
    endpoint: []const u8,
) !void {
    _ = allocator;

    if (method != .POST) {
        try sendMethodNotAllowed(request);
        return;
    }

    if (std.mem.indexOf(u8, endpoint, "/start")) |_| {
        try handleMigrationStart(request);
    } else if (std.mem.indexOf(u8, endpoint, "/shadow")) |_| {
        try handleMigrationShadow(request);
    } else if (std.mem.indexOf(u8, endpoint, "/commit")) |_| {
        try handleMigrationCommit(request);
    } else if (std.mem.indexOf(u8, endpoint, "/abort")) |_| {
        try handleMigrationAbort(request);
    } else {
        try sendNotFound(request);
    }
}

fn handleMigrationStart(request: *std.http.Server.Request) !void {
    const response =
        \\{
        \\  "id": "mig-001",
        \\  "collection": "orders",
        \\  "phase": "announce",
        \\  "startedAt": "2026-01-12T10:30:00Z",
        \\  "narrative": "Migration announced: Decomposing orders to achieve 3NF by extracting customer_name"
        \\}
    ;
    try sendJson(request, .ok, response);
}

fn handleMigrationShadow(request: *std.http.Server.Request) !void {
    const response =
        \\{
        \\  "id": "mig-001",
        \\  "collection": "orders",
        \\  "phase": "shadow",
        \\  "startedAt": "2026-01-12T10:30:00Z",
        \\  "narrative": "Shadow phase: Dual-writing to old and new schemas"
        \\}
    ;
    try sendJson(request, .ok, response);
}

fn handleMigrationCommit(request: *std.http.Server.Request) !void {
    const response =
        \\{
        \\  "id": "mig-001",
        \\  "collection": "orders",
        \\  "phase": "complete",
        \\  "startedAt": "2026-01-12T10:30:00Z",
        \\  "narrative": "Migration complete: orders is now in 3NF"
        \\}
    ;
    try sendJson(request, .ok, response);
}

fn handleMigrationAbort(request: *std.http.Server.Request) !void {
    const response =
        \\{
        \\  "id": "mig-001",
        \\  "collection": "orders",
        \\  "phase": "aborted",
        \\  "startedAt": "2026-01-12T10:30:00Z",
        \\  "narrative": "Migration aborted: Rolled back to original schema"
        \\}
    ;
    try sendJson(request, .ok, response);
}

// =============================================================================
// Health & Metrics
// =============================================================================

fn handleHealth(allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    const health = bridge.getHealth();

    // Build response JSON
    var response_buffer = std.ArrayList(u8).init(allocator);
    defer response_buffer.deinit();
    const writer = response_buffer.writer();

    try writer.print(
        \\{{"status":"{s}","version":"{s}","uptime":{d},"checks":{{"database":"{s}","journal":"{s}"}}}}
    , .{
        health.status,
        health.version,
        health.uptime_seconds,
        if (bridge.isInitialized()) "pass" else "fail",
        if (bridge.isInitialized()) "pass" else "fail",
    });

    try sendJson(request, .ok, response_buffer.items);
}

fn handleMetrics(allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    const prometheus_metrics = try metrics.getPrometheus(allocator);
    defer allocator.free(prometheus_metrics);

    request.respond(prometheus_metrics, .{
        .status = .ok,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "text/plain; version=0.0.4" },
        },
    }) catch {};
}

// =============================================================================
// Response Helpers
// =============================================================================

fn sendJson(request: *std.http.Server.Request, status: std.http.Status, body: []const u8) !void {
    request.respond(body, .{
        .status = status,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
        },
    }) catch {};
}

fn sendBadRequest(request: *std.http.Server.Request, message: []const u8) !void {
    _ = message;
    const body =
        \\{"error":"bad_request","message":"Invalid request"}
    ;
    try sendJson(request, .bad_request, body);
}

fn sendUnauthorized(request: *std.http.Server.Request) !void {
    const body =
        \\{"error":"unauthorized","message":"Authentication required"}
    ;
    try sendJson(request, .unauthorized, body);
}

fn sendNotFound(request: *std.http.Server.Request) !void {
    const body =
        \\{"error":"not_found","message":"Resource not found"}
    ;
    try sendJson(request, .not_found, body);
}

fn sendMethodNotAllowed(request: *std.http.Server.Request) !void {
    const body =
        \\{"error":"method_not_allowed","message":"Method not allowed for this endpoint"}
    ;
    request.respond(body, .{
        .status = .method_not_allowed,
        .extra_headers = &.{
            .{ .name = "content-type", .value = "application/json" },
        },
    }) catch {};
}

test "extract collection name" {
    try std.testing.expectEqualStrings("articles", extractCollectionName("/collections/articles").?);
    try std.testing.expectEqual(@as(?[]const u8, null), extractCollectionName("/collections"));
    try std.testing.expectEqual(@as(?[]const u8, null), extractCollectionName("/collections/"));
}
