SET ROLE postgres
-- Task 2
-- 1
CREATE USER rentaluser WITH PASSWORD 'rentalpassword';
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

-- 2
GRANT SELECT ON TABLE customer TO rentaluser;

SET ROLE rentaluser;

SELECT * FROM customer;

-- 3
CREATE ROLE rental;
GRANT rental TO rentaluser;

-- 4
GRANT INSERT, UPDATE ON TABLE rental TO rental;

SET ROLE rental;

GRANT USAGE, SELECT ON SEQUENCE rental_rental_id_seq TO rental;

INSERT INTO rental(rental_date, inventory_id, customer_id, return_date, staff_id)
VALUES (NOW(), 1, 1, NULL, 1);

SET ROLE rentaluser;
SET ROLE rental;

SET ROLE postgres
GRANT SELECT ON TABLE rental TO rental;
SET ROLE rental;

UPDATE rental 
SET return_date = NOW() 
WHERE rental_id = (SELECT MAX(rental_id) FROM rental);


-- 5
REVOKE INSERT ON TABLE rental FROM rental;
INSERT INTO rental(rental_date, inventory_id, customer_id, staff_id)
VALUES (NOW(), 1, 1, 1);

-- ERROR:  нет доступа к таблице rental 

-- ОШИБКА:  нет доступа к таблице rental
-- SQL state: 42501

-- 6
SELECT customer_id, first_name, last_name
FROM customer
LIMIT 1;

CREATE ROLE client_Linda_Williams LOGIN PASSWORD 'client123';

GRANT SELECT ON TABLE payment TO client_Linda_Williams;
GRANT SELECT ON TABLE rental TO client_Linda_Williams;



-- Task 3
GRANT SELECT ON TABLE rental TO our_client_linda_williams;
GRANT SELECT ON TABLE payment TO our_client_linda_williams;

ALTER TABLE rental ENABLE ROW LEVEL SECURITY;

ALTER TABLE payment ENABLE ROW LEVEL SECURITY;

SELECT * FROM customer

SELECT customer_id, first_name, last_name 
FROM customer 
WHERE customer_id IN (SELECT customer_id FROM rental) 
LIMIT 1;

CREATE ROLE our_client_linda_williams WITH LOGIN PASSWORD 'password123';

GRANT CONNECT ON DATABASE dvdrental TO our_client_linda_williams;
GRANT USAGE ON SCHEMA public TO our_client_linda_williams;

CREATE POLICY select_own_rentals ON rental
FOR SELECT
TO our_client_linda_williams
USING (customer_id = 3); -- Linda Williams id

CREATE POLICY payment_customer_policy ON payment
FOR SELECT
TO our_client_linda_williams
USING (customer_id = 3); -- Linda Williams id

SET ROLE our_client_linda_williams;

SELECT * FROM rental; --52 records shown

SELECT * FROM payment -- same, 52 records

SELECT DISTINCT customer_id FROM rental; -- 3 is returned
SELECT DISTINCT customer_id FROM payment; -- 3 is returned

SELECT * FROM rental WHERE customer_id = 1; -- nothing returned