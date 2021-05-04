#!/bin/bash

# initial variables
resourceGroup="DataScienceThesisRG"
location="westeurope"
storageAccount="dsthesissa"

# get the secrets
source secrets/database_pws.sh

# get new variables
thisIP=`wget -O - -q https://icanhazip.com/`
server=ppp-server-$(openssl rand -hex 5)

# create the server, database and firewall exception
echo "Creating $server in $location..."

az sql server create \
    --name $server \
    --admin-user $login \
    --admin-password $password

az sql server firewall-rule create \
    --server $server \
    -n AllowMyIP \
    --start-ip-address $thisIP \
    --end-ip-address $thisIP

az sql db create \
    --server $server \
    --name $database \
    --service-objective S0 \
    --zone-redundant false

# generate a sas code from azure to access the dfs storage
end=$(date -u -d "200 minutes" '+%Y-%m-%dT%H:%MZ')
sas=$(az storage account generate-sas --permissions cdlruwap --account-name $storageAccount --services b --resource-types sco --expiry $end -o tsv)

# prepare sas code to be read by sed function
newsas=$(echo $sas | sed 's/&/\\\&/g;s/\//\\\//g')

# set up credentials for accessing external source
tempfile=$(sed "s/SASCODE/${newsas}/; s/STORAGEACCOUNT/${storageAccount}/; s/MASTER_PW/${DATABASE_MASTER_PW}/" code/configuration.sql)

sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -Q "${tempfile}"

# create the main tables schema
sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -i code/create-tables.sql

# BULK INSERT all of the data
is=("MB52" "MB51" "MB51-MEP" "MCBA" "ZMRP" "ZFI" "ZMB25" "ZMM001")
js=("MB52" "MB51" "MB51" "MCBA" "MRP" "ZFI" "ZMB25" "ZMM001")
for ((i = 0; i < 8; i++)) 
	do 
        tempfile=$(sed "s/SOURCEFILE/${is[i]}/; s/TABLETOPOPULATE/${js[i]}/;" code/populate-template.sql)
        sqlcmd \
            -S tcp:$server.database.windows.net \
            -d $database \
            -U $login \
            -P $password \
            -Q "${tempfile}"
done

# assign current user as admin
objectID=$(az ad signed-in-user show --query objectId -o tsv)
az sql server ad-admin create \
    --display-name DisplayNameID \
    --object-id $objectID \
    -g $storageAccount \
    --server $server

# create extra tables
sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -i code/create-extra-tables.sql 

# create views
sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -i code/create-views.sql

# get the missing materials inside a TXT file
sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -Q "SELECT * FROM PPP.MissingMaterials" \
    -o missing.txt

# filter all the needed lines from missing TXT file (ZMAT and ZPEC materials)
awk '/^(F|4|6)/ {print $0}' missing.txt > missing.temp
mv -f missing.temp missing.txt

