# Deployment for Supply Chain DB - Azure SQL Database

> This repository is part of the Construction Supply Chain Pipeline for the MSc Thesis developed in Mota-Engil with support from Faculty of Sciences of the University of Lisbon.

In this repository we are able to find all the deployment code in T-SQL. This includes all the configuration of the database to receive data from an external source and the table and views creation. 

Only one deployment script is missing from this dataset, and that is the creation of the extra tables: Locations, and MovementTypes. Here we insert the data manually using INSERT INTO. This was done to avoid divulging company data.


## Requirements

To make this deployment, it is needed to use `Azure CLI` and `sqlcmd`. The CSV files that are deployed to the Azure SQL Database are located in a folder named data-ready/ in an Azure Data Lake Storage.

* [Install Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
* [Install sqlcmd](https://docs.microsoft.com/en-us/sql/tools/sqlcmd-utility?view=sql-server-ver15)
## Code
 
    .
    ├── code/
    │   │
    │   ├── configuration.sql     # External source configuration
    │   │
    │   ├── create-extra-tables.sql   # Create tables with INSERT INTO
    │   │
    │   ├── create-tables.sql    # Create table schema
    │   │
    │   ├── create-views.sql   # Create views for Power BI
    │   │
    │   ├── populate-template.sql   # Create views for Power BI
    │   │
    │   └── initial-populate-template.sql   # Template for initial BULK INSERT
    │   
    ├── screts/   # Configuration host file     
    │   │
    │   └── database-pws.sh   # Secrets for the external source
    │
    ├── deploy_script.sh   # Initial bash db deployment script
    │
    └── maintenance_script.sh # Script for when data is to be added   
    


We can find several types of scripts for the deployment of the database. To upload anything to the database we have to set up the security settings to allow this. The most important are the credentials which are kept in the secrets/ folder in a bash script ready to be sourced.

```bash
# get the secrets
source secrets/database_pws.sh
```

Before the creation of the database, we need the SQL server, and to create it we use the credentials we have defined.

```bash
az sql server create \
    --name $server \
    --admin-user $login \
    --admin-password $password
```

We should also **set up the firewall rules** to allow for the deployment from the local public IP address. In the meantime, it is possible to get this IP by sending a request to https://icanhazip.com/. To do this we use bash command `wget` on it and pass it into the Azure CLI command.

```bash
thisIP=`wget -O - -q https://icanhazip.com/`
az sql server firewall-rule create \
    --server $server \
    -n AllowMyIP \
    --start-ip-address $thisIP \
    --end-ip-address $thisIP
```

And finally we are able to create the database.

```bash
az sql db create \
    --server $server \
    --name $database \
    --service-objective S0 \
    --zone-redundant false
```

Now that we have the server and database, we can now configure the database to communicate with the ADLS and get the required CSV files to do the BULK INSERT. The configuration will use a SAS code to do this access, and for security reasons, this should be generated everytime we deploy anything, so we will make a SAS code with a 200 minutes life span. We also need to modify the SAS code with a `sed` command before using `sed` so we are able to change the configuration.sql file correctly.

We can then proceed to creating the tables schema with the create-tables.sql file and with the help of the initial-populate-template.sql we can populate the tables with the data from the external source. We need a few extra configurations to be able to read the CSV files, including setting up encoding and others for better performance.

```sql
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
```

Other extra things added to the database include 2 extra tables, that helped normalize the rest: MovementCodes and Locations. These extra tables file is not present in this repository since it has company data included in them.

To make our SQL database contribute to its applications, I added some views to allow other software to query the data more easily. Also Admin User access was provided to the current user. Explanation of all views can be found documented in the file create-views.sql.

One view that was also created was to be able to access the missing materials that are not present in ZMM001 table, but present in the rest. This allows to make the user to get back to the source of the data and try to obtain the names for these material IDs.

```sql
DROP VIEW IF EXISTS PPP.MissingMaterials;
GO
CREATE VIEW PPP.MissingMaterials
AS
SELECT DISTINCT y.Material 
FROM (
    SELECT DISTINCT m.Material 
    FROM PPP.MB51 as m 
    LEFT JOIN [PPP].[ZMM001] as t 
    ON t.Material=m.Material 
    WHERE t.Material IS NULL
    UNION ALL
    (...)
) as y;
GO
```

We output the result from this view to a missing.txt file. After a modification using a simple awk command, it is possible to try to obtain this missing data.

**The following should be done when the file is added to the raw-data/ folder in ADLS** (assuming the Azure FunctionApp is deployed)

```bash
# add the queue message to process into CSV
body=$(echo -n 'ZMM001-Extra' | base64)
az storage message put \
    --content $body \
    -q $queueName \
    --time-to-live 120 \
    --auth-mode login \
    --account-name $storageAccount

# adapt template to the new ZMM001 data
tempfile=$(sed "s/SOURCEFILE/ZMM001-Extra/; s/TABLETOPOPULATE/ZMM001/" code/populate-template.sql)

# add data to the table
sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -Q "${tempfile}"
```

### Making posterior addition of data

Assuming we will continue obtaining data in bulk, we want to keep the same process. To do this we can run the maintenance_script.sh, which consists on:

1. Obtaining the needed variables
2. Setting up the security configurations
3. Adding data to MB51 and MCBA
4. Deleting and adding data to the rest of the tables
5. Adding views and querying for missing materials again

## Learn More

* [Doing BULK INSERT with Azure SQL Database from external source](https://www.youtube.com/watch?v=-7fjR3yPUVU)
* [Transact-SQL Documentation](https://docs.microsoft.com/en-us/sql/t-sql/language-reference?view=sql-server-ver15)