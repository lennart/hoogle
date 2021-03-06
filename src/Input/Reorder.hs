{-# LANGUAGE TupleSections #-}

module Input.Reorder(reorderItems) where

import Input.Item
import Data.List.Extra
import Data.Maybe
import Data.Tuple.Extra


-- | Reorder items so the most popular ones are first, using reverse dependencies
reorderItems :: (String -> Int) -> [(a, Item)] -> [(a, Item)]
reorderItems packageOrder xs =
    concatMap snd $ sortOn ((packageOrder &&& id) . fst) $ map rebase $ splitIPackage xs
    where
        refunc = map $ second $ \(x:xs) -> x : sortOn (itemName . snd) xs
        rebase (x, xs) | x `elem` ["base","haskell98","haskell2010"]
                       = (x, concatMap snd $ sortOn ((baseModuleOrder &&& id) . fst) $ refunc $ splitIModule xs)
        rebase (x, xs) = (x, concatMap snd $ sortOn fst $ refunc $ splitIModule xs)


baseModuleOrder :: String -> Int
baseModuleOrder x
    | "GHC." `isPrefixOf` x = maxBound
    | otherwise = fromMaybe (maxBound-1) $ elemIndex x
    ["Prelude","Data.List","Data.Maybe","Data.Function","Control.Monad","List","Maybe","Monad"]
