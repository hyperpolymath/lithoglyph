-- SPDX-License-Identifier: PMPL-1.0-or-later
||| REPL Core - Interactive debugging session state and types
module REPL.Core

import Data.List
import Data.Maybe
import Data.String
import System
import System.File

||| Database column data types (matching PostgreSQL types)
public export
data DataType = DInt | DText | DBool | DTimestamp | DUUID | DJson | DBytes

public export
Show DataType where
  show DInt = "integer"
  show DText = "text"
  show DBool = "boolean"
  show DTimestamp = "timestamp"
  show DUUID = "uuid"
  show DJson = "jsonb"
  show DBytes = "bytea"

||| A database column
public export
record Column where
  constructor MkColumn
  name : String
  dtype : DataType
  nullable : Bool

public export
Show Column where
  show col = col.name ++ " " ++ show col.dtype ++
             (if col.nullable then " NULL" else " NOT NULL")

||| A database table
public export
record Table where
  constructor MkTable
  schemaName : String
  name : String
  columns : List Column
  primaryKey : List String

public export
Show Table where
  show t = t.schemaName ++ "." ++ t.name ++
           " (" ++ show (length t.columns) ++ " columns)"

||| Constraint types
public export
data ConstraintType
  = CPrimaryKey
  | CForeignKey
  | CUnique
  | CCheck
  | CNotNull

public export
Show ConstraintType where
  show CPrimaryKey = "PRIMARY KEY"
  show CForeignKey = "FOREIGN KEY"
  show CUnique = "UNIQUE"
  show CCheck = "CHECK"
  show CNotNull = "NOT NULL"

||| A database constraint
public export
record Constraint where
  constructor MkConstraint
  name : String
  ctype : ConstraintType
  tableName : String
  columns : List String
  foreignTable : Maybe String
  foreignColumns : Maybe (List String)

public export
Show Constraint where
  show c = c.name ++ " " ++ show c.ctype ++ " on " ++ c.tableName ++
           " (" ++ joinBy ", " c.columns ++ ")"

||| A functional dependency X -> Y
public export
record FunctionalDep where
  constructor MkFD
  tableName : String
  determinant : List String  -- X (left side)
  dependent : List String    -- Y (right side)
  confidence : Double

public export
Show FunctionalDep where
  show fd = fd.tableName ++ ": {" ++ joinBy ", " fd.determinant ++ "} -> {" ++
            joinBy ", " fd.dependent ++ "}" ++
            (if fd.confidence < 1.0
             then " [confidence: " ++ show fd.confidence ++ "]"
             else "")

||| A database schema containing tables, constraints, and FDs
public export
record Schema where
  constructor MkSchema
  databaseName : String
  tables : List Table
  constraints : List Constraint
  functionalDeps : List FunctionalDep

||| Debug session state
public export
record DebugState where
  constructor MkDebugState
  connected : Bool
  connectionUri : Maybe String
  schema : Maybe Schema
  currentTable : Maybe String
  history : List String
  snapshotTime : Maybe String

||| Initial state with no connection
public export
initialState : DebugState
initialState = MkDebugState False Nothing Nothing Nothing [] Nothing

||| Find a table by name in schema
public export
findTable : Schema -> String -> Maybe Table
findTable s tableName = find (\t => t.name == tableName) s.tables

||| Get all constraints for a specific table
public export
tableConstraints : Schema -> String -> List Constraint
tableConstraints s tableName = filter (\c => c.tableName == tableName) s.constraints

||| Get all functional dependencies for a specific table
public export
tableFDs : Schema -> String -> List FunctionalDep
tableFDs s tableName = filter (\fd => fd.tableName == tableName) s.functionalDeps

