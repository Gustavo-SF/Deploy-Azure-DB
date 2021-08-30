#!/bin/bash

# Getting server name
echo "[PPP] Starting the database initial deployment for the Procurement Pipeline Project"

SERVER_NAME=$(az sql server list --query [0].name -o tsv)

# get ip and open firewall to it
THIS_IP=$(wget -O - -q https://icanhazip.com/)
az sql server firewall-rule create \
    --server $SERVER_NAME \
    -n AllowMyIP \
    --start-ip-address $THIS_IP \
    --end-ip-address $THIS_IP \
    --output none

echo "[PPP] Added IP to firewall exceptions"

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

# add new data to MB51, MCBA, SP99 and ZMM001
for transaction in "mb51" "mcba" "sp99" "zmm001"
	do 
        populate_code=$(sed "s/SOURCE_FILE/${transaction}/; s/TABLE_TO_POPULATE/${transaction}/;" code/populate-template.sql)
        sqlcmd \
            -S tcp:$SERVER_NAME.database.windows.net \
            -d $DATABASE \
            -U $LOGIN_INPUT \
            -P $PASSWORD_INPUT \
            -Q "${populate_code}"
done

# recreate tables MB51, MRP, ZFI and ZMB25
for transaction in "mb52" "zmrp" "zfi" "zmb25"
	do 
        initial_populate_code=$(sed "s/SOURCE_FILE/${transaction}/; s/TABLE_TO_POPULATE/${transaction}/;" code/initial-populate-template.sql)
        sqlcmd \
            -S tcp:$SERVER_NAME.database.windows.net \
            -d $DATABASE \
            -U $LOGIN_INPUT \
            -P $PASSWORD_INPUT \
            -Q "${initial_populate_code}"
done

echo "[PPP] Data has been added to existing tables"