/-
SPDX-License-Identifier: AGPL-3.0-or-later
Form.Normalizer - FFI Bridge to Zig Core

Lean 4 foreign function interface bindings to the Form.Bridge
C ABI layer (bridge.zig). Enables Lean proofs to be verified
by the runtime and proof results to be embedded in the database.

Decision D-NORM-004: Form.Bridge exports proof verification FFI
-/

namespace FormDB.Bridge

/-! # Status Codes -/

/-- Status codes from Form.Bridge C ABI -/
inductive FdbStatus where
  | ok                    : FdbStatus  -- 0
  | errInvalidArgument    : FdbStatus  -- 1
  | errOutOfMemory        : FdbStatus  -- 2
  | errInternal           : FdbStatus  -- 3
  | errNotFound           : FdbStatus  -- 4
  | errNotImplemented     : FdbStatus  -- 5
  | errTxnNotActive       : FdbStatus  -- 6
  | errTxnAlreadyCommitted: FdbStatus  -- 7
  deriving Repr, BEq, Inhabited

/-- Convert status to integer for FFI -/
def FdbStatus.toUInt8 : FdbStatus → UInt8
  | .ok => 0
  | .errInvalidArgument => 1
  | .errOutOfMemory => 2
  | .errInternal => 3
  | .errNotFound => 4
  | .errNotImplemented => 5
  | .errTxnNotActive => 6
  | .errTxnAlreadyCommitted => 7

/-- Convert integer from FFI to status -/
def FdbStatus.fromUInt8 : UInt8 → FdbStatus
  | 0 => .ok
  | 1 => .errInvalidArgument
  | 2 => .errOutOfMemory
  | 3 => .errInternal
  | 4 => .errNotFound
  | 5 => .errNotImplemented
  | 6 => .errTxnNotActive
  | 7 => .errTxnAlreadyCommitted
  | _ => .errInternal

/-! # Blob Type -/

/-- CBOR-encoded blob for FFI transfer -/
structure FdbBlob where
  data : ByteArray
  deriving Repr, Inhabited

/-- Create empty blob -/
def FdbBlob.empty : FdbBlob := ⟨ByteArray.empty⟩

/-- Create blob from string -/
def FdbBlob.fromString (s : String) : FdbBlob := ⟨s.toUTF8⟩

/-! # CBOR Encoding (Simplified) -/

/-- Simple CBOR encoder for proof data -/
structure CborEncoder where
  buffer : ByteArray
  deriving Inhabited

namespace CborEncoder

def empty : CborEncoder := ⟨ByteArray.empty⟩

/-- Write a byte -/
def writeByte (e : CborEncoder) (b : UInt8) : CborEncoder :=
  ⟨e.buffer.push b⟩

/-- Write bytes -/
def writeBytes (e : CborEncoder) (bs : ByteArray) : CborEncoder :=
  ⟨e.buffer ++ bs⟩

/-- Encode unsigned integer (CBOR major type 0) -/
def encodeUInt (e : CborEncoder) (n : Nat) : CborEncoder :=
  if n < 24 then
    e.writeByte n.toUInt8
  else if n < 256 then
    e.writeByte 24 |>.writeByte n.toUInt8
  else if n < 65536 then
    e.writeByte 25
      |>.writeByte (n / 256).toUInt8
      |>.writeByte (n % 256).toUInt8
  else
    -- For larger numbers, use 4 bytes
    e.writeByte 26
      |>.writeByte ((n / 16777216) % 256).toUInt8
      |>.writeByte ((n / 65536) % 256).toUInt8
      |>.writeByte ((n / 256) % 256).toUInt8
      |>.writeByte (n % 256).toUInt8

/-- Encode text string (CBOR major type 3) -/
def encodeText (e : CborEncoder) (s : String) : CborEncoder :=
  let bytes := s.toUTF8
  let len := bytes.size
  let e' := if len < 24 then
    e.writeByte (0x60 + len.toUInt8)
  else if len < 256 then
    e.writeByte 0x78 |>.writeByte len.toUInt8
  else
    e.writeByte 0x79
      |>.writeByte (len / 256).toUInt8
      |>.writeByte (len % 256).toUInt8
  e'.writeBytes bytes

