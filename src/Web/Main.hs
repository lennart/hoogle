{-
    This file is part of Hoogle, (c) Neil Mitchell 2004-2005
    http://www.cs.york.ac.uk/~ndm/hoogle/
    
    This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike License.
    To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/2.0/
    or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.
-}

{- |
    The Web interface, expects to be run as a CGI script.
    This does not require Haskell CGI etc, it just dumps HTML to the console
-}

module Web.Main where

import Hoogle.Hoogle
import Hoogle.TextUtil

import Web.CGI

import Char
import System
import List
import Maybe
import Directory


-- | Should the output be sent to the console and a file.
--   If true then both, the file is 'debugFile'.
--   Useful mainly for debugging.
debugOut = False

fakeArgs :: IO [(String, String)]
fakeArgs = return $ [("q","map"), ("format","sherlock")]


-- | The main function
main :: IO ()
main = do args <- if debugOut then fakeArgs else cgiArgs
          putStr "Content-type: text/html\n\n"
          appendFile "log.txt" (show args ++ "\n")
          let input = lookupDef "" "q" args
          if null input then hoogleBlank
           else case hoogleParse input of
                    Right x -> showError input x
                    Left x -> showResults x args


lookupDef :: Eq key => val -> key -> [(key, val)] -> val
lookupDef def key list = case lookup key list of
                             Nothing -> def
                             Just x -> x

lookupDefInt :: Eq key => Int -> key -> [(key, String)] -> Int
lookupDefInt def key list = case lookup key list of
                              Nothing -> def
                              Just x -> case reads x of
                                           [(x,"")] -> x
                                           _ -> def


-- | Show the search box
hoogleBlank :: IO ()
hoogleBlank = do debugInit
                 outputFile "front"


-- | Replace all occurances of $ with the parameter
outputFileParam :: FilePath -> String -> IO ()
outputFileParam x param = do src <- readFile ("res/" ++ x ++ ".inc")
                             putLine (f src)
    where
        f ('$':xs) = param ++ f xs
        f (x:xs) = x : f xs
        f [] = []

outputFile :: FilePath -> IO ()
outputFile x = do src <- readFile ("res/" ++ x ++ ".inc")
                  putLine src


showError :: String -> String -> IO ()
showError input err =
    do
        debugInit
        outputFileParam "prefix" input
        outputFileParam "error" err
        outputFileParam "suffix" input
        


-- | Perform a search, dump the results using 'putLine'
showResults :: Search -> [(String, String)] -> IO ()
showResults input args =
    do
        res <- hoogleResults "res/hoogle.txt" input
        let lres = length res
            search = hoogleSearch input
            tSearch = showText search
            useres = take num $ drop start res

        debugInit
        outputFileParam "prefix" tSearch

        putLine $ 
            "<table id='heading'><tr><td>Searched for " ++ showTags search ++
            "</td><td id='count'>" ++
            (if lres == 0 then "No results found" else f lres) ++
            "</td></tr></table>"
        
        case hoogleSuggest True input of
            Nothing -> return ()
            Just x -> putLine $ "<p id='suggest'>" ++ showTags x ++ "</p>"

        if null res then outputFileParam "noresults" tSearch
         else putLine $ "<table id='results'>" ++ concatMap showResult useres ++ "</table>"
        
        putLine $ g lres
        
        putLine $ if format == "sherlock" then sherlock useres else ""

        outputFileParam "suffix" tSearch
    where
        start = lookupDefInt 0 "start" args
        num   = lookupDefInt 25 "num"  args
        format = lookupDef "" "format" args
        nostart = filter ((/=) "start" . fst) args
        
        showPrev len pos = if start <= 0 then "" else
            "<a href='?" ++ asCgi (("start",show (max 0 (start-num))):nostart) ++ "'><img src='res/" ++ pos ++ "_left.png' /></a> "
        
        showNext len pos = if start+num >= len then "" else
            " <a href='?" ++ asCgi (("start",show (start+num)):nostart) ++ "'><img src='res/" ++ pos ++ "_right.png' /></a>"
        
    
        f len =
            showPrev len "top" ++
            "Results <b>" ++ show (start+1) ++ "</b> - <b>" ++ show (min (start+num) len) ++ "</b> of <b>" ++ show len ++ "</b>" ++
            showNext len "top"
        
        g len = if start == 0 && len <= num then "" else
            "<div id='select'>" ++
                showPrev len "bot" ++
                concat (zipWith h [1..10] [0,num..len]) ++
                showNext len "bot" ++
            "</div>"

        h num start2 = " <a " ++ (if start==start2 then "class='active' " else "") ++ "href='?" ++ asCgi (("start",show start2):nostart) ++ "'>" ++ show num ++ "</a> "
        
        

