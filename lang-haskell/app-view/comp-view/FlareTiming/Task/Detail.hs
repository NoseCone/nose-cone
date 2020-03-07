module FlareTiming.Task.Detail (taskDetail) where

import Prelude hiding (map)
import Reflex
import Reflex.Dom
import qualified Data.Text as T (Text, intercalate, pack)
import Data.Time.LocalTime (TimeZone)

import WireTypes.ZoneKind (Shape(..))
import WireTypes.Pilot
    (Pilot(..), Nyp(..), Dnf(..), DfNoTrack(..), Penal(..), nullPilot)
import qualified WireTypes.Comp as Comp
import WireTypes.Comp
    ( UtcOffset(..), Nominal(..), Comp(..), Task(..), TaskStop(..), ScoreBackTime
    , EarthModel(..), EarthMath(..)
    , getRaceRawZones, getStartGates, getOpenShape, getSpeedSection
    , showScoreBackTime
    )
import WireTypes.Route (TaskLength(..), taskLength, taskLegs, showTaskDistance)
import WireTypes.Cross (TrackFlyingSection(..), TrackScoredSection(..))
import WireTypes.Point (Allocation(..))
import WireTypes.Validity (Validity(..))
import FlareTiming.Comms
    ( getTaskScore, getTaskNormScore
    , getTaskBolsterStats, getTaskBonusBolsterStats
    , getTaskReach, getTaskBonusReach
    , getTaskEffort, getTaskLanding, getTaskNormLanding
    , getTaskArrival, getTaskNormArrival, getTaskLead, getTaskTime
    , getTaskValidityWorking, getTaskNormValidityWorking
    , getTaskLengthNormSphere
    , getTaskLengthSphericalEdge
    , getTaskLengthEllipsoidEdge
    , getTaskLengthProjectedEdgeSpherical
    , getTaskPilotDnf, getTaskPilotNyp, getTaskPilotDfNoTrack
    , getTaskPilotTrack
    , getTaskPilotTrackFlyingSection, getTaskFlyingSectionTimes
    , getTaskPilotTrackScoredSection
    , getTaskPilotTag
    , emptyRoute
    )
import FlareTiming.Breadcrumb (crumbTask)
import FlareTiming.Events (IxTask(..))
import FlareTiming.Map.View (viewMap)
import FlareTiming.Plot.Weight (weightPlot)
import FlareTiming.Plot.Reach (reachPlot)
import FlareTiming.Plot.Effort (effortPlot)
import FlareTiming.Plot.Time (timePlot)
import FlareTiming.Plot.Lead (leadPlot)
import FlareTiming.Plot.Arrival (arrivalPlot)
import FlareTiming.Plot.Valid (validPlot)
import qualified FlareTiming.Turnpoint as TP (getName)
import FlareTiming.Nav.TabTask (TaskTab(..), tabsTask)
import FlareTiming.Nav.TabScore (ScoreTab(..), tabsScore)
import FlareTiming.Nav.TabPlot (PlotTab(..), tabsPlot)
import FlareTiming.Nav.TabPlotLead (PlotLeadTab(..), tabsPlotLead)
import FlareTiming.Nav.TabBasis (BasisTab(..), tabsBasis)
import FlareTiming.Task.Score.Over (tableScoreOver)
import FlareTiming.Task.Score.Penal (tableScorePenal)
import FlareTiming.Task.Score.Split (tableScoreSplit)
import FlareTiming.Task.Score.Reach (tableScoreReach)
import FlareTiming.Task.Score.Effort (tableScoreEffort)
import FlareTiming.Task.Score.Speed (tableScoreSpeed)
import FlareTiming.Task.Score.Time (tableScoreTime)
import FlareTiming.Task.Score.Arrive (tableScoreArrive)
import FlareTiming.Task.Geo (tableGeo)
import FlareTiming.Task.Turnpoints (tableTask)
import FlareTiming.Task.Absent (tableAbsent)
import FlareTiming.Task.Validity (viewValidity)
import FlareTiming.Time (showT, timeZone)

raceNote :: T.Text
raceNote = "* A clock for each start gate"

elapsedNote :: T.Text
elapsedNote = "* Each pilot on their own clock"

openNote :: Maybe Shape -> T.Text
openNote (Just Vector{}) = " open distance on a heading"
openNote (Just Star{}) = " open distance"
openNote _ = ""

showStop :: TimeZone -> TaskStop -> T.Text
showStop tz TaskStop{..} = showT tz announced

