-- Task 1
-- Create a query to produce a sales report highlighting the top customers 
-- with the highest sales across different sales channels. 

-- sales of customers for each channel
WITH customer_sales AS (
    SELECT ch.channel_desc, c.cust_id, c.cust_last_name, c.cust_first_name, SUM(s.amount_sold) AS amount_sold
    FROM sales s
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN channels ch ON s.channel_id = ch.channel_id
    GROUP BY ch.channel_desc, c.cust_id, c.cust_last_name, c.cust_first_name
),
-- ranked sales of each channel
ranked_sales AS (
    SELECT channel_desc, cust_last_name, cust_first_name, amount_sold,
	SUM(amount_sold) OVER (PARTITION BY channel_desc) AS total_channel_sales,
	ROW_NUMBER() OVER ( PARTITION BY channel_desc ORDER BY amount_sold DESC) AS rn
	-- row number is used because it assigns unique rank
    FROM customer_sales
)
SELECT channel_desc, cust_last_name, cust_first_name,
    TO_CHAR(amount_sold, 'FM9999999990.00') AS amount_sold,
    TO_CHAR((amount_sold / total_channel_sales) * 100, 'FM999990.0000') || '%' AS sales_percentage
FROM ranked_sales
WHERE rn <= 5
ORDER BY channel_desc, amount_sold DESC;



-- Task 2
-- Create a query to retrieve data for a report that displays the total sales for all products in the Photo category
-- in the Asian region for the year 2000. Calculate the overall report total and name it 'YEAR_SUM'

-- window function SUM() OVER() is the most efficient way to have details right and calculate year_sum right as well
SELECT prod_name, TO_CHAR(year_sum, '999,999,990.00') AS year_sum
FROM (
    SELECT p.prod_name,
	SUM(SUM(s.amount_sold)) OVER (PARTITION BY p.prod_name) AS year_sum
    FROM sales s
    JOIN products p ON s.prod_id = p.prod_id
    JOIN times t ON s.time_id = t.time_id
    JOIN customers cust ON s.cust_id = cust.cust_id
    JOIN countries co ON cust.country_id = co.country_id
    WHERE p.prod_category = 'Photo' 
	AND co.country_region = 'Asia' 
	AND t.calendar_year = 2000
    GROUP BY p.prod_name
)
ORDER BY year_sum DESC;



-- Task 3
-- Create a query to generate a sales report for customers ranked in the top 300 based on total sales in the years 1998, 1999, and 2001. 

-- here used two CTE because its easier to look, debug and work with
-- ROW_NUMBER() OVER (PARTITION BY calendar_year) gives us exactly 300 results for each year
WITH yearly_sales AS (
    SELECT ch.channel_desc, c.cust_id, c.cust_last_name, c.cust_first_name, t.calendar_year,
           SUM(s.amount_sold) AS amount_sold
    FROM sales s
    JOIN customers c ON s.cust_id = c.cust_id
    JOIN channels ch ON s.channel_id = ch.channel_id
    JOIN times t ON s.time_id = t.time_id
    WHERE t.calendar_year IN (1998, 1999, 2001)
    GROUP BY ch.channel_desc, c.cust_id, c.cust_last_name, c.cust_first_name, t.calendar_year
),
ranked AS (
    SELECT channel_desc, cust_id, cust_last_name, cust_first_name, amount_sold,
	ROW_NUMBER() OVER (PARTITION BY calendar_year ORDER BY amount_sold DESC) AS rn
    FROM yearly_sales
)
SELECT channel_desc, cust_id, cust_last_name, cust_first_name,
       TO_CHAR(amount_sold, 'FM999,999,990.00') AS amount_sold
FROM ranked
WHERE rn <= 300
ORDER BY channel_desc, amount_sold DESC;



-- Task 4
-- Create a query to generate a sales report for January 2000, February 2000, and March 2000 specifically for the Europe and Americas regions.
-- Display the result by months and by product category in alphabetical order.

-- SUM()) OVER (PARTITION BY month, category) gives opportunity for calculation without GROUP BY
-- DISTINCT gets rid of identical results	
SELECT DISTINCT t.calendar_month_desc AS report_month, p.prod_category,
TO_CHAR( SUM(s.amount_sold) OVER (PARTITION BY t.calendar_month_desc, p.prod_category), '999,999,990.00') AS total_sales
FROM sales s
JOIN products p  ON s.prod_id = p.prod_id
JOIN times t     ON s.time_id = t.time_id
JOIN customers c ON s.cust_id = c.cust_id
JOIN countries co ON c.country_id = co.country_id
WHERE t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')
AND co.country_region IN ('Europe', 'Americas')
ORDER BY report_month ASC, p.prod_category ASC;