||| Sample schema for demonstration (would be loaded from database)
public export
sampleSchema : Schema
sampleSchema = MkSchema "lithoglyph_demo"
  [ MkTable "public" "authors"
      [ MkColumn "id" DUUID False
      , MkColumn "name" DText False
      , MkColumn "email" DText True
      , MkColumn "created_at" DTimestamp False
      ]
      ["id"]
  , MkTable "public" "articles"
      [ MkColumn "id" DUUID False
      , MkColumn "title" DText False
      , MkColumn "author_id" DUUID False
      , MkColumn "content" DText True
      , MkColumn "published_at" DTimestamp True
      ]
      ["id"]
  , MkTable "public" "evidence"
      [ MkColumn "id" DUUID False
      , MkColumn "article_id" DUUID False
      , MkColumn "source_url" DText False
      , MkColumn "prompt_score" DInt False
      , MkColumn "verified_at" DTimestamp True
      ]
      ["id"]
  ]
  [ MkConstraint "pk_authors" CPrimaryKey "authors" ["id"] Nothing Nothing
  , MkConstraint "pk_articles" CPrimaryKey "articles" ["id"] Nothing Nothing
  , MkConstraint "fk_articles_author" CForeignKey "articles" ["author_id"]
      (Just "authors") (Just ["id"])
  , MkConstraint "pk_evidence" CPrimaryKey "evidence" ["id"] Nothing Nothing
  , MkConstraint "fk_evidence_article" CForeignKey "evidence" ["article_id"]
      (Just "articles") (Just ["id"])
  , MkConstraint "chk_prompt_score" CCheck "evidence" ["prompt_score"] Nothing Nothing
  ]
  [ MkFD "authors" ["id"] ["name", "email", "created_at"] 1.0
  , MkFD "articles" ["id"] ["title", "author_id", "content", "published_at"] 1.0
  , MkFD "evidence" ["id"] ["article_id", "source_url", "prompt_score", "verified_at"] 1.0
  , MkFD "evidence" ["article_id", "source_url"] ["prompt_score"] 0.95
  ]

-- =============================================================================
-- Simple JSON parsing for schema format
-- =============================================================================

||| Extract a quoted string value after a key
extractJsonValue : String -> String -> Maybe String
extractJsonValue key json =
  let pattern = "\"" ++ key ++ "\":"
      chars = unpack json
  in findAndExtract (unpack pattern) chars
  where
    -- Check if list starts with pattern
    startsWith : List Char -> List Char -> Bool
    startsWith [] _ = True
    startsWith _ [] = False
    startsWith (p :: ps) (c :: cs) = p == c && startsWith ps cs

    -- Skip whitespace
    skipWs : List Char -> List Char
    skipWs [] = []
    skipWs (c :: cs) = if c == ' ' || c == '\n' || c == '\t' then skipWs cs else (c :: cs)

    takeUntilQuote : List Char -> List Char -> List Char
    takeUntilQuote [] acc = reverse acc
    takeUntilQuote ('"' :: _) acc = reverse acc
    takeUntilQuote ('\\' :: c :: rest) acc = takeUntilQuote rest (c :: acc)
    takeUntilQuote (c :: rest) acc = takeUntilQuote rest (c :: acc)

    -- Extract a string value (assumes starts after "key":)
    extractValue : List Char -> Maybe String
    extractValue chars =
      case skipWs chars of
        ('"' :: rest) => Just (pack (takeUntilQuote rest []))
        _ => Nothing

    -- Find pattern and extract value after it
    findAndExtract : List Char -> List Char -> Maybe String
    findAndExtract _ [] = Nothing
    findAndExtract pat (c :: cs) =
      if startsWith pat (c :: cs)
        then extractValue (drop (length pat) (c :: cs))
        else findAndExtract pat cs

||| Extract a boolean value
extractJsonBool : String -> String -> Maybe Bool
extractJsonBool key json =
  let pattern = "\"" ++ key ++ "\":"
      chars = unpack json
  in findAndExtractBool (unpack pattern) chars
  where
    startsWith : List Char -> List Char -> Bool
    startsWith [] _ = True
    startsWith _ [] = False
    startsWith (p :: ps) (c :: cs) = p == c && startsWith ps cs

    skipWs : List Char -> List Char
    skipWs [] = []
    skipWs (c :: cs) = if c == ' ' || c == '\n' || c == '\t' then skipWs cs else (c :: cs)

    extractBoolValue : List Char -> Maybe Bool
    extractBoolValue chars =
      case skipWs chars of
        ('t' :: 'r' :: 'u' :: 'e' :: _) => Just True
        ('f' :: 'a' :: 'l' :: 's' :: 'e' :: _) => Just False
        _ => Nothing

    findAndExtractBool : List Char -> List Char -> Maybe Bool
    findAndExtractBool _ [] = Nothing
    findAndExtractBool pat (c :: cs) =
      if startsWith pat (c :: cs)
        then extractBoolValue (drop (length pat) (c :: cs))
        else findAndExtractBool pat cs