showRetro :: TimeZone -> TaskStop -> T.Text
showRetro tz TaskStop{..} = showT tz retroactive

taskTileZones
    :: MonadWidget t m
    => Dynamic t UtcOffset
    -> Dynamic t (Maybe ScoreBackTime)
    -> Dynamic t Task
    -> Dynamic t (Maybe TaskLength)
    -> m ()
taskTileZones utcOffset sb t len = do
    tz <- sample . current $ timeZone <$> utcOffset
    let xs = getRaceRawZones <$> t
    let zs = (fmap . fmap) TP.getName xs
    let title = T.intercalate "-" <$> zs
    let ss = getSpeedSection <$> t
    let gs = length . getStartGates <$> t
    let d = ffor len (maybe "" $ \TaskLength{..} -> showTaskDistance taskRoute)
    let stp = stopped <$> t

    let boxClass =
            ffor stp (\x ->
                let c = "tile is-child box" in
                c <> maybe "" (const " notification is-danger") x)

    elClass "div" "tile" $ do
        elClass "div" "tile is-parent" $ do
            elDynClass "div" boxClass $ do
                elAttr "p" ("class" =: "level title is-3" <> "style" =: "overflow: hidden") $ do
                    elClass "span" "level-item level-left" $ do
                        dynText title

                dyn_ $ ffor ss (\case
                    Just _ -> do
                        let kind = ffor gs (\case
                                    0 -> " elapsed time*"
                                    1 -> " race to goal* with a single start gate"
                                    n -> " race to goal* with " <> (T.pack . show $ n) <> " start gates")

                        let sideNote = ffor gs (\case 0 -> elapsedNote; _ -> raceNote)

                        elClass "p" "level subtitle is-6" $ do
                            elClass "span" "level-item level-left" $ do
                                dynText d
                                dynText $ kind

                            elClass "span" "level-item level-right" $
                                dynText $ sideNote

                    Nothing -> do
                        let openKind = openNote . getOpenShape <$> t

                        elClass "p" "level subtitle is-6" $ do
                            elClass "span" "level-item level-left" $ do
                                dynText d
                                dynText $ openKind)

                dyn_ $ ffor2 stp sb (\x y ->
                    case x of
                        Nothing -> return ()
                        Just x' -> do
                            let stop = "Stopped at " <> showStop tz x' <> "†"

                            elClass "p" "level subtitle is-6" $ do
                                elClass "span" "level-item level-left" $ do
                                            elClass "span" "level-item level-right" $
                                                el "strong" $ text stop

                                case y of
                                    Nothing -> return ()
                                    Just y' -> do
                                        let back =
                                                "† Scored back by "
                                                <> (T.pack . showScoreBackTime $ y')
                                                <> " to "
                                                <> showRetro tz x'

                                        elClass "span" "level-item level-right" $
                                            el "strong" $ text back)

taskDetail
    :: MonadWidget t m
    => IxTask
    -> Dynamic t Comp
    -> Dynamic t Nominal
    -> Dynamic t Task
    -> Dynamic t (Maybe Validity)
    -> Dynamic t (Maybe Validity)
    -> Dynamic t (Maybe Allocation)
    -> m (Event t IxTask)

taskDetail ix@(IxTask _) comp nom task vy vyNorm alloc = do
    let utc = utcOffset <$> comp
    let sb = scoreBack <$> comp
    let hgOrPg = discipline <$> comp
    let free' = free <$> nom
    let sgs = startGates <$> task
    let penalAuto = Penal . Comp.penalsAuto <$> task
    let penal = Penal . Comp.penals <$> task
    let tweak = Comp.taskTweak <$> task
    let early = earlyStart <$> task
    pb <- getPostBuild
    sDf <- holdDyn [] =<< getTaskScore ix pb
    sEx <- holdDyn [] =<< getTaskNormScore ix pb
    reachStats <- holdDyn Nothing =<< (fmap Just <$> getTaskBolsterStats ix pb)
    bonusStats <- holdDyn Nothing =<< (fmap Just <$> getTaskBonusBolsterStats ix pb)
    reach <- holdDyn Nothing =<< (fmap Just <$> getTaskReach ix pb)
    bonusReach <- holdDyn Nothing =<< (fmap Just <$> getTaskBonusReach ix pb)
    ef <- holdDyn Nothing =<< (fmap Just <$> getTaskEffort ix pb)
    lg <- holdDyn Nothing =<< (getTaskLanding ix pb)
    lgN <- holdDyn Nothing =<< (getTaskNormLanding ix pb)
    av <- holdDyn Nothing =<< (fmap Just <$> getTaskArrival ix pb)
    avN <- holdDyn Nothing =<< (fmap Just <$> getTaskNormArrival ix pb)
    ld <- holdDyn Nothing =<< (fmap Just <$> getTaskLead ix pb)
    sd <- holdDyn Nothing =<< (fmap Just <$> getTaskTime ix pb)
    ft <- holdDyn Nothing =<< (fmap Just <$> getTaskFlyingSectionTimes ix pb)
    vw <- holdDyn Nothing =<< getTaskValidityWorking ix pb
    vwNorm <- holdDyn Nothing =<< getTaskNormValidityWorking ix pb
    nyp <- holdDyn (Nyp []) =<< getTaskPilotNyp ix pb
    dnf <- holdDyn (Dnf []) =<< getTaskPilotDnf ix pb
    dfNt <- holdDyn (DfNoTrack []) =<< getTaskPilotDfNoTrack ix pb

    sphericalRoutes <- holdDyn emptyRoute =<< getTaskLengthSphericalEdge ix pb
    ellipsoidRoutes <- holdDyn emptyRoute =<< getTaskLengthEllipsoidEdge ix pb
    let earthMathRoutes = ffor3 comp sphericalRoutes ellipsoidRoutes (\Comp{..} s e ->
            case (earth, earthMath) of
                (EarthAsSphere{}, Haversines) -> s
                (EarthAsEllipsoid{}, Vincenty) -> e
                (EarthAsEllipsoid{}, AndoyerLambert) -> e
                (EarthAsEllipsoid{}, ForsytheAndoyerLambert) -> e
                (EarthAsEllipsoid{}, FsAndoyer) -> e
                _ -> s)

    planarRoute <- holdDyn Nothing =<< getTaskLengthProjectedEdgeSpherical ix pb
    normRoute <- holdDyn Nothing =<< getTaskLengthNormSphere ix pb

    let ln = taskLength <$> earthMathRoutes
    let legs = taskLegs <$> earthMathRoutes

    let ps = (fmap . fmap) points alloc
    let tp = (fmap . fmap) taskPoints alloc
    let wg = (fmap . fmap) weight alloc

    taskTileZones utc sb task ln
    es <- crumbTask ix task comp
    tabTask <- tabsTask

    let taskTabScoreContent = do
            tabScore <- tabsScore
            let tableScoreHold =
                    elAttr "div" ("id" =: "score-overview") $
                        tableScoreOver utc hgOrPg early free' sgs ln dnf dfNt vy vw wg ps tp sDf sEx
            _ <- widgetHold tableScoreHold $
                    (\case
                        ScoreTabOver ->
                            tableScoreHold

                        ScoreTabPenal ->
                            elAttr "div" ("id" =: "score-penal") $
                            tableScorePenal hgOrPg early sgs ln dnf dfNt vy vw wg ps tp sDf sEx
                        ScoreTabSplit ->
                            elAttr "div" ("id" =: "score-points") $
                                tableScoreSplit utc hgOrPg free' sgs ln dnf dfNt vy vw wg ps tp sDf sEx
                        ScoreTabReach ->
                            elAttr "div" ("id" =: "score-reach") $
                                tableScoreReach utc hgOrPg free' sgs ln dnf dfNt vy vw wg ps tp sDf sEx
                        ScoreTabEffort ->
                            elAttr "div" ("id" =: "score-effort") $
                                tableScoreEffort utc hgOrPg free' sgs ln dnf dfNt vy vw wg ps tp sDf sEx lg lgN
                        ScoreTabSpeed ->
                            elAttr "div" ("id" =: "score-speed") $
                                tableScoreSpeed utc hgOrPg free' sgs ln dnf dfNt vy vw wg ps tp sDf sEx
                        ScoreTabTime ->
                            elAttr "div" ("id" =: "score-time") $
                                tableScoreTime utc hgOrPg free' sgs ln dnf dfNt vy vw wg ps tp sDf sEx
                        ScoreTabArrive ->
                            elAttr "div" ("id" =: "score-arrival") $
                                tableScoreArrive utc hgOrPg free' sgs ln dnf dfNt vy vw wg ps tp sDf sEx)

                    <$> tabScore

            return ()

    _ <- widgetHold taskTabScoreContent $
            (\case
                TaskTabTask -> tableTask utc task legs

                TaskTabMap -> mdo
                    p <- viewMap utc ix task sphericalRoutes ellipsoidRoutes planarRoute normRoute pt
                    p' <- holdDyn nullPilot p

                    tfs <- getTaskPilotTrackFlyingSection ix p
                    tfs' <- holdDyn (nullPilot, Nothing) (attachPromptlyDyn p' tfs)

                    tss <- getTaskPilotTrackScoredSection ix p
                    tss' <- holdDyn (nullPilot, Nothing) (attachPromptlyDyn p' tss)

                    tts <- holdUniqDyn $ zipDynWith (,) tfs' tss'
                    ptfs <- holdUniqDyn $ zipDynWith (,) p' tts

                    tag <- getTaskPilotTag ix p
                    tag' <- holdDyn (nullPilot, []) (attachPromptlyDyn p' tag)
                    tag'' <- holdUniqDyn tag'

                    trk <- getTaskPilotTrack ix p
                    trk' <- holdDyn (nullPilot, []) (attachPromptlyDyn p' trk)
                    trk'' <- holdUniqDyn trk'

                    tt <- holdUniqDyn $ zipDynWith (,) trk'' tag''

                    let pt =
                            push readyTrack
                            $ attachPromptlyDyn ptfs (updated tt)

                    return ()

                TaskTabScore -> taskTabScoreContent

                TaskTabPlot -> do
                    tabPlot <- tabsPlot
                    let plotSplit = weightPlot hgOrPg tweak vy vw alloc ln
                    _ <- widgetHold (plotSplit) $
                            (\case
                                PlotTabSplit -> plotSplit
                                PlotTabReach -> reachPlot task sEx reach bonusReach
                                PlotTabEffort -> effortPlot hgOrPg sEx ef
                                PlotTabTime -> timePlot sgs sEx sd

                                PlotTabLead -> do
                                    tabPlotLead <- tabsPlotLead
                                    let plotLead = leadPlot tweak sEx ld
                                    _ <- widgetHold (plotLead) $
                                            (\case
                                                PlotLeadTabPoint -> plotLead
                                                PlotLeadTabArea -> plotLead
                                            )
                                            <$> tabPlotLead
                                    return ()

                                PlotTabArrive -> arrivalPlot hgOrPg tweak av avN
                                PlotTabValid -> validPlot vy vw
                            )
                            <$> tabPlot

                    return ()

                TaskTabBasis -> do
                    tabBasis <- tabsBasis
                    let basisAbsent = tableAbsent utc early ix ln nyp dnf dfNt penalAuto penal sDf
                    _ <- widgetHold basisAbsent $
                            (\case
                                BasisTabAbsent -> basisAbsent
                                BasisTabValidity ->
                                    viewValidity
                                        utc ln free' task
                                        vy vyNorm
                                        vw vwNorm
                                        reachStats bonusStats
                                        reach bonusReach
                                        ft dfNt sEx
                                BasisTabGeo -> tableGeo ix comp)

                            <$> tabBasis

                    return ())

            <$> tabTask

    return es

