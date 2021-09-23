-- Drop all of the FK Constraints to give sometime to change the tables without
-- contraints.
ALTER TABLE proc_db.locations DROP CONSTRAINT fk_locations_zfi;
ALTER TABLE proc_db.mb51 
DROP CONSTRAINT fk_mb51_locations, fk_mb51_movement_types, fk_mb51_zmm001;
ALTER TABLE proc_db.mb52
DROP CONSTRAINT fk_mb52_locations, fk_mb52_zmm001, fk_mb52_zmrp;
ALTER TABLE proc_db.zmb25
DROP CONSTRAINT fk_zmb25_locations, fk_zmb25_zmm001;
ALTER TABLE proc_db.mcba
DROP CONSTRAINT fk_mcba_locations, fk_mcba_zmm001, fk_mcba_sp99;
ALTER TABLE proc_db.zmm001
DROP CONSTRAINT fk_zmm001_picps, fk_zmm001_monos_categories;