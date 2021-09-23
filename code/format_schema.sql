-- Add FK Constraint with MB52 as child table and movement_types as parent table
ALTER TABLE [proc_db].[mb51]
ADD CONSTRAINT fk_mb51_movement_types FOREIGN KEY (movement_type) REFERENCES proc_db.movement_types(movement_type);

-- Add the FK Constraints from fact tables to locations
ALTER TABLE [proc_db].[mb51]
ADD CONSTRAINT fk_mb51_locations FOREIGN KEY (plant_id, warehouse_id) REFERENCES proc_db.locations(plant_id, warehouse_id);

ALTER TABLE [proc_db].[mb52]
ADD CONSTRAINT fk_mb52_locations FOREIGN KEY (plant_id, warehouse_id) REFERENCES proc_db.locations(plant_id, warehouse_id);

ALTER TABLE [proc_db].[mcba]
ADD CONSTRAINT fk_mcba_locations FOREIGN KEY (plant_id, warehouse_id) REFERENCES proc_db.locations(plant_id, warehouse_id);

ALTER TABLE [proc_db].[zmb25]
ADD CONSTRAINT fk_zmb25_locations FOREIGN KEY (plant_id, warehouse_id) REFERENCES proc_db.locations(plant_id, warehouse_id);

-- Add the locations-ZFI Foreign Key
ALTER TABLE proc_db.locations ADD CONSTRAINT fk_locations_zfi FOREIGN KEY (currency) REFERENCES proc_db.zfi(from_currency)

-- Add the rest of the material ids to ZMM001
INSERT proc_db.zmm001 (material_id, material_group, material_type, created_date, last_change_date)  
SELECT material_id, '0000000', '0000', '1900-01-01', '1900-01-01'
FROM proc_db.missing_materials AS mm
WHERE NOT EXISTS (
    SELECT material_id
    FROM proc_db.zmm001 AS zm
    WHERE zm.material_id = mm.material_id);

--Add FK Constraints from fact tables to ZMM001
ALTER TABLE [proc_db].[mb51]
ADD CONSTRAINT fk_mb51_zmm001 FOREIGN KEY (material_id) REFERENCES proc_db.zmm001(material_id);

ALTER TABLE [proc_db].[mb52]
ADD CONSTRAINT fk_mb52_zmm001 FOREIGN KEY (material_id) REFERENCES proc_db.zmm001(material_id);

ALTER TABLE [proc_db].[mcba]
ADD CONSTRAINT fk_mcba_zmm001 FOREIGN KEY (material_id) REFERENCES proc_db.zmm001(material_id);

ALTER TABLE [proc_db].[zmb25]
ADD CONSTRAINT fk_zmb25_zmm001 FOREIGN KEY (material_id) REFERENCES proc_db.zmm001(material_id);

-- Add the rest of the material ids to PICPS
INSERT proc_db.picps (material_id, pic_number)  
SELECT material_id, material_id
FROM proc_db.zmm001 AS zm
WHERE NOT EXISTS (
    SELECT material_id
    FROM proc_db.picps AS pc
    WHERE pc.material_id = zm.material_id);

ALTER TABLE [proc_db].[zmm001]
ADD CONSTRAINT fk_zmm001_picps FOREIGN KEY (material_id) REFERENCES proc_db.picps(material_id);

-- Add the rest of the material ids to monos_categories
INSERT proc_db.monos_categories (material_id, monos_category)  
SELECT material_id, "NOT MONO"
FROM proc_db.zmm001 AS zm
WHERE NOT EXISTS (
    SELECT material_id
    FROM proc_db.monos_categories AS mc
    WHERE mc.material_id = zm.material_id);

ALTER TABLE [proc_db].[zmm001]
ADD CONSTRAINT fk_zmm001_monos_categories FOREIGN KEY (material_id) REFERENCES proc_db.monos_categories(material_id);

-- Add the rest of the stock history to SP99
INSERT proc_db.sp99 (plant_id, material_id, month_of_stock)  
SELECT DISTINCT plant_id, material_id, month_of_stock
FROM proc_db.mcba AS mc
WHERE NOT EXISTS (
    SELECT plant_id, material_id, month_of_stock
    FROM proc_db.sp99 sp
    WHERE sp.plant_id = mc.plant_id AND sp.material_id = mc.material_id AND sp.month_of_stock=mc.month_of_stock);

-- Add MCBA - SP99 FK
ALTER TABLE [proc_db].[mcba]
ADD CONSTRAINT fk_mcba_sp99 FOREIGN KEY (plant_id, material_id, month_of_stock) REFERENCES proc_db.sp99(plant_id, material_id, month_of_stock);

-- Add the rest of materials to ZMRP

INSERT proc_db.zmrp (material_id, warehouse_id)  
SELECT material_id, warehouse_id
FROM proc_db.mb52 AS mb
WHERE NOT EXISTS (
    SELECT material_id, warehouse_id 
    FROM proc_db.zmrp zm 
    WHERE zm.material_id = mb.material_id AND zm.warehouse_id = mb.warehouse_id);

-- Add MB52 - ZMRP FK
ALTER TABLE [proc_db].[mb52]
ADD CONSTRAINT fk_mb52_zmrp FOREIGN KEY (warehouse_id, material_id) REFERENCES [proc_db].[zmrp](warehouse_id, material_id);

