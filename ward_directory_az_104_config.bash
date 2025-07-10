# AZ 104 Ward Directory config commands to create 3 Azure Storage Accounts
# 1 for Bishop, 1 for RSP / EQP, 1 for member

az storage account create --name az104wardbishop --location eastus --resource-group az104_ward1 --sku Standard_LRS --allow-blob-public-access false  BlobStorage --access-tier Hot
az storage account create --name az104wardrspeqp --location centralus --resource-group az104_ward2 --sku Standard_LRS --allow-blob-public-access false  BlobStorage --access-tier Hot
az storage account create --name az104wardmember --location westus --resource-group az104_ward3 --sku Standard_LRS --allow-blob-public-access false  BlobStorage --access-tier Hot

az functionapp create --resource-group az104_ward1 --consumption-plan-location eastus --runtime dotnet-isolated --functions-version 4 --name bishopfunctionapp --storage-account az104wardbishop
az functionapp create --resource-group az104_ward2 --consumption-plan-location eastus --runtime dotnet-isolated --functions-version 4 --name bishopfunctionapp --storage-account az104wardrspeqp
az functionapp create --resource-group az104_ward3 --consumption-plan-location eastus --runtime dotnet-isolated --functions-version 4 --name bishopfunctionapp --storage-account az104wardmember

# Commands for Azure CLI storage with endpoints

sitename1 = az104wardbishopsite
sitename2 = az104wardrspeqpsite
sitename3 = az104wardmembersite
az deployment group create --resource-group eastus --template-uri "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/master/azuredeploy.json" --parameters siteName=$sitename1 hostingPlanName=viewerhost branch=main
az deployment group create --resource-group eastus --template-uri "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/master/azuredeploy.json" --parameters siteName=$sitename2 hostingPlanName=viewerhost branch=main
az deployment group create --resource-group eastus --template-uri "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/master/azuredeploy.json" --parameters siteName=$sitename3 hostingPlanName=viewerhost branch=main

# Subscribe to Blob storage

storageid1=$(az storage account show --name az104wardbishop --resource-group eastus --query id --output tsv)
storageid2=$(az storage account show --name az104wardrspeqp --resource-group centralus --query id --output tsv)
storageid3=$(az storage account show --name az104wardmember --resource-group westus --query id --output tsv)
endpoint1=https://$sitename1.azurewebsites.net/api/updates
endpoint2=https://$sitename2.azurewebsites.net/api/updates
endpoint3=https://$sitename3.azurewebsites.net/api/updates
az eventgrid event-subscription create --source-resource-id $storageid1 --name az104wardeventbishop --endpoint $endpoint1
az eventgrid event-subscription create --source-resource-id $storageid2 --name az104wardeventrspeqp --endpoint $endpoint2
az eventgrid event-subscription create --source-resource-id $storageid3 --name az104wardeventmember --endpoint $endpoint3

# Trigger an event from Blob storage

export AZURE_STORAGE_ACCOUNT1=az104wardbishopstorage
export AZURE_STORAGE_KEY="$(az storage account keys list --account-name az104wardbishopstorage --resource-group eastus --query "[0].value" --output tsv)"
export AZURE_STORAGE_ACCOUNT2=az104wardeqprspstorage
export AZURE_STORAGE_KEY="$(az storage account keys list --account-name az104wardbishopstorage --resource-group centralus --query "[0].value" --output tsv)"
export AZURE_STORAGE_ACCOUNT3=az104wardmemberstorage
export AZURE_STORAGE_KEY="$(az storage account keys list --account-name az104wardbishopstorage --resource-group westus --query "[0].value" --output tsv)"

# Create a message endpoint

$sitenameBishop="az104wardirectorysitebishop"
$resourceGroup1="eastus"
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroup1 -TemplateUri "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/master/azuredeploy.json" -siteName $sitenameBishop -hostingPlanName viewerhost -branch "main"

$sitenameEQPRSP="az104wardirectorysiteeqprsp"
$resourceGroup2="centralus"
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroup2 -TemplateUri "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/master/azuredeploy.json" -siteName $sitenameEQPRSP -hostingPlanName viewerhost -branch "main"

$sitenameMember="az104wardirectorysitebishop"
$resourceGroup3="westus"
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroup3 -TemplateUri "https://raw.githubusercontent.com/Azure-Samples/azure-event-grid-viewer/master/azuredeploy.json" -siteName $sitenameMember -hostingPlanName viewerhost -branch "main"
