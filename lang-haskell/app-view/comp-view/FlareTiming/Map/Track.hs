{-# OPTIONS_GHC -fno-warn-partial-type-signatures #-}

module FlareTiming.Map.Track (tableTrack) where

-- TODO: Find out why hiding Debug.Trace.debugEvent doesn't work.
-- Ambiguous occurrence ‘traceEvent’
-- It could refer to either ‘Debug.Trace.traceEvent’,
--                           imported from ‘Debug.Trace’ at ...
--                           or ‘Reflex.Dom.traceEvent’,
--                           imported from ‘Reflex.Dom’ at ...
--                           (and originally defined in ‘Reflex.Class’)
-- import Debug.Trace hiding (debugEvent)
-- import Reflex.Dom
-- import qualified Debug.Trace as DT
import Prelude hiding (map)
import Text.Printf (printf)
import Reflex.Dom
import qualified Data.Text as T (Text, pack)

import WireTypes.Cross (TrackFlyingSection(..), TrackScoredSection(..))
import WireTypes.Pilot (Pilot(..), pilotIdsWidth)
import WireTypes.Comp (UtcOffset(..))
import FlareTiming.Pilot (showPilot, hashIdHyphenPilot)

tableTrack
    :: MonadWidget t m
    => Dynamic t UtcOffset
    -> Dynamic t [(Pilot, ((Pilot, Maybe TrackFlyingSection), (Pilot, Maybe TrackScoredSection)))]
    -> m ()
tableTrack _utc xs = do
    let w = ffor xs (pilotIdsWidth . fmap fst)
    _ <- elClass "table" "table is-striped" $ do
            el "thead" $ do
                el "tr" $ do
                    elAttr "th" ("rowspan" =: "2") . dynText $ ffor w hashIdHyphenPilot
                    el "th" $ text ""
                    elAttr "th" ("colspan" =: "3") $ text "Fixes"
                    return ()
                el "tr" $ do
                    el "th" $ text "Flying"
                    el "th" $ text "Scored"
                    el "th" $ text "Unscored"
                    return ()
            el "tbody" $ simpleList xs (row w)

    return ()

row
    :: MonadWidget t m
    => Dynamic t Int
    -> Dynamic t (Pilot, ((Pilot, Maybe TrackFlyingSection), (Pilot, Maybe TrackScoredSection)))
    -> m ()
row w x = do
    let td = el "td" . dynText
    let p = fst <$> x
    let flying = snd . fst . snd <$> x
    let scored = snd . snd . snd <$> x
    el "tr" $ do
        td $ ffor2 w p showPilot
        td $ ffor flying (maybe "" showTrackFlyingSection)
        td $ ffor scored (maybe "" showTrackScoredSection)
        td $ ffor2 flying scored showUnscored

showTrackFlyingSection :: TrackFlyingSection -> T.Text
showTrackFlyingSection TrackFlyingSection{flyingFixes} =
    maybe "" (T.pack . show) flyingFixes

showTrackScoredSection :: TrackScoredSection -> T.Text
showTrackScoredSection TrackScoredSection{scoredFixes} =
    maybe "" (T.pack . show) scoredFixes

showUnscored :: Maybe TrackFlyingSection -> Maybe TrackScoredSection -> T.Text
showUnscored (Just TrackFlyingSection{flyingFixes = Just (_, fN)}) (Just TrackScoredSection{scoredFixes = Just (_, sN)}) =
    T.pack . printf "%d" $ fN - sN
showUnscored _ _ = ""