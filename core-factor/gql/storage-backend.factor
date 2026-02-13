! SPDX-License-Identifier: PMPL-1.0-or-later
! Form.Runtime - Storage Backend Abstraction
!
! Pluggable storage layer for FDQL executor.
! - memory: In-memory storage (default, for testing)
! - bridge: Persistent storage via Form.Bridge (production)

USING: accessors alien alien.c-types alien.data alien.libraries alien.strings
arrays assocs byte-arrays classes.struct combinators formatting hashtables
io io.encodings.utf8 json.reader json.writer kernel locals math namespaces
sequences strings vectors ;

IN: storage-backend

! ============================================================
! Lithoglyph Bridge FFI Library
! ============================================================

<< "lithoglyph-bridge" {
    { [ os linux? ] [ "libbridge.so" ] }
    { [ os macosx? ] [ "libbridge.dylib" ] }
    { [ os windows? ] [ "bridge.dll" ] }
} cond cdecl add-library >>

! ============================================================
! Storage Backend Protocol
! ============================================================

MIXIN: storage-backend

GENERIC: backend-init ( backend -- )
GENERIC: backend-close ( backend -- )
GENERIC: backend-get-collection ( name backend -- data )
GENERIC: backend-set-collection ( data name backend -- )
GENERIC: backend-list-collections ( backend -- names )
GENERIC: backend-delete-collection ( name backend -- )
GENERIC: backend-insert ( doc collection backend -- id )
GENERIC: backend-update ( doc id collection backend -- success? )
GENERIC: backend-delete ( id collection backend -- success? )
GENERIC: backend-query ( collection backend -- rows )

! ============================================================
! In-Memory Backend (Default)
! ============================================================

TUPLE: memory-backend
    collections
    next-id ;

: <memory-backend> ( -- backend )
    memory-backend new
        H{ } clone >>collections
        1 >>next-id ;

INSTANCE: memory-backend storage-backend

M: memory-backend backend-init
    drop ;

M: memory-backend backend-close
    drop ;

M: memory-backend backend-get-collection
    collections>> at [ V{ } clone ] unless* ;

M: memory-backend backend-set-collection
    collections>> set-at ;

M: memory-backend backend-list-collections
    collections>> keys ;

M: memory-backend backend-delete-collection
    collections>> delete-at ;

M:: memory-backend backend-insert ( doc collection backend -- id )
    backend next-id>> :> id
    id 1 + backend next-id<<
    ! Add id to document
    id number>string "_id" doc set-at
    ! Get or create collection
    collection backend backend-get-collection :> coll
    doc coll push
    coll collection backend backend-set-collection
    id ;

M:: memory-backend backend-update ( doc id collection backend -- success? )
    collection backend backend-get-collection :> coll
    f :> found!
    coll [
        dup "_id" swap at id number>string = [
            drop doc t found!
        ] when
    ] map collection backend backend-set-collection
    found ;

M:: memory-backend backend-delete ( id collection backend -- success? )
    collection backend backend-get-collection :> coll
    coll [
        "_id" swap at id number>string = not
    ] filter :> new-coll
    new-coll length coll length < :> deleted?
    new-coll collection backend backend-set-collection
    deleted? ;

M: memory-backend backend-query
    backend-get-collection ;

! ============================================================
! Bridge Backend (Persistent Storage)
! ============================================================

! FFI type definitions for Form.Bridge
STRUCT: fdb-blob
    { ptr void* }
    { len size_t } ;

STRUCT: fdb-result
    { value fdb-blob }
    { error fdb-blob }
    { status int } ;

! Status codes matching bridge.zig LgStatus
CONSTANT: FDB_OK 0
CONSTANT: FDB_ERR_INTERNAL 1
CONSTANT: FDB_ERR_NOT_FOUND 2
CONSTANT: FDB_ERR_INVALID_ARGUMENT 3
CONSTANT: FDB_ERR_OUT_OF_MEMORY 4
CONSTANT: FDB_ERR_NOT_IMPLEMENTED 5
CONSTANT: FDB_ERR_TXN_NOT_ACTIVE 6
CONSTANT: FDB_ERR_TXN_ALREADY_COMMITTED 7

! ============================================================
! FFI Function Declarations
! ============================================================

LIBRARY: lithoglyph-bridge

! Database lifecycle
FUNCTION: int fdb_db_open ( void* path ulong path_len void** out_db fdb-blob* out_err )
FUNCTION: void fdb_db_close ( void* db )
FUNCTION: int fdb_get_version ( )

! Transaction management
FUNCTION: int fdb_txn_begin ( void* db bool read_only void** out_txn fdb-blob* out_err )
FUNCTION: int fdb_txn_commit ( void* txn fdb-blob* out_err )
FUNCTION: int fdb_txn_abort ( void* txn )

