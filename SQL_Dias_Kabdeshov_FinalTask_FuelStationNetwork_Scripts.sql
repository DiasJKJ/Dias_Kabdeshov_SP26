DROP SCHEMA IF EXISTS fuel_network CASCADE;
CREATE SCHEMA fuel_network;

SET search_path TO fuel_network;

CREATE TABLE fuel_station (
    station_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(150) NOT NULL,
    phone VARCHAR(20) UNIQUE
);

CREATE TABLE fuel_type (
    fuel_type_id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description VARCHAR(150)
);

CREATE TABLE customer (
    customer_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) UNIQUE
);




CREATE TABLE employee (
    employee_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    position VARCHAR(50) NOT NULL,
    station_id INT NOT NULL,
    
    CONSTRAINT fk_employee_station
        FOREIGN KEY (station_id)
        REFERENCES fuel_station(station_id)
);

CREATE TABLE station_fuel (
    station_id INT,
    fuel_type_id INT,
    available_quantity DECIMAL(10,2) DEFAULT 0,

    PRIMARY KEY (station_id, fuel_type_id),

    CONSTRAINT fk_sf_station
        FOREIGN KEY (station_id)
        REFERENCES fuel_station(station_id),

    CONSTRAINT fk_sf_fuel
        FOREIGN KEY (fuel_type_id)
        REFERENCES fuel_type(fuel_type_id)
);

CREATE TABLE fuel_price (
    price_id SERIAL PRIMARY KEY,
    station_id INT NOT NULL,
    fuel_type_id INT NOT NULL,
    regular_price DECIMAL(10,2) NOT NULL,
    discount_price DECIMAL(10,2),
    effective_date DATE DEFAULT CURRENT_DATE,

    CONSTRAINT fk_price_station
        FOREIGN KEY (station_id)
        REFERENCES fuel_station(station_id),

    CONSTRAINT fk_price_fuel
        FOREIGN KEY (fuel_type_id)
        REFERENCES fuel_type(fuel_type_id)
);

CREATE TABLE sale_transaction (
    transaction_id SERIAL PRIMARY KEY,
    station_id INT NOT NULL,
    fuel_type_id INT NOT NULL,
    customer_id INT,
    quantity DECIMAL(10,2) NOT NULL,
    
    total_amount DECIMAL(12,2) GENERATED ALWAYS AS (quantity * 100) STORED,

    payment_method VARCHAR(20) NOT NULL,
    sale_datetime TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_sale_station
        FOREIGN KEY (station_id)
        REFERENCES fuel_station(station_id),

    CONSTRAINT fk_sale_fuel
        FOREIGN KEY (fuel_type_id)
        REFERENCES fuel_type(fuel_type_id),

    CONSTRAINT fk_sale_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer(customer_id)
);

CREATE TABLE fuel_delivery (
    delivery_id SERIAL PRIMARY KEY,
    station_id INT NOT NULL,
    fuel_type_id INT NOT NULL,
    supplier_name VARCHAR(100) NOT NULL,
    quantity DECIMAL(10,2) NOT NULL,
    delivery_date DATE NOT NULL,

    CONSTRAINT fk_delivery_station
        FOREIGN KEY (station_id)
        REFERENCES fuel_station(station_id),

    CONSTRAINT fk_delivery_fuel
        FOREIGN KEY (fuel_type_id)
        REFERENCES fuel_type(fuel_type_id)
);



-- Because quantity cannot be negative
ALTER TABLE station_fuel
ADD CONSTRAINT chk_sf_quantity_non_negative
CHECK (available_quantity >= 0);

-- Sale quantity must be positive
ALTER TABLE sale_transaction
ADD CONSTRAINT chk_sale_quantity_positive
CHECK (quantity > 0);

-- Delivery quantity must be positive
ALTER TABLE fuel_delivery
ADD CONSTRAINT chk_delivery_quantity_positive
CHECK (quantity > 0);

-- Price must be positive
ALTER TABLE fuel_price
ADD CONSTRAINT chk_price_positive
CHECK (regular_price > 0);

-- Discount price should be less than regular price
ALTER TABLE fuel_price
ADD CONSTRAINT chk_discount_less_than_regular
CHECK (discount_price <= regular_price);

ALTER TABLE fuel_delivery
ADD CONSTRAINT chk_delivery_date_valid
CHECK (delivery_date > DATE '2026-01-01');

ALTER TABLE sale_transaction
ADD CONSTRAINT chk_payment_method_valid
CHECK (payment_method IN ('cash', 'card'));




