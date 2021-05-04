IF EXISTS(SELECT * FROM sys.external_data_sources WHERE name = 'dataready') 
DROP EXTERNAL DATA SOURCE dataready;

IF EXISTS(SELECT * FROM sys.database_scoped_credentials WHERE name = 'AccessCredential') 
DROP DATABASE SCOPED CREDENTIAL AccessCredential;

IF (SELECT COUNT(*) FROM sys.symmetric_keys WHERE name LIKE '%DatabaseMasterKey%') = 0 
BEGIN
CREATE MASTER KEY
ENCRYPTION BY PASSWORD='MASTER_PW'
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