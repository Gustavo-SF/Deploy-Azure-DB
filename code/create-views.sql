/*
View for MB52 in Power BI

- Concatenates Plant with Warehouse code in LocationID
- Joins MRP to identity MRP materials
- Joins MB51 to identify the last movement (with group by) of the material in stock.
*/
DROP VIEW IF EXISTS PPP.MB52view;
GO
CREATE VIEW PPP.MB52view
AS 
SELECT 
    CONCAT(b.Plant, b.Warehouse) as LocationID,
    b.Material, 
    b.Unrestricted, 
    b.Blocked, 
    b.InTransfer, 
    b.InTransit, 
    m.MRPPriority, 
    ISNULL(MAX(p.EntryDate), '01/01/2018') as LastMovement
FROM PPP.MB52 as b 
LEFT JOIN PPP.MRP as m
ON b.Warehouse=m.Warehouse AND b.Material=m.Material
LEFT JOIN (
    SELECT Warehouse, Material, EntryDate
    FROM PPP.MB51
    WHERE 
        MovementType<>'561' AND 
        MovementType<>'562' AND 
        MovementType<>'565' AND 
        MovementType<>'951' AND 
        MovementType<>'952' AND 
        MovementType<>'998' AND 
        MovementType<>'999'
) as p 
ON b.Material=p.Material AND b.Warehouse=p.Warehouse
GROUP BY 
    b.Plant, 
    b.Warehouse, 
    b.Material, 
    b.Unrestricted, 
    b.Blocked, 
    b.InTransfer, 
    b.InTransit, 
    m.MRPPriority;
GO

DROP VIEW IF EXISTS PPP.MCBAcurview;
GO
CREATE VIEW PPP.MCBAcurview
AS 
SELECT 
    CONCAT(mcba.Plant, mcba.Warehouse) as LocationID, 
    mcba.Material,
	mcba.StockQuantity,
    mcba.StockValue * exc.ExchangeRate AS StockValueEuro,
	mcba.StockMonth,
    mrp.MRPPriority,
	mcba.StockQuantity * (sp.TotalEuroValue / sp.Quantity) AS StockRealEuroValue,
	ISNULL(MAX(mb51.EntryDate), '01/01/2018') as LastMovement
FROM (SELECT * FROM PPP.MCBA WHERE StockMonth = (SELECT MAX(StockMonth) FROM PPP.MCBA) AND StockQuantity > 0) as mcba

	LEFT JOIN PPP.MRP as mrp
	ON mcba.Warehouse=mrp.Warehouse AND mcba.Material=mrp.Material

	LEFT JOIN (
		SELECT Warehouse, Material, EntryDate
		FROM PPP.MB51
		WHERE 
			MovementType<>'561' AND 
			MovementType<>'562' AND 
			MovementType<>'565' AND 
			MovementType<>'951' AND 
			MovementType<>'952' AND 
			MovementType<>'998' AND 
			MovementType<>'999'
	) as mb51
	ON mcba.Material=mb51.Material AND mcba.Warehouse=mb51.Warehouse

	LEFT JOIN PPP.SP99 AS sp 
    ON sp.Material=mcba.Material AND sp.Plant=mcba.Plant AND sp.StockMonth=mcba.StockMonth

    LEFT JOIN (
        SELECT loc.PlantID, loc.WarehouseID, zfi.ExchangeRate
        FROM [PPP].[Locations] as loc
        INNER JOIN [PPP].[ZFI] as zfi
        ON loc.Currency=zfi.FromCurrency
    ) as exc
    ON mcba.Plant=exc.PlantID AND mcba.Warehouse=exc.WarehouseID

GROUP BY 
    mcba.Plant, 
    mcba.Warehouse, 
    mcba.Material, 
	mcba.StockQuantity,
	mcba.StockMonth,
    mcba.StockValue,
    exc.ExchangeRate,
	sp.TotalEuroValue,
	sp.Quantity,
    mrp.MRPPriority;
GO

