SET DATEFORMAT dmy;  
GO 

SET NOCOUNT ON -- Reduce network traffic by stopping the message that shows the number of rows affected
    BULK INSERT PPP.TABLETOPOPULATE -- Table created
    FROM 'SOURCEFILE.csv' -- Within the container, the location of the file
    WITH (
        CODEPAGE = '65001',
        DATA_SOURCE = 'dataready', --Using the external data source
        FORMAT='CSV', 
        ROWTERMINATOR='0x0a',
        FIRSTROW=2,
        BATCHSIZE=50000, -- Reduce network traffic by inseting in batches
        TABLOCK -- Minimize number of log records for the insert operation
    );
GO