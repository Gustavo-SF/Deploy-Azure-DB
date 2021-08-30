/*
View for MB52 in Power BI

- Concatenates plant_id with warehouse_id code in location_id
- Joins zmrp to identity zmrp materials
- Joins mb51 to identify the last movement (with group by) of the material_id in stock.
*/
DROP VIEW IF EXISTS proc_db.mb52_view;
GO
CREATE VIEW proc_db.mb52_view
AS 
SELECT 
    CONCAT(zmb25.plant_id, zmb25.warehouse_id) as location_id,
    zmb25.material_id, 
    zmb25.unrestricted, 
    zmb25.blocked, 
    zmb25.in_transfer, 
    zmb25.in_transit, 
    zmrp.mrp_priority, 
    ISNULL(MAX(real_movements.entry_date), '01/01/2018') as last_movement
FROM proc_db.MB52 as zmb25 

LEFT JOIN proc_db.zmrp as zmrp
ON zmb25.warehouse_id=zmrp.warehouse_id AND zmb25.material_id=zmrp.material_id

LEFT JOIN (
    SELECT warehouse_id, material_id, entry_date
    FROM proc_db.mb51
    WHERE 
        movement_type<>'561' AND 
        movement_type<>'562' AND 
        movement_type<>'565' AND 
        movement_type<>'951' AND 
        movement_type<>'952' AND 
        movement_type<>'998' AND 
        movement_type<>'999'
) as real_movements
ON zmb25.material_id=real_movements.material_id AND zmb25.warehouse_id=real_movements.warehouse_id

GROUP BY 
    zmb25.plant_id, 
    zmb25.warehouse_id, 
    zmb25.material_id, 
    zmb25.unrestricted, 
    zmb25.blocked, 
    zmb25.in_transfer, 
    zmb25.in_transit, 
    zmrp.mrp_priority;
GO


/*
mcba current view for PowerBI
*/
DROP VIEW IF EXISTS proc_db.mcba_current_view;
GO
CREATE VIEW proc_db.mcba_current_view
AS 
SELECT 
    CONCAT(mcba.plant_id, mcba.warehouse_id) as location_id, 
    mcba.material_id,
	mcba.stock_quantity,
    mcba.stock_value * exc.exchange_rate AS stock_value_euro,
	mcba.month_of_stock,
    zmrp.mrp_priority,
	mcba.stock_quantity * (sp.total_euro_value / sp.quantity) AS stock_sp_value_euro,
	ISNULL(MAX(real_movements.entry_date), '01/01/2018') as last_movement
FROM (SELECT * FROM proc_db.mcba WHERE month_of_stock = (SELECT MAX(month_of_stock) FROM proc_db.mcba) AND stock_quantity > 0) as mcba

	LEFT JOIN proc_db.zmrp as zmrp
	ON mcba.warehouse_id=zmrp.warehouse_id AND mcba.material_id=zmrp.material_id

	LEFT JOIN (
		SELECT warehouse_id, material_id, entry_date
		FROM proc_db.mb51
		WHERE 
			movement_type<>'561' AND 
			movement_type<>'562' AND 
			movement_type<>'565' AND 
			movement_type<>'951' AND 
			movement_type<>'952' AND 
			movement_type<>'998' AND 
			movement_type<>'999'
	) as real_movements
	ON mcba.material_id=real_movements.material_id AND mcba.warehouse_id=real_movements.warehouse_id

	LEFT JOIN proc_db.sp99 AS sp 
    ON sp.material_id=mcba.material_id AND sp.plant_id=mcba.plant_id AND sp.month_of_stock=mcba.month_of_stock

    LEFT JOIN (
        SELECT loc.plant_id, loc.warehouse_id, zfi.exchange_rate
        FROM proc_db.locations as loc
        INNER JOIN proc_db.zfi as zfi
        ON loc.currency=zfi.from_currency
    ) as exc
    ON mcba.plant_id=exc.plant_id AND mcba.warehouse_id=exc.warehouse_id

