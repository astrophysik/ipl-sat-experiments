module Report.Csv
  ( writeHeader,
    writeRow,
  )
where

import Corpus (Entailment (..))
import Prover.Interface (ProverResult (..))
import Runner (BenchRow (..), RunStatus (..))
import System.IO (Handle, hPutStr)

writeHeader :: Handle -> IO ()
writeHeader handle =
  hPutStr handle "case_id,source,prover,expected,actual,status,time_ms,note\n"

writeRow :: Handle -> BenchRow -> IO ()
writeRow handle row =
  hPutStr handle (renderRow row)

renderRow :: BenchRow -> String
renderRow row =
  joinCsv
    [ rowCaseId row,
      rowSource row,
      rowProver row,
      renderEntailment (rowExpected row),
      renderProverResult (rowActual row),
      renderRunStatus (rowStatus row),
      show (rowTimeMs row),
      rowNote row
    ]
    ++ "\n"

renderEntailment :: Entailment -> String
renderEntailment entailment =
  case entailment of
    Derivable -> "derivable"
    Underivable -> "underivable"
    Unsolved -> "unsolved"

renderProverResult :: ProverResult -> String
renderProverResult result =
  case result of
    ProverDerivable -> "derivable"
    ProverUnderivable -> "underivable"
    ProverUnknown -> "unknown"
    ProverUnsupported _ -> "skipped"
    ProverError _ -> "error"

renderRunStatus :: RunStatus -> String
renderRunStatus status =
  case status of
    Pass -> "pass"
    Fail -> "fail"
    Solved -> "solved"
    Unknown -> "unknown"
    Skip -> "skip"
    BackendError -> "backend-error"

joinCsv :: [String] -> String
joinCsv [] = ""
joinCsv [value] = csvEscape value
joinCsv (value : values) = csvEscape value ++ "," ++ joinCsv values

csvEscape :: String -> String
csvEscape value =
  "\"" ++ concatMap escapeChar value ++ "\""
  where
    escapeChar char =
      case char of
        '"' -> "\"\""
        _ -> [char]
