-- SPDX-License-Identifier: PMPL-1.0-or-later
||| Lithoglyph Debugger - Main Entry Point
module Main

import REPL.Core
import REPL.Commands

||| Main entry point for the Lithoglyph Debugger
main : IO ()
main = do
  putStrLn "Lithoglyph Debugger v0.1.0"
  putStrLn "Type 'help' for available commands, 'quit' to exit."
  putStrLn ""
  runREPL initialState
