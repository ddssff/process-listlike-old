module System.Process.ByteString where

import Control.Exception
import Control.Monad
import Data.ByteString (ByteString)
import qualified Data.ByteString as B
import System.Process
import System.Exit (ExitCode)
import System.IO
import Utils (forkWait)

readProcessWithExitCode
    :: FilePath                 -- ^ command to run
    -> [String]                 -- ^ any arguments
    -> ByteString               -- ^ standard input
    -> IO (ExitCode, ByteString, ByteString) -- ^ exitcode, stdout, stderr
readProcessWithExitCode = readModifiedProcessWithExitCode id

-- | Like 'System.Process.readProcessWithExitCode', but using 'ByteString'
readModifiedProcessWithExitCode
    :: (CreateProcess -> CreateProcess)
                                -- ^ Modify CreateProcess with this
    -> FilePath                 -- ^ command to run
    -> [String]                 -- ^ any arguments
    -> ByteString               -- ^ standard input
    -> IO (ExitCode, ByteString, ByteString) -- ^ exitcode, stdout, stderr
readModifiedProcessWithExitCode modify cmd args input = mask $ \restore -> do
    let modify' p = (modify p) {std_in = CreatePipe, std_out = CreatePipe, std_err = CreatePipe }

    (Just inh, Just outh, Just errh, pid) <-
        createProcess (modify' (proc cmd args))

    flip onException
      (do hClose inh; hClose outh; hClose errh;
          terminateProcess pid; waitForProcess pid) $ restore $ do

      -- fork off a thread to start consuming stdout
      waitOut <- forkWait $ B.hGetContents outh

      -- fork off a thread to start consuming stderr
      waitErr <- forkWait $ B.hGetContents errh

      -- now write and flush any input
      unless (B.null input) $ do B.hPutStr inh input; hFlush inh
      hClose inh -- done with stdin

      -- wait on the output
      out <- waitOut
      err <- waitErr

      hClose outh
      hClose errh

      -- wait on the process
      ex <- waitForProcess pid

      return (ex, out, err)