||| Extract array of strings (simple case)
extractJsonStringArray : String -> String -> List String
extractJsonStringArray key json =
  let pattern = "\"" ++ key ++ "\":"
      chars = unpack json
  in findAndExtractArray (unpack pattern) chars
  where
    startsWith : List Char -> List Char -> Bool
    startsWith [] _ = True
    startsWith _ [] = False
    startsWith (p :: ps) (c :: cs) = p == c && startsWith ps cs

    skipWs : List Char -> List Char
    skipWs [] = []
    skipWs (c :: cs) = if c == ' ' || c == '\n' || c == '\t' then skipWs cs else (c :: cs)

    extractString : List Char -> List Char -> (String, List Char)
    extractString [] acc = (pack (reverse acc), [])
    extractString ('"' :: rest) acc = (pack (reverse acc), rest)
    extractString ('\\' :: c :: rest) acc = extractString rest (c :: acc)
    extractString (c :: rest) acc = extractString rest (c :: acc)

    collectStrings : List Char -> List String -> List String
    collectStrings [] acc = reverse acc
    collectStrings (']' :: _) acc = reverse acc
    collectStrings ('"' :: rest) acc =
      let (str, remaining) = extractString rest []
      in collectStrings remaining (str :: acc)
    collectStrings (_ :: rest) acc = collectStrings rest acc

    parseArray : List Char -> List String
    parseArray chars =
      case skipWs chars of
        ('[' :: rest) => collectStrings rest []
        _ => []

    findAndExtractArray : List Char -> List Char -> List String
    findAndExtractArray _ [] = []
    findAndExtractArray pat (c :: cs) =
      if startsWith pat (c :: cs)
        then parseArray (drop (length pat) (c :: cs))
        else findAndExtractArray pat cs

||| Parse data type from string
parseDataType : String -> DataType
parseDataType s =
  if isInfixOf "int" s then DInt
  else if isInfixOf "uuid" s then DUUID
  else if isInfixOf "bool" s then DBool
  else if isInfixOf "timestamp" s then DTimestamp
  else if isInfixOf "json" s then DJson
  else if isInfixOf "bytea" s then DBytes
  else DText

||| Parse constraint type from string
parseConstraintTypeStr : String -> ConstraintType
parseConstraintTypeStr s =
  if isInfixOf "PrimaryKey" s then CPrimaryKey
  else if isInfixOf "ForeignKey" s then CForeignKey
  else if isInfixOf "Unique" s then CUnique
  else if isInfixOf "NotNull" s then CNotNull
  else CCheck

||| Split JSON into array elements (top-level objects)
splitJsonArray : String -> List String
splitJsonArray json =
  let chars = unpack json
  in case findArrayStart chars of
       Nothing => []
       Just rest => collectObjects rest 0 [] []
  where
    findArrayStart : List Char -> Maybe (List Char)
    findArrayStart [] = Nothing
    findArrayStart ('[' :: rest) = Just rest
    findArrayStart (_ :: rest) = findArrayStart rest

    collectObjects : List Char -> Nat -> List Char -> List String -> List String
    collectObjects [] _ current acc =
      if null current then reverse acc else reverse (pack (reverse current) :: acc)
    collectObjects (']' :: _) 0 current acc =
      if null current then reverse acc else reverse (pack (reverse current) :: acc)
    collectObjects ('{' :: rest) depth current acc =
      collectObjects rest (S depth) ('{' :: current) acc
    collectObjects ('}' :: rest) (S Z) current acc =
      collectObjects rest 0 [] (pack (reverse ('}' :: current)) :: acc)
    collectObjects ('}' :: rest) (S d) current acc =
      collectObjects rest d ('}' :: current) acc
    collectObjects (c :: rest) depth current acc =
      if depth > 0
        then collectObjects rest depth (c :: current) acc
        else collectObjects rest depth current acc

||| Parse a column from JSON object
parseColumnJson : String -> Maybe Column
parseColumnJson json = do
  name <- extractJsonValue "name" json
  dtype <- extractJsonValue "data_type" json
  let nullable = fromMaybe False (extractJsonBool "nullable" json)
  pure $ MkColumn name (parseDataType dtype) nullable