! Operations (buffered until commit)
FUNCTION: fdb-result fdb_apply ( void* txn void* op ulong op_len )
FUNCTION: int fdb_update_block ( void* txn ulong block_id void* data ulong data_len fdb-blob* out_err )
FUNCTION: int fdb_delete_block ( void* txn ulong block_id fdb-blob* out_err )

! Query (full block scan)
FUNCTION: int fdb_read_blocks ( void* db ushort block_type fdb-blob* out_data fdb-blob* out_err )

! Introspection
FUNCTION: int fdb_introspect_schema ( void* db fdb-blob* out_schema fdb-blob* out_err )
FUNCTION: int fdb_introspect_constraints ( void* db fdb-blob* out_constraints fdb-blob* out_err )
FUNCTION: int fdb_render_journal ( void* db ulong since fdb-blob* out_text fdb-blob* out_err )
FUNCTION: int fdb_render_block ( void* db ulong block_id fdb-blob* out_text fdb-blob* out_err )

! Resource cleanup
FUNCTION: void fdb_blob_free ( fdb-blob* blob )

! ============================================================
! FFI Helper Functions
! ============================================================

: make-fdb-blob ( -- blob )
    fdb-blob malloc-struct
        f >>ptr
        0 >>len ;

: blob>string ( blob -- str/f )
    dup ptr>> [
        [ ptr>> ] [ len>> ] bi memory>byte-array utf8 decode
    ] [ drop f ] if ;

: string>fdb-input ( str -- ptr len )
    utf8 encode [ underlying>> ] [ length ] bi ;

: check-fdb-status ( status err-blob -- )
    swap FDB_OK = [
        drop
    ] [
        blob>string "FFI Error: %s\n" sprintf throw
    ] if ;

! Block type constant for documents (0x0011)
CONSTANT: BLOCK_TYPE_DOCUMENT 0x0011

! Parse JSON array of block results into Factor vector of hashtables.
! Input: JSON string like [{"block_id":1,"size":42,"data":"..."},...]
! Output: Vector of hashtables (the "data" field is parsed as JSON if possible)
: parse-block-results ( json-str -- vec )
    json> dup array? [
        >vector
        [
            dup hashtable? [
                ! Try to parse the "data" field as JSON
                dup "data" swap at [
                    [ json> ] [ drop f ] recover
                    dup hashtable? [
                        ! Successfully parsed document JSON
                        swap "data" pick set-at
                    ] [ drop ] if
                ] when*
            ] when
        ] map
    ] [ drop V{ } clone ] if ;

! ============================================================
! Bridge Transaction Helper
! ============================================================

! Execute a single-operation transaction: begin → apply → commit
! Returns the block ID from fdb_apply result, or 0 on failure.
: with-bridge-txn ( doc-json backend -- block-id )
    db-handle>> :> db
    f :> txn-handle!
    make-fdb-blob :> err-blob

    ! Begin read-write transaction
    db f txn-handle! err-blob fdb_txn_begin
    err-blob check-fdb-status

    ! Apply the operation (buffered, not written until commit)
    swap string>fdb-input [
        txn-handle fdb_apply
    ] 2keep 2drop :> result

    ! Commit transaction (WAL: journal → sync → blocks → sync)
    txn-handle err-blob fdb_txn_commit
    err-blob check-fdb-status

    ! Extract block_id from result (JSON: {"block_id":N,"status":"pending"})
    result value>> blob>string [
        json> dup hashtable? [
            "block_id" swap at [ 0 ] unless*
        ] [ drop 0 ] if
    ] [ 0 ] if* ;

! ============================================================
! Bridge Backend Tuple
! ============================================================

TUPLE: bridge-backend
    db-handle
    db-path
    is-open ;

: <bridge-backend> ( path -- backend )
    bridge-backend new
        swap >>db-path
        f >>db-handle
        f >>is-open ;

INSTANCE: bridge-backend storage-backend

! Bridge backend methods - FFI implementations

M:: backend-init ( backend -- ) bridge-backend
    backend db-path>> :> path
    f :> db-handle!
    make-fdb-blob :> err-blob

    path string>fdb-input { void* } [
        db-handle! err-blob fdb_db_open
    ] with-out-parameters

    err-blob check-fdb-status
    db-handle backend db-handle<<
    t backend is-open<<
    "Database opened: %s\n" path sprintf print ;

M:: bridge-backend backend-close ( backend -- )
    backend is-open>> backend db-handle>> and [
        backend db-handle>> fdb_db_close
        f backend db-handle<<
        f backend is-open<<
        "Database closed\n" print
    ] when ;

