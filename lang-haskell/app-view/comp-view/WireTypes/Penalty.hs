{-# LANGUAGE DuplicateRecordFields #-}

module WireTypes.Penalty
    ( PointPenalty(..)
    , Add, Mul, Reset
    , PenaltySeqs(..)
    , effectiveMul, effectiveAdd, effectiveReset
    , showEffectiveMul, showEffectiveAdd, showEffectiveReset
    ) where

import Text.Printf (printf)
import Data.Maybe (listToMaybe, isJust)
import Data.List (sort)
import GHC.Generics (Generic)
import Data.Aeson ((.:), FromJSON(..), withObject)
import qualified Data.Text as T (Text, pack)

data Add
data Mul
data Reset

data PointPenalty a where
    PenaltyFraction :: Double -> PointPenalty Mul
    PenaltyPoints :: Double -> PointPenalty Add
    PenaltyReset :: Maybe Int -> PointPenalty Reset

instance Eq (PointPenalty a) where
    (==) (PenaltyFraction x) (PenaltyFraction y) = x == y
    (==) (PenaltyPoints x) (PenaltyPoints y) = x == y
    (==) (PenaltyReset x) (PenaltyReset y) = x == y

instance Ord (PointPenalty a) where
    compare (PenaltyFraction x) (PenaltyFraction y) = x `compare` y
    compare (PenaltyPoints x) (PenaltyPoints y) = x `compare` y
    compare (PenaltyReset x) (PenaltyReset y) = x `compare` y

instance Show (PointPenalty a) where
    show (PenaltyFraction 1) = "(* id)"
    show (PenaltyPoints 0) = "(+ id)"
    show (PenaltyReset Nothing) = "(= id)"

    show (PenaltyFraction x) = printf "(* %.3f)" x
    show (PenaltyPoints x) =
        if x < 0
           then printf "(- %.3f)" (abs x)
           else printf "(+ %.3f)" x
    show (PenaltyReset (Just x)) = printf "(= %d)" x

instance Num (PointPenalty Mul) where
    (+) _ _ = error "(+) is not defined for PointPenalty Mul."
    (*) (PenaltyFraction a) (PenaltyFraction b) = PenaltyFraction $ a * b
    negate (PenaltyFraction x) = PenaltyFraction $ negate x
    abs (PenaltyFraction x) = PenaltyFraction $ abs x
    signum (PenaltyFraction x) = PenaltyFraction $ signum x
    fromInteger x = PenaltyFraction $ fromInteger x

instance Num (PointPenalty Add) where
    (+) (PenaltyPoints a) (PenaltyPoints b) = PenaltyPoints $ a + b
    (*) _ _ = error "(*) is not defined for PointPenalty Add."
    negate (PenaltyPoints x) = PenaltyPoints $ negate x
    abs (PenaltyPoints x) = PenaltyPoints $ abs x
    signum (PenaltyPoints x) = PenaltyPoints $ signum x
    fromInteger x = PenaltyPoints $ fromInteger x

instance Num (PointPenalty Reset) where
    (+) x@(PenaltyReset (Just _)) (PenaltyReset Nothing) = x
    (+) (PenaltyReset Nothing) x = x
    (+) _ _ = partialNum

    (*) x@(PenaltyReset (Just _)) (PenaltyReset Nothing) = x
    (*) (PenaltyReset Nothing) x = x
    (*) _ _ = partialNum

    negate (PenaltyReset (Just x)) = PenaltyReset . Just $ negate x
    negate x = x

    abs (PenaltyReset (Just x)) = PenaltyReset . Just $ abs x
    abs x = x

    signum _ = PenaltyReset Nothing

    fromInteger x =
        PenaltyReset $
        if x < 0 then Nothing else Just $ fromIntegral x

partialNum :: a
partialNum = error "(+) and (*) are partial for PointPenalty Reset."

instance FromJSON (PointPenalty Mul) where
    parseJSON = withObject "PenaltyPoints" $ \o ->
        PenaltyFraction <$> o .: "penalty-fraction"

instance FromJSON (PointPenalty Add) where
    parseJSON = withObject "PenaltyPoints" $ \o ->
        PenaltyPoints <$> o .: "penalty-points"

instance FromJSON (PointPenalty Reset) where
    parseJSON = withObject "PenaltyPoints" $ \o ->
        PenaltyReset <$> o .: "penalty-reset"

data PenaltySeqs =
    PenaltySeqs
        { muls :: [PointPenalty Mul]
        , adds :: [PointPenalty Add]
        , resets :: [PointPenalty Reset]
        }
    deriving (Eq, Ord, Show, Generic, FromJSON)

effectiveMul :: [PointPenalty Mul] -> PointPenalty Mul
effectiveMul = product

effectiveAdd :: [PointPenalty Add] -> PointPenalty Add
effectiveAdd = sum

effectiveReset :: [PointPenalty Reset] -> PointPenalty Reset
effectiveReset =
    maybe (PenaltyReset Nothing) id
    . listToMaybe
    . take 1
    . sort
    . filter isJustReset

isJustReset :: PointPenalty Reset -> Bool
isJustReset (PenaltyReset x) = isJust x

showEffectiveMul :: [PointPenalty Mul] -> T.Text
showEffectiveMul = T.pack . show . effectiveMul


showEffectiveAdd :: [PointPenalty Add] -> T.Text
showEffectiveAdd = T.pack . show . effectiveAdd

showEffectiveReset :: [PointPenalty Reset] -> T.Text
showEffectiveReset = T.pack . show . effectiveReset
