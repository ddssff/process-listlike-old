module System.Process.Text where

import Control.Exception
import Control.Monad
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as T
import Prelude hiding (catch)
import System.Process
import System.Exit (ExitCode(ExitSuccess, ExitFailure))
import System.IO
import Utils (forkWait, resourceVanished, mkError)

readProcessWithExitCode
    :: FilePath                 -- ^ command to run
    -> [String]                 -- ^ any arguments
    -> Text                     -- ^ standard input
    -> IO (ExitCode, Text, Text) -- ^ exitcode, stdout, stderr
readProcessWithExitCode = readModifiedProcessWithExitCode id

-- | Like 'System.Process.readProcessWithExitCode', but using 'Text'
readModifiedProcessWithExitCode
    :: (CreateProcess -> CreateProcess)
                                -- ^ Modify CreateProcess with this
    -> FilePath                 -- ^ command to run
    -> [String]                 -- ^ any arguments
    -> Text                     -- ^ standard input
    -> IO (ExitCode, Text, Text) -- ^ exitcode, stdout, stderr
readModifiedProcessWithExitCode modify cmd args input = mask $ \restore -> do
    let modify' p = (modify p) {std_in = CreatePipe, std_out = CreatePipe, std_err = CreatePipe }

    (Just inh, Just outh, Just errh, pid) <-
        createProcess (modify' (proc cmd args))

    flip onException
      (do hClose inh; hClose outh; hClose errh;
          terminateProcess pid; waitForProcess pid) $ restore $ do

      -- fork off a thread to start consuming stdout
      waitOut <- forkWait $ T.hGetContents outh

      -- fork off a thread to start consuming stderr
      waitErr <- forkWait $ T.hGetContents errh

      -- now write and flush any input
      unless (T.null input) $ do T.hPutStr inh input; hFlush inh
      hClose inh -- done with stdin

      -- wait on the output
      out <- waitOut
      err <- waitErr

      hClose outh
      hClose errh

      -- wait on the process
      ex <- waitForProcess pid

      return (ex, out, err)

readProcess
    :: FilePath                 -- ^ command to run
    -> [String]                 -- ^ any arguments
    -> Text                     -- ^ standard input
    -> IO Text                  -- ^ stdout
readProcess = readModifiedProcess id

-- | Like 'System.Process.readProcess', but using 'Text'
readModifiedProcess
    :: (CreateProcess -> CreateProcess)
                                -- ^ Modify CreateProcess with this
    -> FilePath                 -- ^ command to run
    -> [String]                 -- ^ any arguments
    -> Text                     -- ^ standard input
    -> IO Text                  -- ^ stdout
readModifiedProcess modify cmd args input = mask $ \restore -> do
    let modify' p = (modify p) {std_in = CreatePipe, std_out = CreatePipe, std_err = Inherit }

    (Just inh, Just outh, _, pid) <-
        createProcess (modify' (proc cmd args))

    flip onException
      (do hClose inh; hClose outh;
          terminateProcess pid; waitForProcess pid) $ restore $ do

      -- fork off a thread to start consuming stdout
      waitOut <- forkWait $ T.hGetContents outh

      -- now write and flush any input
      unless (T.null input) $ (do T.hPutStr inh input
                                  hFlush inh
                                  hClose inh) `catch` resourceVanished

      -- wait on the output
      out <- waitOut

      hClose outh

      -- wait on the process
      ex <- waitForProcess pid

      case ex of
        ExitSuccess   -> return out
        ExitFailure r -> ioError (mkError cmd args r)
