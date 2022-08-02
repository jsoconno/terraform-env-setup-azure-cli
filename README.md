# Terraform Environment Setup Using Azure CLI
The `terraform-setup.sh` script in this repository can be used to stand up baseline resource required for Terraform.  It includes:

* A resource group that contains all of the automation infrastructure.
* A storage account and containers for Terraform state and plan management.
* A key vault for managing secrets used as part of Terraform execution in pipelines.

# How to use
1. Navigate to this folder on the command line using `cd` commands.
2. Run `chmod +x ./terraform-setup.sh` to ensure you can run the script from the command line.
3. Update the scripts with your values in Step 0.  In particular, it is a good idea to update the `SUBSCRIPTION_ID` and `UNIQUE_VALUE` attributes in a way that meets your needs.
4. Run `./terraform-setup.sh` on the command line to execute the script.
5. Use the `credentials` and `terraform-backend` output files to set up service credentials and Terraform scripts for automation.

Note: Secrets should never be added directly to a Git repository.  All output secret values should be stored securely in a Key Vault or similar credential manager.

For example, it is a good idea to remove the `access_key` value from the `terraform-backend` file and pass it to Terraform on the command line with the `-backend-config` flag or using environment variables.

# Test Running Terraform
Now that the baseline infrastructure is established, you can start to use the created service principal for running Terraform in the selected subscription(s).

1. Install Terraform.  A great tool to use is `tfenv`.  Here are the docs: https://github.com/tfutils/tfenv.
2. Log in with the service principal using the details in the `credentials` file by running `az login --service-principal -u <app-id> -p <password-or-cert> --tenant <tenant>`
3. Create a new Terraform project with the following script:

```
terraform {
    backend "azurerm" {
        resource_group_name  = "terraform-29953-dev"
        storage_account_name = "terraform29953dev"
        container_name       = "state"
        key                  = "dev.terraform.tfstate"
    }
    required_providers {
        azurerm = {
            source  = "hashicorp/azurerm"
            version = "~> 3.0"
        }
    }
}

provider "azurerm" {
    subscription_id = "00000000-0000-0000-0000-000000000000"
    client_id       = "00000000-0000-0000-0000-000000000000"
    client_secret   = ""
    tenant_id       = "00000000-0000-0000-0000-000000000000"
    features {
    }
}

resource "azurerm_resource_group" "rides" {
    name = "test-resource-group"
    location = "eastus"
}


```
   
4. Run `terraform init -backend-config="access_key=YOUR_ACCESS_KEY"`
5. Run `terraform plan -var="client_secret=YOUR_CLIENT_SECRET" -out out.tfplan`
6. Run `terraform apply out.tfplan`