INSERT INTO fuel_station (name, location, phone) VALUES 
('Qazaq Oil Left Bank', 'Mangilik El Ave 28, Astana', '+7717200111'),
('Compass Turan', 'Turan Ave 46/1, Astana', '+7717200222'),
('Sinooil Almaty District', 'Tauelsizdik Ave 12, Astana', '+7717200333'),
('GasEnergy Kabanbay', 'Kabanbay Batyr Ave 31, Astana', '+7717200444'),
('Helios Saryarka', 'Saryarka Ave 15, Astana', '+7717200555'),
('Nomad Oil Respublika', 'Respublika Ave 52, Astana', '+7717200666');

INSERT INTO fuel_type (name, description) VALUES 
('AI-92', 'Standard Unleaded Petrol'),
('AI-95', 'Premium Unleaded Petrol'),
('AI-98', 'High Octane Super Petrol'),
('Diesel', 'Winter/Summer Automotive Diesel'),
('LPG', 'Liquefied Petroleum Gas'),
('AdBlue', 'Diesel Exhaust Fluid');

INSERT INTO customer (full_name, phone) VALUES 
('Arman Muratov', '+7701555111'),
('Assel Saduakasova', '+7702555222'),
('Bauyrzhan Ibragimov', '+7705555333'),
('Dinara Kalieva', '+7707555444'),
('Kairat Nurtas', '+7747555555'),
('Elena Petrova', '+7777555666');

INSERT INTO employee (full_name, position, station_id)
SELECT 'Daulet Eskali', 'Manager', station_id FROM fuel_station WHERE name LIKE '%Qazaq%' UNION ALL
SELECT 'Aigul Karimova', 'Cashier', station_id FROM fuel_station WHERE name LIKE '%Compass%' UNION ALL
SELECT 'Serik Bolatov', 'Attendant', station_id FROM fuel_station WHERE name LIKE '%Sinooil%' UNION ALL
SELECT 'Marat Aliyev', 'Attendant', station_id FROM fuel_station WHERE name LIKE '%GasEnergy%' UNION ALL
SELECT 'Svetlana Ivanova', 'Cashier', station_id FROM fuel_station WHERE name LIKE '%Helios%' UNION ALL
SELECT 'Kanat Isakov', 'Manager', station_id FROM fuel_station WHERE name LIKE '%Nomad%';

INSERT INTO station_fuel (station_id, fuel_type_id, available_quantity)
SELECT s.station_id, f.fuel_type_id, 10000.00
FROM fuel_station s CROSS JOIN fuel_type f;

INSERT INTO fuel_price (station_id, fuel_type_id, regular_price, discount_price, effective_date)
SELECT 
    base.station_id, 
    base.fuel_type_id, 
    base.price,
    GREATEST(base.price - (RANDOM() * 20), 0),
    CURRENT_DATE - (gs || ' days')::INTERVAL
FROM (
    SELECT s.station_id, f.fuel_type_id, (200 + RANDOM()*50) AS price
    FROM fuel_station s CROSS JOIN fuel_type f
) base
CROSS JOIN generate_series(0, 5) AS gs;

INSERT INTO fuel_delivery (station_id, fuel_type_id, supplier_name, quantity, delivery_date)
SELECT 
    s.station_id, 
    f.fuel_type_id, 
    'PetroKazakhstan Supply', 
    5000, 
    CURRENT_DATE - interval '10 days'
FROM fuel_station s 
JOIN fuel_type f ON f.name = 'AI-95'
LIMIT 8;

INSERT INTO sale_transaction (station_id, fuel_type_id, customer_id, quantity, payment_method, sale_datetime)
SELECT 
    fs.station_id,
    ft.fuel_type_id,
    c.customer_id,
    (20 + RANDOM() * 40),
    CASE WHEN gs % 2 = 0 THEN 'cash' ELSE 'card' END,
    CURRENT_DATE - (gs || ' days')::INTERVAL
FROM generate_series(1, 15) AS gs
JOIN fuel_station fs ON TRUE
JOIN fuel_type ft ON TRUE
JOIN customer c ON TRUE
LIMIT 15;



