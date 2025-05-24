
SELECT * FROM globe.award;
USE globe;
-- table schema
describe award;

-- Preview the first 10 rows of data in the award table.
SELECT * FROM award
LIMIT 10;
-- Count the total records in the award table.
SELECT COUNT(*) AS total_records 
FROM award;
-- Count total awards given each year.
SELECT `year_award`, COUNT(*) AS total_awards
FROM award
GROUP BY `year_award`
ORDER BY `year_award` ASC;
-- List all distinct award categories available in the data.
SELECT DISTINCT category
FROM award;
-- Count number of awards by category to see which ones are most common.
SELECT category, COUNT(*) AS total
FROM award
GROUP BY category
ORDER BY total DESC;
-- Compare trends between Movie and TV awards over the years.
SELECT `year_award`,  
       SUM(CASE WHEN category LIKE '%film%' THEN 1 ELSE 0 END) AS film_awards,  
       SUM(CASE WHEN category LIKE '%Television%' THEN 1 ELSE 0 END) AS TV_awards  
FROM award  
GROUP BY `year_award`  
ORDER BY `year_award` ASC;
-- cumulative count of awards over the years
SELECT
    `year_award`,
    COUNT(*) AS yearly_awards,
SUM(COUNT(*)) OVER (ORDER BY `year_award`) AS cumulative_awards
FROM award
GROUP BY `year_award`
ORDER BY `year_award`;
    -- - Nomination-to-Win Conversion Analysis
    select 
    nominee,
    COUNT(*) AS total_nominations,
    SUM(CASE WHEN win IS NOT NULL THEN 1 ELSE 0 END) AS total_wins,
    ROUND(SUM(CASE WHEN win IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS win_percentage
FROM award
GROUP BY nominee
HAVING total_nominations > 5  -- Filter for nominees with enough appearances
ORDER BY win_percentage DESC;
-- dominating the awards
SELECT film, COUNT(*) AS total_wins
FROM award
GROUP BY film
ORDER BY total_wins DESC
LIMIT 10;
-- number of nominations for a specific category over time (Best Motion Picture - Drama):ELECT year_award, COUNT(*) AS nominations_count_for_drama
SELECT year_award, COUNT(*) AS nominations_count
FROM award
WHERE category = 'Best Motion Picture - Drama'
GROUP BY year_award
ORDER BY year_award ASC;
-- Find films/TV shows that were nominated multiple times but never won:
SELECT nominee, COUNT( * ) AS total_nominations
FROM award
WHERE nominee IS NOT NULL AND nominee != ''
GROUP BY nominee;  
-- Comparing First-Time Winners vs. Repeat Winners
SELECT nominee, 
       CASE 
           WHEN COUNT(CASE WHEN win = TRUE THEN 1 END) > 1 
           THEN 'Repeat Winner' 
           ELSE 'First-Time Winner' 
       END AS winner_status,
       COUNT(*) AS total_nominations,
       COUNT(CASE WHEN win = TRUE THEN 1 END) AS total_wins
FROM award
GROUP BY nominee;
-- Top Nominees Per Year
WITH NomineeYear AS (
    SELECT 
        year_award,
        nominee,
        COUNT(*) AS nominations,
        SUM(CASE WHEN win = 'true' THEN 1 ELSE 0 END) AS wins
    FROM award
    GROUP BY year_award, nominee
),
NomineeYearRank AS (
    SELECT 
        year_award,
        nominee,
        nominations,
        wins,
        ROW_NUMBER() OVER (PARTITION BY year_award ORDER BY wins DESC) AS rank_in_year
    FROM NomineeYear
)
SELECT year_award, nominee, nominations, wins, rank_in_year
FROM NomineeYearRank
WHERE rank_in_year <= 3
ORDER BY year_award, rank_in_year;
-- Decade-by-Decade Category Analysis
WITH DecadeData AS (
   SELECT 
       FLOOR(year_award / 10) * 10 AS decade, 
       category,
       COUNT(*) AS nominations,
       SUM(CASE WHEN win = 'true' THEN 1 ELSE 0 END) AS wins
   FROM award
   GROUP BY FLOOR(year_award / 10) * 10, category
)
SELECT 
    decade,
    category,
    nominations,
    wins,
    ROUND((wins * 100.0) / nominations, 2) AS win_rate_percentage
FROM DecadeData
ORDER BY decade, category;
-- Yearly Wins Trend with a Rolling Average
WITH YearlyWins AS (
    SELECT year_award, COUNT(*) AS total_wins
    FROM award
    WHERE win = 'true'
    GROUP BY year_award
)
SELECT 
    year_award,
    total_wins,
    ROUND(AVG(total_wins) OVER (ORDER BY year_award ROWS BETWEEN 4 PRECEDING AND CURRENT ROW), 2) AS rolling_avg_wins
FROM YearlyWins
ORDER BY year_award;
--  Cumulative Wins by Nominee Over Time
WITH NomineeWins AS (
    SELECT 
        year_award,
        nominee,
        COUNT(*) AS wins
    FROM award
    WHERE win = 'true'
    GROUP BY year_award, nominee
)
SELECT 
    year_award,
    nominee,
    wins,
    SUM(wins) OVER (PARTITION BY nominee ORDER BY year_award) AS cumulative_wins
FROM NomineeWins
ORDER BY nominee, year_award;
-- Nominee Win Ratio Z-Score
WITH NomineeStats AS (
    SELECT 
        nominee,
        COUNT(*) AS nominations,
        SUM(CASE WHEN win = 'true' THEN 1 ELSE 0 END) AS wins,
        (SUM(CASE WHEN win = 'true' THEN 1 ELSE 0 END) * 1.0) / COUNT(*) AS win_ratio
    FROM award
    GROUP BY nominee
    HAVING COUNT(*) > 5
),
AggregatedStats AS (
    SELECT 
        AVG(win_ratio) AS avg_win_ratio,
        STDDEV(win_ratio) AS std_win_ratio
    FROM NomineeStats
)
SELECT 
    ns.nominee,
    ns.nominations,
    ns.wins,
    ROUND(ns.win_ratio * 100, 2) AS win_percentage,
    CASE 
       WHEN agg.std_win_ratio = 0 THEN 0
       ELSE ROUND((ns.win_ratio - agg.avg_win_ratio) / agg.std_win_ratio, 2)
    END AS z_score
FROM NomineeStats ns CROSS JOIN AggregatedStats agg
ORDER BY z_score DESC;
--  positive Z-score means the nominee’s win ratio is well above average.
-- Performance Comparison: Pre-2000 vs. Post-2000
SELECT nominee, pre_nominations, pre_wins, post_nominations, post_wins, pre_win_percentage, post_win_percentage
FROM (
  -- Part 1: Nominees who appear in the Pre-2000 period (with optional Post-2000 data)
  SELECT 
      p.nominee,
      p.pre_nominations,
      p.pre_wins,
      q.post_nominations,
      q.post_wins,
      CASE 
          WHEN p.pre_nominations IS NOT NULL THEN ROUND((p.pre_wins * 100.0) / p.pre_nominations, 2)
          ELSE NULL 
      END AS pre_win_percentage,
      CASE 
          WHEN q.post_nominations IS NOT NULL THEN ROUND((q.post_wins * 100.0) / q.post_nominations, 2)
          ELSE NULL
      END AS post_win_percentage
  FROM (
      SELECT nominee, COUNT(*) AS pre_nominations, 
             SUM(CASE WHEN win = 'true' THEN 1 ELSE 0 END) AS pre_wins
      FROM award
      WHERE year_award < 2000
      GROUP BY nominee
  ) p
  LEFT JOIN (
      SELECT nominee, COUNT(*) AS post_nominations, 
             SUM(CASE WHEN win = 'true' THEN 1 ELSE 0 END) AS post_wins
      FROM award
      WHERE year_award >= 2000
      GROUP BY nominee
  ) q ON p.nominee = q.nominee
  
  UNION
  
  --  Nominees who are only in the Post-2000 period (they don't appear in Pre-2000)
  SELECT 
      q.nominee,
      NULL AS pre_nominations,
      NULL AS pre_wins,
      q.post_nominations,
      q.post_wins,
      NULL AS pre_win_percentage,
      ROUND((q.post_wins * 100.0) / q.post_nominations, 2) AS post_win_percentage
  FROM (
      SELECT nominee, COUNT(*) AS post_nominations, 
             SUM(CASE WHEN win = 'true' THEN 1 ELSE 0 END) AS post_wins
      FROM award
      WHERE year_award >= 2000
      GROUP BY nominee
  ) q
  WHERE q.nominee NOT IN (
      SELECT nominee
      FROM award
      WHERE year_award < 2000
  )
) AS combined
ORDER BY post_win_percentage DESC;


