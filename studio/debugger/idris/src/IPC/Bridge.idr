-- SPDX-License-Identifier: PMPL-1.0-or-later
||| IPC Bridge - Communication with the Rust CLI backend
module IPC.Bridge

import System
import System.File
import Data.List
import Data.String
import REPL.Core

||| Result of an IPC call
public export
data IPCResult a
  = IPCSuccess a
  | IPCError String
  | IPCParseError String

public export
Functor IPCResult where
  map f (IPCSuccess x) = IPCSuccess (f x)
  map _ (IPCError e) = IPCError e
  map _ (IPCParseError e) = IPCParseError e

||| Path to the fdb-debug CLI binary
||| This should be configurable in production
cliBinary : String
cliBinary = "fdb-debug"

||| Execute a CLI command and capture output
||| Uses popen to run the command and read stdout
execCli : List String -> IO (Either String String)
execCli args = do
  let cmd = cliBinary ++ " " ++ unwords args
  Right h <- popen cmd Read
    | Left _ => pure (Left "Failed to spawn process")
  output <- readAll h
  pclose h
  pure (Right output)
  where
    readAll : File -> IO String
    readAll h = do
      Right line <- fGetLine h
        | Left _ => pure ""
      rest <- readAll h
      pure (line ++ rest)

||| Simple JSON string extraction
||| Extracts the value for a given key from a JSON object string
||| This is a minimal parser for our specific schema format
extractJsonString : String -> String -> Maybe String
extractJsonString key json =
  let pattern = "\"" ++ key ++ "\":"
  in case findSubstring pattern json of
    Nothing => Nothing
    Just idx =>
      let afterKey = substr (idx + length pattern) (length json) json
          trimmed = ltrim afterKey
      in if isPrefixOf "\"" trimmed
         then extractQuoted (strTail trimmed)
         else Nothing
  where
    findSubstring : String -> String -> Maybe Nat
    findSubstring needle haystack = findIdx 0 (unpack haystack)
      where
        needleChars : List Char
        needleChars = unpack needle

        matchAt : List Char -> Bool
        matchAt [] = True
        matchAt xs = isPrefixOf needleChars xs

        findIdx : Nat -> List Char -> Maybe Nat
        findIdx _ [] = Nothing
        findIdx n xs = if matchAt xs then Just n else findIdx (S n) (drop 1 xs)

    extractQuoted : String -> Maybe String
    extractQuoted s = extractUntilQuote (unpack s) []
      where
        extractUntilQuote : List Char -> List Char -> Maybe String
        extractUntilQuote [] _ = Nothing
        extractUntilQuote ('"' :: _) acc = Just (pack (reverse acc))
        extractUntilQuote ('\\' :: c :: rest) acc = extractUntilQuote rest (c :: acc)
        extractUntilQuote (c :: rest) acc = extractUntilQuote rest (c :: acc)

||| Extract a JSON boolean
extractJsonBool : String -> String -> Maybe Bool
extractJsonBool key json =
  let pattern = "\"" ++ key ++ "\":"
  in case findSubstring pattern json of
    Nothing => Nothing
    Just idx =>
      let afterKey = substr (idx + length pattern) (length json) json
          trimmed = ltrim afterKey
      in if isPrefixOf "true" trimmed then Just True
         else if isPrefixOf "false" trimmed then Just False
         else Nothing
  where
    findSubstring : String -> String -> Maybe Nat
    findSubstring needle haystack = findIdx 0 (unpack haystack)
      where
        needleChars : List Char
        needleChars = unpack needle

        matchAt : List Char -> Bool
        matchAt [] = True
        matchAt xs = isPrefixOf needleChars xs

        findIdx : Nat -> List Char -> Maybe Nat
        findIdx _ [] = Nothing
        findIdx n xs = if matchAt xs then Just n else findIdx (S n) (drop 1 xs)

||| Extract JSON array of strings
extractJsonStringArray : String -> String -> Maybe (List String)
extractJsonStringArray key json =
  let pattern = "\"" ++ key ++ "\":"
  in case findSubstring pattern json of
    Nothing => Nothing
    Just idx =>
      let afterKey = substr (idx + length pattern) (length json) json
          trimmed = ltrim afterKey
      in if isPrefixOf "[" trimmed
         then Just (parseArray (strTail trimmed))
         else Nothing
  where
    findSubstring : String -> String -> Maybe Nat
    findSubstring needle haystack = findIdx 0 (unpack haystack)
      where
        needleChars : List Char
        needleChars = unpack needle

        matchAt : List Char -> Bool
        matchAt [] = True
        matchAt xs = isPrefixOf needleChars xs

        findIdx : Nat -> List Char -> Maybe Nat
        findIdx _ [] = Nothing
        findIdx n xs = if matchAt xs then Just n else findIdx (S n) (drop 1 xs)

    parseArray : String -> List String
    parseArray s = parseArrayInner (unpack (ltrim s)) []
      where
        parseArrayInner : List Char -> List String -> List String
        parseArrayInner [] acc = reverse acc
        parseArrayInner (']' :: _) acc = reverse acc
        parseArrayInner ('"' :: rest) acc =
          let (item, remainder) = extractItem rest []
          in parseArrayInner remainder (item :: acc)
        parseArrayInner (_ :: rest) acc = parseArrayInner rest acc

        extractItem : List Char -> List Char -> (String, List Char)
        extractItem [] acc = (pack (reverse acc), [])
        extractItem ('"' :: rest) acc = (pack (reverse acc), rest)
        extractItem ('\\' :: c :: rest) acc = extractItem rest (c :: acc)
        extractItem (c :: rest) acc = extractItem rest (c :: acc)