/*
View for ZMB25 in Power BI

- Concatenates Plant with Warehouse code in LocationID
- Joins MB52 to get the current available stock
- Also sums cumulatively the remaining quantity for each plant, warehouse and material and subtracts that to the available unrestricted.
This is to understand how many reservations it is possible to satisfy with the available stock. 
*/
DROP VIEW IF EXISTS [PPP].[ZMB25view];
GO
CREATE VIEW [PPP].[ZMB25view]
AS 
SELECT 
    j.LocationID,
    j.ReservationID,
    j.ReservationItemID,
    j.Material,
    j.MaterialCat,
    j.RequiredQuantity,
    j.RemainingQuantity,
    j.ActualRemainingQuantity,
    j.PurchaseRequisition,
    j.MaintenanceOrder,
    j.Deleted,
    j.FinalIssue,
    j.CreationDate,
    j.DeliveryDate,
    j.MRPPriority,
    j.ProjectedStockAfter,
    j.AvailableStock,
    ISNULL(h.SumofUnrestricted, 0) AS AvailableSimilarStock,
    ISNULL(h.SumofUnrestricted, 0) - (SUM(j.ActualRemainingQuantity) OVER (PARTITION BY j.Plant, j.Warehouse, j.MaterialCat ORDER BY j.DeliveryDate ASC ROWS UNBOUNDED PRECEDING)) AS ProjectedSimilarStockAfter
FROM (
    SELECT 
        CONCAT(b.Plant, b.Warehouse) as LocationID,
        b.Plant,
        b.Warehouse,
        b.ReservationID, 
        b.ReservationItemID, 
        b.Material, 
        ISNULL(t.PIC, b.Material) AS MaterialCat,
        b.RequiredQuantity, 
        b.RemainingQuantity, 
        CASE
            WHEN b.Deleted = 1 OR b.FinalIssue = 1 OR b.RemainingQuantity<=0
            THEN 0
            ELSE b.RemainingQuantity
        END AS ActualRemainingQuantity,
        b.PurchaseRequisition, 
        b.MaintenanceOrder,
        b.Deleted, 
        b.FinalIssue, 
        b.CreationDate, 
        ISNULL(b.DeliveryDate, b.RequiredDate) AS DeliveryDate,
        m.MRPPriority, 
        ISNULL(p.Unrestricted, 0) - (SUM(b.RemainingQuantity) OVER (PARTITION BY b.Plant, b.Warehouse, b.Material ORDER BY b.RemainingQuantity ASC ROWS UNBOUNDED PRECEDING)) AS ProjectedStockAfter,
        ISNULL(p.Unrestricted, 0) AS AvailableStock
    FROM  [PPP].[ZMB25] as b
    LEFT JOIN [PPP].[MRP] as m
    ON b.Warehouse=m.Warehouse AND b.Material=m.Material
    LEFT JOIN [PPP].[MB52] as p
    ON b.Plant=p.Plant AND b.Warehouse=p.Warehouse AND b.Material=p.Material
    LEFT JOIN [PPP].[MaterialClasses] as t
    ON b.Material=t.Material
) AS j
LEFT JOIN (
    SELECT t.MaterialCat, t.Warehouse, t.Plant, SUM(t.Unrestricted) AS SumofUnrestricted
    FROM (
        SELECT ISNULL(s.PIC, k.Material) AS MaterialCat , k.Warehouse, k.Plant, k.Unrestricted
        FROM [PPP].[MB52] as k
        LEFT JOIN [PPP].[MaterialClasses] as s
        ON s.Material=k.Material
        ) AS t
    GROUP BY t.MaterialCat, t.Warehouse, t.Plant
) as h
ON h.MaterialCat=j.MaterialCat AND h.Warehouse=j.Warehouse AND h.Plant=j.Plant;
GO

/*
View for MB51 in Power BI

- Concatenates Plant with Warehouse code in LocationID
- Joins ZFI and multiplies the respective exchange rate by the local values to get Euro values
- Joins MRP to identity MRP materials
*/
DROP VIEW IF EXISTS [PPP].[MB51view];
GO
CREATE VIEW [PPP].[MB51view]
AS 
SELECT 
    CONCAT(b.Plant, b.Warehouse) as LocationID,
    b.Material,
    b.Quantity,
    b.MovementType,
    b.EntryDate,
    b.RequisitionDate,
    b.MovementValue * u.ExchangeRate as MovementValueEuro,
    b.ReservationID,
    m.MRPPriority
FROM  [PPP].[MB51] as b
LEFT JOIN (
    SELECT q.PlantID, q.WarehouseID, t.ExchangeRate
    FROM [PPP].[Locations] as q
    INNER JOIN [PPP].[ZFI] as t 
    ON q.Currency=t.FromCurrency
) as u 
ON b.Plant=u.PlantID AND b.Warehouse=u.WarehouseID 
LEFT JOIN [PPP].[MRP] as m
ON b.Warehouse=m.Warehouse AND b.Material=m.Material;
GO

