{-# OPTIONS_GHC -fno-warn-missing-signatures #-}
module System.Process.Text.Lazy
    ( readProcess
    , readProcessWithExitCode
    , readModifiedProcess
    , readModifiedProcessWithExitCode
    ) where

import System.Exit (ExitCode)
import System.Process (CreateProcess)
import qualified System.Process.Read as R

readProcess :: R.Chars a => FilePath -> [String] -> a -> IO a
readProcess = R.readProcess
readProcessWithExitCode :: R.Chars a => FilePath -> [String] -> a -> IO (ExitCode, a, a)
readProcessWithExitCode = R.readProcessWithExitCode
readModifiedProcess :: R.Chars a => CreateProcess -> a -> IO a
readModifiedProcess = R.readModifiedProcess
readModifiedProcessWithExitCode :: R.Chars a => CreateProcess -> a -> IO (ExitCode, a, a)
readModifiedProcessWithExitCode = R.readModifiedProcessWithExitCode