-- 5.1 Create a function that updates data in one of your tables
CREATE OR REPLACE FUNCTION fuel_network.update_table_value(
    p_table_name TEXT,
    p_id_column TEXT,
    p_id_value INT,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS VOID AS $$
DECLARE
    v_sql TEXT;
    v_data_type TEXT;
BEGIN
    SELECT udt_name INTO v_data_type
    FROM information_schema.columns
    WHERE table_schema = 'fuel_network'
      AND table_name = p_table_name
      AND column_name = p_column_name;

    IF v_data_type IS NULL THEN
        RAISE EXCEPTION 'Column % does not exist in table %', p_column_name, p_table_name;
    END IF;

    v_sql := format(
        'UPDATE fuel_network.%I SET %I = $1::%s WHERE %I = $2',
        p_table_name,
        p_column_name,
        v_data_type,
        p_id_column
    );

    EXECUTE v_sql USING p_new_value, p_id_value;

    RAISE NOTICE 'Updated %: set % = % where % = %',
        p_table_name, p_column_name, p_new_value, p_id_column, p_id_value;
END;
$$ LANGUAGE plpgsql;

-- example
SELECT fuel_network.update_table_value(
    'customer',
    'customer_id',
    1,
    'phone',
    '+7701999999'
);


-- 5.2 Create a function that adds a new transaction to your transaction table. 
CREATE OR REPLACE FUNCTION fuel_network.add_sale_transaction(
    p_station_name TEXT,
    p_fuel_type_name TEXT,
    p_customer_name TEXT,
    p_quantity NUMERIC,
    p_payment_method TEXT,
    p_sale_datetime TIMESTAMP
)
RETURNS VOID AS $$
DECLARE
    v_station_id INT;
    v_fuel_type_id INT;
    v_customer_id INT;
BEGIN
    SELECT station_id INTO v_station_id
    FROM fuel_network.fuel_station
    WHERE name = p_station_name;

    SELECT fuel_type_id INTO v_fuel_type_id
    FROM fuel_network.fuel_type
    WHERE name = p_fuel_type_name;

    SELECT customer_id INTO v_customer_id
    FROM fuel_network.customer
    WHERE full_name = p_customer_name;

    INSERT INTO fuel_network.sale_transaction (
        station_id,
        fuel_type_id,
        customer_id,
        quantity,
        payment_method,
        sale_datetime
    )
    VALUES (
        v_station_id,
        v_fuel_type_id,
        v_customer_id,
        p_quantity,
        p_payment_method,
        p_sale_datetime
    );

    RAISE NOTICE 'Transaction added successfully';
END;
$$ LANGUAGE plpgsql;


SELECT fuel_network.add_sale_transaction(
    'Qazaq Oil Left Bank'::TEXT,
    'AI-92'::TEXT,
    'Arman Muratov'::TEXT,
    30::NUMERIC,
    'card'::TEXT,
    CURRENT_TIMESTAMP::TIMESTAMP
);


-- 6. Create a view that presents analytics for the most recently added quarter in your database
CREATE OR REPLACE VIEW fuel_network.quarterly_sales_analytics AS
SELECT 
    fs.name AS station_name,
    ft.name AS fuel_type,
    COUNT(*) AS total_transactions,
    SUM(st.quantity) AS total_fuel_sold,
    AVG(st.quantity) AS avg_fuel_per_transaction,
    SUM(st.total_amount) AS total_revenue
FROM fuel_network.sale_transaction st
JOIN fuel_network.fuel_station fs ON st.station_id = fs.station_id
JOIN fuel_network.fuel_type ft ON st.fuel_type_id = ft.fuel_type_id
WHERE st.sale_datetime >= CURRENT_DATE - INTERVAL '3 months'
GROUP BY fs.name, ft.name
ORDER BY total_revenue DESC;


SELECT * FROM fuel_network.quarterly_sales_analytics;

"station_name"	"fuel_type"	"total_transactions"	"total_fuel_sold"	"avg_fuel_per_transaction"	"total_revenue"
"Qazaq Oil Left Bank"	"AI-92"	7	277.33	39.6185714285714286	27733.00
"Qazaq Oil Left Bank"	"AI-95"	6	269.80	44.9666666666666667	26980.00
"Qazaq Oil Left Bank"	"AI-98"	3	131.59	43.8633333333333333	13159.00



-- 7. Create a read-only role for the manager.
CREATE ROLE manager LOGIN PASSWORD 'StrongPassword123';

GRANT USAGE ON SCHEMA fuel_network TO manager;

GRANT SELECT ON ALL TABLES IN SCHEMA fuel_network TO manager;

ALTER DEFAULT PRIVILEGES IN SCHEMA fuel_network
GRANT SELECT ON TABLES TO manager;