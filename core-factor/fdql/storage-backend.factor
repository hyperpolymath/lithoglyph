! SPDX-License-Identifier: AGPL-3.0-or-later
! Form.Runtime - Storage Backend Abstraction
!
! Pluggable storage layer for FDQL executor.
! - memory: In-memory storage (default, for testing)
! - bridge: Persistent storage via Form.Bridge (production)

USING: accessors alien alien.c-types alien.data alien.strings arrays
assocs byte-arrays classes.struct combinators formatting hashtables
io io.encodings.utf8 kernel locals math namespaces sequences strings
vectors ;

IN: storage-backend

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

! Status codes matching bridge.zig FdbStatus
CONSTANT: FDB_OK 0
CONSTANT: FDB_ERR_INTERNAL 1
CONSTANT: FDB_ERR_NOT_FOUND 2
CONSTANT: FDB_ERR_INVALID_ARGUMENT 3
CONSTANT: FDB_ERR_OUT_OF_MEMORY 4
CONSTANT: FDB_ERR_NOT_IMPLEMENTED 5

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

! Bridge backend methods - placeholder implementations
! In production, these would FFI to bridge.zig

M:: bridge-backend backend-init ( backend -- )
    ! In production: call fdb_db_open via FFI
    backend db-path>> :> path
    "Opening database: %s (bridge backend not fully wired)\n" path sprintf print
    t backend is-open<< ;

M:: bridge-backend backend-close ( backend -- )
    ! In production: call fdb_db_close via FFI
    backend is-open>> [
        "Closing database\n" print
        f backend is-open<<
    ] when ;

M:: bridge-backend backend-get-collection ( name backend -- data )
    ! In production: call fdb_apply with query operation via FFI
    ! For now, return empty vector
    "Bridge backend: get-collection %s (stub)\n" name sprintf print
    V{ } clone ;

M:: bridge-backend backend-set-collection ( data name backend -- )
    ! In production: call fdb_apply with bulk insert via FFI
    "Bridge backend: set-collection %s with %d docs (stub)\n"
    name data length 2array vsprintf print ;

M: bridge-backend backend-list-collections
    ! In production: call fdb_introspect_schema via FFI
    "Bridge backend: list-collections (stub)\n" print
    { } ;

M:: bridge-backend backend-delete-collection ( name backend -- )
    ! In production: call fdb_apply with drop operation via FFI
    "Bridge backend: delete-collection %s (stub)\n" name sprintf print ;

M:: bridge-backend backend-insert ( doc collection backend -- id )
    ! In production: call fdb_apply with insert operation via FFI
    "Bridge backend: insert into %s (stub)\n" collection sprintf print
    0 ;

M:: bridge-backend backend-update ( doc id collection backend -- success? )
    ! In production: call fdb_apply with update operation via FFI
    "Bridge backend: update %s in %s (stub)\n" id collection 2array vsprintf print
    f ;

M:: bridge-backend backend-delete ( id collection backend -- success? )
    ! In production: call fdb_apply with delete operation via FFI
    "Bridge backend: delete %s from %s (stub)\n" id collection 2array vsprintf print
    f ;

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