||| Parse a table from JSON object
parseTableJson : String -> Maybe Table
parseTableJson json = do
  name <- extractJsonValue "name" json
  let schemaName = fromMaybe "public" (extractJsonValue "schema_name" json)
  let pk = extractJsonStringArray "primary_key" json
  -- Parse columns array
  let columnsJson = extractArraySection "columns" json
  let columns = mapMaybe parseColumnJson (splitJsonArray columnsJson)
  pure $ MkTable schemaName name columns pk
  where
    startsWith : List Char -> List Char -> Bool
    startsWith [] _ = True
    startsWith _ [] = False
    startsWith (p :: ps) (x :: xs) = p == x && startsWith ps xs

    extractUntilClose : List Char -> Nat -> List Char -> List Char
    extractUntilClose [] _ acc = reverse acc
    extractUntilClose ('[' :: rest) depth acc = extractUntilClose rest (S depth) ('[' :: acc)
    extractUntilClose (']' :: rest) (S Z) acc = reverse (']' :: acc)
    extractUntilClose (']' :: rest) (S d) acc = extractUntilClose rest d (']' :: acc)
    extractUntilClose (']' :: _) Z acc = reverse acc
    extractUntilClose (c :: rest) depth acc = extractUntilClose rest depth (c :: acc)

    findAndExtractSection : List Char -> List Char -> List Char
    findAndExtractSection _ [] = []
    findAndExtractSection pat (c :: cs) =
      if startsWith pat (c :: cs)
        then extractUntilClose (drop (length pat) (c :: cs)) 0 []
        else findAndExtractSection pat cs

    extractArraySection : String -> String -> String
    extractArraySection key j =
      let pattern = "\"" ++ key ++ "\":"
          chars = unpack j
      in pack (findAndExtractSection (unpack pattern) chars)

||| Parse a constraint from JSON object
parseConstraintJson : String -> Maybe Constraint
parseConstraintJson json = do
  name <- extractJsonValue "name" json
  let ctype = fromMaybe "Check" (extractJsonValue "constraint_type" json)
  tableName <- extractJsonValue "table_name" json
  let cols = extractJsonStringArray "columns" json
  let foreignTable = extractJsonValue "foreign_table" json
  let foreignCols = case extractJsonStringArray "foreign_columns" json of
                      [] => Nothing
                      xs => Just xs
  pure $ MkConstraint name (parseConstraintTypeStr ctype) tableName cols foreignTable foreignCols

||| Parse a functional dependency from JSON object
parseFDJson : String -> Maybe FunctionalDep
parseFDJson json = do
  tableName <- extractJsonValue "table_name" json
  let det = extractJsonStringArray "determinant" json
  let dep = extractJsonStringArray "dependent" json
  pure $ MkFD tableName det dep 1.0

||| Parse full schema from CLI JSON output
parseSchemaJson : String -> Maybe Schema
parseSchemaJson json = do
  -- Check success
  True <- extractJsonBool "success" json
    | _ => Nothing
  -- Extract database name from data section
  dbName <- extractJsonValue "database_name" json
  -- Parse tables
  let tablesSection = extractDataSection "tables" json
  let tables = mapMaybe parseTableJson (splitJsonArray tablesSection)
  -- Parse constraints
  let constraintsSection = extractDataSection "constraints" json
  let constraints = mapMaybe parseConstraintJson (splitJsonArray constraintsSection)
  -- Parse FDs
  let fdsSection = extractDataSection "functional_deps" json
  let fds = mapMaybe parseFDJson (splitJsonArray fdsSection)
  pure $ MkSchema dbName tables constraints fds
  where
    startsWith : List Char -> List Char -> Bool
    startsWith [] _ = True
    startsWith _ [] = False
    startsWith (p :: ps) (x :: xs) = p == x && startsWith ps xs

    extractBracket : List Char -> Nat -> List Char -> List Char
    extractBracket [] _ acc = reverse acc
    extractBracket ('[' :: rest) depth acc = extractBracket rest (S depth) ('[' :: acc)
    extractBracket (']' :: rest) (S Z) acc = reverse (']' :: acc)
    extractBracket (']' :: rest) (S d) acc = extractBracket rest d (']' :: acc)
    extractBracket (']' :: _) Z acc = reverse acc
    extractBracket (c :: rest) depth acc = extractBracket rest depth (c :: acc)

    findSection : List Char -> List Char -> List Char
    findSection _ [] = []
    findSection pat (c :: cs) =
      if startsWith pat (c :: cs)
        then extractBracket (drop (length pat) (c :: cs)) 0 []
        else findSection pat cs

    extractDataSection : String -> String -> String
    extractDataSection key j =
      let pattern = "\"" ++ key ++ "\":"
          chars = unpack j
      in pack (findSection (unpack pattern) chars)

