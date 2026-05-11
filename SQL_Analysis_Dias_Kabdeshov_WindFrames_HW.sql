SELECT * FROM products
WHERE prod_category_id = 202

-- Task 1
-- Create a query for analyzing the annual sales data for the years 1999 to 2001, 
-- focusing on different sales channels and regions: 'Americas,' 'Asia,' and 'Europe.' 
WITH CTE1 AS (
    SELECT r.country_region, t.calendar_year, c.channel_desc, SUM(s.amount_sold) AS amount_sold
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    JOIN sh.channels c ON s.channel_id = c.channel_id
    JOIN sh.customers cu ON s.cust_id = cu.cust_id
    JOIN sh.countries r ON cu.country_id = r.country_id
    WHERE t.calendar_year BETWEEN 1999 AND 2001
	AND r.country_region IN ('Americas', 'Asia', 'Europe')
    GROUP BY r.country_region, t.calendar_year, c.channel_desc
),
CTE2 AS (
    SELECT country_region, calendar_year, channel_desc, amount_sold, 
	ROUND(100 * amount_sold / SUM(amount_sold) OVER (
            PARTITION BY country_region, calendar_year
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING), 2) AS pct_by_channels
    FROM CTE1
)
SELECT country_region, calendar_year, channel_desc, amount_sold, pct_by_channels || '%' AS "% BY CHANNELS",
    LAG(pct_by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year) || '%' AS "% PREVIOUS PERIOD",
    (pct_by_channels - LAG(pct_by_channels) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year)) AS "% DIFF"
FROM CTE2
ORDER BY country_region ASC, calendar_year ASC, channel_desc ASC;



-- Task 2
-- Generate a sales report for the 49th, 50th, and 51st weeks of 1999.
SELECT calendar_week_number, time_id, day_name amount_sold,
    SUM(amount_sold) OVER (PARTITION BY calendar_week_number ORDER BY time_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CUM_SUM,
    AVG(amount_sold) OVER (ORDER BY time_id ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS CENTERED_3_DAY_AVG
FROM (
    SELECT s.time_id, t.day_name, t.calendar_week_number, SUM(s.amount_sold) as amount_sold
    FROM sh.sales s
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year = 1999 
	AND t.calendar_week_number BETWEEN 49 AND 51
    GROUP BY s.time_id, t.calendar_week_number, t.day_name
)
ORDER BY time_id;


-- Task 3

-- ROWS is particularly good in this example because we work with certain amount of rows(here 3)
-- So we have our current row, one preceding and one after it
SELECT t.time_id, t.day_name, SUM(s.amount_sold) AS daily_sales,
AVG(SUM(s.amount_sold)) OVER ( ORDER BY t.time_id ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS centered_3_day_avg
FROM sh.sales s
JOIN sh.times t ON s.time_id = t.time_id
WHERE t.calendar_year = 1999
GROUP BY t.time_id, t.day_name
ORDER BY t.time_id;

-- RANGE here is good because it groups rows with the same value ordered
-- If they have the same sales, they are calculated together
SELECT c.channel_desc, SUM(s.amount_sold) AS sales,
SUM(SUM(s.amount_sold)) OVER (ORDER BY SUM(s.amount_sold) RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_sales
FROM sh.sales s
JOIN sh.channels c ON s.channel_id = c.channel_id
GROUP BY c.channel_desc
ORDER BY sales;

-- GROUPS are used when we move accross groups, not individualy, so we move between groups themselves, not just values themselves
SELECT prod_id, amount_sold,
COUNT(*) OVER (ORDER BY amount_sold GROUPS BETWEEN 1 PRECEDING AND CURRENT ROW) AS rows_in_current_and_previous_group
FROM sh.sales
WHERE amount_sold < 100
ORDER BY amount_sold;