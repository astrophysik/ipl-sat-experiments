{-# OPTIONS_GHC -fno-warn-simplifiable-class-constraints #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RankNTypes #-}

module Prover.Rzk
  ( rzkProver,
  )
where

import Control.Monad.Foil (DExt, Distinct, NameBinder)
import qualified Control.Monad.Foil as Foil
import Control.Monad.Foil.Internal (S (VoidS))
import Control.Monad.Free.Foil (AST (Var))
import Control.Monad.Reader (asks)
import Corpus (SequentCase (..))
import Data.Char (isAlphaNum, isAsciiLower, isAsciiUpper)
import Data.Data (Data, cast, gmapQ)
import Data.List (intercalate, isInfixOf, nub)
import qualified Data.Text as Text
import qualified Language.Rzk.Foil.Convert as Convert
import Language.Rzk.Foil.Names (TModality (Id), markUnresolved, toBinder, varIdent)
import Language.Rzk.Foil.Syntax (Term, TermT, cubeT, topeT, universeT, pattern Hole)
import qualified Language.Rzk.Syntax as Rzk
import Prover.Interface (Prover (..), ProverResult (..))
import Rzk.TypeCheck
  ( OutputDirection (BottomUp),
    TypeCheck,
    TypeErrorInScopedContext,
    checkTope,
    ctxScope,
    localTope,
    ppTypeErrorInScopedContext,
    runTypeCheck,
    typecheck,
    withBinder,
  )

rzkProver :: Prover
rzkProver =
  Prover
    { proverName = "rzk",
      proveSequent = proveWithRzk
    }

proveWithRzk :: SequentCase -> ProverResult
proveWithRzk sequent =
  case parseSequent sequent of
    Left err -> ProverUnsupported err
    Right query ->
      case runQuery query of
        Right True -> ProverDerivable
        Right False -> ProverUnderivable
        Left err ->
          let rendered = ppTypeErrorInScopedContext BottomUp err
           in if isEntailmentFailure rendered
                then ProverUnderivable
                else if isUnsupportedFormulaFailure rendered
                  then ProverUnsupported rendered
                  else ProverError rendered

data ParsedSequent = ParsedSequent
  { parsedDeclarations :: [ParsedDeclaration],
    parsedHypotheses :: [Rzk.Term],
    parsedGoal :: Rzk.Term
  }

data ParsedDeclaration = ParsedDeclaration
  { parsedBinder :: Rzk.Pattern,
    parsedType :: Rzk.Term,
    parsedDeclarationSort :: DeclarationSort
  }

parseSequent :: SequentCase -> Either String ParsedSequent
parseSequent sequent = do
  checkSupportedTopeFragment sequent
  declarations <- sequentDeclarations sequent
  checkNoDuplicateBinders declarations
  parsedDeclarations' <- traverse parseParsedDeclaration declarations
  parsedHypotheses' <- traverse (parseRzkTerm "Rzk tope hypothesis") (hypotheses sequent)
  parsedGoal' <- parseRzkTerm "Rzk tope goal" (goal sequent)
  validateParsedSequent parsedDeclarations' parsedHypotheses' parsedGoal'
  pure
    ParsedSequent
      { parsedDeclarations = parsedDeclarations',
        parsedHypotheses = parsedHypotheses',
        parsedGoal = parsedGoal'
      }

parseParsedDeclaration :: Declaration -> Either String ParsedDeclaration
parseParsedDeclaration declaration =
  ParsedDeclaration
    <$> parseBinderPattern (declBinder declaration)
    <*> parseRzkTerm "Rzk context type" (declType declaration)
    <*> pure (declDeclarationSort declaration)

parseBinderPattern :: String -> Either String Rzk.Pattern
parseBinderPattern binderSource =
  case Rzk.parseTerm (Text.pack ("\\ " ++ binderSource ++ " -> TOP")) of
    Left err -> Left ("cannot parse Rzk context binder " ++ show binderSource ++ ": " ++ Text.unpack err)
    Right (Rzk.Lambda _ [Rzk.ParamPattern _ pattern_] _) -> Right pattern_
    Right (Rzk.ASCII_Lambda _ [Rzk.ParamPattern _ pattern_] _) -> Right pattern_
    Right _ -> Left ("unsupported Rzk context binder " ++ show binderSource)

parseRzkTerm :: String -> String -> Either String Rzk.Term
parseRzkTerm label termSource =
  case Rzk.parseTerm (Text.pack termSource) of
    Left err -> Left ("cannot parse " ++ label ++ ": " ++ Text.unpack err)
    Right term -> Right term

runQuery :: ParsedSequent -> Either TypeErrorInScopedContext Bool
runQuery query =
  runTypeCheck (solveSequent query)

solveSequent :: ParsedSequent -> TypeCheck 'VoidS Bool
solveSequent query =
  solveWithDeclarations emptyEnv (parsedDeclarations query) query

solveWithDeclarations ::
  Distinct n =>
  Convert.Env n ->
  [ParsedDeclaration] ->
  ParsedSequent ->
  TypeCheck n Bool
solveWithDeclarations env [] query =
  solveWithTopes env (parsedHypotheses query) (parsedGoal query)
solveWithDeclarations env (declaration : declarations) query = do
  declarationType <- typecheckDeclarationType env declaration
  withBinder (toBinder (parsedBinder declaration)) Id declarationType $ \binder ->
    solveWithDeclarations
      (extendEnv (parsedBinder declaration) binder env)
      declarations
      query

typecheckDeclarationType ::
  Distinct n =>
  Convert.Env n ->
  ParsedDeclaration ->
  TypeCheck n (TermT n)
typecheckDeclarationType env declaration =
  case parsedDeclarationSort declaration of
    CubeDeclaration -> typecheckInContext env (parsedType declaration) cubeT
    TopeDeclaration -> typecheckInContext env (parsedType declaration) universeT

solveWithTopes ::
  Distinct n =>
  Convert.Env n ->
  [Rzk.Term] ->
  Rzk.Term ->
  TypeCheck n Bool
solveWithTopes env [] goalTerm = do
  goalTope <- typecheckInContext env goalTerm topeT
  checkTope goalTope
solveWithTopes env (hypothesis : hypotheses') goalTerm = do
  hypothesisTope <- typecheckInContext env hypothesis topeT
  localTope hypothesisTope $
    solveWithTopes env hypotheses' goalTerm

typecheckInContext ::
  Distinct n =>
  Convert.Env n ->
  Rzk.Term ->
  TermT n ->
  TypeCheck n (TermT n)
typecheckInContext env term expected = do
  coreTerm <- termInContext env term
  typecheck coreTerm expected

termInContext ::
  Distinct n =>
  Convert.Env n ->
  Rzk.Term ->
  TypeCheck n (Term n)
termInContext env term = do
  scope <- asks ctxScope
  pure (Convert.toTerm scope env term)

extendEnv ::
  DExt n l =>
  Rzk.Pattern ->
  NameBinder n l ->
  Convert.Env n ->
  Convert.Env l
extendEnv pattern_ binder env name =
  case lookup name bound of
    Just term -> term
    Nothing -> Foil.sink (env name)
  where
    bound = Convert.bindings pattern_ (Var (Foil.nameOf binder))

emptyEnv :: Convert.Env n
emptyEnv name =
  Hole (Just (markUnresolved name))

validateParsedSequent :: [ParsedDeclaration] -> [Rzk.Term] -> Rzk.Term -> Either String ()
validateParsedSequent declarations hypotheses' goal' = do
  declaredNames <- validateDeclarations [] declarations
  mapM_ (checkKnownTermVars "Rzk tope hypothesis" declaredNames) hypotheses'
  checkKnownTermVars "Rzk tope goal" declaredNames goal'

validateDeclarations :: [String] -> [ParsedDeclaration] -> Either String [String]
validateDeclarations declaredNames [] =
  Right declaredNames
validateDeclarations declaredNames (declaration : declarations) = do
  checkKnownTermVars
    ("Rzk context type for " ++ intercalate ", " (patternNames (parsedBinder declaration)))
    declaredNames
    (parsedType declaration)
  validateDeclarations
    (declaredNames ++ patternNames (parsedBinder declaration))
    declarations

checkKnownTermVars :: String -> [String] -> Rzk.Term -> Either String ()
checkKnownTermVars label declaredNames term =
  case [name | name <- freeVarNames term, name `notElem` declaredNames] of
    [] -> Right ()
    missingNames ->
      Left
        ( "undefined Rzk variable(s) in "
            ++ label
            ++ ": "
            ++ intercalate ", " (nub missingNames)
        )

freeVarNames :: Rzk.Term -> [String]
freeVarNames =
  nub . map (show . varIdent) . collectVarIdents

patternNames :: Rzk.Pattern -> [String]
patternNames =
  nub . map (show . varIdent) . collectVarIdents

collectVarIdents :: Data a => a -> [Rzk.VarIdent]
collectVarIdents value =
  case cast value of
    Just ident -> [ident]
    Nothing -> concat (gmapQ collectVarIdents value)

sequentDeclarations :: SequentCase -> Either String [Declaration]
sequentDeclarations sequent =
  case context sequent of
    [] -> Right (dummyCubeDeclaration : topeAtomDeclarations sequent)
    declarations -> traverse parseCubeDeclaration declarations

dummyCubeDeclaration :: Declaration
dummyCubeDeclaration =
  Declaration {declBinder = "benchdummy", declType = "2", declDeclarationSort = CubeDeclaration}

topeAtomDeclarations :: SequentCase -> [Declaration]
topeAtomDeclarations sequent =
  [ Declaration {declBinder = atom, declType = "TOPE", declDeclarationSort = TopeDeclaration}
    | atom <- nub (concatMap atomNames (hypotheses sequent ++ [goal sequent]))
  ]

parseCubeDeclaration :: String -> Either String Declaration
parseCubeDeclaration declaration =
  case break (== ':') declaration of
    (binder, ':' : ty)
      | not (null (trim binder)) && not (null (trim ty)) ->
          Right Declaration {declBinder = trim binder, declType = trim ty, declDeclarationSort = CubeDeclaration}
    _ -> Left ("unsupported Rzk context declaration " ++ show declaration)

data Declaration = Declaration
  { declBinder :: String,
    declType :: String,
    declDeclarationSort :: DeclarationSort
  }

data DeclarationSort = CubeDeclaration | TopeDeclaration

checkNoDuplicateBinders :: [Declaration] -> Either String ()
checkNoDuplicateBinders declarations =
  case duplicates (concatMap (binderNames . declBinder) declarations) of
    [] -> Right ()
    names -> Left ("duplicate Rzk context binder(s): " ++ intercalate ", " names)

binderNames :: String -> [String]
binderNames [] = []
binderNames text =
  case dropWhile (not . isIdentifierChar) text of
    [] -> []
    rest ->
      let (name, remaining) = span isIdentifierChar rest
       in name : binderNames remaining

duplicates :: [String] -> [String]
duplicates values =
  [value | value <- nub values, length (filter (== value) values) > 1]

isIdentifierChar :: Char -> Bool
isIdentifierChar char =
  isAlphaNum char || char == '_' || char == '-'

checkSupportedTopeFragment :: SequentCase -> Either String ()
checkSupportedTopeFragment sequent
  | any containsUnsupportedIplConnective (hypotheses sequent ++ [goal sequent]) =
      Left "Rzk prover supports only the tope fragment; IPL implication, negation, and equivalence are skipped"
  | otherwise = Right ()

containsUnsupportedIplConnective :: String -> Bool
containsUnsupportedIplConnective formula =
  any (`isInfixOf` formula) ["→", "->", "¬", "↔", "<->"]

atomNames :: String -> [String]
atomNames [] = []
atomNames text =
  case dropWhile (not . isAtomStart) text of
    [] -> []
    rest ->
      let (name, remaining) = span isAtomChar rest
       in if isReservedAtom name
            then atomNames remaining
            else name : atomNames remaining

isAtomStart :: Char -> Bool
isAtomStart char =
  isAsciiLower char || isAsciiUpper char

isAtomChar :: Char -> Bool
isAtomChar char =
  isAlphaNum char || char == '_' || char == '-'

isReservedAtom :: String -> Bool
isReservedAtom atom =
  atom `elem` ["TOP", "BOT", "TOPE"]

isEntailmentFailure :: String -> Bool
isEntailmentFailure message =
  "does not entail" `isInfixOf` message
    || "local context is not included" `isInfixOf` message
    || "is not included in" `isInfixOf` message

isUnsupportedFormulaFailure :: String -> Bool
isUnsupportedFormulaFailure message =
  "undefined variable" `isInfixOf` message
    || "tope params are illegal" `isInfixOf` message
    || "not a subtype of TOPE" `isInfixOf` message
    || "expected type TOPE" `isInfixOf` message
    || "unexpected function type" `isInfixOf` message

trim :: String -> String
trim = dropWhile (== ' ') . reverse . dropWhile (== ' ') . reverse
