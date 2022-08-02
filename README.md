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