sherlock :: [Result] -> String
sherlock xs = "\n<!--\n<sherlock>\n" ++ concatMap f xs ++ "</sherlock>\n-->\n"
    where
        f (Result modu name typ _ _ _) =
            "<item>" ++ hoodoc modu (Just name) ++
            "<abbr title='" ++ escapeHTML (showText typ) ++ "'>" ++ 
            showTags name ++ "</abbr> " ++
            "<span style='font-size:small;'>(" ++ showText modu ++ ")</span></a>" ++
            "</item>\n"


                 
showTags :: TagStr -> String
showTags (Str x) = x
showTags (Tag "b" x) = "<b>" ++ showTags x ++ "</b>"
showTags (Tag "u" x) = "<i>" ++ showTags x ++ "</i>"
showTags (Tag "a" x) = "<a href='?q=" ++ escape (showText x) ++ "'>" ++ showTags x ++ "</a>"
showTags (Tag [n] x) | n >= '1' && n <= '6' = 
    "<span class='c" ++ n : "'>" ++ showTags x ++ "</span>"
showTags (Tag n x) = showTags x
showTags (Tags xs) = concatMap showTags xs


showTagsLimit :: Int -> TagStr -> String
showTagsLimit n x = if length s > n then take (n-2) s ++ ".." else s
    where
        s = showText x


showResult :: Result -> String
showResult (Result modu name typ _ _ _) = 
    "<tr>" ++
        "<td class='mod'>" ++
            hoodoc modu Nothing ++ showTagsLimit 20 modu ++ "</a>." ++
        "</td><td class='fun'>"
            ++ openA ++ showTags name ++ "</a>" ++
        "</td><td class='typ'>"
            ++ openA ++ ":: " ++ showTags typ ++ "</a>" ++
        "</td>" ++
    "</tr>\n"
        where
           openA = hoodoc modu (Just name)


hoodoc :: TagStr -> Maybe TagStr -> String
hoodoc modu func = case func of
                        Nothing -> f $ showText modu
                        Just x -> f $ showText modu ++ "&amp;func=" ++ escape (showText x)
    where f x = "<a href='hoodoc.cgi?module=" ++ x ++ "'>"


-- | The file to output to if 'debugOut' is True
debugFile = "temp.htm"


-- | Clear the debugging file
debugInit = if debugOut then writeFile debugFile "" else return ()

-- | Write out a line, to console and optional to a debugging file
putLine :: String -> IO ()
putLine x = do putStrLn x
               if debugOut then appendFile debugFile x else return ()


-- | Read the hit count, increment it, return the new value.
--   Hit count is stored in hits.txt
hitCount :: IO Integer
hitCount = do x <- readHitCount
              -- HUGS SCREWS THIS UP WITHOUT `seq`
              -- this should not be needed, but it is
              -- (we think)
              x `seq` writeHitCount (x+1)
              return (x+1)
    where
        hitFile = "hits.txt"
        
        readHitCount :: IO Integer
        readHitCount =
            do exists <- doesFileExist hitFile
               if exists
                   then do src <- readFile hitFile
                           return (parseHitCount src)
                   else return 0
        
        writeHitCount :: Integer -> IO ()
        writeHitCount x = writeFile hitFile (show x)
        
        parseHitCount = read . head . lines
              

-- | Take a piece of text and escape all the HTML special bits
escapeHTML :: String -> String
escapeHTML = concatMap f
    where
        f :: Char -> String
        f '<' = "&lt;"
        f '>' = "&gt;"
        f '&' = "&amp;"
        f  x  = x:[]