M:: bridge-backend backend-get-collection ( name backend -- data )
    backend db-handle>> [
        make-fdb-blob :> data-blob
        make-fdb-blob :> err-blob

        ! Read all document blocks via fdb_read_blocks (type = 0x0011)
        backend db-handle>> BLOCK_TYPE_DOCUMENT data-blob err-blob fdb_read_blocks
        err-blob check-fdb-status

        ! Parse JSON result into vector of documents
        data-blob blob>string [ "[]" ] unless*
        parse-block-results

        ! Free the blob
        data-blob fdb_blob_free
    ] [ V{ } clone ] if ;

M:: bridge-backend backend-set-collection ( data name backend -- )
    backend db-handle>> [
        ! Insert each document via individual transactions
        data [
            >json backend with-bridge-txn drop
        ] each
    ] when ;

M:: bridge-backend backend-list-collections ( backend -- names )
    backend db-handle>> [
        make-fdb-blob :> schema-blob
        make-fdb-blob :> err-blob

        backend db-handle>> schema-blob err-blob fdb_introspect_schema
        err-blob check-fdb-status

        ! Parse JSON schema and extract collection names
        schema-blob blob>string [ "{\"version\":0,\"collections\":[]}" ] unless*
        json> dup hashtable? [
            "collections" swap at [ { } ] unless*
        ] [ drop { } ] if

        schema-blob fdb_blob_free
    ] [ { } ] if ;

M:: bridge-backend backend-delete-collection ( name backend -- )
    backend db-handle>> [
        ! Read all blocks and delete those matching the collection
        ! (For PoC, collection filtering is not yet implemented at block level)
        "Bridge backend: delete-collection %s (requires collection metadata)\n"
        name sprintf print
    ] when ;

M:: bridge-backend backend-insert ( doc collection backend -- id )
    backend db-handle>> [
        ! Serialize document to JSON for storage
        doc >json :> doc-json

        ! Execute insert through bridge transaction
        doc-json backend with-bridge-txn
    ] [ 0 ] if ;

M:: bridge-backend backend-update ( doc id collection backend -- success? )
    backend db-handle>> [
        f :> txn-handle!
        make-fdb-blob :> err-blob

        ! Begin transaction
        backend db-handle>> f txn-handle! err-blob fdb_txn_begin
        err-blob check-fdb-status

        ! Serialize new document data
        doc >json :> doc-json
        doc-json string>fdb-input :> ( data-ptr data-len )

        ! Update the block
        txn-handle id data-ptr data-len err-blob fdb_update_block
        err-blob check-fdb-status

        ! Commit
        txn-handle err-blob fdb_txn_commit
        err-blob check-fdb-status
        t
    ] [ f ] if ;

M:: bridge-backend backend-delete ( id collection backend -- success? )
    backend db-handle>> [
        f :> txn-handle!
        make-fdb-blob :> err-blob

        ! Begin transaction
        backend db-handle>> f txn-handle! err-blob fdb_txn_begin
        err-blob check-fdb-status

        ! Delete the block
        txn-handle id err-blob fdb_delete_block
        err-blob check-fdb-status

        ! Commit
        txn-handle err-blob fdb_txn_commit
        err-blob check-fdb-status
        t
    ] [ f ] if ;

M: bridge-backend backend-query
    backend-get-collection ;

! ============================================================
! Global Backend Selection
! ============================================================

SYMBOL: current-backend

: init-memory-backend ( -- )
    <memory-backend> dup backend-init current-backend set ;

: init-bridge-backend ( path -- )
    <bridge-backend> dup backend-init current-backend set ;

: get-backend ( -- backend )
    current-backend get [ init-memory-backend current-backend get ] unless* ;

: close-backend ( -- )
    current-backend get [ backend-close ] when*
    f current-backend set ;

! ============================================================
! Convenience API (used by executor)
! ============================================================

: storage-get-collection ( name -- data )
    get-backend backend-get-collection ;

: storage-set-collection ( data name -- )
    get-backend backend-set-collection ;

: storage-list-collections ( -- names )
    get-backend backend-list-collections ;

: storage-delete-collection ( name -- )
    get-backend backend-delete-collection ;

: storage-insert ( doc collection -- id )
    get-backend backend-insert ;

: storage-update ( doc id collection -- success? )
    get-backend backend-update ;

: storage-delete ( id collection -- success? )
    get-backend backend-delete ;

: storage-query ( collection -- rows )
    get-backend backend-query ;

! ============================================================
! Backend Selection at Startup
! ============================================================

: use-memory-storage ( -- )
    close-backend
    init-memory-backend
    "Using in-memory storage backend\n" print ;

: use-bridge-storage ( path -- )
    close-backend
    init-bridge-backend
    "Using bridge storage backend\n" print ;

! Default to memory backend
init-memory-backend
