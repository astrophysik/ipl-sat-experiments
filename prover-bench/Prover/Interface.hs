module Prover.Interface
  ( Prover (..),
    ProverResult (..),
  )
where

import Corpus (SequentCase)

data Prover = Prover
  { proverName :: String,
    proveSequent :: SequentCase -> ProverResult
  }

data ProverResult
  = ProverDerivable
  | ProverUnderivable
  | ProverUnknown
  | ProverUnsupported String
  | ProverError String
  deriving (Eq, Show)
