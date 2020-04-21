{-# LANGUAGE JavaScriptFFI #-}
{-# LANGUAGE ForeignFunctionInterface #-}

module FlareTiming.Plot.Time.Plot (timePlot) where

import Prelude hiding (map, log)
import GHCJS.Types (JSVal)
import GHCJS.DOM.Element (IsElement)
import GHCJS.DOM.Types (Element(..), toElement, toJSVal, toJSValListOf)
import Data.List (nub)
import FlareTiming.Plot.Foreign (Plot(..))

foreign import javascript unsafe
    "functionPlot(\
    \{ target: '#hg-plot-speed'\
    \, title: 'Time Point Distribution'\
    \, width: 700\
    \, height: 640\
    \, disableZoom: true\
    \, xAxis: {label: 'Time (hours)', domain: [$2, $3]}\
    \, yAxis: {domain: [-0.05, 1.05]}\
    \, data: [{\
    \    points: $4\
    \  , fnType: 'points'\
    \  , color: '#808080'\
    \  , graphType: 'polyline'\
    \  },{\
    \    points: $5\
    \  , fnType: 'points'\
    \  , color: '#808080'\
    \  , attr: { stroke-dasharray: '5,5' }\
    \  , graphType: 'polyline'\
    \  },{\
    \    points: $6\
    \  , fnType: 'points'\
    \  , color: '#1e1e1e'\
    \  , attr: { r: 3 }\
    \  , graphType: 'scatter'\
    \  },{\
    \    points: $7\
    \  , fnType: 'points'\
    \  , color: '#377eb8'\
    \  , attr: { r: 9 }\
    \  , graphType: 'scatter'\
    \  },{\
    \    points: $8\
    \  , fnType: 'points'\
    \  , color: '#ff7f00'\
    \  , attr: { r: 9 }\
    \  , graphType: 'scatter'\
    \  },{\
    \    points: $9\
    \  , fnType: 'points'\
    \  , color: '#4daf4a'\
    \  , attr: { r: 9 }\
    \  , graphType: 'scatter'\
    \  },{\
    \    points: $10\
    \  , fnType: 'points'\
    \  , color: '#e41a1c'\
    \  , attr: { r: 9 }\
    \  , graphType: 'scatter'\
    \  },{\
    \    points: $11\
    \  , fnType: 'points'\
    \  , color: '#984ea3'\
    \  , attr: { r: 9 }\
    \  , graphType: 'scatter'\
    \  }]\
    \})"
    plot_ :: JSVal -> JSVal -> JSVal -> JSVal -> JSVal -> JSVal -> JSVal -> JSVal -> JSVal -> JSVal -> JSVal -> IO JSVal

timePlot
    :: IsElement e
    => e
    -> (Double, Double)
    -> [[Double]] -- ^ All xy pairs
    -> [[Double]] -- ^ Selected xy pairs
    -> IO Plot
timePlot e (tMin, tMax) xs ys = do
    let xyfn :: [[Double]] =
            [ [x', fnGAP tMin x']
            | x <- [0 .. 199 :: Integer]
            , let step = abs $ (tMax - tMin) / 200
            , let x' = tMin + step * fromIntegral x
            ]

    let xyfnFS :: [[Double]] =
            [ [x', fnFS tMin x']
            | x <- [0 .. 199 :: Integer]
            , let step = abs $ (tMax - tMin) / 200
            , let x' = tMin + step * fromIntegral x
            ]

    -- NOTE: 0.083 hr = 5 min
    let pad = (\case 0 -> 0.083; x -> x) . abs $ (tMax - tMin) / 40
    tMin' <- toJSVal $ tMin - pad
    tMax' <- toJSVal $ tMax + pad

    xyfn' <- toJSValListOf xyfn
    xyfnFS' <- toJSValListOf xyfnFS
    xs' <- toJSValListOf $ nub xs
    ys1 <- toJSValListOf $ take 1 ys
    ys2 <- toJSValListOf $ take 1 $ drop 1 ys
    ys3 <- toJSValListOf $ take 1 $ drop 2 ys
    ys4 <- toJSValListOf $ take 1 $ drop 3 ys
    ys5 <- toJSValListOf $ take 1 $ drop 4 ys

    Plot <$> plot_ (unElement . toElement $ e) tMin' tMax' xyfn' xyfnFS' xs' ys1 ys2 ys3 ys4 ys5

-- | The equation from the GAP rules.
fnGAP :: Double -> Double -> Double
fnGAP tMin t =
    max 0.0 $ 1.0 - ((t - tMin)**2/tMin**(1.0/2.0))**(1.0/3.0)

-- | The equation from the FS implementation.
fnFS :: Double -> Double -> Double
fnFS tMin t =
    max 0.0 $ 1.0 - ((t - tMin)/tMin**(1.0/2.0))**(2.0/3.0)