GROUP BY 
    mcba.plant_id, 
    mcba.warehouse_id, 
    mcba.material_id, 
	mcba.stock_quantity,
	mcba.month_of_stock,
    mcba.stock_value,
    exc.exchange_rate,
	sp.total_euro_value,
	sp.quantity,
    zmrp.mrp_priority;
GO

/*
View for ZMB25 in Power BI

- Concatenates plant_id with warehouse_id code in location_id
- Joins MB52 to get the current available stock
- Also sums cumulatively the remaining quantity for each plant_id, warehouse_id and material_id and subtracts that to the available unrestricted.
This is to understand how many reservations it is possible to satisfy with the available stock. 
*/
DROP VIEW IF EXISTS proc_db.zmb25_view;
GO
CREATE VIEW proc_db.zmb25_view
AS 
SELECT 
    zmb25_with_pic_and_mrp.location_id,
    zmb25_with_pic_and_mrp.reservation_id,
    zmb25_with_pic_and_mrp.reservation_item_id,
    zmb25_with_pic_and_mrp.material_id,
    zmb25_with_pic_and_mrp.material_category,
    zmb25_with_pic_and_mrp.required_quantity,
    zmb25_with_pic_and_mrp.remaining_quantity,
    zmb25_with_pic_and_mrp.corrected_remaining_quantity,
    zmb25_with_pic_and_mrp.purchase_requisition,
    zmb25_with_pic_and_mrp.maintenance_order,
    zmb25_with_pic_and_mrp.is_deleted,
    zmb25_with_pic_and_mrp.is_final_issue,
    zmb25_with_pic_and_mrp.creation_date,
    zmb25_with_pic_and_mrp.delivery_date,
    zmb25_with_pic_and_mrp.mrp_priority,
    zmb25_with_pic_and_mrp.total_stock 
        - (SUM(zmb25_with_pic_and_mrp.corrected_remaining_quantity) OVER (
            PARTITION BY 
                zmb25_with_pic_and_mrp.plant_id, 
                zmb25_with_pic_and_mrp.warehouse_id, 
                zmb25_with_pic_and_mrp.material_id 
            ORDER BY 
                zmb25_with_pic_and_mrp.delivery_date ASC ROWS UNBOUNDED PRECEDING
        )) AS leftover_stock,
    zmb25_with_pic_and_mrp.total_stock,
    ISNULL(grouped_qty_by_material_category.total_similar_stock, 0) AS total_similar_stock,
    ISNULL(grouped_qty_by_material_category.total_similar_stock, 0) - (
            SUM(zmb25_with_pic_and_mrp.corrected_remaining_quantity) 
            OVER (
                PARTITION BY 
                    zmb25_with_pic_and_mrp.plant_id, 
                    zmb25_with_pic_and_mrp.warehouse_id, 
                    zmb25_with_pic_and_mrp.material_category 
                ORDER BY zmb25_with_pic_and_mrp.delivery_date ASC ROWS UNBOUNDED PRECEDING
            )
        ) AS leftover_similar_stock
FROM (

    SELECT 
        CONCAT(zmb25.plant_id, zmb25.warehouse_id) as location_id,
        zmb25.plant_id,
        zmb25.warehouse_id,
        zmb25.reservation_id, 
        zmb25.reservation_item_id, 
        zmb25.material_id, 
        ISNULL(pic.pic_number, zmb25.material_id) AS material_category,
        zmb25.required_quantity, 
        zmb25.remaining_quantity, 
        CASE
            WHEN zmb25.is_deleted = 1 OR zmb25.is_final_issue = 1 OR zmb25.remaining_quantity<=0
            THEN 0
            ELSE zmb25.remaining_quantity
        END AS corrected_remaining_quantity,
        zmb25.purchase_requisition, 
        zmb25.maintenance_order,
        zmb25.is_deleted, 
        zmb25.is_final_issue, 
        zmb25.creation_date, 
        ISNULL(zmb25.delivery_date, zmb25.required_date) AS delivery_date,
        zmrp.mrp_priority, 
        ISNULL(mb52.unrestricted, 0) AS total_stock
    FROM  proc_db.zmb25 as zmb25

    LEFT JOIN proc_db.zmrp as zmrp
    ON zmb25.warehouse_id=zmrp.warehouse_id AND zmb25.material_id=zmrp.material_id

    LEFT JOIN proc_db.mb52 as mb52
    ON zmb25.plant_id=mb52.plant_id AND zmb25.warehouse_id=mb52.warehouse_id AND zmb25.material_id=mb52.material_id

    LEFT JOIN proc_db.picps as pic
    ON zmb25.material_id=pic.material_id

) AS zmb25_with_pic_and_mrp

