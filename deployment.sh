#!/bin/bash
#
# Deployment script for data into the Azure DB

echo "[PPP] Starting the database initial deployment for the Procurement Pipeline Project"

# get new variables
export THIS_IP=`wget -O - -q https://icanhazip.com/`
export SERVER_NAME=ppp-server-$(openssl rand -hex 5)

# create the server, database and firewall exception
echo "[PPP] Creating $SERVER_NAME in $LOCATION..."

az sql server create \
    --name $SERVER_NAME \
    --admin-user $LOGIN_INPUT \
    --admin-password $PASSWORD_INPUT \
    --output none

echo "[PPP] Server creation done!"

az sql server firewall-rule create \
    --server $SERVER_NAME \
    -n AllowMyIP \
    --start-ip-address $THIS_IP \
    --end-ip-address $THIS_IP \
    --output none

echo "[PPP] Firewall setup creation done!"

az sql db create \
    --server $SERVER_NAME \
    --name $DATABASE \
    --service-objective S0 \
    --zone-redundant false \
    --output none

echo "[PPP] Creating tables for database"

# create the main tables schema
sqlcmd \
    -S tcp:$SERVER_NAME.database.windows.net \
    -d $DATABASE \
    -U $LOGIN_INPUT \
    -P $PASSWORD_INPUT \
    -i code/create-tables.sql

echo "[PPP] Created main tables"

# assign current user as admin
object_id=$(az ad signed-in-user show --query objectId -o tsv)
az sql server ad-admin create \
    --display-name DisplayNameID \
    --object-id $object_id \
    -g $RESOURCE_GROUP \
    --server $SERVER_NAME \
    --output none

echo "[PPP] Added Admin user to Server"


# create views
sqlcmd \
    -S tcp:$SERVER_NAME.database.windows.net \
    -d $DATABASE \
    -U $LOGIN_INPUT \
    -P $PASSWORD_INPUT \
    -i code/create-views.sql

echo "[PPP] Created views for PowerBI"

# generate a sas code from azure to access the dfs storage
sas_validation_date=$(date -u -d "200 minutes" '+%Y-%m-%dT%H:%MZ')
sas_code=$(az storage account generate-sas --permissions cdlruwap --account-name $STORAGE_ACCOUNT --services b --resource-types sco --expiry $sas_validation_date -o tsv)

# prepare sas code to be read by sed function
sed_sas_code=$(echo $sas_code | sed 's/&/\\\&/g;s/\//\\\//g')

# set up credentials for accessing external source
config_code=$(sed "s/SAS_CODE/${sed_sas_code}/; s/STORAGE_ACCOUNT/${STORAGE_ACCOUNT}/; s/MASTER_PW/${DATABASE_MASTER_PW}/" code/configuration.sql)

sqlcmd \
    -S tcp:$SERVER_NAME.database.windows.net \
    -d $DATABASE \
    -U $LOGIN_INPUT \
    -P $PASSWORD_INPUT \
    -Q "${config_code}"

sleep 5s

echo "[PPP] Configuration file is set up. Now proceeding with uploading data."

transaction="zfi"
populate_code=$(sed "s/SOURCE_FILE/${transaction}/; s/TABLE_TO_POPULATE/${transaction}/;" code/populate-template.sql)
sqlcmd \
    -S tcp:$SERVER_NAME.database.windows.net \
    -d $DATABASE \
    -U $LOGIN_INPUT \
    -P $PASSWORD_INPUT \
    -Q "${populate_code}"
echo "[PPP] Uploaded data for ${transaction}"

# create extra tables
sqlcmd \
    -S tcp:$SERVER_NAME.database.windows.net \
    -d $DATABASE \
    -U $LOGIN_INPUT \
    -P $PASSWORD_INPUT \
    -i code/create-extra-tables.sql \
    -o /dev/null

echo "[PPP] Created extra tables with INSERT"

# BULK INSERT all of the data
for transaction in "mb52" "mb51" "mcba" "zmrp" "zmb25" "zmm001" "sp99" "picps" "monos_categories"
	do 
        populate_code=$(sed "s/SOURCE_FILE/${transaction}/; s/TABLE_TO_POPULATE/${transaction}/;" code/populate-template.sql)
        sqlcmd \
            -S tcp:$SERVER_NAME.database.windows.net \
            -d $DATABASE \
            -U $LOGIN_INPUT \
            -P $PASSWORD_INPUT \
            -Q "${populate_code}"
        echo "[PPP] Uploaded data for ${transaction}"
done

echo "[PPP] Create the missing text file to extract ZMM001 new data from SAP"

# get the missing materials inside a TXT file
sqlcmd \
    -S tcp:$SERVER_NAME.database.windows.net \
    -d $DATABASE \
    -U $LOGIN_INPUT \
    -P $PASSWORD_INPUT \
    -Q "SELECT * FROM proc_db.missing_materials" \
    -o missing.txt

# filter all the needed lines from missing TXT file (ZMAT and ZPEC materials)
awk '/^(F|4|6)/ {print $0}' missing.txt > missing.temp
mv -f missing.temp missing.txt

# In the end we can add the foreign key constraints. This will also add any missing rows to
# the parent tables. The way these rows are added to the parent tables can be adjusted
# in the T-SQL code.
sqlcmd \
    -S tcp:$SERVER_NAME.database.windows.net \
    -d $DATABASE \
    -U $LOGIN_INPUT \
    -P $PASSWORD_INPUT \
    -i code/format_schema.sql

echo "[PPP] Database deployment done"

