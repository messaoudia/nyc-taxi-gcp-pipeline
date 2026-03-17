# NYC taxi pipeline from raw data to vizualisation & IA

This project is meant to show you my skills on GCP + DBT

> DISCLAIMER 1: this project is in work in progress 🏗️

> DISCLAIMER 2: 
> - This is NOT Vibe Coding at all !! A good developer keeps control of the code always of course IA was used and should be used to ease productivity but not to just code instead of the developer
> - This is handwritting code by myself that I can explain 100%

## Architecture
![Architecture Diagram](docs/infrastructure.drawio.png)

## Want to try the project ?
1. Download GCP cli + auth login
2. Create a project on GCP
`gcloud projects create PROJECT_ID`
3. Select your project
`gcloud config set project PROJECT_ID`

Ideally we should have on project per env but for ease I decided to go for one project for all envs to avoid complexity for a small project

gcloud projects add-iam-policy-binding PROJECT_ID --member="user:USER_IDENTIFIER" --role=ROLE
gcloud projects add-iam-policy-binding nyc-taxi-gcp-pipeline --member="user:gcpuser.example@example.com" --role=roles/compute.instanceAdmin.v1

## Terraform
### Init required tf state bucket
To be able to use this project you need to first create the tf stated bucket where will be stored tf state per env

cd terraform/required
terraform init
terraform plan (done in apply also but to be safe)
terraform apply

### Per env apply
cd terraform/dev
terraform init -backend-config=backend.hcl

# Service Account Impersonate
Service accounts are very important for several reasons. One of them is testing your flow locally using least privilege conditions by impersonating the service account via gcloud cli, you can test in real conditions with the exact same permissions as production, avoiding any surprises at deployment time.
```sh
# scripts/auth.sh

#!/bin/bash

ACTION=$1  # "deploy" ou "local"
SA=$2      # Service Account email (ex: "nyctaxi-load-bq-sa-dev@nyc-taxi-gcp-pipeline.iam.gserviceaccount.com")

case $ACTION in
  deploy)
    echo "🔄 Switching to Owner account for Terraform..."
    gcloud auth application-default login
    echo "✅ Ready to terraform apply"
    ;;
  local)
    echo "🔄 Switching to Service Account for local testing..."
    gcloud auth application-default login \
      --impersonate-service-account=$SA
    echo "✅ Ready to test main.py locally"
    ;;
  whoami)
    echo "🔍 Current ADC credentials:"
    cat ~/.config/gcloud/application_default_credentials.json | grep -E "client_email|service_account_impersonation"
    ;;
  *)
    echo "Usage: ./scripts/auth.sh [deploy|local|whoami]"
    ;;
esac
```

