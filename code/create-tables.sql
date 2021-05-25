IF SCHEMA_ID("PPP") IS NULL
EXEC ("CREATE SCHEMA PPP");

-- stock
DROP TABLE IF EXISTS PPP.MB52;
CREATE TABLE PPP.MB52
(
    Plant    CHAR(4) NOT NULL,
    Warehouse    CHAR(4) DEFAULT 'USTK',
    Material    VARCHAR(20) NOT NULL,
    Unrestricted    DECIMAL,
    UnrestrictedValue   DECIMAL,
    Blocked     DECIMAL,
    BlockedValue DECIMAL,
    InTransfer    DECIMAL,
    InTransit DECIMAL,
    InTransitValue DECIMAL,
    PRIMARY KEY (Plant, Warehouse, Material)
);

-- stock movements
DROP TABLE IF EXISTS PPP.MB51;
CREATE TABLE PPP.MB51
(
    MovementId INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Plant CHAR(4) NOT NULL,
    Warehouse CHAR(4) DEFAULT 'USTK',
    Material VARCHAR(20) NOT NULL,
    Quantity DECIMAL,
    MovementType CHAR(3),
    EntryDate DATE,
    RequisitionDate DATE,
    MovementValue DECIMAL NOT NULL,
    ReservationID VARCHAR(15)
);

-- stock history
DROP TABLE IF EXISTS PPP.MCBA;
CREATE TABLE PPP.MCBA
(
    Plant CHAR(4) NOT NULL,
    Material VARCHAR(20) NOT NULL,
    Warehouse CHAR(4) DEFAULT 'USTK',
    MRPType CHAR(2),
    Month_ DATE NOT NULL,
    IssuedQuantity DECIMAL,
    ReceivedQuantity DECIMAL,
    StockQuantity DECIMAL,
    StockValue DECIMAL,
    ReceivedValue DECIMAL,
    IssuedValue DECIMAL,
    PRIMARY KEY (Plant, Material, Warehouse, Month_)
);

-- Material Requirements Planning
DROP TABLE IF EXISTS PPP.MRP;
CREATE TABLE PPP.MRP
(
    Warehouse CHAR(4) NOT NULL,
    MRPPriority VARCHAR(6),
    ProposedQuantity DECIMAL,
    AveragePrice DECIMAL,
    Material VARCHAR(20) NOT NULL,
    MRPType CHAR(2)
    PRIMARY KEY (Warehouse, Material)
);

-- conversion rates
DROP TABLE IF EXISTS PPP.ZFI;
CREATE TABLE PPP.ZFI
(
    FromCurrency CHAR(3),
    ToCurrency CHAR(3),
    ValidDate DATE,
    ExchangeRate FLOAT,
    PRIMARY KEY (FromCurrency, ToCurrency, ValidDate)
);

-- reservations
DROP TABLE IF EXISTS PPP.ZMB25;
CREATE TABLE PPP.ZMB25
(
    Plant CHAR(4) NOT NULL,
    Warehouse CHAR(4) DEFAULT 'USTK',
    ReservationID VARCHAR(10) NOT NULL,
    ReservationItemID INTEGER NOT NULL,
    Material VARCHAR(20),
    RequiredQuantity DECIMAL,
    RemainingQuantity DECIMAL,
    PurchaseRequisition VARCHAR(15),
    MaintenanceOrder VARCHAR(15),
    DestinationCC VARCHAR(10),
    MovementType CHAR(3),
    Deleted BIT,
    FinalIssue BIT,
    RequiredDate DATE,
    DeliveryDate DATE,
    CreationDate DATE,
    PRIMARY KEY (ReservationID, ReservationItemID)
);

-- materials
DROP TABLE IF EXISTS PPP.ZMM001;
CREATE TABLE PPP.ZMM001
(
    Material VARCHAR(20) PRIMARY KEY NOT NULL,
    MaterialDescription TEXT,
    MaterialGroup VARCHAR(15) NOT NULL,
    MaterialGroupDescription TEXT,
    Unit VARCHAR(10),
    MaterialType CHAR(4) NOT NULL,
    Created DATE NOT NULL,
    LastChange Date NOT NULL
);