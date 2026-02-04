\ SPDX-License-Identifier: AGPL-3.0-or-later
\ Form.Model - Multi-model logical layer
\
\ Documents, edges, collections, and schemas.
\ All operations go through the journal.

require formbd-journal.fs

\ ============================================================
\ Collection Management
\ ============================================================

\ Collection metadata structure
\ - name (up to 64 bytes)
\ - type (document or edge)
\ - schema_id (0 if no schema)
\ - document_count
\ - created_at
\ - modified_at

64 constant MAX-COLLECTION-NAME

\ Collection types
0 constant CTYPE-DOCUMENT
1 constant CTYPE-EDGE

\ In-memory collection registry (simple linked list for PoC)
variable collection-list  \ Head of collection list
0 collection-list !

\ Collection node structure
struct
  cell% field coll-next        \ Next collection in list
  cell% field coll-block-id    \ Block ID of collection metadata
  cell% field coll-type        \ Document or edge
  cell% field coll-schema-id   \ Schema block ID (0 if none)
  cell% field coll-doc-count   \ Number of documents
  MAX-COLLECTION-NAME 1+ char% field coll-name
end-struct collection%

\ Allocate new collection node
: alloc-collection ( -- addr )
  collection% %allot ;

\ Find collection by name
: find-collection ( addr len -- coll-addr | 0 )
  collection-list @
  begin
    dup 0<>
  while
    >r
    2dup r@ coll-name count compare 0= if
      2drop r> exit
    then
    r> coll-next @
  repeat
  2drop 0 ;

\ Create new collection
: create-collection ( name-addr name-len type -- coll-addr | 0 )
  \ Check if already exists
  2 pick 2 pick find-collection if
    drop 2drop 0 exit
  then
  \ Allocate block for collection metadata
  alloc-block-id
  \ Create journal entry
  OP-COLLECTION-CREATE over begin-journal-op
  \ Allocate collection node
  alloc-collection >r
  r@ coll-block-id !
  r@ coll-type !
  dup r@ coll-name c!
  r@ coll-name 1+ swap move
  0 r@ coll-schema-id !
  0 r@ coll-doc-count !
  \ Link into list
  collection-list @ r@ coll-next !
  r@ collection-list !
  \ Commit journal entry
  end-journal-op drop
  r> ;

\ Drop collection
: drop-collection ( name-addr name-len -- flag )
  find-collection dup 0= if exit then
  \ Create journal entry
  OP-COLLECTION-DROP over coll-block-id @ begin-journal-op
  \ TODO: Actually remove from list and free blocks
  end-journal-op ;

\ ============================================================
\ Document Operations
\ ============================================================

\ Document ID structure (16 bytes: prefix + counter)
16 constant DOC-ID-SIZE

variable doc-counter
0 doc-counter !

\ Generate new document ID
create doc-id-buffer DOC-ID-SIZE allot
: gen-doc-id ( -- addr )
  \ Simple counter-based ID for PoC
  1 doc-counter +!
  doc-id-buffer DOC-ID-SIZE 0 fill
  s" doc_" doc-id-buffer swap move
  doc-counter @ doc-id-buffer 4 + !
  doc-id-buffer ;

\ Insert document into collection
: insert-document ( coll-addr payload-addr payload-len -- doc-id | 0 )
  \ Validate collection exists
  over 0= if 2drop drop 0 exit then
  \ Allocate block for document
  alloc-block-id >r
  \ Initialize document block
  TYPE-DOCUMENT r@ init-block-header
  \ Set payload
  set-block-payload
  \ Create journal entry
  OP-DOC-INSERT r@ begin-journal-op
  \ TODO: Set forward/inverse/provenance payloads
  \ Write block
  r@ block-buffer write-block if
    \ Commit journal
    end-journal-op if
      \ Increment document count
      1 swap coll-doc-count +!
      gen-doc-id
    else
      0
    then
  else
    rollback-journal-op
    0
  then
  r> drop ;

\ Update document
: update-document ( doc-block-id field-addr field-len value-addr value-len -- flag )
  \ Read existing block
  4 pick block-buffer read-block 0= if 2drop 2drop drop false exit then
  \ Create journal entry with inverse (old values)
  OP-DOC-UPDATE 4 pick begin-journal-op
  \ TODO: Parse CBOR, update field, reserialize
  \ For now, just replace entire payload
  2drop  \ field
  set-block-payload
  \ Write block
  swap block-buffer write-block if
    end-journal-op
  else
    rollback-journal-op
    false
  then ;

