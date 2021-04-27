IF SCHEMA_ID("PPP") IS NULL
EXEC ("CREATE SCHEMA PPP");


DROP TABLE IF EXISTS PPP.MB52;
CREATE TABLE PPP.MB52
(
    Plant    CHAR(4) NOT NULL,
    Warehouse    CHAR(4) DEFAULT 'TRFR',
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

DROP TABLE IF EXISTS PPP.MB51;
CREATE TABLE PPP.MB51
(
    MovementId INTEGER IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Plant CHAR(4) NOT NULL,
    Warehouse CHAR(4) DEFAULT 'TRFR',
    Material VARCHAR(20) NOT NULL,
    Quantity DECIMAL,
    MovementType CHAR(3),
    UserName VARCHAR(20),
    EntryDate DATE,
    RequisitionDate DATE,
    MovementValue DECIMAL NOT NULL,
    ReservationID VARCHAR(15)
);

DROP TABLE IF EXISTS PPP.MCBA;
CREATE TABLE PPP.MCBA
(
    Plant CHAR(4) NOT NULL,
    Material VARCHAR(20) NOT NULL,
    Warehouse CHAR(4) DEFAULT 'TRFR',
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

DROP TABLE IF EXISTS PPP.ZFI;
CREATE TABLE PPP.ZFI
(
    FromCurrency CHAR(3),
    ToCurrency CHAR(3),
    ValidDate DATE,
    ExchangeRate FLOAT,
    PRIMARY KEY (FromCurrency, ToCurrency, ValidDate)
);

DROP TABLE IF EXISTS PPP.ZMB25;
CREATE TABLE PPP.ZMB25
(
    Plant CHAR(4) NOT NULL,
    Warehouse CHAR(4) DEFAULT 'TRFR',
    ReservationID VARCHAR(10) NOT NULL,
    ReservationItemID INTEGER NOT NULL,
    Material VARCHAR(20),
    RequiredQuantity DECIMAL,
    RemainingQuantity DECIMAL,
    PurchaseRequisition VARCHAR(15),
    MaintenanceOrder VARCHAR(15),
    DestinationCC VARCHAR(10),
    UserName VARCHAR(40),
    MovementType CHAR(3),
    Deleted BIT,
    FinalIssue BIT,
    RequiredDate DATE,
    DeliveryDate DATE,
    CreationDate DATE,
    PRIMARY KEY (ReservationID, ReservationItemID)
);

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

IF EXISTS(SELECT * FROM sys.external_data_sources WHERE name = 'dataready') 
DROP EXTERNAL DATA SOURCE dataready;

IF EXISTS(SELECT * FROM sys.database_scoped_credentials WHERE name = 'AccessCredential') 
DROP DATABASE SCOPED CREDENTIAL AccessCredential;

IF (SELECT COUNT(*) FROM sys.symmetric_keys WHERE name LIKE '%DatabaseMasterKey%') = 0 
BEGIN
CREATE MASTER KEY
ENCRYPTION BY PASSWORD='MASTERKEYPWD000!'
END;

CREATE DATABASE SCOPED CREDENTIAL AccessCredential
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = 'SASCODE';

CREATE EXTERNAL DATA SOURCE dataready
WITH (
    TYPE = BLOB_STORAGE,
    LOCATION = 'https://STORAGEACCOUNT.blob.core.windows.net/data-ready',
    CREDENTIAL = AccessCredential
);