LEFT JOIN (
    SELECT 
        pic_with_quantity_in_stock.material_category,
        pic_with_quantity_in_stock.warehouse_id,
        pic_with_quantity_in_stock.plant_id,
        SUM(pic_with_quantity_in_stock.unrestricted) AS total_similar_stock
    FROM (
        SELECT 
            ISNULL(pic.pic_number, mb52.material_id) AS material_category ,
            mb52.warehouse_id, 
            mb52.plant_id, 
            mb52.unrestricted
        FROM proc_db.mb52 as mb52
        LEFT JOIN proc_db.picps as pic
        ON pic.material_id=mb52.material_id
        ) AS pic_with_quantity_in_stock
    GROUP BY pic_with_quantity_in_stock.material_category, pic_with_quantity_in_stock.warehouse_id, pic_with_quantity_in_stock.plant_id
) as grouped_qty_by_material_category
ON 
        grouped_qty_by_material_category.material_category=zmb25_with_pic_and_mrp.material_category 
    AND grouped_qty_by_material_category.warehouse_id=zmb25_with_pic_and_mrp.warehouse_id 
    AND grouped_qty_by_material_category.plant_id=zmb25_with_pic_and_mrp.plant_id;

GO

/*
View for mb51 in Power BI

- Concatenates plant_id with warehouse_id code in location_id
- Joins ZFI and multiplies the respective exchange rate by the local values to get Euro values
- Joins zmrp to identity zmrp materials
*/
DROP VIEW IF EXISTS proc_db.mb51_view;
GO
CREATE VIEW proc_db.mb51_view
AS 
SELECT 
    CONCAT(mb51.plant_id, mb51.warehouse_id) as location_id,
    mb51.material_id,
    mb51.quantity,
    mb51.movement_type,
    mb51.entry_date,
    mb51.requisition_date,
    mb51.movement_value * exc.exchange_rate AS movement_value_euro,
    mb51.reservation_id,
    zmrp.mrp_priority
FROM  proc_db.mb51 as mb51

LEFT JOIN (
    SELECT loc.plant_id, loc.warehouse_id, zfi.exchange_rate
    FROM proc_db.locations as loc
    INNER JOIN proc_db.zfi as zfi 
    ON loc.currency=zfi.from_currency
) AS exc
ON mb51.plant_id=exc.plant_id AND mb51.warehouse_id=exc.warehouse_id 

LEFT JOIN proc_db.zmrp as zmrp
ON mb51.warehouse_id=zmrp.warehouse_id AND mb51.material_id=zmrp.material_id;

GO

/*
View for ZMM001 in PowerBI

- Concatenates material_id and MaterialDescription
- Concatenates MaterialGroup and MaterialGroupDescription
*/
DROP VIEW IF EXISTS proc_db.zmm001_view;
GO
CREATE VIEW proc_db.zmm001_view
AS 
SELECT 
	material_id, 
	CONCAT(material_id,' - ', material_description) AS material,
	CONCAT(material_group, ' - ', material_group_description) AS material_group,
	unit,
	material_type
FROM proc_db.zmm001;
GO

/*
View for mcba in Power BI

- Concatenates plant_id with warehouse_id code in location_id
- Joins ZFI and multiplies the respective exchange rate by the local values to get Euro values
*/
DROP VIEW IF EXISTS proc_db.mcba_view;
GO
CREATE VIEW proc_db.mcba_view
AS
SELECT
    CONCAT(mcba.plant_id, mcba.warehouse_id) AS location_id,
    mcba.material_id,
    mcba.mrp_type,
    zmrp.mrp_priority,
    mcba.month_of_stock,
    mcba.stock_quantity,
    mcba.stock_value * exchange_rate.exchange_rate AS stock_value_euro,
    mcba.issued_quantity,
    mcba.issued_value * exchange_rate.exchange_rate AS issued_value_euro,
    mcba.stock_quantity * (sp.total_euro_value / sp.quantity) AS stock_sp_value_euro
