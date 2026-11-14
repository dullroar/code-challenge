-- DEMO ONLY. Fictional timecards, written to a scratch SQLite file under XDG_DATA_HOME.
-- Run: runghc timecards.hs
import Data.Bits (shiftR)
import Data.List (intercalate)
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime, getZonedTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import System.Directory (createDirectoryIfMissing)
import System.Environment (lookupEnv)
import System.Posix.Process (getProcessID)
import System.Process (readProcess)

-- The whole challenge: random hours, cut after the first running total over 40, cycling the categories.
timecards :: Integer -> [(String, Integer, Integer)]
timecards seed = zip3 (cycle ["Meetings", "Coding", "Debugging", "Learning"]) hs (scanl1 (+) hs)
  where
    rolls = map (\s -> 10 + (s `shiftR` 33) `mod` 10) (tail (iterate (\s -> (s * 6364136223846793005 + 1442695040888963407) `mod` 2 ^ 64) seed))
    hs    = take (1 + length (takeWhile (<= 40) (scanl1 (+) rolls))) rolls

q :: String -> String
q x = "'" ++ x ++ "'"

main :: IO ()
main = do
  now  <- getCurrentTime
  pid  <- getProcessID
  week <- formatTime defaultTimeLocale "%G-W%V" <$> getZonedTime
  base <- maybe (maybe "." (++ "/.local/share") <$> lookupEnv "HOME") pure =<< lookupEnv "XDG_DATA_HOME"
  let seed  = floor (utcTimeToPOSIXSeconds now * 1000000) * 7919 + toInteger pid
      run   = show (floor (utcTimeToPOSIXSeconds now) :: Integer) ++ "-" ++ show pid
      cards = timecards seed
      total = (\(_, _, t) -> t) (last cards)
      sql   = unlines $
        [ "CREATE TABLE IF NOT EXISTS demo_timecards(id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,running_total INTEGER,iso_week TEXT,created_at TEXT,demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));", "BEGIN;" ]
        ++ [ "INSERT INTO demo_timecards(run_id,category,hours,running_total,iso_week,created_at) VALUES(" ++ intercalate "," [q run, q c, show h, show t, q week, "datetime('now')"] ++ ");" | (c, h, t) <- cards ]
        ++ [ "COMMIT;" ]
  createDirectoryIfMissing True (base ++ "/Haskell")
  _ <- readProcess "sqlite3" [base ++ "/Haskell/demo-timecards.db"] sql
  putStr . unlines $
    ["# DEMO ONLY run " ++ run]
      ++ [intercalate "\t" [c, show h, show t, week, "DEMO ONLY"] | (c, h, t) <- cards]
      ++ ["# committed total=" ++ show total ++ " entries=" ++ show (length cards) ++ " DEMO ONLY", "# the whole challenge is one pure function, timecards; main is just plumbing"]