taskDetail IxTaskNone _ _ _ _ _ _ = return never

readyTrack
    :: Monad m
    =>
        (
            ( Pilot
            ,
                ( (Pilot, Maybe TrackFlyingSection)
                , (Pilot, Maybe TrackScoredSection)
                )
            )
        ,
            ( (Pilot, [a])
            , (Pilot, [b])
            )
        )
    -> m
        (Maybe
            (
                ( Pilot
                ,
                    ( (Pilot, Maybe TrackFlyingSection)
                    , (Pilot, Maybe TrackScoredSection)
                    )
                )
            ,
                ( (Pilot, [a])
                , (Pilot, [b])
                )
            )
        )
readyTrack x@((p, ((fq, tf), (sq, ts))), ((xq, xs), (yq, ys)))
    | p == nullPilot = return Nothing
    | fq == nullPilot = return Nothing
    | sq == nullPilot = return Nothing
    | xq == nullPilot = return Nothing
    | yq == nullPilot = return Nothing
    | p /= fq || p /= sq || p /= xq || p /= yq = return Nothing
    | null xs = return Nothing
    | null ys = return Nothing
    | otherwise = return $
        case (tf, ts) of
            (Nothing, _) -> Nothing
            (_, Nothing) -> Nothing
            (Just TrackFlyingSection{flyingFixes = Nothing}, _) -> Nothing
            (_, Just TrackScoredSection{scoredFixes = Nothing}) -> Nothing
            (Just _, Just _) -> Just x