/*
View for ZMM001 in PowerBI

- Concatenates Material and MaterialDescription
- Concatenates MaterialGroup and MaterialGroupDescription
*/
DROP VIEW IF EXISTS [PPP].[ZMM001view];
GO
CREATE VIEW [PPP].[ZMM001view]
AS 
SELECT 
	Material as MaterialID, 
	CONCAT(Material,' - ', MaterialDescription) AS Material,
	CONCAT(MaterialGroup, ' - ', MaterialGroupDescription) AS MaterialGroup,
	Unit,
	MaterialType
FROM [PPP].[ZMM001];
GO

/*
View for MCBA in Power BI

- Concatenates Plant with Warehouse code in LocationID
- Joins ZFI and multiplies the respective exchange rate by the local values to get Euro values
*/
DROP VIEW IF EXISTS [PPP].[MCBAview];
GO
CREATE VIEW [PPP].[MCBAview]
AS
SELECT
    CONCAT(mc.Plant, mc.Warehouse) AS LocationID,
    mc.Material,
    mc.MRPType,
    mrp.MRPPriority,
    mc.StockMonth,
    mc.StockQuantity,
    mc.StockValue * ex.ExchangeRate AS StockValueEuro,
    mc.IssuedQuantity,
    mc.IssuedValue * ex.ExchangeRate AS IssuedValueEuro,
    mc.StockQuantity * (sp.TotalEuroValue / sp.Quantity) AS StockRealEuroValue
FROM [PPP].[MCBA] as mc

	LEFT JOIN PPP.MRP as mrp
	    ON mc.Warehouse=mrp.Warehouse AND mc.Material=mrp.Material

    LEFT JOIN (
        SELECT q.PlantID, q.WarehouseID, t.ExchangeRate
        FROM [PPP].[Locations] as q
        INNER JOIN [PPP].[ZFI] as t 
        ON q.Currency=t.FromCurrency
    ) as ex
    ON mc.Plant=ex.PlantID AND mc.Warehouse=ex.WarehouseID

    LEFT JOIN PPP.SP99 AS sp 
    ON sp.Material=mc.Material AND sp.Plant=mc.Plant AND sp.StockMonth=mc.StockMonth;

GO

/*
View for MRP in Power BI

- Concatenates Plant with Warehouse code in LocationID
To get the Plant name we get it from the Locations data table.
*/
DROP VIEW IF EXISTS [PPP].[MRPview];
GO
CREATE VIEW [PPP].[MRPview]
AS
SELECT
    CONCAT(u.PlantID, b.Warehouse) AS LocationID,
    b.Material,
    b.MRPPriority
FROM PPP.MRP as b
LEFT JOIN (
    SELECT *
    FROM PPP.Locations
    WHERE WarehouseID <> 'USTK'
) as u
ON b.Warehouse=u.WarehouseID;
GO

/*
View for Locations in PowerBI

- Concatenates Plant with Warehouse code in LocationID
- Concatenates Plant and PlantName
- Concatenates WarehouseID and WarehouseName
*/
DROP VIEW IF EXISTS [PPP].[LocationsView];
GO
CREATE VIEW [PPP].[LocationsView]
AS
SELECT
    CONCAT(PlantID, WarehouseID) AS LocationID,
    CONCAT(PlantID, ' - ', PlantName) AS Plant,
    CONCAT(WarehouseID, ' - ', WarehouseName) AS Warehouse,
    Country,
    Project
FROM [PPP].[Locations];
GO

/*
View to get missing materials from ZMM001

- Checks all the materials that are not present in the ZMM001 table and concatenates vertically.
*/
DROP VIEW IF EXISTS PPP.MissingMaterials;
GO
CREATE VIEW PPP.MissingMaterials
AS
SELECT DISTINCT y.Material FROM (SELECT DISTINCT m.Material FROM PPP.MB51 as m LEFT JOIN [PPP].[ZMM001] as t ON t.Material=m.Material WHERE t.Material IS NULL
UNION ALL
SELECT DISTINCT m.Material FROM PPP.MB52 as m LEFT JOIN [PPP].[ZMM001] as t ON t.Material=m.Material WHERE t.Material IS NULL
UNION ALL
SELECT DISTINCT m.Material FROM PPP.ZMB25 as m LEFT JOIN [PPP].[ZMM001] as t ON t.Material=m.Material WHERE t.Material IS NULL
UNION ALL
SELECT DISTINCT m.Material FROM PPP.MCBA as m LEFT JOIN [PPP].[ZMM001] as t ON t.Material=m.Material WHERE t.Material IS NULL
UNION ALL
SELECT DISTINCT m.Material FROM PPP.MRP as m LEFT JOIN [PPP].[ZMM001] as t ON t.Material=m.Material WHERE t.Material IS NULL) as y;
GO
--  