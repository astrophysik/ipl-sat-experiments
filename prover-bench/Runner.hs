module Runner
  ( BenchRow (..),
    RunStatus (..),
    runCase,
    runCases,
  )
where

import Corpus (Entailment (..), SequentCase (..))
import Control.Exception (evaluate)
import Data.Word (Word64)
import GHC.Clock (getMonotonicTimeNSec)
import Prover.Interface (Prover (..), ProverResult (..))
import System.Timeout (timeout)

data RunStatus
  = Pass
  | Fail
  | Solved
  | Unknown
  | Skip
  | BackendError
  deriving (Eq, Show)

data BenchRow = BenchRow
  { rowCaseId :: String,
    rowSource :: String,
    rowProver :: String,
    rowExpected :: Entailment,
    rowActual :: ProverResult,
    rowStatus :: RunStatus,
    rowTimeMs :: Double,
    rowNote :: String
  }
  deriving (Show)

runCases :: Prover -> Int -> [SequentCase] -> IO [BenchRow]
runCases prover timeoutMs =
  mapM (runCase prover timeoutMs)

runCase :: Prover -> Int -> SequentCase -> IO BenchRow
runCase prover timeoutMs sequent = do
  start <- getMonotonicTimeNSec
  timedResult <- timeout (millisecondsToMicroseconds timeoutMs) (evaluate (proveSequent prover sequent))
  end <- getMonotonicTimeNSec
  let actual =
        case timedResult of
          Nothing -> ProverUnknown
          Just result -> result
  let timeoutNote =
        case timedResult of
          Nothing -> "timeout after " ++ show timeoutMs ++ " ms"
          Just _ -> note actual
  pure
    BenchRow
      { rowCaseId = caseId sequent,
        rowSource = source sequent,
        rowProver = proverName prover,
        rowExpected = equententailment sequent,
        rowActual = actual,
        rowStatus = classify (equententailment sequent) actual,
        rowTimeMs = nanosecondsToMilliseconds (end - start),
        rowNote = timeoutNote
      }

classify :: Entailment -> ProverResult -> RunStatus
classify _ (ProverUnsupported _) = Skip
classify _ (ProverError _) = BackendError
classify _ ProverUnknown = Unknown
classify Derivable ProverDerivable = Pass
classify Derivable ProverUnderivable = Fail
classify Underivable ProverUnderivable = Pass
classify Underivable ProverDerivable = Fail
classify Unsolved ProverDerivable = Solved
classify Unsolved ProverUnderivable = Solved

note :: ProverResult -> String
note result =
  case result of
    ProverUnsupported message -> message
    ProverError message -> message
    _ -> ""

nanosecondsToMilliseconds :: Word64 -> Double
nanosecondsToMilliseconds nanoseconds =
  fromIntegral nanoseconds / 1000000

millisecondsToMicroseconds :: Int -> Int
millisecondsToMicroseconds milliseconds =
  milliseconds * 1000
