-- DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME.
-- Run: runghc timecards.hs
import Data.Bits (shiftR)
import Data.Function (fix)
import Data.List (intercalate)
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime, getZonedTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Posix.Process (getProcessID)
import System.Process (readProcess)

data Category = Meetings | Coding | Debugging | Learning deriving (Show, Enum, Bounded)

data Card = Card { category :: Category, hours :: Integer, total :: Integer }

-- No loop, no recursion, no accumulator: the list of cards is a fixed point of itself.
-- Each card's running total is read off the card before it, and the list ends where that total passes 40.
sheet :: Integer -> [Card]
sheet seed = fix $ \cards ->
  let before = 0 : map total cards
   in map snd . takeWhile ((<= 40) . fst) $ zip before (zipWith3 (\c h t -> Card c h (t + h)) (cycle [minBound ..]) (rolls seed) before)
  where rolls = map (\s -> 10 + (s `shiftR` 33) `mod` 10) . tail . fix . (\s0 xs -> s0 : map (\s -> (s * 6364136223846793005 + 1442695040888963407) `mod` 2 ^ 64) xs)

row :: String -> Card -> String
row week (Card c h t) = intercalate "\t" [show c, show h, show t, week, "DEMO ONLY"]

insert :: String -> String -> Card -> String
insert run week (Card c h t) = "INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES(" ++ intercalate "," ["'" ++ run ++ "'", "'" ++ show c ++ "'", show h, show t, "'" ++ week ++ "'", "datetime('now')"] ++ ");"

main :: IO ()
main = do
  now  <- getCurrentTime
  pid  <- getProcessID
  week <- formatTime defaultTimeLocale "%G-W%V" <$> getZonedTime
  base <- maybe (maybe "." (++ "/.local/share") <$> lookupEnv "HOME") pure =<< lookupEnv "XDG_DATA_HOME"
  let run   = show (floor (utcTimeToPOSIXSeconds now) :: Integer) ++ "-" ++ show pid
      cards = sheet (floor (utcTimeToPOSIXSeconds now * 1000000) * 7919 + toInteger pid)
      sql   = unlines $ ["CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));", "BEGIN;"] ++ map (insert run week) cards ++ ["COMMIT;"]
  createDirectoryIfMissing True (base ++ "/HaskellWeird")
  _ <- readProcess "sqlite3" [base ++ "/HaskellWeird/demo-timecards.db"] sql
  putStr . unlines $ ["# DEMO ONLY run " ++ run] ++ map (row week) cards ++ ["# committed total=" ++ show (total (last cards)) ++ " entries=" ++ show (length cards) ++ " DEMO ONLY", "# the list of cards is a fixed point of itself"]