-- =============================================================================
-- IPC Implementation
-- =============================================================================

||| Generate a temporary file path for IPC
tmpFilePath : IO String
tmpFilePath = do
  t <- time
  pure $ "/tmp/fdb-ipc-" ++ show t ++ ".json"

||| Read entire file contents
readFileContents : String -> IO (Either FileError String)
readFileContents path = do
  Right h <- openFile path Read
    | Left err => pure (Left err)
  contents <- readAll h
  closeFile h
  pure (Right contents)
  where
    readAll : File -> IO String
    readAll h = do
      False <- fEOF h
        | True => pure ""
      Right line <- fGetLine h
        | Left _ => pure ""
      rest <- readAll h
      pure (line ++ rest)

||| Execute CLI command and read output using temp file
execCliCommand : List String -> IO (Either String String)
execCliCommand args = do
  tmpFile <- tmpFilePath
  let cmd = "fdb-debug " ++ unwords args ++ " > " ++ tmpFile ++ " 2>&1"
  exitCode <- system cmd
  if exitCode /= 0
    then do
      -- Try to read error output anyway
      Right output <- readFileContents tmpFile
        | Left _ => pure (Left $ "Command failed with exit code " ++ show exitCode)
      _ <- system $ "rm -f " ++ tmpFile
      pure (Left output)
    else do
      Right output <- readFileContents tmpFile
        | Left err => pure (Left $ "Failed to read output: " ++ show err)
      _ <- system $ "rm -f " ++ tmpFile
      pure (Right output)

||| Connect to a database using the Rust CLI backend
connectToDatabase : DebugState -> String -> IO DebugState
connectToDatabase state connStr = do
  putStrLn $ "Connecting to: " ++ connStr
  result <- execCliCommand ["ping", "-c", connStr]
  case result of
    Left err => do
      putStrLn $ "Connection failed: " ++ err
      pure state
    Right output =>
      if isInfixOf "connected" output
        then do
          putStrLn "Connected. Fetching schema..."
          schemaResult <- execCliCommand ["schema", "-c", connStr]
          case schemaResult of
            Left err => do
              putStrLn $ "Schema fetch failed: " ++ err
              pure $ { connected := True, connectionUri := Just connStr } state
            Right schemaJson =>
              case parseSchemaJson schemaJson of
                Nothing => do
                  putStrLn "Warning: Failed to parse schema, using demo schema."
                  pure $ { connected := True
                         , connectionUri := Just connStr
                         , schema := Just sampleSchema } state
                Just realSchema => do
                  putStrLn $ "Schema loaded: " ++ show (length realSchema.tables) ++ " tables, " ++
                             show (length realSchema.constraints) ++ " constraints, " ++
                             show (length realSchema.functionalDeps) ++ " FDs"
                  pure $ { connected := True
                         , connectionUri := Just connStr
                         , schema := Just realSchema } state
        else do
          putStrLn $ "Connection failed: " ++ substr 0 100 output
          pure state

||| Disconnect from database
disconnectFromDatabase : DebugState -> IO DebugState
disconnectFromDatabase state =
  case state.connected of
    False => do
      putStrLn "Not connected."
      pure state
    True => do
      putStrLn "Disconnected."
      pure $ { connected := False
             , connectionUri := Nothing
             , schema := Nothing } state

||| Show connection status
showStatus : DebugState -> IO ()
showStatus state = do
  putStrLn $ "Connected: " ++ show state.connected
  case state.connectionUri of
    Nothing => putStrLn "No connection URI"
    Just uri => putStrLn $ "URI: " ++ uri
  case state.schema of
    Nothing => putStrLn "No schema loaded"
    Just s => putStrLn $ "Schema: " ++ s.databaseName

