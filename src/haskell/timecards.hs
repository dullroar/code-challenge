-- DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
-- XDG_DATA_HOME. Nothing here touches a real time-reporting system.
--
-- Run: runghc timecards.hs
--
-- The challenge ("add 10-19 hour cards until the running total passes 40") is
-- the pure function 'timecards'. Everything in 'main' is plumbing: ask the
-- clock for a seed, run the function, and hand the answer to sqlite3.
module Main (main) where

import Data.Bits (shiftR)
import Data.List (intercalate)
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime, getZonedTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import Data.Word (Word64)
import System.Directory (XdgDirectory (XdgData), createDirectoryIfMissing, getXdgDirectory)
import System.FilePath ((</>))
import System.Posix.Process (getProcessID)
import System.Process (readProcess)

-- ---------------------------------------------------------------------------
-- The challenge
-- ---------------------------------------------------------------------------

data Category = Meetings | Coding | Debugging | Learning
  deriving (Show, Enum, Bounded)

data Card = Card
  { category :: Category,
    hours :: Int,
    runningTotal :: Int
  }

-- | An endless, repeatable stream of hours in 10..19.
--
-- GHC ships no random-number package, so this is a 64-bit linear congruential
-- generator (Knuth's MMIX constants). 'Word64' arithmetic wraps around on
-- overflow, which is exactly the "mod 2^64" the algorithm calls for. The low
-- bits of an LCG are weak, so we use the high ones.
rolls :: Word64 -> [Int]
rolls = map toHours . tail . iterate next
  where
    next s = s * 6364136223846793005 + 1442695040888963407
    toHours s = 10 + fromIntegral ((s `shiftR` 33) `mod` 10)

-- | Every card there could ever be: the categories repeat, and each card
-- carries the total so far. 'scanl1' is a running sum.
allCards :: Word64 -> [Card]
allCards seed = zipWith3 Card (cycle [minBound ..]) hs (scanl1 (+) hs)
  where
    hs = rolls seed

-- | Keep adding cards until the total passes 40, and keep the one that
-- crosses the line. Laziness is why this terminates: 'span' stops reading the
-- infinite list at the first card over the limit.
timecards :: Word64 -> [Card]
timecards seed = under ++ take 1 over
  where
    (under, over) = span ((<= 40) . runningTotal) (allCards seed)

-- ---------------------------------------------------------------------------
-- Output
-- ---------------------------------------------------------------------------

schema :: String
schema =
  concat
    [ "CREATE TABLE IF NOT EXISTS demo_timecards(",
      "id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,",
      "running_total INTEGER,iso_week TEXT,created_at TEXT,",
      "demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));"
    ]

-- | A SQL string literal. Doubling embedded quotes is the whole escaping rule;
-- here the inputs are fixed, but a helper that is safe anyway costs nothing.
quote :: String -> String
quote s = "'" ++ concatMap (\c -> if c == '\'' then "''" else [c]) s ++ "'"

insert :: String -> String -> Card -> String
insert run week card =
  "INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES("
    ++ intercalate
      ","
      [ quote run,
        quote (show (category card)),
        show (hours card),
        show (runningTotal card),
        quote week,
        "datetime('now')"
      ]
    ++ ");"

row :: String -> Card -> String
row week card =
  intercalate
    "\t"
    [show (category card), show (hours card), show (runningTotal card), week, "DEMO ONLY"]

-- ---------------------------------------------------------------------------
-- Plumbing
-- ---------------------------------------------------------------------------

main :: IO ()
main = do
  now <- getCurrentTime
  pid <- getProcessID
  week <- formatTime defaultTimeLocale "%G-W%V" <$> getZonedTime
  dir <- getXdgDirectory XdgData "Haskell"
  let micros = floor (utcTimeToPOSIXSeconds now * 1000000) :: Word64
      seed = micros * 7919 + fromIntegral pid
      run = show (micros `div` 1000000) ++ "-" ++ show pid
      cards = timecards seed
      sql = unlines (["BEGIN;", schema] ++ map (insert run week) cards ++ ["COMMIT;"])
  createDirectoryIfMissing True dir
  _ <- readProcess "sqlite3" [dir </> "demo-timecards.db"] sql
  putStr . unlines $
    ["# DEMO ONLY run " ++ run]
      ++ map (row week) cards
      ++ [ "# committed total=" ++ show (sum (map hours cards)) ++ " entries=" ++ show (length cards) ++ " DEMO ONLY",
           "# the whole challenge is one pure function, timecards; main is just plumbing"
         ]
