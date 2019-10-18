module FlareTiming.Comp.Detail (compDetail) where

import Reflex
import Reflex.Dom

import WireTypes.Comp (Comp, Nominal, Task)
import WireTypes.Route (TaskDistance)
import FlareTiming.Comp.Header (compHeader)
import FlareTiming.Breadcrumb (crumbComp)
import FlareTiming.Events (IxTask(..))
import FlareTiming.Comp.Tab (CompTab(..), tabsComp)
import FlareTiming.Comp.Tasks (taskList)
import FlareTiming.Comp.Pilot (tablePilot)
import FlareTiming.Comp.Settings (tableComp)

compDetail
    :: MonadWidget t m
    => Dynamic t [TaskDistance]
    -> Dynamic t [Comp]
    -> Dynamic t [Nominal]
    -> Dynamic t [Task]
    -> m (Event t IxTask)
compDetail ls cs ns ts = do
    compHeader cs ns
    _ <- simpleList cs crumbComp
    tab <- tabsComp

    e <- widgetHold (taskList ls ts) $
            (\case
                CompTabSettings -> do
                    _ <- simpleList cs tableComp
                    return never

                CompTabTask -> taskList ls ts

                CompTabPilot -> do
                    tablePilot ts
                    return never)
            <$> tab

    return $ switchDyn e