||| Show help text
showHelp : IO ()
showHelp = do
  putStrLn ""
  putStrLn "FormBD Debugger Commands"
  putStrLn "========================"
  putStrLn ""
  putStrLn "Connection:"
  putStrLn "  connect <uri>     Connect to PostgreSQL database"
  putStrLn "  disconnect        Disconnect from database"
  putStrLn "  status            Show connection status"
  putStrLn "  demo              Load demo schema for exploration"
  putStrLn ""
  putStrLn "Schema Inspection:"
  putStrLn "  schema            Show loaded schema summary"
  putStrLn "  tables            List all tables"
  putStrLn "  describe <table>  Show table structure"
  putStrLn ""
  putStrLn "Constraints & FDs:"
  putStrLn "  fds               Show all functional dependencies"
  putStrLn "  fds <table>       Show FDs for specific table"
  putStrLn "  constraints       Show all constraints"
  putStrLn ""
  putStrLn "Diagnostics:"
  putStrLn "  diagnose          Check for constraint violations"
  putStrLn "  explain <name>    Explain a constraint"
  putStrLn ""
  putStrLn "General:"
  putStrLn "  help              Show this help"
  putStrLn "  quit              Exit debugger"
  putStrLn ""

||| Load demo schema
loadDemo : DebugState -> IO DebugState
loadDemo state = do
  putStrLn "Loading demo schema: lithoglyph_demo"
  putStrLn "  3 tables, 6 constraints, 4 functional dependencies"
  pure $ { schema := Just sampleSchema } state

||| Show schema summary
showSchemaInfo : DebugState -> IO ()
showSchemaInfo state =
  case state.schema of
    Nothing => putStrLn "No schema loaded. Use 'demo' to load sample schema."
    Just s => do
      putStrLn $ "Database: " ++ s.databaseName
      putStrLn $ "Tables: " ++ show (length s.tables)
      putStrLn $ "Constraints: " ++ show (length s.constraints)
      putStrLn $ "Functional Dependencies: " ++ show (length s.functionalDeps)

||| List all tables
listTables : DebugState -> IO ()
listTables state =
  case state.schema of
    Nothing => putStrLn "No schema loaded."
    Just s => do
      putStrLn "Tables:"
      traverse_ (\t => putStrLn $ "  " ++ show t) s.tables

||| Describe a table
describeTable : DebugState -> String -> IO ()
describeTable state tableName =
  case state.schema of
    Nothing => putStrLn "No schema loaded."
    Just s => case findTable s tableName of
      Nothing => putStrLn $ "Table not found: " ++ tableName
      Just t => do
        putStrLn $ "\nTable: " ++ t.schemaName ++ "." ++ t.name
        putStrLn "\nColumns:"
        traverse_ (\c => putStrLn $ "  " ++ show c) t.columns
        putStrLn "\nPrimary Key:"
        putStrLn $ "  " ++ show t.primaryKey
        putStrLn "\nConstraints:"
        let cons = tableConstraints s tableName
        if null cons
          then putStrLn "  (none)"
          else traverse_ (\c => putStrLn $ "  " ++ show c) cons
        putStrLn "\nFunctional Dependencies:"
        let fds = tableFDs s tableName
        if null fds
          then putStrLn "  (none)"
          else traverse_ (\fd => putStrLn $ "  " ++ show fd) fds

||| Show all functional dependencies
showAllFDs : DebugState -> IO ()
showAllFDs state =
  case state.schema of
    Nothing => putStrLn "No schema loaded."
    Just s => do
      putStrLn "Functional Dependencies:"
      if null s.functionalDeps
        then putStrLn "  (none)"
        else traverse_ (\fd => putStrLn $ "  " ++ show fd) s.functionalDeps

||| Show FDs for a specific table
showTableFDs : DebugState -> String -> IO ()
showTableFDs state tableName =
  case state.schema of
    Nothing => putStrLn "No schema loaded."
    Just s => do
      let fds = tableFDs s tableName
      putStrLn $ "Functional Dependencies for " ++ tableName ++ ":"
      if null fds
        then putStrLn "  (none)"
        else traverse_ (\fd => putStrLn $ "  " ++ show fd) fds

||| Show all constraints
showAllConstraints : DebugState -> IO ()
showAllConstraints state =
  case state.schema of
    Nothing => putStrLn "No schema loaded."
    Just s => do
      putStrLn "Constraints:"
      if null s.constraints
        then putStrLn "  (none)"
        else traverse_ (\c => putStrLn $ "  " ++ show c) s.constraints

