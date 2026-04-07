-- Task 1

-- 1. INSERT FILMS
-- Each block is isolated so failure does not corrupt other steps
-- If transaction fails then all changes rollback automatically
-- Referential integrity preserved because inserts follow FK order

ROLLBACK;

BEGIN;

WITH new_films AS (
    SELECT *
    FROM (
        VALUES 
        ('Inception', 2010, 4.99, 7),
        ('Interstellar', 2014, 9.99, 14),
        ('The Dark Knight', 2008, 19.99, 21)
    ) AS f(title, release_year, rental_rate, rental_duration)
)
INSERT INTO public.film (
    title, release_year, rental_rate, rental_duration, language_id, last_update
)
SELECT nf.title, nf.release_year, nf.rental_rate, nf.rental_duration,
    1, -- English
    CURRENT_DATE
FROM new_films nf
WHERE NOT EXISTS (
    SELECT 1 FROM public.film f WHERE f.title = nf.title
)
RETURNING film_id, title;

-- Uniqueness ensured via title check
-- INSERT INTO ... SELECT avoids hardcoding IDs

COMMIT;


-- 2. INSERT ACTORS

BEGIN;

WITH new_actors AS (
    SELECT *
    FROM (
        VALUES
        ('Leonardo', 'DiCaprio'),
        ('Joseph', 'Gordon-Levitt'),
        ('Matthew', 'McConaughey'),
        ('Anne', 'Hathaway'),
        ('Christian', 'Bale'),
        ('Heath', 'Ledger')
    ) AS a(first_name, last_name)
)
INSERT INTO public.actor (first_name, last_name, last_update)
SELECT 
    na.first_name,
    na.last_name,
    CURRENT_DATE
FROM new_actors na
WHERE NOT EXISTS (
    SELECT 1 
    FROM public.actor a
    WHERE a.first_name = na.first_name
      AND a.last_name = na.last_name
)
RETURNING actor_id, first_name;

-- Avoid duplicates using name match

COMMIT;


-- 3. LINK ACTORS TO FILMS (film_actor)

BEGIN;

INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT 
    a.actor_id,
    f.film_id,
    CURRENT_DATE
FROM public.actor a
JOIN public.film f ON
    (f.title = 'Inception' AND a.last_name IN ('DiCaprio','Gordon-Levitt'))
 OR (f.title = 'Interstellar' AND a.last_name IN ('McConaughey','Hathaway'))
 OR (f.title = 'The Dark Knight' AND a.last_name IN ('Bale','Ledger'))
WHERE NOT EXISTS (
    SELECT 1
    FROM public.film_actor fa
    WHERE fa.actor_id = a.actor_id
      AND fa.film_id = f.film_id
);

COMMIT;


-- 4. ADD FILMS TO INVENTORY

BEGIN;

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT 
    f.film_id,
    1, -- any store
    CURRENT_DATE
FROM public.film f
WHERE f.title IN ('Inception','Interstellar','The Dark Knight')
AND NOT EXISTS (
    SELECT 1 FROM public.inventory i WHERE i.film_id = f.film_id
)
RETURNING inventory_id;

COMMIT;


-- 5. UPDATE CUSTOMER

BEGIN;

UPDATE public.customer c
SET 
    first_name = 'Dias',
    last_name = 'Kabdeshov',
    address_id = (SELECT address_id FROM public.address LIMIT 1),
    last_update = CURRENT_DATE
WHERE c.customer_id = (
    SELECT c2.customer_id
    FROM public.customer c2
    JOIN public.rental r ON c2.customer_id = r.customer_id
    JOIN public.payment p ON c2.customer_id = p.customer_id
    GROUP BY c2.customer_id
    HAVING COUNT(DISTINCT r.rental_id) >= 43
       AND COUNT(DISTINCT p.payment_id) >= 43
    LIMIT 1
)
RETURNING customer_id;

-- Safe because only one selected customer updated

COMMIT;


-- 6. DELETE RELATED RECORDS

BEGIN;


-- SELECT * FROM public.rental WHERE customer_id IN (
--     SELECT customer_id FROM public.customer WHERE first_name = 'Dias'
-- );

DELETE FROM public.payment
WHERE customer_id IN (
    SELECT customer_id FROM public.customer WHERE first_name = 'Dias'
);

DELETE FROM public.rental
WHERE customer_id IN (
    SELECT customer_id FROM public.customer WHERE first_name = 'Dias'
);

-- Safe because only affects our modified customer
-- Referential integrity preserved

COMMIT;


-- 7. RENT MOVIES + PAYMENTS

BEGIN;

WITH cust AS (
    SELECT customer_id FROM public.customer WHERE first_name = 'Dias' LIMIT 1
),
inv AS (
    SELECT inventory_id FROM public.inventory i
    JOIN public.film f ON i.film_id = f.film_id
    WHERE f.title IN ('Inception','Interstellar','The Dark Knight')
),
staff_member AS (
    SELECT staff_id FROM public.staff LIMIT 1
),
new_rentals AS (
    INSERT INTO public.rental (
        rental_date, inventory_id, customer_id, staff_id, last_update
    )
    SELECT 
        DATE '2017-03-01', inv.inventory_id, cust.customer_id, staff_member.staff_id, CURRENT_DATE
    FROM cust, inv, staff_member
    RETURNING rental_id, customer_id, staff_id
)
INSERT INTO public.payment (
    customer_id, staff_id, rental_id, amount, payment_date
)
SELECT nr.customer_id, nr.staff_id, nr.rental_id, 9.99, DATE '2017-03-01'
FROM new_rentals nr;

-- Relationships preserved via RETURNING
-- No hardcoded IDs

COMMIT;


-- Overall i guess its needed to say that all if transaction fails all changes insied
-- transaction rolled back automatically
-- Rollback works before commit and after Commit nothing can be changed
