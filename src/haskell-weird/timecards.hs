-- DEMO ONLY. Fictional timecards, written to a scratch SQLite file under
-- XDG_DATA_HOME. Nothing here touches a real time-reporting system.
--
-- Run: runghc timecards.hs
--
-- THE STUNT: an infinite list of cards whose *elements have side effects*.
--
-- Forcing the n-th cell of the list prints card n and sends its INSERT to
-- sqlite3. Nothing else in the program writes a row. So the stop rule is not
-- "a loop that decides when to quit": it is a consumer (@span@) that simply
-- stops asking for the next cell, and the INSERTs stop with it.
--
-- There is no loop, no accumulator, no recursion and no counter. Two knots are
-- tied with 'fix'/'fixIO':
--
--   * the random stream is a list defined in terms of itself;
--   * each card's running total is read off the previous card, which is
--     an element of the very list being built.
--
-- 'unsafeInterleaveIO' is what makes an IO action wait until its cell is
-- demanded. It is named "unsafe" because the order of effects is then decided
-- by the evaluator, not by the program text. Here that is the point.
module Main (main) where

import Control.Exception (evaluate)
import Data.Bits (shiftR)
import Data.Function (fix)
import Data.List (intercalate)
import Data.Time (defaultTimeLocale, formatTime, getCurrentTime, getZonedTime)
import Data.Time.Clock.POSIX (utcTimeToPOSIXSeconds)
import Data.Word (Word64)
import System.Directory (XdgDirectory (XdgData), createDirectoryIfMissing, getXdgDirectory)
import System.Exit (ExitCode (ExitSuccess))
import System.FilePath ((</>))
import System.IO (Handle, fixIO, hClose, hPutStrLn)
import System.IO.Unsafe (unsafeInterleaveIO)
import System.Posix.Process (getProcessID)
import System.Process (CreateProcess (std_in), StdStream (CreatePipe), createProcess, proc, waitForProcess)

data Category = Meetings | Coding | Debugging | Learning
  deriving (Show, Enum, Bounded)

data Card = Card
  { category :: Category,
    hours :: Int,
    runningTotal :: Int
  }

-- | Hours in 10..19, as a list defined in terms of itself: each element is
-- the generator step applied to the one before it. (A 64-bit LCG with Knuth's
-- constants; 'Word64' wraps on overflow, which is the "mod 2^64".)
rolls :: Word64 -> [Int]
rolls seed = map toHours (tail (fix (\xs -> seed : map next xs)))
  where
    next s = s * 6364136223846793005 + 1442695040888963407
    toHours s = 10 + fromIntegral ((s `shiftR` 33) `mod` 10)

-- | Turn a list of IO actions into an IO action of a list, but *lazily*: the
-- effect for each element runs only when that cell of the result is forced.
-- (Ordinary 'sequence' would run every action, and on an infinite list never
-- return.)
lazily :: [IO a] -> IO [a]
lazily = fix $ \self actions ->
  unsafeInterleaveIO $ case actions of
    [] -> pure []
    act : rest -> (:) <$> act <*> self rest

-- | The endless sheet of cards. @onBirth@ is what happens to a card the moment it
-- is born; it is the only place any output occurs.
--
-- The knot: @cards@ is the result, and @before@ is "0, then the total of each
-- card" -- so card n's total is read from card n-1, an element of the list
-- under construction. 'fixIO' hands us that list before it exists.
sheet :: (Card -> IO ()) -> Word64 -> IO [Card]
sheet onBirth seed = fixIO $ \cards ->
  let before = 0 : map runningTotal cards
      born (c, h, t) = let card = Card c h (t + h) in card <$ onBirth card
   in lazily (map born (zip3 (cycle [minBound ..]) (rolls seed) before))

-- | The stop rule. It is nothing but how much of the list we choose to read:
-- everything up to the first total over 40, plus that card.
untilOver40 :: [Card] -> [Card]
untilOver40 cards = under ++ take 1 over
  where
    (under, over) = span ((<= 40) . runningTotal) cards

schema :: String
schema =
  concat
    [ "CREATE TABLE IF NOT EXISTS demo_timecards(",
      "id INTEGER PRIMARY KEY,run_id TEXT,category TEXT,hours INTEGER,",
      "running_total INTEGER,iso_week TEXT,created_at TEXT,",
      "demo_only INTEGER NOT NULL DEFAULT 1 CHECK(demo_only=1));"
    ]

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

-- | What happens to a card when it is born: show it, and save it.
emit :: Handle -> String -> String -> Card -> IO ()
emit sqlite run week card = do
  putStrLn (row week card)
  hPutStrLn sqlite (insert run week card)

main :: IO ()
main = do
  now <- getCurrentTime
  pid <- getProcessID
  week <- formatTime defaultTimeLocale "%G-W%V" <$> getZonedTime
  dir <- getXdgDirectory XdgData "HaskellWeird"
  createDirectoryIfMissing True dir
  (Just sqlite, _, _, process) <-
    createProcess (proc "sqlite3" [dir </> "demo-timecards.db"]) {std_in = CreatePipe}
  let micros = floor (utcTimeToPOSIXSeconds now * 1000000) :: Word64
      run = show (micros `div` 1000000) ++ "-" ++ show pid
  putStrLn ("# DEMO ONLY run " ++ run)
  hPutStrLn sqlite "BEGIN;"
  hPutStrLn sqlite schema
  -- Nothing has been written yet except the schema: the list is just a promise.
  cards <- untilOver40 <$> sheet (emit sqlite run week) (micros * 7919 + fromIntegral pid)
  -- Counting the kept cards is what demands them, and so what runs the effects.
  -- (Try a lazy `let entries = length cards` here: the count is not demanded until
  -- the summary is printed, after COMMIT, and the pipe is already closed.)
  entries <- evaluate (length cards)
  hPutStrLn sqlite "COMMIT;"
  hClose sqlite
  status <- waitForProcess process
  if status == ExitSuccess then pure () else ioError (userError "sqlite3 failed")
  putStrLn ("# committed total=" ++ show (sum (map hours cards)) ++ " entries=" ++ show entries ++ " DEMO ONLY")
  putStrLn "# the list of cards is a fixed point of itself, and reading it is what wrote the rows"
