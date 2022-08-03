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
CLEAN_UP=false

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
az storage container create --name $STATE_CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --auth-mode login
az storage container create --name $PLAN_CONTAINER_NAME --account-name $STORAGE_ACCOUNT_NAME --auth-mode login

# 5. Create the service principal for the target environment and get IDs
export MSYS_NO_PATHCONV=1
SP_CREDENTIALS=$(az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME)
echo "$SP_CREDENTIALS" > "credentials-$ENVIRONMENT.json"
SPN_ID=$(az ad sp list --all --query "[?displayName=='$SERVICE_PRINCIPAL_NAME'].id" -o tsv)
APP_ID=$(az ad app list --all --query "[?displayName=='$SERVICE_PRINCIPAL_NAME'].id" -o tsv)
CLIENT_SECRET=$(grep -o '"password": "[^"]*' credentials-$ENVIRONMENT.json | grep -o '[^"]*$')

# 6. Assign service principal roles and permissions
az role assignment create --assignee $SPN_ID --role "Owner" --scope /subscriptions/$SUBSCRIPTION_ID
az role assignment create --assignee $SPN_ID --role "Contributor" --scope /subscriptions/$SUBSCRIPTION_ID

# 7. Create the key vault and add an access policy for Terraform
az keyvault create --resource-group $RESOURCE_GROUP_NAME --location $RESOURCE_GROUP_LOCATION --name $KEY_VAULT_NAME
az keyvault set-policy --name $KEY_VAULT_NAME --secret-permissions all --key-permissions all --certificate-permissions all --object-id $APP_ID

# 8. Create a working Terraform test script to validate credentials
TENANT_ID=$(az account show --query tenantId -o tsv)
CLIENT_ID=$(az ad app list --all --query "[?displayName=='$SERVICE_PRINCIPAL_NAME'].appId" -o tsv)
TERRAFORM_BACKEND=$(cat <<EOF
terraform {
    backend "azurerm" {
        resource_group_name  = "$RESOURCE_GROUP_NAME"
        storage_account_name = "$STORAGE_ACCOUNT_NAME"
        container_name       = "$STATE_CONTAINER_NAME"
        key                  = "$ENVIRONMENT.terraform.tfstate"
        access_key           = "$ACCESS_KEY"
    }
    required_providers {
        azurerm = {
            source  = "hashicorp/azurerm"
            version = "~> 3.0"
        }
    }
}

provider "azurerm" {
    subscription_id = "$SUBSCRIPTION_ID"
    client_id       = "$CLIENT_ID"
    client_secret   = "$CLIENT_SECRET"
    tenant_id       = "$TENANT_ID"
    features {
    }
}

resource "azurerm_resource_group" "example" {
    name = "test-resource-group"
    location = "eastus"
}
EOF
)
echo "$TERRAFORM_BACKEND" > "terraform-backend-$ENVIRONMENT.tf"

# 9. Create a file to make running Terraform code simpler
TERRAFORM_RUN=$(cat <<EOF
az login --service-principal -u $CLIENT_ID -p $CLIENT_SECRET --tenant $TENANT_ID
terraform init
terraform plan -out out.tfplan
terraform apply out.tfplan
terraform apply -destroy -auto-approve
EOF
)
echo "$TERRAFORM_RUN" > "terraform-run.sh"

# X. Clean up (optional)
if [ $CLEAN_UP = true ]
then
    az group delete --name $RESOURCE_GROUP_NAME
    az keyvault purge --name $KEY_VAULT_NAME
    az ad sp delete --id $SPN_ID
    az ad app delete --id $APP_ID
fi