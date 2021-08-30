/*
Configuration needed for doing BULK Insert of Azure Blob Storage files
*/

-- Drop everything before doing the setup again
IF EXISTS(SELECT * FROM sys.external_data_sources WHERE name = 'data_ready') 
DROP EXTERNAL DATA SOURCE data_ready;
IF EXISTS(SELECT * FROM sys.database_scoped_credentials WHERE name = 'access_credential') 
DROP DATABASE SCOPED CREDENTIAL access_credential;

-- Create Master Key for Database
IF (SELECT COUNT(*) FROM sys.symmetric_keys WHERE name LIKE '%DatabaseMasterKey%') = 0 
BEGIN
CREATE MASTER KEY
ENCRYPTION BY PASSWORD='MASTER_PW'
END;

-- Provide sas code for accessing storage
CREATE DATABASE SCOPED CREDENTIAL access_credential
WITH IDENTITY = 'SHARED ACCESS SIGNATURE',
SECRET = 'SAS_CODE';

-- Configure access location
CREATE EXTERNAL DATA SOURCE data_ready
WITH (
    TYPE = BLOB_STORAGE,
    LOCATION = 'https://STORAGE_ACCOUNT.blob.core.windows.net/data-ready',
    CREDENTIAL = access_credential
);