-- View for MB52 in Power BI

DROP VIEW IF EXISTS PPP.MB52view;
GO
CREATE VIEW PPP.MB52view
AS 
SELECT 
    CONCAT(b.Plant, b.Warehouse) as LocationID,
    b.Material, 
    b.Unrestricted, 
    b.UnrestrictedValue * u.ExchangeRate as UnrestrictedValueEuro, 
    b.Blocked, 
    b.BlockedValue * u.ExchangeRate as BlockedValueEuro, 
    b.InTransfer, 
    b.InTransit, 
    b.InTransitValue * u.ExchangeRate as InTransitValueEuro, 
    m.MRPPriority, 
    ISNULL(MAX(p.EntryDate), '01/01/2018') as LastIssue
FROM PPP.MB52 as b 
LEFT JOIN (SELECT q.PlantID, q.WarehouseID, t.ExchangeRate
FROM PPP.Locations as q 
INNER JOIN PPP.ZFI as t 
ON q.Currency=t.FromCurrency) as u 
ON b.Plant=u.PlantID AND b.Warehouse=u.WarehouseID
LEFT JOIN PPP.MRP as m
ON b.Warehouse=m.Warehouse AND b.Material=m.Material
LEFT JOIN (
    SELECT Warehouse, Material, EntryDate
    FROM PPP.MB51
    WHERE 
        MovementType='201' OR 
        MovementType='202' OR 
        MovementType='261' OR 
        MovementType='262' OR 
        MovementType='601' OR 
        MovementType='602' OR 
        MovementType='Z21' OR 
        MovementType='Z22' OR 
        MovementType='Z31' OR 
        MovementType='Z32'
) as p 
ON b.Material=p.Material AND b.Warehouse=p.Warehouse
GROUP BY 
    b.Plant, 
    b.Warehouse, 
    b.Material, 
    b.Unrestricted, 
    b.UnrestrictedValue, 
    b.Blocked, 
    b.BlockedValue, 
    b.InTransfer, 
    b.InTransit, 
    b.InTransitValue, 
    u.ExchangeRate, 
    m.MRPPriority;
GO

-- View for ZMB25 in Power BI
DROP VIEW IF EXISTS [PPP].[ZMB25view];
GO
CREATE VIEW [PPP].[ZMB25view]
AS 
SELECT 
    CONCAT(b.Plant, b.Warehouse) as LocationID,
    b.ReservationID, 
    b.ReservationItemID, 
    b.Material, 
    b.RequiredQuantity, 
    b.RemainingQuantity, 
    b.PurchaseRequisition, 
    b.MaintenanceOrder,
    b.Deleted, 
    b.FinalIssue, 
    b.CreationDate, 
    m.MRPPriority, 
    ISNULL(p.Unrestricted, 0) as AvailableStock
FROM  [PPP].[ZMB25] as b
LEFT JOIN [PPP].[MRP] as m
ON b.Warehouse=m.Warehouse AND b.Material=m.Material
LEFT JOIN [PPP].[MB52] as p
ON b.Plant=p.Plant AND b.Warehouse=p.Warehouse AND b.Material=p.Material;
GO

-- View for MB51 in Power BI

DROP VIEW IF EXISTS [PPP].[MB51view];
GO
CREATE VIEW [PPP].[MB51view]
AS 
SELECT 
    CONCAT(b.Plant, b.Warehouse) as LocationID,
    b.Material,
    b.Quantity,
    b.MovementType,
    b.UserName,
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

-- View for ZMM001 in PowerBI

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

-- View for MCBA in Power BI

DROP VIEW IF EXISTS [PPP].[MCBAview];
GO
CREATE VIEW [PPP].[MCBAview]
AS
SELECT
    CONCAT(b.Plant, b.Warehouse) AS LocationID,
    b.Material,
    b.MRPType,
    b.Month_,
    b.StockQuantity,
    b.StockValue * u.ExchangeRate AS StockValueEuro,
    b.IssuedQuantity,
    b.IssuedValue * u.ExchangeRate AS IssuedValueEuro
FROM [PPP].[MCBA] as b
LEFT JOIN (
    SELECT q.PlantID, q.WarehouseID, t.ExchangeRate
    FROM [PPP].[Locations] as q
    INNER JOIN [PPP].[ZFI] as t 
    ON q.Currency=t.FromCurrency
) as u 
ON b.Plant=u.PlantID AND b.Warehouse=u.WarehouseID;
GO

-- View for MRP in Power BI

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
    WHERE WarehouseID <> 'TRFR'
) as u
ON b.Warehouse=u.WarehouseID;
GO

-- View for Locations in PowerBI

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

-- View to get missing materials from ZMM001

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