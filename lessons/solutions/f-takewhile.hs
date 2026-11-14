-- Reference answer for exercise F: prove the README claim "takeWhile is not enough"
-- (src/haskell/README.md). The running totals are 15, 26, 38, 49 and the limit is 40, so the card
-- that crosses the line is the one that makes 49.
--
-- Run: lessons/tools/run-in-sandbox.sh lessons/solutions runghc f-takewhile.hs
main :: IO ()
main = do
  let totals = scanl1 (+) [15, 11, 12, 11] :: [Int]
  putStrLn ("takeWhile: " ++ show (takeWhile (<= 40) totals))
  let (under, over) = span (<= 40) totals
  putStrLn ("span: " ++ show (under ++ take 1 over))
