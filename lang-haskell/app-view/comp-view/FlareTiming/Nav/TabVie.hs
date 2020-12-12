module FlareTiming.Nav.TabVie (VieTab(..), tabsVie) where

import Reflex
import Reflex.Dom

data VieTab
    = VieTabScore
    | VieTabScoreFs
    | VieTabPlotFs

tabsVie :: MonadWidget t m => m (Event t VieTab)
tabsVie =
    elClass "div" "tabs" $
        el "ul" $ mdo
            (score, _) <- elDynClass' "li" scoreClass $ el "a" (text "3-Way (Ft,Fs,As)")
            (scoreFs, _) <- elDynClass' "li" scoreFsClass $ el "a" (text "Flight System (Fs)")
            (plotFs, _) <- elDynClass' "li" plotFsClass $ el "a" (text " Plot Fs")

            let eScore = (const VieTabScore) <$> domEvent Click score
            let eScoreFs = (const VieTabScoreFs) <$> domEvent Click scoreFs
            let ePlotFs = (const VieTabPlotFs) <$> domEvent Click plotFs

            scoreClass <- holdDyn "is-active" . leftmost $
                            [ "is-active" <$ eScore
                            , "" <$ eScoreFs
                            , "" <$ ePlotFs
                            ]

            scoreFsClass <- holdDyn "" . leftmost $
                            [ "" <$ eScore
                            , "is-active" <$ eScoreFs
                            , "" <$ ePlotFs
                            ]

            plotFsClass <- holdDyn "" . leftmost $
                            [ "" <$ eScore
                            , "" <$ eScoreFs
                            , "is-active" <$ ePlotFs
                            ]

            return . leftmost $
                [ eScore
                , eScoreFs
                , ePlotFs
                ]
