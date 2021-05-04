#!/bin/bash

# initial variables
resourceGroup="DataScienceThesisRG"
location="westeurope"
storageAccount="dsthesissa"

# get the secrets
source secrets/database_pws.sh
server=$(az sql server list --query [0].name -o tsv)

# get ip and open firewall to it
thisIP=$(wget -O - -q https://icanhazip.com/)
az sql server firewall-rule create \
    --server $server \
    -n AllowMyIP \
    --start-ip-address $thisIP \
    --end-ip-address $thisIP

# get the last date in the data and extract month and year
lastentry=$(sqlcmd -S tcp:$server.database.windows.net -d $database -U $login -P $password -Q "SELECT MAX(EntryDate) FROM [PPP].[MB51]" | awk '/2/ {print $1}')
yearLastEntry=$(echo $lastentry | awk 'BEGIN { FS = "-" } ; { print $1 }')
monthLastEntry=$(echo $lastentry | awk 'BEGIN { FS = "-" } ; { print $2 }')

# delete the last month from MCBA which was incomplete
sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -Q "DELETE FROM [PPP].[MCBA] WHERE Month_='${yearLastEntry}-${monthLastEntry}-01'"

# delete the last day from MB51 which was incomplete
sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -Q "DELETE FROM [PPP].[MB51] WHERE EntryDate='${lastentry}'"

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

# add new data to MB51 and MCBA
is=("MB51" "MCBA")
for ((i = 0; i < 2; i++)) 
	do 
        tempfile=$(sed "s/SOURCEFILE/${is[i]}/; s/TABLETOPOPULATE/${is[i]}/;" code/populate-template.sql)
        sqlcmd \
            -S tcp:$server.database.windows.net \
            -d $database \
            -U $login \
            -P $password \
            -Q "${tempfile}"
done

# recreate tables MB51, MRP, ZFI and ZMB25
is=("MB52" "ZMRP" "ZFI" "ZMB25")
js=("MB52" "MRP" "ZFI" "ZMB25")
for ((i = 0; i < 4; i++)) 
	do 
        tempfile=$(sed "s/SOURCEFILE/${is[i]}/; s/TABLETOPOPULATE/${js[i]}/;" code/initial-populate-template.sql)
        sqlcmd \
            -S tcp:$server.database.windows.net \
            -d $database \
            -U $login \
            -P $password \
            -Q "${tempfile}"
done

# recreate extra tables
sqlcmd \
    -S tcp:$server.database.windows.net \
    -d $database \
    -U $login \
    -P $password \
    -i code/create-extra-tables.sql 

# recreate views
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

# filter all the needed lines (ZMAT and ZPEC materials)
awk '/^(F|4|6)/ {print $0}' missing.txt > missing.temp
mv -f missing.temp missing.txt