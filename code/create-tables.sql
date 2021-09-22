IF SCHEMA_ID("proc_db") IS NULL
EXEC ("CREATE SCHEMA proc_db");

-- conversion rates to EUR on the latest date
DROP TABLE IF EXISTS proc_db.zfi;
CREATE TABLE proc_db.zfi
(
    from_currency CHAR(3),
    to_currency CHAR(3),
    valid_date DATE,
    exchange_rate FLOAT,
    PRIMARY KEY (from_currency)
);

DROP TABLE IF EXISTS proc_db.locations;
CREATE TABLE proc_db.locations
(
    plant_id CHAR(4),
    warehouse_id CHAR(4),
    warehouse_location VARCHAR(30),
    warehouse_name VARCHAR(20),
    plant_name VARCHAR(20),
    country_code CHAR(2),
    country VARCHAR(15),
    continent VARCHAR(15),
    currency CHAR(3),
    project VARCHAR(15)
    PRIMARY KEY (plant_id, warehouse_id),
    CONSTRAINT fk_locations_zfi FOREIGN KEY (currency) REFERENCES proc_db.zfi(from_currency)
);

DROP TABLE IF EXISTS proc_db.movement_types;
CREATE TABLE proc_db.movement_types
(
    movement_type CHAR(3) PRIMARY KEY,
    is_used_in_reservations BIT,
    movement_type_group VARCHAR(20)
);

DROP TABLE IF EXISTS proc_db.picps;
CREATE TABLE proc_db.picps
(
    pic_number    VARCHAR(40) NOT NULL,
    material_id    VARCHAR(20) NOT NULL PRIMARY KEY
);

DROP TABLE IF EXISTS proc_db.monos_categories;
CREATE TABLE proc_db.monos_categories
(
    material_id    VARCHAR(20) NOT NULL PRIMARY KEY,
    monos_category    VARCHAR(100) NOT NULL
);

-- materials
DROP TABLE IF EXISTS proc_db.zmm001;
CREATE TABLE proc_db.zmm001
(
    material_id VARCHAR(20) PRIMARY KEY NOT NULL,
    material_description TEXT,
    material_group VARCHAR(15) NOT NULL,
    material_group_description TEXT,
    unit VARCHAR(10),
    material_type CHAR(4) NOT NULL,
    created_date DATE NOT NULL,
    last_change_date Date NOT NULL
);

-- stock values
DROP TABLE IF EXISTS proc_db.sp99;
CREATE TABLE proc_db.sp99
(
    material_id VARCHAR(20),
    quantity FLOAT,
    unit VARCHAR(20),
    total_euro_value FLOAT,
    currency CHAR(3),
    plant_id CHAR(4),
    month_of_stock CHAR(7),
    PRIMARY KEY (plant_id, material_id, month_of_stock)
);

-- stock
DROP TABLE IF EXISTS proc_db.mb52;
CREATE TABLE proc_db.mb52
(
    plant_id    CHAR(4) NOT NULL,
    warehouse_id    CHAR(4) DEFAULT 'USTK',
    material_id    VARCHAR(20) NOT NULL,
    unrestricted    FLOAT,
    blocked     FLOAT,
    in_transfer    FLOAT,
    in_transit FLOAT,
    PRIMARY KEY (plant_id, warehouse_id, material_id),
    FOREIGN KEY (plant_id, warehouse_id) REFERENCES proc_db.locations(plant_id, warehouse_id)
);

-- stock movements
DROP TABLE IF EXISTS proc_db.mb51;
CREATE TABLE proc_db.mb51
(
    movement_id INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
    plant_id CHAR(4) NOT NULL,
    warehouse_id CHAR(4) DEFAULT 'USTK',
    material_id VARCHAR(20) NOT NULL,
    quantity FLOAT,
    movement_type CHAR(3),
    entry_date DATE,
    requisition_date DATE,
    movement_value FLOAT NOT NULL,
    reservation_id VARCHAR(15),
    FOREIGN KEY (plant_id, warehouse_id) REFERENCES proc_db.locations(plant_id, warehouse_id),
    FOREIGN KEY (movement_type) REFERENCES proc_db.movement_types(movement_type)
);

-- stock history
DROP TABLE IF EXISTS proc_db.mcba;
CREATE TABLE proc_db.mcba
(
    plant_id CHAR(4) NOT NULL,
    material_id VARCHAR(20) NOT NULL,
    warehouse_id CHAR(4) DEFAULT 'USTK',
    mrp_type CHAR(2),
    month_of_stock CHAR(7),
    issued_quantity FLOAT,
    received_quantity FLOAT,
    stock_quantity FLOAT,
    stock_value FLOAT,
    received_value FLOAT,
    issued_value FLOAT,
    PRIMARY KEY (plant_id, material_id, warehouse_id, month_of_stock),
    FOREIGN KEY (plant_id, warehouse_id) REFERENCES proc_db.locations(plant_id, warehouse_id);
);

-- material Requirements Planning
DROP TABLE IF EXISTS proc_db.zmrp;
CREATE TABLE proc_db.zmrp
(
    warehouse_id CHAR(4) NOT NULL,
    mrp_priority VARCHAR(6),
    proposed_quantity FLOAT,
    average_price FLOAT,
    material_id VARCHAR(20) NOT NULL,
    mrp_type CHAR(2)
    PRIMARY KEY (warehouse_id, material_id)
);

-- reservations
DROP TABLE IF EXISTS proc_db.zmb25;
CREATE TABLE proc_db.zmb25
(
    plant_id CHAR(4) NOT NULL,
    warehouse_id CHAR(4) DEFAULT 'USTK',
    reservation_id VARCHAR(10) NOT NULL,
    reservation_item_id INTEGER NOT NULL,
    material_id VARCHAR(20),
    required_quantity FLOAT,
    remaining_quantity FLOAT,
    purchase_requisition VARCHAR(15),
    maintenance_order VARCHAR(15),
    destination_cost_centre VARCHAR(10),
    movement_type CHAR(3),
    is_deleted BIT,
    is_final_issue BIT,
    required_date DATE,
    delivery_date DATE,
    creation_date DATE,
    PRIMARY KEY (reservation_id, reservation_item_id),
    FOREIGN KEY (plant_id, warehouse_id) REFERENCES proc_db.locations(plant_id, warehouse_id)
);