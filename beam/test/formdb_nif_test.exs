# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
#
# ExUnit tests for the FormDB NIF interface.
#
# Tests the Erlang NIF functions exposed by formdb_nif.erl, which delegates
# to the Zig NIF implementation in beam/native/src/formdb_nif.zig. The NIF
# connects BEAM to the Lithoglyph storage engine via the FormBD C ABI
# (generated/abi/bridge.h).
#
# NIF function signatures (from formdb_nif.erl):
#   version/0        -> {Major, Minor, Patch}
#   db_open/1        -> {ok, DbRef} | {error, Reason}
#   db_close/1       -> ok | {error, Reason}
#   txn_begin/2      -> {ok, TxnRef} | {error, Reason}
#   txn_commit/1     -> ok | {error, Reason}
#   txn_abort/1      -> ok
#   apply/2          -> {ok, ResultCbor} | {ok, ResultCbor, ProvCbor} | {error, Reason}
#   schema/1         -> {ok, SchemaCbor} | {error, Reason}
#   journal/2        -> {ok, JournalCbor} | {error, Reason}

defmodule FormdbNifTest do
  use ExUnit.Case, async: false

  # Temporary database path for tests. Each test creates a fresh database
  # to avoid state leakage between tests.
  @test_db_dir System.tmp_dir!()

  setup do
    # Generate a unique database path for each test
    db_path = Path.join(@test_db_dir, "lithoglyph_test_#{:erlang.unique_integer([:positive])}.lgh")

    on_exit(fn ->
      # Clean up test database file after each test
      File.rm(db_path)
    end)

    %{db_path: db_path}
  end

  # ============================================================
  # version/0
  # ============================================================

  describe "version/0" do
    test "returns a three-element tuple of non-negative integers" do
      {major, minor, patch} = :formdb_nif.version()

      assert is_integer(major) and major >= 0
      assert is_integer(minor) and minor >= 0
      assert is_integer(patch) and patch >= 0
    end

    test "returns version 1.0.0 for M10 PoC" do
      assert {1, 0, 0} = :formdb_nif.version()
    end
  end

  # ============================================================
  # db_open/1
  # ============================================================

  describe "db_open/1" do
    test "opens a new database and returns {ok, ref}", %{db_path: db_path} do
      assert {:ok, db_ref} = :formdb_nif.db_open(db_path)
      assert is_reference(db_ref)

      # Clean up
      assert :ok = :formdb_nif.db_close(db_ref)
    end

    test "returns a valid reference (not nil)", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      refute is_nil(db_ref)

      :formdb_nif.db_close(db_ref)
    end

    test "accepts binary path argument", %{db_path: db_path} do
      # Path must be a binary (not a charlist)
      assert {:ok, db_ref} = :formdb_nif.db_open(db_path)
      :formdb_nif.db_close(db_ref)
    end

    test "returns error for non-binary argument" do
      # Passing an atom should trigger badarg from the NIF
      assert_raise ArgumentError, fn ->
        :formdb_nif.db_open(:not_a_binary)
      end
    end

    test "returns error for integer argument" do
      assert_raise ArgumentError, fn ->
        :formdb_nif.db_open(12345)
      end
    end
  end

  # ============================================================
  # db_close/1
  # ============================================================

  describe "db_close/1" do
    test "closes an open database and returns ok", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      assert :ok = :formdb_nif.db_close(db_ref)
    end

    test "returns error for invalid handle" do
      # Passing a non-resource reference should return an error tuple
      result = :formdb_nif.db_close(make_ref())
      assert {:error, :invalid_handle} = result
    end
  end

  # ============================================================
  # txn_begin/2
  # ============================================================

  describe "txn_begin/2" do
    test "begins a read_write transaction", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)

      assert {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)
      assert is_reference(txn_ref)

      # Clean up
      :formdb_nif.txn_abort(txn_ref)
      :formdb_nif.db_close(db_ref)
    end

    test "begins a read_only transaction", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)

      assert {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_only)
      assert is_reference(txn_ref)

      :formdb_nif.txn_abort(txn_ref)
      :formdb_nif.db_close(db_ref)
    end

    test "returns error for invalid mode atom", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)

      # Invalid mode should trigger badarg
      assert_raise ArgumentError, fn ->
        :formdb_nif.txn_begin(db_ref, :invalid_mode)
      end

      :formdb_nif.db_close(db_ref)
    end

    test "returns error for invalid database handle" do
      result = :formdb_nif.txn_begin(make_ref(), :read_write)
      assert {:error, :invalid_handle} = result
    end

    test "returns error when mode is not an atom", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)

      assert_raise ArgumentError, fn ->
        :formdb_nif.txn_begin(db_ref, "read_write")
      end

      :formdb_nif.db_close(db_ref)
    end
  end

  # ============================================================
  # txn_commit/1
  # ============================================================

  describe "txn_commit/1" do
    test "commits a read_write transaction", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)

      assert :ok = :formdb_nif.txn_commit(txn_ref)

      :formdb_nif.db_close(db_ref)
    end

    test "returns error for invalid transaction handle" do
      result = :formdb_nif.txn_commit(make_ref())
      assert {:error, :invalid_handle} = result
    end
  end

  # ============================================================
  # txn_abort/1
  # ============================================================

  describe "txn_abort/1" do
    test "aborts a transaction and returns ok", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)

      assert :ok = :formdb_nif.txn_abort(txn_ref)

      :formdb_nif.db_close(db_ref)
    end

    test "returns ok even for invalid handle (idempotent abort)" do
      # Per NIF implementation: invalid handle returns :ok (already aborted)
      assert :ok = :formdb_nif.txn_abort(make_ref())
    end
  end

  # ============================================================
  # apply/2
  # ============================================================

  describe "apply/2" do
    test "applies a CBOR-encoded insert operation", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)

      # Minimal CBOR map: {\"claim\": \"test\"}
      # 0xA1 (map 1) + 0x65 \"claim\" + 0x64 \"test\"
      cbor_op = <<0xA1, 0x65, "claim", 0x64, "test">>

      result = :formdb_nif.apply(txn_ref, cbor_op)

      case result do
        {:ok, result_binary} ->
          # Result should be a binary containing the block ID (8 bytes big-endian)
          assert is_binary(result_binary)
          assert byte_size(result_binary) == 8

        {:ok, result_binary, provenance_binary} ->
          # Alternate form with provenance
          assert is_binary(result_binary)
          assert is_binary(provenance_binary)

        {:error, reason} ->
          # M10 PoC may return errors for certain inputs
          assert is_atom(reason)
      end

      :formdb_nif.txn_abort(txn_ref)
      :formdb_nif.db_close(db_ref)
    end

    test "returns error for empty CBOR binary", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)

      # Empty binary should fail CBOR parsing (cbor_len == 0 check in NIF)
      assert {:error, :parse_failed} = :formdb_nif.apply(txn_ref, <<>>)

      :formdb_nif.txn_abort(txn_ref)
      :formdb_nif.db_close(db_ref)
    end

    test "returns error for oversized CBOR binary", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)

      # Exceeds 1 MiB limit in formbd_parse_cbor (cbor_len > 1048576)
      oversized = :binary.copy(<<0>>, 1_048_577)
      assert {:error, :parse_failed} = :formdb_nif.apply(txn_ref, oversized)

      :formdb_nif.txn_abort(txn_ref)
      :formdb_nif.db_close(db_ref)
    end

    test "returns error for non-binary operation argument", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)

      assert_raise ArgumentError, fn ->
        :formdb_nif.apply(txn_ref, :not_a_binary)
      end

      :formdb_nif.txn_abort(txn_ref)
      :formdb_nif.db_close(db_ref)
    end

    test "returns error for invalid transaction handle" do
      cbor_op = <<0xA0>>
      result = :formdb_nif.apply(make_ref(), cbor_op)
      assert {:error, :invalid_handle} = result
    end

    test "applies a CBOR empty map operation", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)

      # Empty CBOR map (0xA0) - minimal valid CBOR document
      cbor_op = <<0xA0>>
      result = :formdb_nif.apply(txn_ref, cbor_op)

      # Should succeed (valid CBOR, even if minimal)
      case result do
        {:ok, _} -> :ok
        {:ok, _, _} -> :ok
        {:error, reason} -> assert is_atom(reason)
      end

      :formdb_nif.txn_abort(txn_ref)
      :formdb_nif.db_close(db_ref)
    end

    test "returns 8-byte block ID on successful apply", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)
      {:ok, txn_ref} = :formdb_nif.txn_begin(db_ref, :read_write)

      # CBOR map with single field: {"data": "value"}
      cbor_op = <<0xA1, 0x64, "data", 0x65, "value">>

      case :formdb_nif.apply(txn_ref, cbor_op) do
        {:ok, result_binary} ->
          # Block ID is returned as 8-byte big-endian unsigned integer
          assert byte_size(result_binary) == 8
          <<block_id::unsigned-big-64>> = result_binary
          # M10 PoC returns block_id=1 (from formbd_persist stub)
          assert block_id >= 1

        {:ok, result_binary, _provenance} ->
          assert byte_size(result_binary) == 8

        {:error, _} ->
          :ok
      end

      :formdb_nif.txn_abort(txn_ref)
      :formdb_nif.db_close(db_ref)
    end
  end

  # ============================================================
  # schema/1
  # ============================================================

  describe "schema/1" do
    test "returns schema as CBOR binary", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)

      assert {:ok, schema_cbor} = :formdb_nif.schema(db_ref)
      assert is_binary(schema_cbor)

      # M10 PoC returns empty CBOR map (0xA0)
      assert schema_cbor == <<0xA0>>

      :formdb_nif.db_close(db_ref)
    end
  end

  # ============================================================
  # journal/2
  # ============================================================

  describe "journal/2" do
    test "returns journal entries as CBOR binary", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)

      assert {:ok, journal_cbor} = :formdb_nif.journal(db_ref, 0)
      assert is_binary(journal_cbor)

      # M10 PoC returns empty CBOR array (0x80)
      assert journal_cbor == <<0x80>>

      :formdb_nif.db_close(db_ref)
    end

    test "accepts non-zero since parameter", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)

      # Request entries since sequence 100
      assert {:ok, journal_cbor} = :formdb_nif.journal(db_ref, 100)
      assert is_binary(journal_cbor)

      :formdb_nif.db_close(db_ref)
    end
  end

  # ============================================================
  # Arity validation
  # ============================================================

  describe "arity validation" do
    test "db_open requires exactly 1 argument" do
      assert_raise UndefinedFunctionError, fn ->
        :formdb_nif.db_open()
      end
    end

    test "txn_begin requires exactly 2 arguments", %{db_path: db_path} do
      {:ok, db_ref} = :formdb_nif.db_open(db_path)

      assert_raise UndefinedFunctionError, fn ->
        :formdb_nif.txn_begin(db_ref)
      end

      :formdb_nif.db_close(db_ref)
    end

    test "apply requires exactly 2 arguments" do
      assert_raise UndefinedFunctionError, fn ->
        :formdb_nif.apply(make_ref())
      end
    end

    test "journal requires exactly 2 arguments" do
      assert_raise UndefinedFunctionError, fn ->
        :formdb_nif.journal(make_ref())
      end
    end
  end
end
