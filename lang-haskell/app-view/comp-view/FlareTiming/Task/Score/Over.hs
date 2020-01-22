module FlareTiming.Task.Score.Over (tableScoreOver) where

import Prelude hiding (min)
import Text.Printf (printf)
import Reflex.Dom
import qualified Data.Text as T (Text, pack)
import qualified Data.Map.Strict as Map

import WireTypes.Route (TaskLength(..))
import qualified WireTypes.Point as Norm (NormBreakdown(..))
import qualified WireTypes.Point as Pt (Points(..), StartGate(..))
import qualified WireTypes.Point as Wg (Weights(..))
import qualified WireTypes.Validity as Vy (Validity(..))
import WireTypes.Point
    ( TaskPlacing(..)
    , TaskPoints(..)
    , Breakdown(..)
    , PilotDistance(..)
    , ReachToggle(..)
    , showPilotDistance
    , showTaskDistancePoints
    , showTaskArrivalPoints
    , showTaskLeadingPoints
    , showTaskTimePoints
    , showTaskPointsRounded
    , showTaskPointsDiff
    , showTaskPointsDiffStats
    , showRounded
    , showJumpedTheGunTime
    )
import WireTypes.ValidityWorking (ValidityWorking(..), TimeValidityWorking(..))
import WireTypes.Comp
    ( UtcOffset(..), Discipline(..), MinimumDistance(..)
    , EarlyStart(..), JumpTheGunLimit(..)
    )
import WireTypes.Pilot (Pilot(..), Dnf(..), DfNoTrack(..))
import qualified WireTypes.Pilot as Pilot (DfNoTrackPilot(..))
import FlareTiming.Pilot (showPilot, classOfEarlyStart)
import FlareTiming.Time (timeZone)
import FlareTiming.Task.Score.Show

tableScoreOver
    :: MonadWidget t m
    => Dynamic t UtcOffset
    -> Dynamic t Discipline
    -> Dynamic t EarlyStart
    -> Dynamic t MinimumDistance
    -> Dynamic t [Pt.StartGate]
    -> Dynamic t (Maybe TaskLength)
    -> Dynamic t Dnf
    -> Dynamic t DfNoTrack
    -> Dynamic t (Maybe Vy.Validity)
    -> Dynamic t (Maybe ValidityWorking)
    -> Dynamic t (Maybe Wg.Weights)
    -> Dynamic t (Maybe Pt.Points)
    -> Dynamic t (Maybe TaskPoints)
    -> Dynamic t [(Pilot, Breakdown)]
    -> Dynamic t [(Pilot, Norm.NormBreakdown)]
    -> m ()
