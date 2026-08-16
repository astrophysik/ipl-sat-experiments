module Corpus (Entailment (..), SequentCase (..), readSequentCase) where

import Data.Aeson (Value (Array, Object, String))
import qualified Data.Aeson.Key as Key
import qualified Data.Aeson.KeyMap as KeyMap
import qualified Data.Text as Text
import qualified Data.Vector as Vector
import qualified Data.Yaml as Yaml

data Entailment = Underivable | Derivable | Unsolved deriving (Show)

data PremisesConsistency = Consistent | Inconsistent deriving (Show)

data SequentCase = SequentCase
  { caseId :: String,
    source :: String,
    equententailment :: Entailment,
    consistency :: PremisesConsistency,
    context :: [String],
    hypotheses :: [String],
    goal :: String
  } deriving (Show)

lookupField :: String -> KeyMap.KeyMap Value -> Maybe Value
lookupField field object =
  KeyMap.lookup (Key.fromString field) object

extractField :: String -> KeyMap.KeyMap Value -> Either String Value
extractField field object =
  case lookupField field object of
    Just value -> Right value
    Nothing -> Left ("Missing " ++ field ++ " field")

extractObjectField :: String -> KeyMap.KeyMap Value -> Either String (KeyMap.KeyMap Value)
extractObjectField field object = do
  value <- extractField field object
  case value of
    (Object obj) -> Right obj
    _ -> Left $ field ++ " field must be a yaml object"

extractStringField :: String -> KeyMap.KeyMap Value -> Either String String
extractStringField field object = do
  value <- extractField field object
  case value of
    String text -> Right $ Text.unpack text
    _ -> Left $ field ++ " field must be a string"

extractArrayStringField :: String -> KeyMap.KeyMap Value -> Either String [String]
extractArrayStringField field object = do
  value <- extractField field object
  case value of
    Array values ->
      sequence $ map valueToString (Vector.toList values)
    _ -> Left $ field ++ " field must be a YAML array"
  where
    valueToString value =
      case value of
        String text ->
          Right $ Text.unpack text
        _ -> Left $ "unepexted value" -- todo

parseEntailment :: String -> Either String Entailment
parseEntailment string =
  case string of
    "derivable" -> Right Derivable
    "underivable" -> Right Underivable
    "unsolved" -> Right Unsolved
    _ -> Left $ "Wrong entailment value"

parseConsistency :: String -> Either String PremisesConsistency
parseConsistency string =
  case string of
    "consistent" -> Right Consistent
    "inconsistent" -> Right Inconsistent
    _ -> Left $ "Wrong consistency value"

extractSequentCase :: KeyMap.KeyMap Value -> Either String SequentCase
extractSequentCase object = do
  sequentId <- extractStringField "id" object
  sequentSource <- extractStringField "source" object

  input <- extractObjectField "input" object
  sequentContext <- extractArrayStringField "context" input
  sequentHypotheses <- extractArrayStringField "hypotheses" input
  sequentGoal <- extractStringField "goal" input

  expected <- extractObjectField "expected" object
  sequentEntailment <- extractStringField "entailment" expected >>= parseEntailment
  sequentConsistency <- extractStringField "premises_consistency" expected >>= parseConsistency

  pure $ SequentCase {caseId = sequentId, source = sequentSource, equententailment = sequentEntailment, consistency = sequentConsistency, context = sequentContext, hypotheses = sequentHypotheses, goal = sequentGoal}

readSequentCase :: FilePath -> IO (Either String (Maybe SequentCase))
readSequentCase filePath = do
  result <- Yaml.decodeFileEither filePath
  case result of
    Left err ->
      pure $ Left $ "Cannot decode file " ++ filePath ++ " with error " ++ (show err)
    Right (Object object) ->
      case extractStringField "kind" object of
        Left err -> pure $ Left err
        Right "sequent" -> pure $ Just <$> extractSequentCase object
        Right _ -> pure $ Right Nothing
    Right _ -> 
      pure $ Left $ "File should contain a YAML object " ++ filePath 
