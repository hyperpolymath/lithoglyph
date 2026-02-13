-- SPDX-License-Identifier: PMPL-1.0-or-later
||| REPL Commands - Available debug commands
module REPL.Commands

import REPL.Core

||| Available commands in the debugger
public export
data Command
  = Help
  | Connect String           -- Connection string
  | Disconnect
  | Schema                   -- Show current schema
  | Tables                   -- List tables
  | Describe String          -- Describe table
  | Timeline                 -- Show database timeline
  | Goto String              -- Go to timestamp
  | Diagnose                 -- Run diagnostics
  | Explain String           -- Explain constraint violation
  | Recover                  -- Generate recovery plan
  | Verify String            -- Verify migration
  | Quit

||| Parse a command from input
public export
parseCommand : String -> Maybe Command
parseCommand "help" = Just Help
parseCommand "schema" = Just Schema
parseCommand "tables" = Just Tables
parseCommand "timeline" = Just Timeline
parseCommand "diagnose" = Just Diagnose
parseCommand "recover" = Just Recover
parseCommand "quit" = Just Quit
parseCommand "exit" = Just Quit
parseCommand _ = Nothing

||| Show help text
public export
showHelp : IO ()
showHelp = do
  putStrLn "FormBD Debugger Commands:"
  putStrLn ""
  putStrLn "  connect <uri>     Connect to a database"
  putStrLn "  disconnect        Disconnect from database"
  putStrLn "  schema            Show current schema"
  putStrLn "  tables            List all tables"
  putStrLn "  describe <table>  Describe table structure"
  putStrLn ""
  putStrLn "  timeline          Show database timeline"
  putStrLn "  goto <timestamp>  Time-travel to snapshot"
  putStrLn "  diff <timestamp>  Show changes since timestamp"
  putStrLn ""
  putStrLn "  diagnose          Run constraint diagnostics"
  putStrLn "  explain <name>    Explain constraint violation"
  putStrLn "  recover           Generate recovery plan"
  putStrLn "  verify <file>     Verify migration safety"
  putStrLn ""
  putStrLn "  help              Show this help"
  putStrLn "  quit              Exit debugger"