tableScoreOver utcOffset hgOrPg early free sgs ln dnf' dfNt _vy vw _wg pt tp sDfs sEx = do
    let dnf = unDnf <$> dnf'
    lenDnf :: Int <- sample . current $ length <$> dnf
    lenDfs :: Int <- sample . current $ length <$> sDfs
    let dnfPlacing =
            (if lenDnf == 1 then TaskPlacing else TaskPlacingEqual)
            . fromIntegral
            $ lenDfs + 1

    let thSpace = elClass "th" "th-space" $ text ""

    let tableClass =
            let tc = "table is-striped is-narrow is-fullwidth" in
            ffor2 hgOrPg sgs (\x gs ->
                let y = T.pack . show $ x in
                y <> (if null gs then " " else " sg ") <> tc)

    let cTimePoints =
            let thc = "th-time-points"
                tdc = "td-time-points"
            in
                ffor2 hgOrPg vw (\x vw' ->
                    maybe
                        (thc, tdc)
                        (\ValidityWorking{time = TimeValidityWorking{..}} ->
                            case (x, gsBestTime) of
                                (HangGliding, Nothing) ->
                                    ( "gr-zero " <> thc
                                    , "gr-zero " <> tdc
                                    )
                                (HangGliding, Just _) -> (thc, tdc)
                                (Paragliding, Nothing) ->
                                    ( "gr-zero " <> thc
                                    , "gr-zero " <> tdc
                                    )
                                (Paragliding, Just _) -> (thc, tdc))
                        vw')

    let cArrivalPoints =
            let thc = "th-arrival-points"
                tdc = "td-arrival-points"
            in
                ffor2 hgOrPg vw (\x vw' ->
                    maybe
                        (thc, tdc)
                        (\ValidityWorking{time = TimeValidityWorking{..}} ->
                            case (x, gsBestTime) of
                                (HangGliding, Nothing) ->
                                    ( "gr-zero " <> thc
                                    , "gr-zero " <> tdc
                                    )
                                (HangGliding, Just _) -> (thc, tdc)
                                (Paragliding, _) -> (thc, tdc))
                        vw')

    let yDiff = ffor2 sEx sDfs (\sEx' sDfs' ->
                    let exs = Map.fromList sEx'
                    in
                        [ let ex = Map.lookup pilot exs
                          in ((\Norm.NormBreakdown{total = p} -> p) <$> ex, p')
                        | (pilot, Breakdown{total = p'}) <- sDfs'
                        ])

    let pointStats = ffor yDiff (uncurry showTaskPointsDiffStats . unzip)

    _ <- elDynClass "table" tableClass $ do
        el "thead" $ do

            el "tr" $ do
                elAttr "th" ("colspan" =: "3") $ text ""
                elAttr "th" ("colspan" =: "6" <> "class" =: "th-speed-section") . dynText
                    $ showSpeedSection <$> ln
                elAttr "th" ("colspan" =: "2" <> "class" =: "th-distance") $ text "Distance Flown"
                elAttr "th" ("colspan" =: "7" <> "class" =: "th-points") $ dynText pointStats

            el "tr" $ do
                elClass "th" "th-norm th-placing" $ text "✓"
                elClass "th" "th-placing" $ text "Place"
                elClass "th" "th-pilot" $ text "###-Pilot"
                elClass "th" "th-start-early" $ text "Early ¶"
                elClass "th" "th-start-start" $ text "Start"
                elClass "th" "th-start-gate" $ text "Gate"
                elClass "th" "th-time-end" $ text "End"
                elClass "th" "th-time" $ text "Time ‖"
                elClass "th" "th-speed" $ text "Speed"

                elClass "th" "th-min-distance" $ text "Min"
                elClass "th" "th-best-distance" $ text "Reach †"

                elClass "th" "th-distance-points" $ text "Distance"
                elDynClass "th" (fst <$> cTimePoints) $ text "Time"
                elClass "th" "th-leading-points" $ text "Lead"
                elDynClass "th" (fst <$> cArrivalPoints) $ text "Arrival"
                elClass "th" "th-total-points" $ text "Total"
                elClass "th" "th-norm th-total-points" $ text "✓"
                elClass "th" "th-norm th-diff" $ text "Δ"

            elClass "tr" "tr-allocation" $ do
                elAttr "th" ("colspan" =: "3" <> "class" =: "th-allocation") $ text "Available Points (Units)"
                elAttr "th" ("colspan" =: "5") $ text ""
                elClass "th" "th-speed-units" $ text "(km/h)"
                elClass "th" "th-min-distance-units" $ text "(km)"
                elClass "th" "th-best-distance-units" $ text "(km)"

                elClass "th" "th-distance-alloc" . dynText $
                    maybe
                        ""
                        ( (\x -> showTaskDistancePoints (Just x) x)
                        . Pt.distance
                        )
                    <$> pt

                elClass "th" "th-time-alloc" . dynText $
                    maybe
                        ""
                        ( (\x -> showTaskTimePoints (Just x) x)
                        . Pt.time
                        )
                    <$> pt

                elClass "th" "th-leading-alloc" . dynText $
                    maybe
                        ""
                        ( (\x -> showTaskLeadingPoints (Just x) x)
                        . Pt.leading
                        )
                    <$> pt

                elClass "th" "th-arrival-alloc" . dynText $
                    maybe
                        ""
                        ( (\x -> showTaskArrivalPoints (Just x) x)
                        . Pt.arrival
                        )
                    <$> pt

                elClass "th" "th-task-alloc" . dynText $
                    maybe
                        ""
                        (\x -> showTaskPointsRounded (Just x) x)
                    <$> tp

                thSpace
                thSpace

        _ <- el "tbody" $ do
            _ <-
                simpleList
                    sDfs
                    (pointRow
                        (earliest <$> early)
                        (snd <$> cTimePoints)
                        (snd <$> cArrivalPoints)
                        utcOffset
                        free
                        dfNt
                        pt
                        tp
                        (Map.fromList <$> sEx))

            dnfRows dnfPlacing dnf'
            return ()

        let tdFoot = elAttr "td" ("colspan" =: "18")
        let foot = el "tr" . tdFoot . text

        el "tfoot" $ do
            foot "* Any points so annotated are the maximum attainable."
            foot "† How far along the course, reaching goal or elsewhere. The distance reached in the air can be further than the distance at landing."
            foot "‖ \"Time\" is the time across the speed section from time zero of the start gate taken."
            foot "¶ \"Early\" how much earlier than the start did this pilot jump the gun?"
            foot "☞ Pilots without a tracklog but given a distance by the scorer."
            foot "✓ An expected value as calculated by the official scoring program, FS."
            foot "Δ A difference between a value and an expected value."
            dyn_ $ ffor hgOrPg (\case
                HangGliding -> return ()
                Paragliding -> do
                    el "tr" . tdFoot $ do
                            elClass "span" "pg not" $ text "Arrival"
                            text " points are not scored for paragliding."
                    el "tr" . tdFoot $ do
                            elClass "span" "pg not" $ text "Effort"
                            text " or distance difficulty is not scored for paragliding.")
            dyn_ $ ffor sgs (\gs ->
                if null gs then do
                    el "tr" . tdFoot $ do
                            text "With no "
                            elClass "span" "sg not" $ text "gate"
                            text " to start the speed section "
                            elClass "span" "sg not" $ text "time"
                            text ", the pace clock starts ticking whenever the pilot starts."
                else return ())
            dyn_ $ ffor hgOrPg (\case
                HangGliding ->
                    dyn_ $ ffor vw (\vw' ->
                        maybe
                            (return ())
                            (\ValidityWorking{time = TimeValidityWorking{..}} ->
                                case gsBestTime of
                                    Just _ -> return ()
                                    Nothing -> el "tr" . tdFoot $ do
                                        text "No one made it through the speed section to get "
                                        elClass "span" "gr-zero" $ text "time"
                                        text " and "
                                        elClass "span" "gr-zero" $ text "arrival"
                                        text " points.")
                            vw'
                        )
                Paragliding ->
                    dyn_ $ ffor vw (\vw' ->
                        maybe
                            (return ())
                            (\ValidityWorking{time = TimeValidityWorking{..}} ->
                                case gsBestTime of
                                    Just _ -> return ()
                                    Nothing -> el "tr" . tdFoot $ do
                                        text "No one made it through the speed section to get "
                                        elClass "span" "gr-zero" $ text "time"
                                        text " points.")
                            vw'
                        ))

    return ()

pointRow
    :: MonadWidget t m
    => Dynamic t JumpTheGunLimit
    -> Dynamic t T.Text
    -> Dynamic t T.Text
    -> Dynamic t UtcOffset
    -> Dynamic t MinimumDistance
    -> Dynamic t DfNoTrack
    -> Dynamic t (Maybe Pt.Points)
    -> Dynamic t (Maybe TaskPoints)
    -> Dynamic t (Map.Map Pilot Norm.NormBreakdown)
    -> Dynamic t (Pilot, Breakdown)
    -> m ()
pointRow earliest cTime cArrival utcOffset free dfNt pt tp sEx x = do
    let tz = timeZone <$> utcOffset
    let pilot = fst <$> x
    let xB = snd <$> x
    let y = ffor3 pilot sEx x (\pilot' sEx' (_, Breakdown{total = p'}) ->
                case Map.lookup pilot' sEx' of
                    Nothing -> ("", "", "")
                    Just
                        Norm.NormBreakdown
                            { place = nth
                            , total = p@(TaskPoints pts)
                            } -> (showRank nth, showRounded pts, showTaskPointsDiff p p'))

    let yRank = ffor y $ \(yr, _, _) -> yr
    let yScore = ffor y $ \(_, ys, _) -> ys
    let yDiff = ffor y $ \(_, _, yd) -> yd

    let xReach = reach <$> xB
    let points = breakdown . snd <$> x
    let v = velocity . snd <$> x
    let jtg = jump . snd <$> x

    let classPilot = ffor2 pilot dfNt (\p (DfNoTrack ps) ->
                        let n = showPilot p in
                        if p `elem` (Pilot.pilot <$> ps)
                           then ("pilot-dfnt", n <> " ☞ ")
                           else ("", n))

    let classEarly = ffor2 earliest jtg classOfEarlyStart

    let awardFree = ffor2 free xReach (\(MinimumDistance f) pd ->
            let c = "td-best-distance" in
            maybe
                (c, "")
                (\ReachToggle{extra = PilotDistance r} ->
                    if r >= f then (c, "") else
                       let c' = c <> " award-free"
                       in (c', T.pack $ printf "%.1f" f))
                pd)

    elDynClass "tr" (fst <$> classPilot) $ do
        elClass "td" "td-norm td-placing" $ dynText yRank
        elClass "td" "td-placing" . dynText $ showRank . place <$> xB
        elClass "td" "td-pilot" . dynText $ snd <$> classPilot
        elDynClass "td" classEarly . dynText $ showJumpedTheGunTime <$> jtg
        elClass "td" "td-start-start" . dynText $ (maybe "" . showSs) <$> tz <*> v
        elClass "td" "td-start-gate" . dynText $ (maybe "" . showGs) <$> tz <*> v
        elClass "td" "td-time-end" . dynText $ (maybe "" . showEs) <$> tz <*> v
        elClass "td" "td-time" . dynText $ maybe "" showGsVelocityTime <$> v
        elClass "td" "td-speed" . dynText $ maybe "" showVelocityVelocity <$> v

        elClass "td" "td-min-distance" . dynText $ snd <$> awardFree
        elDynClass "td" (fst <$> awardFree) . dynText
            $ maybe "" (showPilotDistance 1 . extra) <$> xReach

        elClass "td" "td-distance-points" . dynText
            $ showMax Pt.distance showTaskDistancePoints pt points
        elDynClass "td" cTime . dynText
            $ showMax Pt.time showTaskTimePoints pt points
        elClass "td" "td-leading-points" . dynText
            $ showMax Pt.leading showTaskLeadingPoints pt points
        elDynClass "td" cArrival . dynText
            $ showMax Pt.arrival showTaskArrivalPoints pt points

        elClass "td" "td-total-points" . dynText
            $ zipDynWith showTaskPointsRounded tp (total <$> xB)

        elClass "td" "td-norm td-total-points" $ dynText yScore
        elClass "td" "td-norm td-total-points" $ dynText yDiff

dnfRows
    :: MonadWidget t m
    => TaskPlacing
    -> Dynamic t Dnf
    -> m ()
dnfRows place ps' = do
    let ps = unDnf <$> ps'
    len <- sample . current $ length <$> ps
    let p1 = take 1 <$> ps
    let pN = drop 1 <$> ps

    case len of
        0 -> do
            return ()
        1 -> do
            _ <- simpleList ps (dnfRow place (Just 1))
            return ()
        n -> do
            _ <- simpleList p1 (dnfRow place (Just n))
            _ <- simpleList pN (dnfRow place Nothing)
            return ()

dnfRow
    :: MonadWidget t m
    => TaskPlacing
    -> Maybe Int
    -> Dynamic t Pilot
    -> m ()
dnfRow place rows pilot = do
    let dnfMajor =
            case rows of
                Nothing -> return ()
                Just n -> do
                    elAttr
                        "td"
                        ( "rowspan" =: (T.pack $ show n)
                        <> "colspan" =: "12"
                        <> "class" =: "td-dnf"
                        )
                        $ text "DNF"
                    return ()

    let dnfMinor =
            case rows of
                Nothing -> return ()
                Just n -> do
                    elAttr
                        "td"
                        ( "rowspan" =: (T.pack $ show n)
                        <> "colspan" =: "2"
                        <> "class" =: "td-dnf"
                        )
                        $ text "DNF"
                    return ()

    elClass "tr" "tr-dnf" $ do
        elClass "td" "td-norm td-placing" $ text ""
        elClass "td" "td-placing" . text $ showRank place
        elClass "td" "td-pilot" . dynText $ showPilot <$> pilot
        dnfMajor
        elClass "td" "td-total-points" $ text "0"
        dnfMinor
        return ()