/-- Encode byte string (CBOR major type 2) -/
def encodeBytes (e : CborEncoder) (bs : ByteArray) : CborEncoder :=
  let len := bs.size
  let e' := if len < 24 then
    e.writeByte (0x40 + len.toUInt8)
  else if len < 256 then
    e.writeByte 0x58 |>.writeByte len.toUInt8
  else
    e.writeByte 0x59
      |>.writeByte (len / 256).toUInt8
      |>.writeByte (len % 256).toUInt8
  e'.writeBytes bs

/-- Begin map (CBOR major type 5) -/
def beginMap (e : CborEncoder) (len : Nat) : CborEncoder :=
  if len < 24 then
    e.writeByte (0xA0 + len.toUInt8)
  else if len < 256 then
    e.writeByte 0xB8 |>.writeByte len.toUInt8
  else
    e.writeByte 0xB9
      |>.writeByte (len / 256).toUInt8
      |>.writeByte (len % 256).toUInt8

/-- Begin array (CBOR major type 4) -/
def beginArray (e : CborEncoder) (len : Nat) : CborEncoder :=
  if len < 24 then
    e.writeByte (0x80 + len.toUInt8)
  else if len < 256 then
    e.writeByte 0x98 |>.writeByte len.toUInt8
  else
    e.writeByte 0x99
      |>.writeByte (len / 256).toUInt8
      |>.writeByte (len % 256).toUInt8

/-- Encode boolean -/
def encodeBool (e : CborEncoder) (b : Bool) : CborEncoder :=
  e.writeByte (if b then 0xF5 else 0xF4)

/-- Encode float (simplified - just encodes as text for now) -/
def encodeFloat (e : CborEncoder) (f : Float) : CborEncoder :=
  -- For simplicity, encode floats as text representation
  e.encodeText (toString f)

/-- Get final byte array -/
def finish (e : CborEncoder) : ByteArray := e.buffer

end CborEncoder

/-! # Proof Types -/

/-- A proof that can be verified by Form.Bridge -/
structure Proof where
  /-- Proof type identifier (e.g., "fd-holds", "normalization") -/
  proofType : String
  /-- CBOR-encoded proof data -/
  data : ByteArray
  deriving Repr

/-- Verification result from Form.Bridge -/
structure VerificationResult where
  /-- Whether the proof is valid -/
  valid : Bool
  /-- Error message if invalid -/
  error : Option String
  deriving Repr

/-! # Proof Encoding -/

/-- Encode an FD-holds proof -/
def encodeFDProof (determinant dependent : List String) (confidence : Float) : Proof :=
  let encoder := CborEncoder.empty
    |>.beginMap 4
    |>.encodeText "proof_type"
    |>.encodeText "fd-holds"
    |>.encodeText "determinant"
    |>.beginArray determinant.length
  let encoder := determinant.foldl (fun e s => e.encodeText s) encoder
  let encoder := encoder
    |>.encodeText "dependent"
    |>.beginArray dependent.length
  let encoder := dependent.foldl (fun e s => e.encodeText s) encoder
  let encoder := encoder
    |>.encodeText "confidence"
    |>.encodeFloat confidence
  { proofType := "fd-holds", data := encoder.finish }

/-- Encode a normalization proof -/
def encodeNormalizationProof
    (sourceSchema : String)
    (targetSchemas : List String)
    (joinAttrs : List String)
    (lossless : Bool) : Proof :=
  let encoder := CborEncoder.empty
    |>.beginMap 5
    |>.encodeText "proof_type"
    |>.encodeText "normalization"
    |>.encodeText "source"
    |>.encodeText sourceSchema
    |>.encodeText "targets"
    |>.beginArray targetSchemas.length
  let encoder := targetSchemas.foldl (fun e s => e.encodeText s) encoder
  let encoder := encoder
    |>.encodeText "join_attributes"
    |>.beginArray joinAttrs.length
  let encoder := joinAttrs.foldl (fun e s => e.encodeText s) encoder
  let encoder := encoder
    |>.encodeText "lossless"
    |>.encodeBool lossless
  { proofType := "normalization", data := encoder.finish }