\ Delete document
: delete-document ( coll-addr doc-block-id -- flag )
  \ Read block to capture for inverse
  dup block-buffer read-block 0= if 2drop false exit then
  \ Create journal entry
  OP-DOC-DELETE over begin-journal-op
  \ TODO: Set inverse payload with full document content
  \ Mark block as deleted
  free-block
  \ Update collection count
  swap -1 swap coll-doc-count +!
  end-journal-op ;

\ ============================================================
\ Edge Operations
\ ============================================================

\ Edge structure in payload:
\ - from_collection (64 bytes)
\ - from_id (16 bytes)
\ - to_collection (64 bytes)
\ - to_id (16 bytes)
\ - edge_type (64 bytes)
\ - properties (CBOR, variable)

224 constant EDGE-HEADER-SIZE

\ Create edge buffer
create edge-buffer PAYLOAD-SIZE allot

\ Build edge payload
: build-edge ( from-coll from-id to-coll to-id edge-type props-addr props-len -- addr len )
  edge-buffer PAYLOAD-SIZE 0 fill
  \ Copy edge type (at offset 160)
  >r >r
  edge-buffer 160 + 64 0 fill
  over edge-buffer 160 + swap move drop
  \ Copy to_id (at offset 144)
  edge-buffer 144 + 16 0 fill
  swap edge-buffer 144 + swap move drop
  \ Copy to_collection (at offset 80)
  edge-buffer 80 + 64 0 fill
  over edge-buffer 80 + swap move drop
  \ Copy from_id (at offset 64)
  edge-buffer 64 + 16 0 fill
  swap edge-buffer 64 + swap move drop
  \ Copy from_collection (at offset 0)
  edge-buffer 64 0 fill
  over edge-buffer swap move drop
  \ Copy properties
  r> r>
  edge-buffer EDGE-HEADER-SIZE + swap move
  edge-buffer EDGE-HEADER-SIZE + ;

\ Insert edge
: insert-edge ( edge-coll from-coll from-id to-coll to-id type props-addr props-len -- flag )
  \ Build edge payload
  build-edge
  \ Insert as document in edge collection
  rot insert-document
  0<> ;

\ ============================================================
\ Schema Operations
\ ============================================================

\ Schema structure:
\ - version (4 bytes)
\ - field_count (4 bytes)
\ - fields (variable: name + type + constraints)

\ Create schema
: create-schema ( coll-addr schema-payload-addr schema-len -- flag )
  \ Allocate block for schema
  alloc-block-id >r
  TYPE-SCHEMA r@ init-block-header
  set-block-payload
  \ Journal
  OP-SCHEMA-CREATE r@ begin-journal-op
  \ Write block
  r@ block-buffer write-block if
    \ Link schema to collection
    r> swap coll-schema-id !
    end-journal-op
  else
    r> drop drop
    rollback-journal-op
    false
  then ;

\ ============================================================
\ Query Support (Minimal)
\ ============================================================

\ Callback type for iteration
\ ( block-addr -- continue? )

\ Iterate all documents in collection
: foreach-document ( coll-addr xt -- )
  swap coll-block-id @  \ Get collection block ID
  \ TODO: Iterate through document chain
  \ For now, just a placeholder
  2drop ;

\ ============================================================
\ Canonical Rendering
\ ============================================================

\ Render collection info
: .collection ( coll-addr -- )
  ." Collection: " dup coll-name count type cr
  ."   type: " dup coll-type @ case
    CTYPE-DOCUMENT of ." document" endof
    CTYPE-EDGE of ." edge" endof
  endcase cr
  ."   documents: " dup coll-doc-count @ . cr
  ."   schema_id: " coll-schema-id @ . cr ;

\ List all collections
: .collections ( -- )
  ." Collections:" cr
  collection-list @
  begin
    dup 0<>
  while
    ."   " dup coll-name count type cr
    coll-next @
  repeat
  drop ;

\ ============================================================
\ Initialization
\ ============================================================

: init-model ( -- )
  0 collection-list !
  0 doc-counter ! ;

init-model
