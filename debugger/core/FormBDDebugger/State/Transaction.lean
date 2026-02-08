-- SPDX-License-Identifier: AGPL-3.0-or-later
import FormBDDebugger.State.Delta

/-!
# Database Transactions

Transaction types for tracking database operations.
-/

namespace FormBDDebugger.State

/-- Transaction isolation level -/
inductive IsolationLevel where
  | readUncommitted : IsolationLevel
  | readCommitted : IsolationLevel
  | repeatableRead : IsolationLevel
  | serializable : IsolationLevel
  deriving Repr, DecidableEq

/-- Transaction state -/
inductive TransactionState where
  | active : TransactionState
  | committed : TransactionState
  | rolledBack : TransactionState
  | failed : String → TransactionState  -- Error message
  deriving Repr

/-- A database transaction -/
structure Transaction where
  id : String           -- Transaction ID (hex string)
  startTime : Timestamp
  endTime : Option Timestamp
  isolation : IsolationLevel
  state : TransactionState
  deltas : List Delta   -- Changes within this transaction
  actor : String
  deriving Repr

/-- Check if a transaction is still active -/
def Transaction.isActive (t : Transaction) : Bool :=
  match t.state with
  | TransactionState.active => true
  | _ => false

/-- Check if a transaction succeeded -/
def Transaction.isCommitted (t : Transaction) : Bool :=
  match t.state with
  | TransactionState.committed => true
  | _ => false

/-- Get the total number of changes in a transaction -/
def Transaction.changeCount (t : Transaction) : Nat :=
  t.deltas.foldl (fun acc d => acc + d.changes.length) 0

/-- A transaction log (history of transactions) -/
structure TransactionLog where
  transactions : List Transaction
  deriving Repr

/-- Get transactions in a time range -/
def TransactionLog.inRange (log : TransactionLog) (start finish : Timestamp)
    : List Transaction :=
  log.transactions.filter (fun t => t.startTime >= start && t.startTime <= finish)

end FormBDDebugger.State