||| Parse a column from JSON object string
parseColumn : String -> Maybe Column
parseColumn json = do
  name <- extractJsonString "name" json
  dtype <- extractJsonString "data_type" json
  nullable <- extractJsonBool "nullable" json
  pure $ MkColumn name (parseDataType dtype) nullable
  where
    parseDataType : String -> DataType
    parseDataType "integer" = DInt
    parseDataType "bigint" = DInt
    parseDataType "smallint" = DInt
    parseDataType "text" = DText
    parseDataType "varchar" = DText
    parseDataType "character varying" = DText
    parseDataType "boolean" = DBool
    parseDataType "timestamp" = DTimestamp
    parseDataType "timestamp with time zone" = DTimestamp
    parseDataType "timestamp without time zone" = DTimestamp
    parseDataType "uuid" = DUUID
    parseDataType "json" = DJson
    parseDataType "jsonb" = DJson
    parseDataType "bytea" = DBytes
    parseDataType _ = DText  -- Default to text for unknown types

||| Parse a table from JSON object string
parseTable : String -> Maybe Table
parseTable json = do
  name <- extractJsonString "name" json
  schemaName <- extractJsonString "schema_name" json <|> Just "public"
  primaryKey <- extractJsonStringArray "primary_key" json <|> Just []
  -- Columns would need more complex parsing
  pure $ MkTable schemaName name [] primaryKey

||| Parse constraint type from string
parseConstraintType : String -> ConstraintType
parseConstraintType "PrimaryKey" = CPrimaryKey
parseConstraintType "ForeignKey" = CForeignKey
parseConstraintType "Unique" = CUnique
parseConstraintType "Check" = CCheck
parseConstraintType "NotNull" = CNotNull
parseConstraintType _ = CCheck

||| Parse a constraint from JSON object string
parseConstraint : String -> Maybe Constraint
parseConstraint json = do
  name <- extractJsonString "name" json
  ctype <- extractJsonString "constraint_type" json
  tableName <- extractJsonString "table_name" json
  columns <- extractJsonStringArray "columns" json <|> Just []
  let foreignTable = extractJsonString "foreign_table" json
  let foreignColumns = extractJsonStringArray "foreign_columns" json
  pure $ MkConstraint name (parseConstraintType ctype) tableName columns foreignTable foreignColumns

||| Parse a functional dependency from JSON
parseFD : String -> Maybe FunctionalDep
parseFD json = do
  tableName <- extractJsonString "table_name" json
  determinant <- extractJsonStringArray "determinant" json <|> Just []
  dependent <- extractJsonStringArray "dependent" json <|> Just []
  -- confidence <- parse number (not implemented, default to 1.0)
  pure $ MkFD tableName determinant dependent 1.0

||| Connect to database and fetch schema
||| Calls: fdb-debug schema -c <connection_string>
export
fetchSchema : String -> IO (IPCResult Schema)
fetchSchema connStr = do
  result <- execCli ["schema", "-c", "\"" ++ connStr ++ "\""]
  case result of
    Left err => pure (IPCError err)
    Right output =>
      case extractJsonBool "success" output of
        Just True =>
          case extractJsonString "database_name" output of
            Just dbName => pure $ IPCSuccess $ MkSchema dbName [] [] []
            Nothing => pure (IPCParseError "Missing database_name in response")
        Just False =>
          case extractJsonString "error" output of
            Just errMsg => pure (IPCError errMsg)
            Nothing => pure (IPCError "Unknown error from backend")
        Nothing => pure (IPCParseError $ "Failed to parse response: " ++ take 200 output)

||| Ping database connection
||| Calls: fdb-debug ping -c <connection_string>
export
pingDatabase : String -> IO (IPCResult ())
pingDatabase connStr = do
  result <- execCli ["ping", "-c", "\"" ++ connStr ++ "\""]
  case result of
    Left err => pure (IPCError err)
    Right output =>
      case extractJsonBool "success" output of
        Just True => pure (IPCSuccess ())
        Just False =>
          case extractJsonString "error" output of
            Just errMsg => pure (IPCError errMsg)
            Nothing => pure (IPCError "Connection failed")
        Nothing => pure (IPCParseError "Failed to parse response")

||| Show IPC result for debugging
export
showIPCResult : Show a => IPCResult a -> String
showIPCResult (IPCSuccess x) = "Success: " ++ show x
showIPCResult (IPCError e) = "Error: " ++ e
showIPCResult (IPCParseError e) = "Parse Error: " ++ e