||| Parse diagnostics output
parseDiagnoseResult : String -> (Nat, Nat, List String)
parseDiagnoseResult json =
  let total = fromMaybe 0 (extractJsonNat "total_constraints" json)
      satisfied = fromMaybe 0 (extractJsonNat "satisfied" json)
      violations = fromMaybe 0 (extractJsonNat "violations" json)
      -- Extract violation explanations
      violationMessages = extractViolationMessages json
  in (total, violations, violationMessages)
  where
    extractJsonNat : String -> String -> Maybe Nat
    extractJsonNat key j =
      let pattern = "\"" ++ key ++ "\":"
          chars = unpack j
      in findAndExtractNat (unpack pattern) chars
      where
        startsWith : List Char -> List Char -> Bool
        startsWith [] _ = True
        startsWith _ [] = False
        startsWith (p :: ps) (c :: cs) = p == c && startsWith ps cs

        skipWs : List Char -> List Char
        skipWs [] = []
        skipWs (c :: cs) = if c == ' ' || c == '\n' || c == '\t' then skipWs cs else (c :: cs)

        extractNum : List Char -> List Char -> Nat
        extractNum [] acc = foldr (\d, n => n * 10 + d) 0 (reverse acc)
        extractNum (c :: rest) acc =
          if c >= '0' && c <= '9'
            then extractNum rest (cast (ord c - ord '0') :: acc)
            else foldr (\d, n => n * 10 + d) 0 (reverse acc)

        findAndExtractNat : List Char -> List Char -> Maybe Nat
        findAndExtractNat _ [] = Nothing
        findAndExtractNat pat (c :: cs) =
          if startsWith pat (c :: cs)
            then Just (extractNum (skipWs (drop (length pat) (c :: cs))) [])
            else findAndExtractNat pat cs

    extractViolationMessages : String -> List String
    extractViolationMessages j =
      -- Simple extraction: look for "explanation" fields
      let chars = unpack j
      in collectExplanations chars []
      where
        collectExplanations : List Char -> List String -> List String
        collectExplanations [] acc = reverse acc
        collectExplanations cs acc =
          case findExplanation cs of
            Nothing => reverse acc
            Just (msg, rest) => collectExplanations rest (msg :: acc)

        findExplanation : List Char -> Maybe (String, List Char)
        findExplanation cs =
          let pattern = unpack "\"explanation\":"
          in case findPattern pattern cs of
            Nothing => Nothing
            Just rest =>
              case skipWsAndQuote rest of
                Nothing => Nothing
                Just afterQuote =>
                  let (msg, remainder) = extractUntilQuote afterQuote []
                  in Just (msg, remainder)

        findPattern : List Char -> List Char -> Maybe (List Char)
        findPattern _ [] = Nothing
        findPattern pat (c :: cs) =
          if startsWith pat (c :: cs)
            then Just (drop (length pat) (c :: cs))
            else findPattern pat cs

        startsWith : List Char -> List Char -> Bool
        startsWith [] _ = True
        startsWith _ [] = False
        startsWith (p :: ps) (x :: xs) = p == x && startsWith ps xs

        skipWsAndQuote : List Char -> Maybe (List Char)
        skipWsAndQuote [] = Nothing
        skipWsAndQuote (c :: cs) =
          if c == ' ' || c == '\n' || c == '\t' then skipWsAndQuote cs
          else if c == '"' then Just cs
          else Nothing

        extractUntilQuote : List Char -> List Char -> (String, List Char)
        extractUntilQuote [] acc = (pack (reverse acc), [])
        extractUntilQuote ('"' :: rest) acc = (pack (reverse acc), rest)
        extractUntilQuote ('\\' :: c :: rest) acc = extractUntilQuote rest (c :: acc)
        extractUntilQuote (c :: rest) acc = extractUntilQuote rest (c :: acc)

