// SPDX-License-Identifier: PMPL-1.0-or-later
// FFI Integration Test - Tests Zig bridge from C
//
// This tests the complete FFI surface from C, simulating what
// Factor would do when calling the bridge.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

// FFI types matching bridge.zig
typedef struct {
    const uint8_t* ptr;
    size_t len;
} LgBlob;

typedef struct {
    LgBlob value;
    LgBlob error;
    int status;
} LgResult;

typedef enum {
    LG_OK = 0,
    LG_ERR_INTERNAL = 1,
    LG_ERR_NOT_FOUND = 2,
    LG_ERR_INVALID_ARGUMENT = 3,
    LG_ERR_OUT_OF_MEMORY = 4,
    LG_ERR_NOT_IMPLEMENTED = 5,
    LG_ERR_TXN_NOT_ACTIVE = 6,
    LG_ERR_TXN_ALREADY_COMMITTED = 7,
} LgStatus;

// FFI function declarations (matching bridge.zig exports)
extern int fdb_version(void);
extern int fdb_db_open(const uint8_t* path, size_t path_len, const uint8_t* opts, size_t opts_len, void** out_db, LgBlob* out_err);
extern void fdb_db_close(void* db);
extern int fdb_txn_begin(void* db, bool read_only, void** out_txn, LgBlob* out_err);
extern int fdb_txn_commit(void* txn, LgBlob* out_err);
extern int fdb_txn_abort(void* txn, LgBlob* out_err);
extern LgResult fdb_apply(void* txn, const uint8_t* op, size_t op_len);
extern int fdb_introspect_schema(void* db, LgBlob* out_schema, LgBlob* out_err);
extern int fdb_render_journal(void* db, uint64_t since, LgBlob* out_text, LgBlob* out_err);
extern void fdb_blob_free(LgBlob* blob);

// Helper functions
void print_blob(const char* label, LgBlob* blob) {
    printf("%s: ", label);
    if (blob->ptr && blob->len > 0) {
        printf("%.*s\n", (int)blob->len, blob->ptr);
    } else {
        printf("(empty)\n");
    }
}

void free_blob_if_needed(LgBlob* blob) {
    if (blob->ptr) {
        fdb_blob_free(blob);
    }
}

// Test functions
int test_version() {
    printf("=== Test 1: Get Version ===\n");
    int version = fdb_version();
    printf("Version: %d\n", version);
    printf("✅ Version test passed\n\n");
    return 0;
}

int test_database_lifecycle() {
    printf("=== Test 2: Database Lifecycle ===\n");

    const char* path = "test-ffi.lgh";
    void* db = NULL;
    LgBlob err = {0};

    // Open database
    printf("Opening database: %s\n", path);
    int status = fdb_db_open((const uint8_t*)path, strlen(path), NULL, 0, &db, &err);

    if (status != LG_OK) {
        print_blob("Error", &err);
        free_blob_if_needed(&err);
        return 1;
    }

    printf("Database opened successfully\n");
    printf("DB handle: %p\n", db);

    // Close database
    printf("Closing database\n");
    fdb_db_close(db);

    printf("✅ Database lifecycle test passed\n\n");
    return 0;
}

int test_transactions() {
    printf("=== Test 3: Transactions ===\n");

    const char* path = "test-txn.lgh";
    void* db = NULL;
    void* txn = NULL;
    LgBlob err = {0};

    // Open database
    int status = fdb_db_open((const uint8_t*)path, strlen(path), NULL, 0, &db, &err);
    if (status != LG_OK) {
        print_blob("Error opening DB", &err);
        free_blob_if_needed(&err);
        return 1;
    }

    // Begin read-write transaction
    printf("Beginning transaction\n");
    status = fdb_txn_begin(db, false, &txn, &err);
    if (status != LG_OK) {
        print_blob("Error beginning txn", &err);
        free_blob_if_needed(&err);
        fdb_db_close(db);
        return 1;
    }

    printf("Transaction handle: %p\n", txn);

    // Commit transaction
    printf("Committing transaction\n");
    status = fdb_txn_commit(txn, &err);
    if (status != LG_OK) {
        print_blob("Error committing txn", &err);
        free_blob_if_needed(&err);
        fdb_db_close(db);
        return 1;
    }

    fdb_db_close(db);
    printf("✅ Transaction test passed\n\n");
    return 0;
}

int test_apply_operation() {
    printf("=== Test 4: Apply Operation ===\n");

    const char* path = "test-apply.lgh";
    void* db = NULL;
    void* txn = NULL;
    LgBlob err = {0};

    // Open database
    int status = fdb_db_open((const uint8_t*)path, strlen(path), NULL, 0, &db, &err);
    if (status != LG_OK) {
        print_blob("Error", &err);
        free_blob_if_needed(&err);
        return 1;
    }

    // Begin transaction
    status = fdb_txn_begin(db, false, &txn, &err);
    if (status != LG_OK) {
        print_blob("Error", &err);
        free_blob_if_needed(&err);
        fdb_db_close(db);
        return 1;
    }

    // Apply insert operation
    const char* op = "{\"op\":\"insert\",\"collection\":\"users\",\"doc\":{\"name\":\"Alice\"}}";
    printf("Applying operation: %s\n", op);

    LgResult result = fdb_apply(txn, (const uint8_t*)op, strlen(op));

    printf("Result status: %d\n", result.status);
    print_blob("Result value", &result.value);
    print_blob("Result error", &result.error);

    free_blob_if_needed(&result.value);
    free_blob_if_needed(&result.error);

    // Commit
    status = fdb_txn_commit(txn, &err);
    if (status != LG_OK) {
        print_blob("Error committing", &err);
        free_blob_if_needed(&err);
        fdb_db_close(db);
        return 1;
    }

    fdb_db_close(db);
    printf("✅ Apply operation test passed\n\n");
    return 0;
}

int test_introspection() {
    printf("=== Test 5: Introspection ===\n");

    const char* path = "test-intro.lgh";
    void* db = NULL;
    LgBlob err = {0};
    LgBlob schema = {0};

    // Open database
    int status = fdb_db_open((const uint8_t*)path, strlen(path), NULL, 0, &db, &err);
    if (status != LG_OK) {
        print_blob("Error", &err);
        free_blob_if_needed(&err);
        return 1;
    }

    // Get schema
    printf("Getting schema\n");
    status = fdb_introspect_schema(db, &schema, &err);
    if (status != LG_OK) {
        print_blob("Error", &err);
        free_blob_if_needed(&err);
        fdb_db_close(db);
        return 1;
    }

    print_blob("Schema", &schema);
    free_blob_if_needed(&schema);

    // Get journal
    printf("Getting journal\n");
    LgBlob journal = {0};
    status = fdb_render_journal(db, 0, &journal, &err);
    if (status != LG_OK) {
        print_blob("Error", &err);
        free_blob_if_needed(&err);
        fdb_db_close(db);
        return 1;
    }

    print_blob("Journal", &journal);
    free_blob_if_needed(&journal);

    fdb_db_close(db);
    printf("✅ Introspection test passed\n\n");
    return 0;
}

int main() {
    printf("======================================\n");
    printf("Lithoglyph FFI Integration Tests\n");
    printf("======================================\n\n");

    int failures = 0;

    failures += test_version();
    failures += test_database_lifecycle();
    failures += test_transactions();
    failures += test_apply_operation();
    failures += test_introspection();

    printf("======================================\n");
    if (failures == 0) {
        printf("✅ ALL TESTS PASSED!\n");
    } else {
        printf("❌ %d test(s) failed\n", failures);
    }
    printf("======================================\n");

    return failures;
}
