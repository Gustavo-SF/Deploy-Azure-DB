/*
Template for truncating and populating a table with SOURCE_FILE data
*/


SET DATEFORMAT dmy;  
GO 

-- To be the first data to go in the table, we start by truncating it
TRUNCATE TABLE proc_db.TABLE_TO_POPULATE;
GO

SET NOCOUNT ON -- Reduce network traffic by stopping the message that shows the number of rows affected
    BULK INSERT proc_db.TABLE_TO_POPULATE -- Table created
    FROM 'SOURCE_FILE.csv' -- Within the container, the location of the file
    WITH (
        CODEPAGE = '65001', -- Reading UTF-8 encoded CSV file
        DATA_SOURCE = 'data_ready', -- Using an external data source
        FORMAT='CSV', 
        ROWTERMINATOR='0x0a',
        FIRSTROW=2,
        BATCHSIZE=50000, -- Reduce network traffic by inseting in batches
        TABLOCK -- Minimize number of log records for the insert operation
    );
GO