||| Run diagnostics
runDiagnose : DebugState -> IO ()
runDiagnose state =
  case state.connectionUri of
    Nothing =>
      case state.schema of
        Nothing => putStrLn "No schema loaded. Use 'demo' or 'connect' first."
        Just s => do
          -- Offline mode: just check schema structure
          putStrLn "Running constraint diagnostics (offline mode)..."
          putStrLn ""
          putStrLn $ "  Total constraints: " ++ show (length s.constraints)
          putStrLn "  Status: Schema-only check (connect for full diagnostics)"
          putStrLn ""
          putStrLn "Constraints defined:"
          traverse_ (\c => putStrLn $ "  [OK] " ++ show c) s.constraints
    Just connStr => do
      -- Online mode: use CLI backend
      putStrLn "Running constraint diagnostics..."
      result <- execCliCommand ["diagnose", "-c", connStr]
      case result of
        Left err => do
          putStrLn $ "Diagnostics failed: " ++ err
        Right output =>
          case extractJsonBool "success" output of
            Just True => do
              let (total, violations, messages) = parseDiagnoseResult output
              putStrLn ""
              putStrLn $ "  Total constraints: " ++ show total
              putStrLn $ "  Satisfied: " ++ show (minus total violations)
              putStrLn $ "  Violations: " ++ show violations
              putStrLn ""
              if violations == 0
                then putStrLn "All constraints satisfied."
                else do
                  putStrLn "Constraint violations found:"
                  traverse_ (\msg => putStrLn $ "  - " ++ msg) messages
            Just False =>
              case extractJsonValue "error" output of
                Just errMsg => putStrLn $ "Diagnostics error: " ++ errMsg
                Nothing => putStrLn "Diagnostics failed with unknown error."
            Nothing => putStrLn $ "Failed to parse diagnostics response."

||| Explain a constraint
explainConstraint : DebugState -> String -> IO ()
explainConstraint state name =
  case state.schema of
    Nothing => putStrLn "No schema loaded."
    Just s => case find (\c => c.name == name) s.constraints of
      Nothing => putStrLn $ "Constraint not found: " ++ name
      Just c => do
        putStrLn $ "\nConstraint: " ++ c.name
        putStrLn $ "Type: " ++ show c.ctype
        putStrLn $ "Table: " ++ c.tableName
        putStrLn $ "Columns: " ++ show c.columns
        case c.ctype of
          CForeignKey => do
            putStrLn $ "References: " ++ fromMaybe "?" c.foreignTable
            putStrLn $ "Foreign Columns: " ++ show (fromMaybe [] c.foreignColumns)
            putStrLn ""
            putStrLn "This constraint ensures referential integrity."
            putStrLn "Violations occur when referenced rows are missing."
          CPrimaryKey => do
            putStrLn ""
            putStrLn "This constraint ensures row uniqueness."
            putStrLn "Violations occur with duplicate key values."
          CUnique => do
            putStrLn ""
            putStrLn "This constraint ensures column uniqueness."
            putStrLn "Violations occur with duplicate values."
          CCheck => do
            putStrLn ""
            putStrLn "This constraint validates data values."
            putStrLn "Violations occur when check expression is false."
          CNotNull => do
            putStrLn ""
            putStrLn "This constraint prevents NULL values."

||| Process a single command
processCommand : DebugState -> String -> IO DebugState
processCommand state cmd =
  let parts = words cmd
  in case parts of
    ["help"] => showHelp >> pure state
    ["demo"] => loadDemo state
    ("connect" :: rest) =>
      case rest of
        [] => do
          putStrLn "Usage: connect <connection_string>"
          putStrLn "Example: connect postgres://user:pass@localhost/mydb"
          pure state
        _ => connectToDatabase state (unwords rest)
    ["disconnect"] => disconnectFromDatabase state
    ["status"] => showStatus state >> pure state
    ["schema"] => showSchemaInfo state >> pure state
    ["tables"] => listTables state >> pure state
    ["describe", t] => describeTable state t >> pure state
    ["fds"] => showAllFDs state >> pure state
    ["fds", t] => showTableFDs state t >> pure state
    ["constraints"] => showAllConstraints state >> pure state
    ["diagnose"] => runDiagnose state >> pure state
    ["explain", n] => explainConstraint state n >> pure state
    _ => do
      putStrLn $ "Unknown command: " ++ cmd
      putStrLn "Type 'help' for available commands."
      pure state

||| Run the main REPL loop
public export
runREPL : DebugState -> IO ()
runREPL state = do
  putStr "lithoglyph-debug> "
  line <- getLine
  case trim line of
    "quit" => putStrLn "Goodbye!"
    "exit" => putStrLn "Goodbye!"
    "" => runREPL state
    cmd => do
      newState <- processCommand state cmd
      runREPL newState
