-- Task 1
-- Current quarter, year extracted using EXTRACT and YEAR FROM CURRENT_DATE or QUARTER FROM CURRENT_DATE
-- INNER JOIN excludes zero sales and has only categories with sales
-- Dynamic because of CURRENT_DATE
CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_sales
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN inventory i ON fc.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
WHERE EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
  AND EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE)
GROUP BY c.name
HAVING COUNT(p.payment_id) > 0;

-- to retrieve
SELECT * FROM sales_revenue_by_category_qtr;

-- Used this query to test if my query itself for view works:
SELECT 
    c.name AS category,
    SUM(p.amount) AS total_sales
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN inventory i ON fc.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
WHERE EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM DATE '2017-05-01')
  AND EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM DATE '2017-05-01')
GROUP BY c.name
HAVING COUNT(p.payment_id) > 0;
-- basically replaced current date with the one that exists in a database



-- Task 2
-- Parameters are needed because it allows to query ANY year or quarter
CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(p_year INT, p_quarter INT)
RETURNS TABLE (category TEXT, total_sales NUMERIC) 
LANGUAGE sql
AS $$
SELECT 
    c.name::TEXT,
    SUM(p.amount)
FROM category c
JOIN film_category fc ON c.category_id = fc.category_id
JOIN inventory i ON fc.film_id = i.film_id
JOIN rental r ON i.inventory_id = r.inventory_id
JOIN payment p ON r.rental_id = p.rental_id
WHERE EXTRACT(YEAR FROM p.payment_date) = p_year
  AND EXTRACT(QUARTER FROM p.payment_date) = p_quarter
GROUP BY c.name;
$$;

-- To check if it works(year where data exists)
SELECT * FROM get_sales_revenue_by_category_qtr(2017, 2);

-- Edge case(year where nothing exists)
SELECT * FROM get_sales_revenue_by_category_qtr(2007, 2);
-- Empty set is returned if there is no data or data given is invalid(like for quarter value less < 1 or > 4)



-- Task 3
-- most popular is based on COUNT(rentals)
-- Uses LIMIT 1 sp arbitrary pick among ties
-- for a tie the function uses ROW_NUMBER() with a tie-breaker
DROP FUNCTION most_popular_films_by_countries(text[])

CREATE OR REPLACE FUNCTION most_popular_films_by_countries(countries TEXT[])
RETURNS TABLE(
    country TEXT,
    film_title TEXT,
    rating TEXT,
    language TEXT,
    film_length TEXT,
    release_year TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH FilmRentalCounts AS (
        SELECT 
            co.country::TEXT AS c_name,
            f.title::TEXT AS f_title,
            f.rating::TEXT AS f_rating,
            l.name::TEXT AS l_name,
            f.length::TEXT AS f_len,
            f.release_year::TEXT AS f_year,
            ROW_NUMBER() OVER (
                PARTITION BY co.country 
                ORDER BY COUNT(r.rental_id) DESC, f.title ASC
            ) as popularity_rank
        FROM country co
        JOIN city ci ON co.country_id = ci.country_id
        JOIN address a ON ci.city_id = a.city_id
        JOIN customer cu ON a.address_id = cu.address_id
        JOIN rental r ON cu.customer_id = r.customer_id
        JOIN inventory i ON r.inventory_id = i.inventory_id
        JOIN film f ON i.film_id = f.film_id
        JOIN language l ON f.language_id = l.language_id
        WHERE co.country = ANY(countries)
        GROUP BY co.country, f.film_id, l.name
    )
    SELECT c_name, f_title, f_rating, l_name, f_len, f_year
    FROM FilmRentalCounts
    WHERE popularity_rank = 1;
END;
$$;

-- test
SELECT * FROM most_popular_films_by_countries(ARRAY['Afghanistan', 'United States','Brazil']);

-- edge case(returns empty)
SELECT * FROM most_popular_films_by_countries(ARRAY['UnknownCountry']);



-- Task 4
-- Used ILIKE instead of LIKE because its case insensitive
-- Returns everything that matches in name no matter where the word placed
-- The 'match_count' check at the beginning prevents running heavy join query 
-- if the pattern doesn't match any films 
-- To minimize processing 'NOT EXISTS' is used
-- This is generally more efficient 
DROP FUNCTION films_in_stock_by_title(text)

CREATE OR REPLACE FUNCTION films_in_stock_by_title(p_pattern TEXT)
RETURNS TABLE (
    row_num INT, 
    film_title TEXT, 
    language TEXT, 
    customer_name TEXT, 
    rental_date TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE 
    match_count INT;
BEGIN
    SELECT COUNT(*) INTO match_count FROM film WHERE title ILIKE p_pattern;
    
    IF match_count = 0 THEN
        RAISE EXCEPTION 'No films found matching pattern: %', p_pattern;
    END IF;
    RETURN QUERY
    SELECT 
        (ROW_NUMBER() OVER (ORDER BY f.title, r.rental_date DESC))::INT,
        f.title::TEXT,
        l.name::TEXT,
        (c.first_name || ' ' || c.last_name)::TEXT,
        r.rental_date
    FROM film f
    JOIN language l ON f.language_id = l.language_id
    JOIN inventory i ON f.film_id = i.film_id
    LEFT JOIN rental r ON i.inventory_id = r.inventory_id
    LEFT JOIN customer c ON r.customer_id = c.customer_id
    WHERE f.title ILIKE p_pattern
    AND NOT EXISTS (
        SELECT 1 FROM rental r2 
        WHERE r2.inventory_id = i.inventory_id 
        AND r2.return_date IS NULL
    );
END;
$$;

-- test
SELECT * FROM films_in_stock_by_title('%love%');

-- edge case(exception is raised if no matches)
SELECT * FROM films_in_stock_by_title('%xyz123%');



-- Task 5
-- film_id is SERIAL. By omitting film_id from INSERT, it automatically 
-- fetches the next value from sequence, so ID is unique..
-- IF EXISTS before we insert so that there are no duplicates
-- RAISE EXCEPTION if movie was already there 
-- To validate language SELECT lookup on the language is used
-- If v_lang_id is NULL it means language doesnt exist, so exception is raised
-- If the INSERT fails, PL/pgSQL aborts the transaction
-- Consistency is preserved because PostgreSQL functions are atomic
CREATE OR REPLACE FUNCTION new_movie(
    p_title TEXT, 
    p_year INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT, 
    p_lang TEXT DEFAULT 'Klingon'
)
RETURNS VOID 
LANGUAGE plpgsql 
AS $$
DECLARE
    v_lang_id INT;
BEGIN
    IF EXISTS (SELECT 1 FROM film WHERE title = p_title) THEN
        RAISE EXCEPTION 'Movie title "%" already exists.', p_title;
    END IF;

    SELECT language_id INTO v_lang_id FROM language WHERE name = p_lang;
    
    IF v_lang_id IS NULL THEN
        RAISE EXCEPTION 'Language "%" not found in database.', p_lang;
    END IF;
    INSERT INTO film (
        title, release_year, language_id, rental_duration, rental_rate, replacement_cost
    )
    VALUES (
        p_title, p_year, v_lang_id, 3, 4.99, 19.99
    );
    
    RAISE NOTICE 'Movie "%" added successfully.', p_title;
END;
$$;

INSERT INTO language (name) VALUES ('Klingon');

SELECT new_movie('TEST');

SELECT 
    film_id, 
    title, 
    release_year, 
    rental_rate, 
    rental_duration, 
    replacement_cost,
    last_update
FROM film 
WHERE title = 'TEST';