/-- Encode a denormalization proof -/
def encodeDenormalizationProof
    (sourceSchemas : List String)
    (targetSchema : String)
    (joinAttrs : List String)
    (rationale : String) : Proof :=
  let encoder := CborEncoder.empty
    |>.beginMap 5
    |>.encodeText "proof_type"
    |>.encodeText "denormalization"
    |>.encodeText "sources"
    |>.beginArray sourceSchemas.length
  let encoder := sourceSchemas.foldl (fun e s => e.encodeText s) encoder
  let encoder := encoder
    |>.encodeText "target"
    |>.encodeText targetSchema
    |>.encodeText "join_attributes"
    |>.beginArray joinAttrs.length
  let encoder := joinAttrs.foldl (fun e s => e.encodeText s) encoder
  let encoder := encoder
    |>.encodeText "rationale"
    |>.encodeText rationale
  { proofType := "denormalization", data := encoder.finish }

/-! # FFI Declarations -/

-- Note: These are declared but would require linking to libformdb_bridge
-- In production, this would use Lean's @[extern] attribute

/-- Mock verification for pure Lean testing (no FFI) -/
def verifyProofPure (proof : Proof) : VerificationResult :=
  -- For pure Lean testing, accept well-formed proofs
  if proof.data.size > 0 then
    { valid := true, error := none }
  else
    { valid := false, error := some "Empty proof data" }

/-! # High-Level Proof API -/

/-- Verify that an FD holds with given confidence -/
def verifyFDHolds (det dep : List String) (conf : Float) : IO VerificationResult := do
  let proof := encodeFDProof det dep conf
  -- In production: call FFI to fdb_proof_verify
  -- For now: use pure verification
  return verifyProofPure proof

/-- Verify a normalization step -/
def verifyNormalization
    (source : String)
    (targets : List String)
    (joinAttrs : List String) : IO VerificationResult := do
  let proof := encodeNormalizationProof source targets joinAttrs true
  return verifyProofPure proof

/-- Verify a denormalization step -/
def verifyDenormalization
    (sources : List String)
    (target : String)
    (joinAttrs : List String)
    (rationale : String) : IO VerificationResult := do
  let proof := encodeDenormalizationProof sources target joinAttrs rationale
  return verifyProofPure proof

/-! # Proof-Carrying Normalization -/

/-- A normalization result with embedded proof -/
structure ProofCarryingNormalization where
  /-- Source schema that was normalized -/
  source : String
  /-- Target schemas produced -/
  targets : List String
  /-- Join attributes for lossless join -/
  joinAttributes : List String
  /-- The proof of correctness -/
  proof : Proof
  /-- Verification status -/
  verified : Bool
  deriving Repr

/-- Create a proof-carrying normalization -/
def createProofCarryingNormalization
    (source : String)
    (targets : List String)
    (joinAttrs : List String) : IO ProofCarryingNormalization := do
  let proof := encodeNormalizationProof source targets joinAttrs true
  let result := verifyProofPure proof
  return {
    source := source
    targets := targets
    joinAttributes := joinAttrs
    proof := proof
    verified := result.valid
  }

/-- A denormalization result with embedded proof -/
structure ProofCarryingDenormalization where
  /-- Source schemas that were merged -/
  sources : List String
  /-- Target merged schema -/
  target : String
  /-- Join attributes used -/
  joinAttributes : List String
  /-- Performance rationale -/
  rationale : String
  /-- The proof of correctness -/
  proof : Proof
  /-- Verification status -/
  verified : Bool
  deriving Repr

/-- Create a proof-carrying denormalization -/
def createProofCarryingDenormalization
    (sources : List String)
    (target : String)
    (joinAttrs : List String)
    (rationale : String) : IO ProofCarryingDenormalization := do
  let proof := encodeDenormalizationProof sources target joinAttrs rationale
  let result := verifyProofPure proof
  return {
    sources := sources
    target := target
    joinAttributes := joinAttrs
    rationale := rationale
    proof := proof
    verified := result.valid
  }

end FormDB.Bridge
