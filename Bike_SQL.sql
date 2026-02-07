## Preview the Rides table to understand the fields and kinds of values 
SELECT * FROM `plants-478617.sqlproject.rides` LIMIT 1000;

## Preview the stations table to see station IDs and names (needed for joins and station analysis)
SELECT * FROM `plants-478617.sqlproject.stations` LIMIT 1000;

## Preview the users table to understand user attributes like membership level and signup date.
SELECT * FROM `plants-478617.sqlproject.users` LIMIT 1000;

## Check the size of each table (how many rides, stations, and users exist in the dataset)
SELECT
  (SELECT COUNT(*) FROM `plants-478617.sqlproject.rides`) AS total_rides,
  (SELECT COUNT(*) FROM `plants-478617.sqlproject.stations`) AS total_stations,
  (SELECT COUNT(*) FROM `plants-478617.sqlproject.users`) AS total_users;

## Check for missing values in key ride fields
SELECT
  COUNTIF(ride_id IS NULL) AS null_ride_id,
  COUNTIF(user_id IS NULL) AS null_user_id,
  COUNTIF(start_station_id IS NULL) AS null_start_station_id,
  COUNTIF(end_station_id IS NULL) AS null_end_station_id,
  COUNTIF(distance_km IS NULL) AS null_distance_km
FROM
  `plants-478617.sqlproject.rides`;


## Summary statistics - Summarize ride distance and ride duration to understand typical trip behavior and outliers
SELECT
  MIN(distance_km) AS min_distance,
  MAX(distance_km) AS max_distance,
  ROUND(AVG(distance_km),2) AS avg_distance,
  APPROX_QUANTILES(distance_km, 1)[OFFSET(1)] AS med_distance,
  MIN(TIMESTAMP_DIFF(end_time, start_time, MINUTE)) AS min_duration,
  MAX(TIMESTAMP_DIFF(end_time, start_time, MINUTE)) AS max_duration,
  ROUND(AVG(TIMESTAMP_DIFF(end_time, start_time, MINUTE)),2) AS avg_duration
FROM
  `plants-478617.sqlproject.rides`;

## Check for false starts for the rides - Identify potentially low-quality trips (very short trips and invalid/negative distances)
SELECT
  COUNTIF(TIMESTAMP_DIFF(end_time, start_time, MINUTE)<2) AS short_duration_trips,
  COUNTIF(distance_km < 0) AS zero_distance_trips
FROM
  `plants-478617.sqlproject.rides`;


## Compare ride activity and ride patterns across membership levels (volume, average distance, average duration)
SELECT
  u.membership_level,
  COUNT(r.ride_id) AS total_rides,
  ROUND(AVG(r.distance_km),2) AS avg_distance,
  ROUND(AVG(TIMESTAMP_DIFF(r.end_time,r.start_time, MINUTE)),2) AS avg_duration
FROM  
  `plants-478617.sqlproject.users` AS u
JOIN
  `plants-478617.sqlproject.rides` AS r ON u.user_id = r.user_id
GROUP BY
  u.membership_level
ORDER BY
  total_rides DESC;


## Find peak ride hours by counting trips by the hour they started

SELECT
  EXTRACT(HOUR FROM start_time) AS hour_of_day,
  COUNT(*) AS no_of_rides
FROM
  `plants-478617.sqlproject.rides`
GROUP BY
  hour_of_day
ORDER BY
  hour_of_day;


## Identify the most popular start stations by ranking stations by number of rides starting there
SELECT
  s.station_name,
  COUNT(ride_id) AS total_rides
FROM
  `plants-478617.sqlproject.rides` AS r
JOIN
  `plants-478617.sqlproject.stations` AS s ON r.start_station_id = s.station_id
GROUP BY
  s.station_name 
ORDER BY
  total_rides DESC
LIMIT 10;

### Segment rides into short/medium/long categories and count how many trips fall into each bucket

SELECT
  CASE
    WHEN TIMESTAMP_DIFF(end_time,start_time, MINUTE)<= 10 THEN 'Short (<10m)'
    WHEN TIMESTAMP_DIFF(end_time,start_time, MINUTE) BETWEEN 11 AND 30 THEN 'Medium(11m-30m)'
    ELSE 'Long(>30m)'
  END AS ride_category,
  COUNT(*) AS no_of_rides
FROM 
  `plants-478617.sqlproject.rides`
GROUP BY
  ride_category
ORDER BY
  no_of_rides DESC;


## Calculate station net flow (departures minus arrivals) to see which stations tend to gain or lose bikes overall

WITH departures AS (
  SELECT 
    start_station_id, 
    COUNT(*) AS total_departures
  FROM `plants-478617.sqlproject.rides`
  GROUP BY start_station_id
),
arrivals AS (
  SELECT 
    end_station_id, 
    COUNT(*) AS total_arrivals
  FROM `plants-478617.sqlproject.rides`
  GROUP BY end_station_id
)
SELECT
  s.station_name,
  d.total_departures,
  a.total_arrivals,
  (d.total_departures - a.total_arrivals) AS net_flow
FROM `plants-478617.sqlproject.stations` AS s   
LEFT JOIN departures d ON d.start_station_id = s.station_id
LEFT JOIN arrivals a ON a.end_station_id = s.station_id
ORDER BY net_flow;


## Track monthly user signups and compute month-over-month growth to understand acquisition trends over time

WITH monthly_signups AS (
  SELECT
    DATE_TRUNC(created_at, MONTH) AS signup_month,
    COUNT(user_id) AS new_users_count
  FROM `plants-478617.sqlproject.users`
  GROUP BY signup_month
)
SELECT
  signup_month,
  new_users_count,
  LAG(new_users_count) OVER (ORDER BY signup_month) AS previous_month_new_users,
  ROUND((new_users_count - LAG(new_users_count) OVER (ORDER BY signup_month))
  / NULLIF(LAG(new_users_count) OVER (ORDER BY signup_month), 0) * 100,2) AS mom_growth
FROM monthly_signups
ORDER BY signup_month;


