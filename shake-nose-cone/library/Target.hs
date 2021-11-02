module Target where

import Development.Shake (Rules)
import Web (buildRules, cleanRules)

allWants :: [ String ]
allWants =
    [
    -- WARNING: The following targets don't currently build.
    --, "view-www"
    ]

allRules :: Rules ()
allRules = do
    Target.cleanRules
    Target.buildRules

cleanRules :: Rules ()
cleanRules = do
    Web.cleanRules

buildRules :: Rules ()
buildRules = do
    Web.buildRules