SET DATEFORMAT dmy;  
GO 

-- To be the first data to go in the table, we start by truncating it
TRUNCATE TABLE PPP.TABLETOPOPULATE;
GO

SET NOCOUNT ON -- Reduce network traffic by stopping the message that shows the number of rows affected
    BULK INSERT PPP.TABLETOPOPULATE -- Table created
    FROM 'SOURCEFILE.csv' -- Within the container, the location of the file
    WITH (
        CODEPAGE = '65001', -- Reading UTF-8 encoded CSV file
        DATA_SOURCE = 'dataready', -- Using an external data source
        FORMAT='CSV', 
        ROWTERMINATOR='0x0a',
        FIRSTROW=2,
        BATCHSIZE=50000, -- Reduce network traffic by inseting in batches
        TABLOCK -- Minimize number of log records for the insert operation
    );
GO