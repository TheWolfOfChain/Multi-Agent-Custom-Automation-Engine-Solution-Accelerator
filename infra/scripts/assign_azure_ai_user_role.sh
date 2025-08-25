#!/bin/bash

# Variables
resource_group="$1"
aif_resource_id="$2"
principal_ids="$3"


# Authenticate with Azure
if az account show &> /dev/null; then
    echo "Already authenticated with Azure."
else
    if [ -n "$managedIdentityClientId" ]; then
        # Use managed identity if running in Azure
        echo "Authenticating with Managed Identity..."
        az login --identity --client-id ${managedIdentityClientId}
    else
        # Use Azure CLI login if running locally
        echo "Authenticating with Azure CLI..."
        az login
    fi
    echo "Not authenticated with Azure. Attempting to authenticate..."
fi

echo "Getting signed in user id"
signed_user_id=$(az ad signed-in-user show --query id -o tsv)

IFS=',' read -r -a principal_ids_array <<< $principal_ids

# Check if signed-in user ID is already in the array
found=false
for principal_id in "${principal_ids_array[@]}"; do
  if [ "$principal_id" == "$signed_user_id" ]; then
    found=true
    break
  fi
done

if [ "$found" = false ]; then
  principal_ids_array+=("$signed_user_id")
fi


echo "Assigning Cosmos DB Built-in Data Contributor role to users"
for principal_id in "${principal_ids_array[@]}"; do

    echo "Using provided Azure AI resource id: $aif_resource_id"

    # Check if the user has the Azure AI User role
    echo "Checking if user has the Azure AI User role"
    role_assignment=$(MSYS_NO_PATHCONV=1 az role assignment list --role 53ca6127-db72-4b80-b1b0-d745d6d5456d --scope $aif_resource_id --assignee $principal_id --query "[].roleDefinitionId" -o tsv)
    if [ -z "$role_assignment" ]; then
        echo "User does not have the Azure AI User role. Assigning the role."
        MSYS_NO_PATHCONV=1 az role assignment create --assignee $principal_id --role 53ca6127-db72-4b80-b1b0-d745d6d5456d --scope $aif_resource_id --output none
        if [ $? -eq 0 ]; then
            echo "Azure AI User role assigned successfully."
        else
            echo "Failed to assign Azure AI User role."
            exit 1
        fi
    else
        echo "User already has the Azure AI User role."
    fi
done