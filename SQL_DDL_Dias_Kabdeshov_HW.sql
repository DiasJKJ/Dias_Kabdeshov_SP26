CREATE TABLE IF NOT EXISTS line (
    line_id SERIAL PRIMARY KEY, --Using SERIAL for auto-increment
    name VARCHAR(100) NOT NULL,
    description VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS station (
    station_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    location VARCHAR(255),
    opened_date DATE CHECK (opened_date > '2000-01-01'), --So that there are no garbage values
    closed_date DATE
);

CREATE TABLE IF NOT EXISTS train (
    train_id SERIAL PRIMARY KEY,
    train_number VARCHAR(20) NOT NULL,
    capacity INT CHECK (capacity > 0)
);

CREATE TABLE IF NOT EXISTS Passenger (
    passenger_id SERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL, --So that no duplicate emails
    phone_number VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS FareCategory (
    category_id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL
);


CREATE TABLE IF NOT EXISTS LineStation (
    line_id INT REFERENCES Line(line_id), --Without these FKs, Schedule table could reference
    station_id INT REFERENCES Station(station_id), --non-existent line-station mappings
    station_order INT NOT NULL,
    PRIMARY KEY (line_id, station_id)
);

CREATE TABLE IF NOT EXISTS TrainAssignment (
    assignment_id SERIAL PRIMARY KEY,
    train_id INT REFERENCES Train(train_id), --If FK missing, you could assign
    line_id INT REFERENCES Line(line_id), --a train or line that doesn’t exist
    assigned_from DATE,
    assigned_to DATE
);

CREATE TABLE IF NOT EXISTS Schedule (
    schedule_id SERIAL PRIMARY KEY,
    train_id INT REFERENCES Train(train_id),
    line_id INT,
    station_id INT,
    departure_time TIMESTAMP,
    arrival_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'active' CONSTRAINT check_status_enum 
        CHECK (status IN ('active', 'cancelled', 'delayed')),
	FOREIGN KEY (line_id, station_id) REFERENCES LineStation(line_id, station_id)
	--Schedule cannot exist without valid train & station mapping. 
	--Wrong order of inserts causes FK error 23503.
);

CREATE TABLE IF NOT EXISTS Booking (
    booking_id SERIAL PRIMARY KEY,
    train_id INT REFERENCES Train(train_id),
    schedule_id INT REFERENCES Schedule(schedule_id),
    booking_date DATE DEFAULT CURRENT_DATE,
    total_price DECIMAL(10, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS Ticket (
    ticket_id SERIAL PRIMARY KEY,
    passenger_id INT REFERENCES Passenger(passenger_id),
    category_id INT REFERENCES FareCategory(category_id),
    booking_id INT REFERENCES Booking(booking_id),
    valid_from DATE,
    valid_to DATE,
    purchase_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    price DECIMAL(10, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS TrainMaintenance (
    maintenance_id SERIAL PRIMARY KEY,
    train_id INT,
    maintenance_start TIMESTAMP NOT NULL,
    maintenance_end TIMESTAMP,
    description TEXT,
	FOREIGN KEY (train_id) REFERENCES Train(train_id)
	--Without FK, maintenance could be assigned to non-existent train
);

CREATE TABLE IF NOT EXISTS StationMaintenance (
    maintenance_id SERIAL PRIMARY KEY,
    station_id INT REFERENCES Station(station_id),
    maintenance_start TIMESTAMP,
    maintenance_end TIMESTAMP,
    description TEXT
);

-- record_ts for auditing
ALTER TABLE Line ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE Station ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE Train ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE Schedule ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE Passenger ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE Booking ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE Ticket ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE LineStation ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE TrainAssignment ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE FareCategory ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE TrainMaintenance ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE StationMaintenance ADD COLUMN IF NOT EXISTS record_ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL;


-- It is important we add parent tables first because they are what we are referencing
INSERT INTO line (name, description) VALUES 
('Red Line', 'Main North-South Corridor'),
('Blue Line', 'East-West Express')
ON CONFLICT DO NOTHING;

INSERT INTO station (name, location, opened_date) VALUES 
('Central Station', 'Downtown Hub', '2010-05-20'),
('Airport Terminal', 'East End', '2015-11-12'),
('Suburban Park', 'North District', '2018-01-30')
ON CONFLICT DO NOTHING;

INSERT INTO train (train_number, capacity) VALUES 
('TRN-101', 350),
('TRN-102', 500)
ON CONFLICT DO NOTHING;

INSERT INTO Passenger (full_name, email, phone_number) VALUES 
('Alice Vance', 'alice.v@example.com', '555-0101'),
('Bob Miller', 'bob.m@example.com', '555-0202')
ON CONFLICT DO NOTHING;

INSERT INTO FareCategory (type_name) VALUES 
('Adult'),
('Student'),
('Senior')
ON CONFLICT DO NOTHING;

-- Mapping stations to lines
INSERT INTO LineStation (line_id, station_id, station_order) VALUES 
((SELECT line_id FROM line WHERE name = 'Red Line'), (SELECT station_id FROM station WHERE name = 'Central Station'), 1),
((SELECT line_id FROM line WHERE name = 'Red Line'), (SELECT station_id FROM station WHERE name = 'Suburban Park'), 2),
((SELECT line_id FROM line WHERE name = 'Blue Line'), (SELECT station_id FROM station WHERE name = 'Central Station'), 1),
((SELECT line_id FROM line WHERE name = 'Blue Line'), (SELECT station_id FROM station WHERE name = 'Airport Terminal'), 2)
ON CONFLICT DO NOTHING;

-- ASSIGNMENTS & SCHEDULES
INSERT INTO TrainAssignment (train_id, line_id, assigned_from) VALUES 
((SELECT train_id FROM train WHERE train_number = 'TRN-101'), (SELECT line_id FROM line WHERE name = 'Red Line'), '2024-01-01'),
((SELECT train_id FROM train WHERE train_number = 'TRN-102'), (SELECT line_id FROM line WHERE name = 'Blue Line'), '2024-01-01')
ON CONFLICT DO NOTHING;

INSERT INTO Schedule (train_id, line_id, station_id, departure_time, arrival_time, status) VALUES 
(
    (SELECT train_id FROM train WHERE train_number = 'TRN-101'),
    (SELECT line_id FROM line WHERE name = 'Red Line'),
    (SELECT station_id FROM station WHERE name = 'Central Station'),
    '2024-04-10 08:00:00', '2024-04-10 08:05:00', 'active'
),
(
    (SELECT train_id FROM train WHERE train_number = 'TRN-102'),
    (SELECT line_id FROM line WHERE name = 'Blue Line'),
    (SELECT station_id FROM station WHERE name = 'Airport Terminal'),
    '2024-04-10 09:30:00', '2024-04-10 09:40:00', 'active'
)
ON CONFLICT DO NOTHING;

-- Bookings reference specific schedules
INSERT INTO Booking (train_id, schedule_id, total_price) VALUES 
(
    (SELECT train_id FROM train WHERE train_number = 'TRN-101'),
    (SELECT schedule_id FROM Schedule LIMIT 1), -- Simplification for sample data
    25.00
),
(
    (SELECT train_id FROM train WHERE train_number = 'TRN-102'),
    (SELECT schedule_id FROM Schedule OFFSET 1 LIMIT 1),
    30.00
)
ON CONFLICT DO NOTHING;

INSERT INTO Ticket (passenger_id, category_id, booking_id, price, valid_from, valid_to) VALUES 
(
    (SELECT passenger_id FROM Passenger WHERE email = 'alice.v@example.com'),
    (SELECT category_id FROM FareCategory WHERE type_name = 'Adult'),
    (SELECT booking_id FROM Booking LIMIT 1),
    25.00, '2024-04-10', '2024-04-11'
),
(
    (SELECT passenger_id FROM Passenger WHERE email = 'bob.m@example.com'),
    (SELECT category_id FROM FareCategory WHERE type_name = 'Student'),
    (SELECT booking_id FROM Booking OFFSET 1 LIMIT 1),
    30.00, '2024-04-10', '2024-04-11'
)
ON CONFLICT DO NOTHING;

-- MAINTENANCE
INSERT INTO TrainMaintenance (train_id, maintenance_start, description) VALUES 
((SELECT train_id FROM train WHERE train_number = 'TRN-101'), '2024-03-15 10:00:00', 'Routine brake check'),
((SELECT train_id FROM train WHERE train_number = 'TRN-102'), '2024-03-20 09:00:00', 'HVAC repair')
ON CONFLICT DO NOTHING;

INSERT INTO StationMaintenance (station_id, maintenance_start, description) VALUES 
((SELECT station_id FROM station WHERE name = 'Central Station'), '2024-04-01 23:00:00', 'Escalator deep clean'),
((SELECT station_id FROM station WHERE name = 'Airport Terminal'), '2024-04-05 22:30:00', 'Platform tile replacement')
ON CONFLICT DO NOTHING;
