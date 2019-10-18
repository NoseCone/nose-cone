{-# LANGUAGE JavaScriptFFI #-}
{-# LANGUAGE ForeignFunctionInterface #-}

module FlareTiming.Map.Leaflet
    ( Map(..)
    , TileLayer(..)
    , Marker(..)
    , Circle(..)
    , Semicircle(..)
    , LatLngBounds
    , map
    , mapSetView
    , mapInvalidateSize
    , tileLayer
    , tileLayerAddToMap
    , marker
    , markerAddToMap
    , markerPopup
    , circle
    , circleAddToMap
    , semicircle
    , semicircleAddToMap
    , trackLine
    , discardLine
    , routeLine
    , polylineAddToMap
    , circleBounds
    , polylineBounds
    , extendBounds
    , fitBounds
    , panToBounds
    , latLngBounds
    , layerGroup
    , layerGroupAddToMap
    , layersControl
    , layersExpand
    , addOverlay
    ) where

import Prelude hiding (map, log)
import GHCJS.Types (JSVal, JSString)
import GHCJS.DOM.Element (IsElement)
import GHCJS.DOM.Types
    (ToJSVal(..), Element(..), toElement, toJSString, toJSVal, toJSValListOf)

import WireTypes.Pilot (PilotName(..))
import FlareTiming.Earth (AzimuthFwd(..))

-- SEE: https://gist.github.com/ali-abrar/fa2adbbb7ee64a0295cb
newtype Map = Map { unMap :: JSVal }
newtype LayerGroup = LayerGroup { unLayerGroup :: JSVal }
newtype TileLayer = TileLayer { unTileLayer :: JSVal }
newtype Marker = Marker { unMarker :: JSVal }
newtype Circle = Circle { unCircle :: JSVal }
newtype Semicircle = Semicircle { unSemicircle :: JSVal }
newtype Polyline = Polyline { unPolyline :: JSVal }
newtype LatLngBounds = LatLngBounds { unLatLngBounds :: JSVal }
newtype Layers = Layers { unLayers :: JSVal }

instance ToJSVal LayerGroup where
    toJSVal = return . unLayerGroup

foreign import javascript unsafe
    "L['map']($1)"
    map_ :: JSVal -> IO JSVal

foreign import javascript unsafe
    "$1['setView']([$2, $3], $4)"
    mapSetView_ :: JSVal -> Double -> Double -> Int -> IO ()

foreign import javascript unsafe
    "$1['invalidateSize']()"
    mapInvalidateSize_ :: JSVal -> IO ()

foreign import javascript unsafe
    "L['tileLayer']($1, {maxZoom: $2, opacity: 0.6})"
    tileLayer_ :: JSString -> Int -> IO JSVal

foreign import javascript unsafe
    "$1['addTo']($2)"
    addToMap_ :: JSVal -> JSVal -> IO ()

foreign import javascript unsafe
    "L.layerGroup($2).addLayer($1)"
    layerGroup_ :: JSVal -> JSVal -> IO JSVal

foreign import javascript unsafe
    "L.control.layers(\
    \ (function () {\
    \ var o = {};\
    \ var ks = $3;\
    \ var vs = $4;\
    \ ks.forEach(function (k, i){o[k] = vs[i];});\
    \ return o;\
    \})()\
    \, { 'Map': $1}\
    \, { 'sortLayers': true\
    \, 'sortFunction': function (m, n, i, j) {\
    \ var a = $3.indexOf(i);\
    \ var b = $3.indexOf(j);\
    \ return a < b ? -1 : (b < a ? 1 : 0);\
    \}}).addTo($2)"
    layersControl_ :: JSVal -> JSVal -> JSVal -> JSVal -> IO JSVal

foreign import javascript unsafe
    "$1.addOverlay($2, $3)"
    addBaseLayer_ :: JSVal -> JSVal -> JSString -> IO ()

foreign import javascript unsafe
    "$1.expand()"
    layersExpand_ :: JSVal -> IO ()

foreign import javascript unsafe
    "L['marker']([$1, $2])"
    marker_ :: Double -> Double -> IO JSVal

foreign import javascript unsafe
    "$1['bindPopup']($2)"
    markerPopup_ :: JSVal -> JSString -> IO ()

foreign import javascript unsafe
    "L['circle']([$1, $2], {radius: $3, color: $4, opacity: 0.6, weight: 1, stroke: $5, fill: $6})"
    circle_ :: Double -> Double -> Double -> JSString -> Bool -> Bool -> IO JSVal

foreign import javascript unsafe
    "L['semiCircle']([$1, $2], {radius: $3, color: $5, opacity: 0.6, weight: 1, stroke: $6, fill: $7}).setDirection($4, 180)"
    semicircle_ :: Double -> Double -> Double -> Double -> JSString -> Bool -> Bool -> IO JSVal

foreign import javascript unsafe
    "L['polyline']($1, {color: $2, opacity: 0.6, dashArray: '20,15', lineJoin: 'round'})"
    routeLine_ :: JSVal -> JSString -> IO JSVal

foreign import javascript unsafe
    "L['polyline']($1, {color: $2, weight: 1})"
    trackLine_ :: JSVal -> JSString -> IO JSVal

foreign import javascript unsafe
    "L['polyline']($1, {color: $2, weight: 1, opacity: 1.0, dashArray: '5,5,1,5'})"
    discardLine_ :: JSVal -> JSString -> IO JSVal

foreign import javascript unsafe
    "$1['getBounds']()"
    getBounds_ :: JSVal -> IO JSVal

foreign import javascript unsafe
    "L.latLng($1, $2)"
    latLng_ :: Double -> Double -> IO JSVal

foreign import javascript unsafe
    "$1['toBounds']($2)"
    latLngRadiusBounds_ :: JSVal -> Double -> IO JSVal

foreign import javascript unsafe
    "$1['extend']($2)"
    extendBounds_ :: JSVal -> JSVal -> IO JSVal

foreign import javascript unsafe
    "$1['fitBounds']($2)"
    fitBounds_ :: JSVal -> JSVal -> IO ()

foreign import javascript unsafe
    "$1['setView']($2.getCenter())"
    panToBounds_ :: JSVal -> JSVal -> IO ()

map :: IsElement e => e -> IO Map
map e =
    Map <$> (map_ . unElement . toElement $ e)

mapSetView :: Map -> (Double, Double) -> Int -> IO ()
mapSetView lm (lat, lng) zoom =
    mapSetView_ (unMap lm) lat lng zoom

mapInvalidateSize :: Map -> IO ()
mapInvalidateSize lmap =
    mapInvalidateSize_ (unMap lmap)

layerGroup :: Polyline -> [Marker] -> IO LayerGroup
layerGroup line xs = do
    ys <- toJSVal $ unMarker <$> xs
    fg <- layerGroup_ (unPolyline line) ys
    return $ LayerGroup fg

layerGroupAddToMap :: LayerGroup -> Map -> IO ()
layerGroupAddToMap x lmap = addToMap_ (unLayerGroup x) (unMap lmap)

layersControl
    :: TileLayer
    -> Map
    -> LayerGroup -- ^ Point to point course line
    -> LayerGroup -- ^ Expected optimal course line
    -> LayerGroup -- ^ Optimal spherical route of the course
    -> LayerGroup -- ^ Subset of the optimal spherical route's course line
    -> LayerGroup -- ^ Optimal spherical route through the waypoints of the speed section
    -> LayerGroup -- ^ Optimal ellipsoid route of the course
    -> LayerGroup -- ^ Subset of the optimal ellipsoid route's course line
    -> LayerGroup -- ^ Optimal ellipsoid route through the waypoints of the speed section
    -> LayerGroup -- ^ Planar route of the course
    -> IO Layers
layersControl
    x lmap course
    normRoute
    taskSphericalRoute taskSphericalRouteSubset speedSphericalRoute
    taskEllipsoidRoute taskEllipsoidRouteSubset speedEllipsoidRoute

    taskPlanarRoute = do
        ns' <- toJSValListOf ns
        gs' <- toJSValListOf gs
        layers <- layersControl_ (unTileLayer x) (unMap lmap) ns' gs'
        return $ Layers layers
    where
        gs =
            [ course
            , normRoute
            , taskSphericalRoute
            , taskEllipsoidRoute
            , taskPlanarRoute
            , taskSphericalRouteSubset
            , taskEllipsoidRouteSubset
            , speedSphericalRoute
            , speedEllipsoidRoute
            ]

        ns :: [String]
        ns =
            [ "Task"
            , "Path (✓ expected)"
            , "Path (spherical)"
            , "Path (ellipsoid)"
            , "Path (planar)"
            , "Race (spherical subset of path)"
            , "Race (ellipsoid subset of path)"
            , "Race (spherical subset of waypoints)"
            , "Race (ellipsoid subset of waypoints)"
            ]

addOverlay
    :: Layers
    -> (PilotName, LayerGroup) -- ^ Pilot's track
    -> IO ()
addOverlay layers (PilotName pilotName, pilotLine) = do
    addBaseLayer_
        (unLayers layers)
        (unLayerGroup pilotLine)
        (toJSString pilotName)

layersExpand :: Layers -> IO ()
layersExpand layers = layersExpand_ $ unLayers layers

tileLayer :: String -> Int -> IO TileLayer
tileLayer src maxZoom =
    TileLayer <$> tileLayer_ (toJSString src) maxZoom

-- | Adds the tile layer to the map. The layers control does this too.
-- If this call is made before setting up the layers control then the map layer
-- will be checked and shown.
tileLayerAddToMap :: TileLayer -> Map -> IO ()
tileLayerAddToMap x lmap = addToMap_ (unTileLayer x) (unMap lmap)

marker :: (Double, Double) -> IO Marker
marker (lat, lng) =
    Marker <$> marker_ lat lng

markerAddToMap :: Marker -> Map -> IO ()
markerAddToMap x lmap = addToMap_ (unMarker x) (unMap lmap)

markerPopup :: Marker -> String -> IO ()
markerPopup x msg =
    markerPopup_ (unMarker x) (toJSString msg)

circle :: (Double, Double) -> Double -> String -> Bool -> Bool -> IO Circle
circle (lat, lng) radius color stroke fill =
    Circle <$> circle_ lat lng radius (toJSString color) stroke fill

circleAddToMap :: Circle -> Map -> IO ()
circleAddToMap x lmap = addToMap_ (unCircle x) (unMap lmap)

semicircle
    :: (Double, Double)
    -> Double
    -> AzimuthFwd
    -> String
    -> Bool
    -> Bool
    -> IO Semicircle
semicircle (lat, lng) radius (AzimuthFwd az) color stroke fill =
    Semicircle <$> semicircle_ lat lng radius az (toJSString color) stroke fill

semicircleAddToMap :: Semicircle -> Map -> IO ()
semicircleAddToMap x lmap = addToMap_ (unSemicircle x) (unMap lmap)

routeLine :: [(Double, Double)] -> String -> IO Polyline
routeLine xs color = do
    ys <- toJSVal $ (\ (lat, lng) -> [ lat, lng ]) <$> xs
    Polyline <$> routeLine_ ys (toJSString color)

trackLine :: [[Double]] -> String -> IO Polyline
trackLine xs color = do
    ys <- toJSVal xs
    Polyline <$> trackLine_ ys (toJSString color)

discardLine :: [[Double]] -> String -> IO Polyline
discardLine xs color = do
    ys <- toJSVal xs
    Polyline <$> discardLine_ ys (toJSString color)

polylineAddToMap :: Polyline -> Map -> IO ()
polylineAddToMap x lmap = addToMap_ (unPolyline x) (unMap lmap)

circleBounds :: Circle -> IO LatLngBounds
circleBounds x =
    LatLngBounds <$> getBounds_ (unCircle x)

polylineBounds :: Polyline -> IO LatLngBounds
polylineBounds x =
    LatLngBounds <$> getBounds_ (unPolyline x)

extendBounds :: LatLngBounds -> LatLngBounds -> IO LatLngBounds
extendBounds x y =
    LatLngBounds <$> extendBounds_ (unLatLngBounds x) (unLatLngBounds y)

fitBounds :: Map -> LatLngBounds -> IO ()
fitBounds lm bounds = fitBounds_ (unMap lm) (unLatLngBounds bounds)

panToBounds :: Map -> LatLngBounds -> IO ()
panToBounds lm bounds = panToBounds_ (unMap lm) (unLatLngBounds bounds)

latLngBounds :: [(Double, Double, Double)] -> IO LatLngBounds
latLngBounds [] = fail "Empty list passed to latLngBounds"
latLngBounds xs = do
    (y : ys) :: [JSVal] <- sequence $ f <$> xs
    bounds :: JSVal <- foldr g (pure y) ys
    return $ LatLngBounds bounds
    where
        f (lat, lng, radius) = do
            ll <- latLng_ lat lng
            latLngRadiusBounds_ ll (2 * radius)

        g x y = do
            y' <- y
            extendBounds_ x y'
