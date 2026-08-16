import Control.Monad (unless, when)
import Control.Monad.State
import Corpus (caseId, readSequentCase)
import Data.IORef (modifyIORef, newIORef, readIORef)
import Data.List (isSuffixOf, sort)
import Prover.G4ip (g4ipProver)
import qualified Report.Csv as Csv
import Runner (BenchRow (..), runCase)
import System.Directory (createDirectoryIfMissing, doesDirectoryExist, doesFileExist, listDirectory)
import System.Environment (getArgs)
import System.Exit (die)
import System.FilePath ((</>))
import System.IO (Handle, IOMode (WriteMode), hFlush, stdout, withFile)
import Text.Read (readMaybe)

data Arguments = Arguments
  { corpusPath :: FilePath,
    outputDirectory :: FilePath,
    timeoutMs :: Int
  }
  deriving (Show)

data ParsedArguments = ParsedArguments
  { parsedCorpusPath :: Maybe FilePath,
    parsedOutputDirectory :: Maybe FilePath,
    parsedTimeoutMs :: Int
  }
  deriving (Show)

data Counters = Counters
  { processedCount :: Int,
    skippedCount :: Int,
    errorCount :: Int
  }

emptyCounters :: Counters
emptyCounters = Counters {processedCount = 0, skippedCount = 0, errorCount = 0}

defaultArguments :: ParsedArguments
defaultArguments = ParsedArguments {parsedCorpusPath = Nothing, parsedOutputDirectory = Nothing, parsedTimeoutMs = 100}

processArgs :: [String] -> StateT ParsedArguments (Either String) ()
processArgs args = do
  case args of
    ("--corpus" : corpus : rest) -> do
      modify (\ctx -> ctx {parsedCorpusPath = Just corpus})
      processArgs rest
    ("--corpus" : _) -> lift (Left $ "--corpus requires argument")
    ("--output" : output : rest) -> do
      modify (\ctx -> ctx {parsedOutputDirectory = Just output})
      processArgs rest
    ("--output" : _) -> lift (Left $ "--output requires argument")
    ("--timeout-ms" : timeoutText : rest) ->
      case readMaybe timeoutText of
        Just timeout
          | timeout > 0 -> do
              modify (\ctx -> ctx {parsedTimeoutMs = timeout})
              processArgs rest
        _ ->
          lift (Left $ "--timeout-ms requires a positive integer")
    ("--timeout-ms" : _) -> lift (Left $ "--timeout-ms requires argument")
    ["--help"] -> lift (Left usage)
    [] -> pure ()
    (arg : _) -> lift (Left $ "Unknown argument " ++ (show arg) ++ "\n\n" ++ usage)

requireArguments :: ParsedArguments -> Either String Arguments
requireArguments parsed = do
  corpus <-
    case parsedCorpusPath parsed of
      Just path -> Right path
      Nothing -> Left "--corpus is required"
  output <-
    case parsedOutputDirectory parsed of
      Just path -> Right path
      Nothing -> Left "--output is required"
  Right Arguments {corpusPath = corpus, outputDirectory = output, timeoutMs = parsedTimeoutMs parsed}

usage :: String
usage =
  unlines
    [ "prover-bench",
      "",
      "Run sequent cases from the YAML test corpus with the G4ip prover and write a CSV report.",
      "",
      "Usage:",
      "  stack run prover-bench -- --corpus test/corpus --output results --timeout-ms 100",
      "",
      "Options:",
      "  --corpus PATH       Required. Corpus root to scan recursively for .yaml files.",
      "  --output DIR        Required. Directory where report.csv will be written.",
      "                      The directory is created automatically.",
      "                      Existing report.csv is overwritten.",
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

processYamlFile :: Arguments -> Handle -> FilePath -> IO (Counters, [String])
processYamlFile arguments handle path = do
  result <- readSequentCase path
  case result of
    Left err ->
      pure (emptyCounters {errorCount = 1}, [err])
    Right Nothing ->
      pure (emptyCounters {skippedCount = 1}, [])
    Right (Just sequentCase) -> do
      putStr ("running " ++ caseId sequentCase ++ " ... ")
      hFlush stdout
      row <- runCase g4ipProver (timeoutMs arguments) sequentCase
      Csv.writeRow handle row
      putStrLn (show (rowStatus row) ++ " (" ++ show (rowTimeMs row) ++ " ms)")
      pure (emptyCounters {processedCount = 1}, [])

addCounters :: Counters -> Counters -> Counters
addCounters left right =
  Counters
    { processedCount = processedCount left + processedCount right,
      skippedCount = skippedCount left + skippedCount right,
      errorCount = errorCount left + errorCount right
    }

renderSummary :: Counters -> FilePath -> String
renderSummary counters reportPath =
  unlines
    [ "done",
      "processed sequent cases: " ++ show (processedCount counters),
      "skipped non-sequent files: " ++ show (skippedCount counters),
      "errors: " ++ show (errorCount counters),
      "report: " ++ reportPath
    ]

main :: IO ()
main = do
  args <- getArgs
  case runStateT (processArgs args) defaultArguments of
    Left err -> die err
    Right (_, parsedArguments) ->
      case requireArguments parsedArguments of
        Left err -> die (err ++ "\n\n" ++ usage)
        Right arguments -> runWithArguments arguments

runWithArguments :: Arguments -> IO ()
runWithArguments arguments = do
  exists <- doesDirectoryExist (corpusPath arguments)
  unless exists $ do
    die ("corpus path " ++ (corpusPath arguments) ++ " doesn't exsist")
  errorsRef <- newIORef []
  countersRef <- newIORef emptyCounters
  let reportPath = outputDirectory arguments </> "report.csv"
  createDirectoryIfMissing True (outputDirectory arguments)
  withFile reportPath WriteMode $ \handle -> do
    Csv.writeHeader handle
    forEachYamlFile (corpusPath arguments) $ \path -> do
      (counters, errors) <- processYamlFile arguments handle path
      modifyIORef countersRef (addCounters counters)
      unless (null errors) $
        modifyIORef errorsRef (++ errors)
  errors <- readIORef errorsRef
  counters <- readIORef countersRef
  unless (null errors) $
    die (unlines errors)
  putStr (renderSummary counters reportPath)