FROM proc_db.mcba as mcba

	LEFT JOIN proc_db.zmrp as zmrp
	    ON mcba.warehouse_id=zmrp.warehouse_id AND mcba.material_id=zmrp.material_id

    LEFT JOIN (
        SELECT loc.plant_id, loc.warehouse_id, zfi.exchange_rate
        FROM proc_db.locations as loc
        INNER JOIN proc_db.zfi as zfi 
        ON loc.currency=zfi.from_currency
    ) as exchange_rate
    ON mcba.plant_id=exchange_rate.plant_id AND mcba.warehouse_id=exchange_rate.warehouse_id

    LEFT JOIN proc_db.sp99 AS sp 
    ON sp.material_id=mcba.material_id AND sp.plant_id=mcba.plant_id AND sp.month_of_stock=mcba.month_of_stock;

GO

/*
View for zmrp in Power BI

- Concatenates plant_id with warehouse_id code in location_id
To get the plant_id name we get it from the Locations data table.
*/
DROP VIEW IF EXISTS proc_db.zmrp_view;
GO
CREATE VIEW proc_db.zmrp_view
AS
SELECT
    CONCAT(loc.plant_id, zmrp.warehouse_id) AS location_id,
    zmrp.material_id,
    zmrp.mrp_priority
FROM proc_db.zmrp as zmrp
LEFT JOIN (
    SELECT *
    FROM proc_db.locations
    WHERE warehouse_id <> 'USTK'
) as loc
ON zmrp.warehouse_id=loc.warehouse_id;
GO

/*
View for Locations in PowerBI

- Concatenates plant_id with warehouse_id code in location_id
- Concatenates plant_id and plant_name
- Concatenates warehouse_id and warehouse_name
*/
DROP VIEW IF EXISTS proc_db.locations_view;
GO
CREATE VIEW proc_db.locations_view
AS
SELECT
    CONCAT(plant_id, warehouse_id) AS location_id,
    CONCAT(plant_id, ' - ', plant_name) AS plant,
    CONCAT(warehouse_id, ' - ', warehouse_name) AS warehouse,
    country,
    project
FROM proc_db.Locations;
GO

/*
View to get missing materials from ZMM001

- Checks all the materials that are not present in the ZMM001 table and concatenates vertically.
*/
DROP VIEW IF EXISTS proc_db.missing_materials;
GO
CREATE VIEW proc_db.missing_materials
AS
SELECT DISTINCT remaining_materials.material_id FROM (SELECT DISTINCT mb51.material_id FROM proc_db.mb51 as mb51 LEFT JOIN proc_db.zmm001 as zm ON zm.material_id=mb51.material_id WHERE zm.material_id IS NULL
UNION ALL
SELECT DISTINCT mb52.material_id FROM proc_db.mb52 as mb52 LEFT JOIN proc_db.zmm001 as zm ON zm.material_id=mb52.material_id WHERE zm.material_id IS NULL
UNION ALL
SELECT DISTINCT zmb25.material_id FROM proc_db.zmb25 as zmb25 LEFT JOIN proc_db.zmm001 as zm ON zm.material_id=zmb25.material_id WHERE zm.material_id IS NULL
UNION ALL
SELECT DISTINCT mcba.material_id FROM proc_db.mcba as mcba LEFT JOIN proc_db.zmm001 as zm ON zm.material_id=mcba.material_id WHERE zm.material_id IS NULL
UNION ALL
SELECT DISTINCT zmrp.material_id FROM proc_db.zmrp as zmrp LEFT JOIN proc_db.zmm001 as zm ON zm.material_id=zmrp.material_id WHERE zm.material_id IS NULL) as remaining_materials;
GO
--  