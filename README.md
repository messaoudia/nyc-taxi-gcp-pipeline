# NYC taxi pipeline from raw data to vizualisation & IA

This project is meant to show you my skills on GCP + DBT

## Architecture

## Want to try the project ?
1. Download GCP cli + auth login
2. Create a project on GCP
`gcloud projects create PROJECT_ID`
3. Select your project
`gcloud config set project PROJECT_ID`

Ideally we should have on project per env but for ease I decided to go for one project for all envs to avoid complexity for a small project

gcloud projects add-iam-policy-binding PROJECT_ID --member="user:USER_IDENTIFIER" --role=ROLE
gcloud projects add-iam-policy-binding nyc-taxi-gcp-pipeline --member="user:gcpuser.flagship446@slmails.com" --role=roles/compute.instanceAdmin.v1

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

