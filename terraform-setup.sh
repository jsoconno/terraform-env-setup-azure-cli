#!/bin/bash

# 0. Set variables
SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
ENVIRONMENT="dev"
UNIQUE_VALUE=$RANDOM
RESOURCE_GROUP_NAME="terraform-$UNIQUE_VALUE-$ENVIRONMENT"
RESOURCE_GROUP_LOCATION="eastus"
STORAGE_ACCOUNT_NAME="terraform$UNIQUE_VALUE$ENVIRONMENT"
STATE_CONTAINER_NAME="state"
PLAN_CONTAINER_NAME="plan"
KEY_VAULT_NAME="terraform-$UNIQUE_VALUE-$ENVIRONMENT"
SERVICE_PRINCIPAL_NAME="sp-terraform-$ENVIRONMENT"
TAGS="environment=$ENVIRONMENT"
CLEAN_UP=true

# 1. Sign into Azure with az login
az login
az account show
az account set --subscription $SUBSCRIPTION_ID

# 2. Create resource group
az group create --name $RESOURCE_GROUP_NAME --location $RESOURCE_GROUP_LOCATION --tags $TAGS

# 3. Create storage account
az storage account create --resource-group $RESOURCE_GROUP_NAME --name $STORAGE_ACCOUNT_NAME --sku Standard_LRS --encryption-services blob
ACCESS_KEY=$(az storage account keys list --resource-group $RESOURCE_GROUP_NAME --account-name $STORAGE_ACCOUNT_NAME --query '[0].value' -o tsv)

# 4. Create blob containers
az storage container create --name $STATE_CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME
az storage container create --name $PLAN_CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME

# 5. Create key vault for secrets management
az keyvault create --resource-group $RESOURCE_GROUP_NAME --location $RESOURCE_GROUP_LOCATION --name $KEY_VAULT_NAME

# 6. Get Terraform backend configuration
TERRAFORM_BACKEND=$(cat <<EOF
terraform {
    backend "azurerm" {
        resource_group_name  = "$RESOURCE_GROUP_NAME"
        storage_account_name = "$STORAGE_ACCOUNT_NAME"
        container_name       = "$STATE_CONTAINER_NAME"
        key                  = "$ENVIRONMENT.terraform.tfstate"
        access_key           = "$ACCESS_KEY"
    }
}
EOF
)
echo "$TERRAFORM_BACKEND" > "terraform-backend-$ENVIRONMENT.tf"

# 7. Create the service principal for the target environment
export MSYS_NO_PATHCONV=1
SP_CREDENTIALS=$(az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME --role Contributor --scopes /subscriptions/$SUBSCRIPTION_ID)
echo "$SP_CREDENTIALS" > "credentials-$ENVIRONMENT.json"

# X. Clean up (optional)
if [ $CLEAN_UP = true ]
then
    az group delete --name $RESOURCE_GROUP_NAME
    az keyvault purge --name $KEY_VAULT_NAME
    SPN_ID=$(az ad sp list --all --query "[?displayName=='$SERVICE_PRINCIPAL_NAME'].appId" -o tsv)
    APP_ID=$(az ad app list --all --query "[?displayName=='$SERVICE_PRINCIPAL_NAME'].appId" -o tsv)
    az ad sp delete --id $SPN_ID
    az ad app delete --id $APP_ID
fi