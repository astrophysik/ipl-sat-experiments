import Control.Monad (unless, when)
import Control.Monad.State
import Corpus (readSequentCase)
import Data.IORef (modifyIORef, newIORef, readIORef)
import Data.List (isSuffixOf, sort)
import Prover.G4ip (g4ipProver)
import qualified Report.Csv as Csv
import Runner (runCase)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath (takeDirectory, (</>))
import System.IO (Handle, IOMode (WriteMode), withFile)
import Text.Read (readMaybe)

data Arguments = Arguments
  { corpusPath :: FilePath,
    outputPath :: FilePath,
    timeoutMs :: Int
  }
  deriving (Show)

defaultArguments :: Arguments
defaultArguments = Arguments {corpusPath = "test/corpus", outputPath = "results/report.csv", timeoutMs = 100}

processArgs :: [String] -> StateT Arguments (Either String) ()
processArgs args = do
  case args of
    ("--corpus" : corpus : rest) -> do
      modify (\ctx -> ctx {corpusPath = corpus})
      processArgs rest
    ("--corpus" : _) -> lift (Left $ "--corpus requires argument")
    ("--output" : output : rest) -> do
      modify (\ctx -> ctx {outputPath = output})
      processArgs rest
    ("--output" : _) -> lift (Left $ "--output requires argument")
    ("--timeout-ms" : timeoutText : rest) ->
      case readMaybe timeoutText of
        Just timeout
          | timeout > 0 -> do
              modify (\ctx -> ctx {timeoutMs = timeout})
              processArgs rest
        _ ->
          lift (Left $ "--timeout-ms requires a positive integer")
    ("--timeout-ms" : _) -> lift (Left $ "--timeout-ms requires argument")
    ["--help"] -> lift (Left usage)
    [] -> pure ()
    (arg : _) -> lift (Left $ "Unknown argument " ++ (show arg))

usage :: String
usage =
  unlines
    [ "prover-report",
      "",
      "Run sequent cases from the YAML test corpus with the G4ip prover and write a CSV report.",
      "",
      "Usage:",
      "  stack run prover-report -- --corpus test/corpus --output results/g4ip.csv --timeout-ms 100",
      "",
      "Options:",
      "  --corpus PATH       Corpus root to scan recursively for .yaml files.",
      "                      Default: test/corpus",
      "  --output PATH       CSV report path. Parent directories are created automatically.",
      "                      Existing files are overwritten.",
      "                      Default: results/g4ip.csv",
      "  --timeout-ms N      Per-case prover timeout in milliseconds.",
      "                      Timed-out cases are reported as unknown.",
      "                      Default: 100",
      "  --help              Show this help message.",
      "",
      "CSV columns:",
      "  case_id, source, prover, expected, actual, status, time_ms, note"
    ]

forEachYamlFile :: FilePath -> (FilePath -> IO ()) -> IO ()
forEachYamlFile path handleFile = do
  entries <- sort <$> listDirectory path
  mapM_ visit entries
  where
    visit entry = do
      let entryPath = path </> entry
      isDirectory <- doesDirectoryExist entryPath
      isFile <- doesFileExist entryPath
      if isDirectory
        then forEachYamlFile entryPath handleFile
        else when (isFile && isSuffixOf ".yaml" entryPath) (handleFile entryPath)

processYamlFile :: Arguments -> Handle -> FilePath -> IO [String]
processYamlFile arguments handle path = do
  result <- readSequentCase path
  case result of
    Left err ->
      pure [err]
    Right Nothing ->
      pure []
    Right (Just sequentCase) -> do
      row <- runCase g4ipProver (timeoutMs arguments) sequentCase
      Csv.writeRow handle row
      pure []

main :: IO ()
main = do
  args <- getArgs
  case runStateT (processArgs args) defaultArguments of
    Left err -> die err
    Right (_, arguments) -> do
      exists <- doesDirectoryExist (corpusPath arguments)
      unless exists $ do
        die ("corpus path " ++ (corpusPath arguments) ++ " doesn't exsist")
      errorsRef <- newIORef []
      createDirectoryIfMissing True (takeDirectory (outputPath arguments))
      withFile (outputPath arguments) WriteMode $ \handle -> do
        Csv.writeHeader handle
        forEachYamlFile (corpusPath arguments) $ \path -> do
          errors <- processYamlFile arguments handle path
          unless (null errors) $
            modifyIORef errorsRef (++ errors)
      errors <- readIORef errorsRef
      unless (null errors) $
        die (unlines errors)
