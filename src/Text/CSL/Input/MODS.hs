{-# LANGUAGE PatternGuards, CPP #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Text.CSL.Input.MODS
-- Copyright   :  (c) Andrea Rossato
-- License     :  BSD-style (see LICENSE)
--
-- Maintainer  :  Andrea Rossato <andrea.rossato@unitn.it>
-- Stability   :  unstable
-- Portability :  unportable
--
-- An ugly MODS parser
--
-----------------------------------------------------------------------------

module Text.CSL.Input.MODS where

import Text.CSL.Eval ( split )
import Text.CSL.Output.Plain ( (<+>), tail' )
import Text.CSL.Pickle
import Text.CSL.Reference
import Text.CSL.Style ( betterThen )

import Data.Char ( isDigit, isLower )
import qualified Data.Map as M

-- | Read a file with a single MODS record.
readModsFile :: FilePath -> IO Reference
readModsFile = readXmlFile xpMods

-- | Read a file with a collection of MODS records.
readModsCollectionFile :: FilePath -> IO [Reference]
readModsCollectionFile = readXmlFile xpModsCollection

xpModsCollection :: PU [Reference]
xpModsCollection = xpIElem "modsCollection" $ xpList xpMods

xpMods :: PU Reference
xpMods = xpIElem "mods" xpReference

xpReference :: PU Reference
xpReference
    = xpWrap ( \ ( ref
                , (ck,(ty,gn),ti,i,d)
                ,((au,ed,tr,sp),(re,it,pu',dr),(co,ce,dg,om))
                ,((di',pg,vl,is),(nu,sc,ch))
                , (di,ac,pu,pp,et)
                , ((ac',uri),ln,st,no)
                 ) ->
               ref { refId            = ck `betterThen` take 10 (concat . words $ fst ti)
                   , refType          = if ty /= NoType then ty else
                                        if refType ref == Book then Chapter else refType ref
                   , title            = fst ti
                   , titleShort       = snd ti
                   , author           = au
                   , editor           = ed `betterThen` editor           ref
                   , edition          = et `betterThen` edition          ref
                   , translator       = tr `betterThen` translator       ref
                   , recipient        = re `betterThen` recipient        ref
                   , interviewer      = it `betterThen` interviewer      ref
                   , composer         = co `betterThen` composer         ref
                   , director         = dr `betterThen` director         ref
                   , collectionEditor = ce `betterThen` collectionEditor ref
                   , publisherPlace   = pp `betterThen` publisherPlace   ref
                   , containerAuthor  = containerAuthor  ref
                   , url              = uri
                   , note             = no
                   , isbn             = i
                   , doi              = d
                   , genre            = genre         ref `betterThen` gn
                   , issued           = issued        ref `betterThen` di `betterThen` di'
                   , accessed         = accessed      ref `betterThen` ac `betterThen` ac'
                   , page             = page          ref `betterThen` pg
                   , volume           = volume        ref `betterThen` vl
                   , issue            = issue         ref `betterThen` is  `betterThen`
                                        number        ref `betterThen` nu
                   , number           = number        ref `betterThen` nu
                   , section          = section       ref `betterThen` sc
                   , chapterNumber    = chapterNumber ref `betterThen` ch
                   , language         = language      ref `betterThen` ln
                   , status           = status        ref `betterThen` st
                   , publisher        = fromAgent pu
                                           `betterThen` publisher ref
                                           `betterThen` fromAgent pu'
                                           `betterThen` fromAgent dg
                                           `betterThen` fromAgent om
                                           `betterThen` fromAgent sp
                   }
             , \r -> (  r
                     , (refId     r,(refType r,genre r), (title r, titleShort r), isbn r, doi r)
                     ,((author    r, editor           r, translator r, director r)
                      ,(recipient r, interviewer      r, emptyAgents,  director r)
                      ,(composer  r, collectionEditor r, emptyAgents, emptyAgents))
                     ,((issued    r, page  r, volume r, issue r)
                      ,(number    r, section   r, chapterNumber r))
                     , (issued    r, accessed r, emptyAgents, publisherPlace r, edition r)
                     ,((accessed  r, url r),  status r, language r, note r)
                     )) $
      xp6Tuple (xpDefault emptyReference xpRelatedItem)
               (xp5Tuple xpCiteKey xpRefType xpTitle xpIsbn xpDoi)
                xpAgents xpPart xpOrigin
               (xp4Tuple xpUrl xpLang xpStatus xpNote)

xpCiteKey :: PU String
xpCiteKey
    = xpDefault [] $
      xpChoice (xpAttr "ID" xpText)
               (xpElemWithAttrValue "identifier" "type" "citekey" xpText)
                xpLift

xpOrigin :: PU ([RefDate],[RefDate],[Agent],String,String)
xpOrigin
    = xpDefault ([],[],[],[],[]) . xpIElem "originInfo" $
      xp5Tuple (xpDefault [] $ xpWrap (readDate,show) $
                xpIElem "dateIssued" xpText0)
               (xpDefault [] $ xpWrap (readDate,show) $
                xpIElem "dateCaptured" xpText0)
               (xpDefault [] $ xpList $ xpWrap (\s -> Agent [] [] [] s [] [] False, show) $
                xpIElem "publisher" xpText0)
               (xpDefault [] $ xpIElem "place"   $ xpIElem "placeTerm" xpText0)
               (xpDefault [] $ xpIElem "edition" $                     xpText0)

xpRefType :: PU (RefType, String)
xpRefType
    = xpDefault (NoType,[]) $
      xpWrap (readRefType, const []) xpGenre

xpGenre :: PU [String]
xpGenre
    = xpList $ xpIElem "genre" $
      xpChoice xpZero
              (xpPair (xpDefault [] $ xpAttr "authority" xpText) xpText)
              $ xpLift . snd

xpRelatedItem :: PU Reference
xpRelatedItem
    = xpIElem "relatedItem" . xpAddFixedAttr "type" "host" $
      xpWrap ( \( ((ty,gn),ct)
                ,((ca,ed,tr,sp),(re,it,pu',dr),(co,ce,dg,om))
                ,((di,pg,vl,is),(nu,sc,ch))
                , (di',ac,pu,pp,et)
                , (ln, st)
                ) ->
               emptyReference { refType             = ty
                              , containerAuthor     = ca
                              , containerTitle      = fst ct
                              , containerTitleShort = snd ct
                              , editor              = ed
                              , edition             = et
                              , translator          = tr
                              , recipient           = re
                              , interviewer         = it
                              , publisherPlace      = pp
                              , composer            = co
                              , director            = dr
                              , collectionEditor    = ce
                              , issued              = di `betterThen` di'
                              , accessed            = ac
                              , page                = pg
                              , volume              = vl
                              , issue               = is `betterThen` nu
                              , number              = nu
                              , section             = sc
                              , chapterNumber       = ch
                              , genre               = gn
                              , language            = ln
                              , status              = st
                              , publisher           = fromAgent $ pu `betterThen` pu' `betterThen`
                                                                  dg `betterThen` om  `betterThen` sp

                              }
             , \r -> ( ((refType r,genre r), (containerTitle  r, containerTitleShort r))
                     ,((containerAuthor r, editor           r, translator r, director r)
                      ,(recipient       r, interviewer      r, emptyAgents,  director r)
                      ,(composer        r, collectionEditor r, emptyAgents, emptyAgents))
                     ,((issued  r, page  r, volume r, issue r)
                      ,(number  r, section   r, chapterNumber r))
                     , (issued  r, accessed  r,emptyAgents, publisherPlace r, edition r)
                     , (language r, status r)
                     )) $
      xp5Tuple (xpPair xpRefType xpTitle)
                xpAgents xpPart xpOrigin
               (xpPair xpLang xpStatus)

xpTitle :: PU (String,String)
xpTitle
    = xpWrap (\((a,b),c) -> createTitle a b c , \s -> (s,[])) $
      xpPair (xpIElem "titleInfo" $
              xpPair (xpIElem "title" xpText0)
                     (xpDefault [] $ xpIElem "subTitle" xpText0))
             (xpDefault [] $ xpIElem "titleInfo" $
              xpAddFixedAttr "type" "abbreviated" $ xpElem "title" xpText0)
    where
      createTitle [] [] [] = ([],[])
      createTitle s  [] [] = breakLong s
      createTitle s  [] ab = (s ,ab)
      createTitle s sub [] = (s ++ colon s ++ sub,  s)
      createTitle s sub ab = (s ++ colon s ++ sub, ab)
      colon s = if last s == '!' || last s == '?' then " " else ": "
      breakLong s = let (a,b) = break (== ':') s
                    in  if b /= [] then (s,a) else (s, [])

xpAgents :: PU (([Agent],[Agent],[Agent],[Agent])
               ,([Agent],[Agent],[Agent],[Agent])
               ,([Agent],[Agent],[Agent],[Agent]))
xpAgents
    = xpTriple (xp4Tuple (xpAgent "author"         "aut")
                         (xpAgent "editor"         "edt")
                         (xpAgent "translator"     "trl")
                         (xpAgent "sponsor"        "spn"))
               (xp4Tuple (xpAgent "recipient"      "rcp")
                         (xpAgent "interviewer"    "ivr")
                         (xpAgent "publisher"      "pbl")
                         (xpAgent "director"       "drt"))
               (xp4Tuple (xpAgent "composer"       "cmp")
                         (xpAgent "collector"      "xol")
                         (xpAgent "degree grantor" "dgg")
                         (xpAgent "organizer of meeting" "orm"))

xpAgent :: String -> String -> PU [Agent]
xpAgent sa sb
    = xpDefault [] $ xpList $ xpIElem "name" $
      xpChoice  xpZero
               (xpIElem "role" $ xpIElem "roleTerm" xpText0)
               (\x -> if x == sa || x == sb then xpickle else xpZero)

instance XmlPickler Agent where
    xpickle = xpAlt tag ps
        where
          tag _ = 0
          ps    = [ personal, others ]
          personal = xpWrap ( uncurry parseName
                            , \(Agent gn _ _ fn _ _ _) -> (gn,fn)) $
                     xpAddFixedAttr "type" "personal" xpNameData
          others   = xpWrap (\s -> Agent [] [] [] [] [] s False, undefined) $
                     xpElem "namePart" xpText0

-- | "von Hicks,! Jr., Michael" or "la Martine,! III, Martin B. de" or
-- "Rossato, Jr., Andrea G. B." or "Paul, III, Juan".
parseName :: [String] -> String -> Agent
parseName gn fn
    | ("!":sf:",":xs) <- gn     = parse xs (sf ++ ".") True
    | ("!":sf    :xs) <- gn
    , sf /= [] , last sf == ',' = parse xs  sf         True

    | (sf:",":xs)     <- gn     = parse xs (sf ++ ".") False
    | (sf    :xs)     <- gn
    , sf /= [], last sf == ','  = parse xs  sf         False
    | otherwise                 = parse gn  ""         False
    where
      parse g s b = Agent (getGiven g) (getDrop g) (getNonDrop fn) (getFamily fn) s [] b
      setInit   s = if length s == 1 then s ++ "." else s
      getDrop     = unwords     . reverse . takeWhile (and . map isLower) . reverse
      getGiven    = map setInit . reverse . dropWhile (and . map isLower) . reverse
      getNonDrop  = unwords . takeWhile (and . map isLower) . words
      getFamily   = unwords . dropWhile (and . map isLower) . words

xpNameData :: PU ([String],String)
xpNameData
    = xpWrap (readName,const []) $
      xpList $ xpElem "namePart" $ xpPair (xpAttr "type" xpText) xpText0
    where
      readName x = (readg x, readf x)
      readf = foldr (\(k,v) xs -> if k == "family" then v    else xs) []
      readg = foldr (\(k,v) xs -> if k == "given"  then v:xs else xs) []

xpPart :: PU (([RefDate],String,String,String)
             ,(String,String,String))
xpPart
    = xpDefault none . xpIElem "part" .
      xpWrap (readIt none,const []) $ xpList xpDetail
    where
      none = (([],"","",""),("","",""))
      readIt r [] = r
      readIt acc@((d,p,v,i),(n,s,c)) (x:xs)
          | Date      y <- x = readIt ((y,p,v,i),(n,s,c)) xs
          | Page      y <- x = readIt ((d,y,v,i),(n,s,c)) xs
          | Volume    y <- x = readIt ((d,p,y,i),(n,s,c)) xs
          | Issue     y <- x = readIt ((d,p,v,y),(n,s,c)) xs
          | Number    y <- x = readIt ((d,p,v,i),(y,s,c)) xs
          | ChapterNr y <- x = readIt ((d,p,v,i),(n,s,y)) xs
          | Section   y <- x = readIt ((d,p,v,i),(n,y,c)) xs
          | otherwise        = acc

data Detail
    = Date     [RefDate]
    | Page      String
    | Volume    String
    | Issue     String
    | Number    String
    | ChapterNr String
    | Section   String
      deriving ( Eq, Show )

xpDetail :: PU Detail
xpDetail
    = xpAlt tag ps
    where
      tag _ = 0
      ps = [ xpWrap (Date, const []) $ xpDate
           , xpWrap (Page,     show) $ xpPage
           , xpWrap (Volume,   show) $ xp "volume"
           , xpWrap (Issue,    show) $ xp "issue"
           , xpWrap (Number,   show) $ xp "number"
           , xpWrap (Number,   show) $ xp "report number"
           , xpWrap (Section,  show) $ xp "section"
           , xpWrap (ChapterNr,show) $ xp "chapter"
           ]
      xpDate = xpWrap (readDate,show) (xpElem "date" xpText0)
      xp   s = xpElemWithAttrValue "detail" "type" s $
               xpElem "number" xpText

xpPage :: PU String
xpPage
    = xpChoice (xpElemWithAttrValue "detail" "type" "page" $ xpIElem "number" xpText)
               (xpElemWithAttrValue "extent" "unit" "page" $
                xpPair (xpElem "start" xpText)
                       (xpElem "end"   xpText))
               (\(s,e) -> xpLift (s ++ "-" ++ e))

xpUrl :: PU ([RefDate],String)
xpUrl
    = xpDefault ([],[]) . xpIElem "location" $
      xpPair (xpWrap (readDate,show) $
              xpDefault [] $ xpAttr "dateLastAccessed" xpText)
             (xpDefault [] $ xpElem "url"              xpText)

xpIsbn :: PU String
xpIsbn = xpDefault [] $ xpIdentifier "isbn"

xpDoi :: PU String
xpDoi = xpDefault [] $ xpIdentifier "doi"

xpIdentifier :: String -> PU String
xpIdentifier i
    = xpIElem "identifier" $ xpAddFixedAttr "type" i xpText

xpNote :: PU (String)
xpNote = xpDefault [] $ xpIElem "note" xpText

xpLang :: PU String
xpLang
    = xpDefault [] $
      xpChoice (xpIElem "recordInfo" $ xpIElem "languageOfCataloging" $
                xpIElem "language" $ xpIElem "languageTerm"  xpText)
               (xpIElem "recordInfo" $ xpIElem "languageOfCataloging" $
                xpIElem "languageTerm"  xpText)
                xpLift

xpStatus :: PU String
xpStatus
    = xpDefault [] $
      --xpElemWithAttrValue "note" "type" "publication status" xpText
      xpIElem "note" $ xpAddFixedAttr "type" "publication status" xpText

readDate :: String -> [RefDate]
readDate s = (parseDate         $ takeWhile (/= '/') s) ++
             (parseDate . tail' $ dropWhile (/= '/') s)

-- | Possible formats: "YYYY", "YYYY-MM", "YYYY-MM-DD".
parseDate :: String -> [RefDate]
parseDate s = case split (== '-') (unwords $ words s) of
                [y,m,d] -> [RefDate y m [] d  [] []]
                [y,m]   -> [RefDate y m [] [] [] []]
                [y]     -> if and (map isDigit y)
                           then [RefDate y  [] [] [] [] []]
                           else [RefDate [] [] [] [] y  []]
                _       -> []

emptyAgents :: [Agent]
emptyAgents  = []

fromAgent :: [Agent] -> String
fromAgent = foldr (<+>) [] . map show

readRefType :: [String] -> (RefType, String)
readRefType [] = (NoType,[])
readRefType (t:ts) =
  case M.lookup t genreTypeMapping of
    Just x  -> (x, if ts /= [] then head ts else [])
    Nothing -> if ts /= []
               then case M.lookup (head ts) genreTypeMapping of
                      Just  x -> (x, t)
                      Nothing -> (ArticleJournal, t)
               else (ArticleJournal, [])

-- The string constants come from http://www.loc.gov/standards/valuelist/marcgt.html, which are used in the
-- "<genre></genre>" element (http://www.loc.gov/standards/mods/userguide/genre.html)
genreTypeMapping ::  M.Map String RefType
genreTypeMapping = M.fromList
  [ ( "book",                       Book             )
  , ( "book chapter",               Chapter          )
  , ( "periodical",                 ArticleJournal   )
  , ( "newspaper",                  ArticleNewspaper )
  , ( "magazine",                   ArticleNewspaper )
  , ( "magazine article",           ArticleNewspaper )
  , ( "encyclopedia",               EntryEncyclopedia)
  , ( "conference publication",     Book             )
  , ( "academic journal",           ArticleJournal   )
  , ( "collection",                 Chapter          )
  , ( "legal case and case notes",  LegalCase        )
  , ( "legislation",                Legislation      )
  , ( "instruction",                Book             )
  , ( "motion picture",             MotionPicture    )
  , ( "film",                       MotionPicture    )
  , ( "tvBroadcast",                MotionPicture    )
  , ( "videoRecording",             MotionPicture    )
  , ( "videorecording",             MotionPicture    )
  , ( "patent",                     Patent           )
  , ( "Ph.D. thesis",               Thesis           )
  , ( "Masters thesis",             Thesis           )
  , ( "report",                     Report           )
  , ( "technical report",           Report           )
  , ( "review",                     Review           )
  , ( "thesis",                     Thesis           )
  , ( "unpublished",                NoType           )
  , ( "web page",                   Webpage          )
  , ( "webpage",                    Webpage          )
  , ( "web site",                   Webpage          )
  ]
