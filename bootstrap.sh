#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'

NC='\033[0m' # No Color
MSG="${RED}Please edit vars.sh and execute \`source vars.sh\` before running this script again.${NC}"
[ -z $PROJECT_ID ]  && echo -e "\$PROJECT_ID is not set. ${MSG}" && exit 1
[ -z $GCP_USERNAME ]  && echo -e "\$GCP_USERNAME is not set. ${MSG}" && exit 1
[ -z $REGION ]  && echo -e "\$GCP_USERNAME is not set. ${MSG}" && exit 1

set -x # print out commands that are being executed

gcloud config set project $PROJECT_ID

# Enable necessary APIs
gcloud services enable storage-component.googleapis.com notebooks.googleapis.com serviceusage.googleapis.com cloudresourcemanager.googleapis.com pubsub.googleapis.com compute.googleapis.com metastore.googleapis.com datacatalog.googleapis.com analyticshub.googleapis.com bigquery.googleapis.com dataplex.googleapis.com datalineage.googleapis.com dataform.googleapis.com dataproc.googleapis.com bigqueryconnection.googleapis.com aiplatform.googleapis.com

# Install Git and Git LFS
if ! $(git lfs >/dev/null); then
  sudo apt-get update
  sudo apt-get install git
  sudo apt-get install git-lfs
fi

# Clone the repository
git clone https://github.com/fhirschmann/bootkon-h2-2024.git
cd bootkon-h2-2024/
git lfs pull

# Verify checksums and remove checksum files
cd data-prediction
sha256sum -c checksums.sha256
rm -f checksums.sha256
cd ..
cd data-ingestion/csv/ulb_fraud_detection/
sha256sum -c checksums.sha256
rm -f checksums.sha256
cd ../..
cd parquet/ulb_fraud_detection/
sha256sum -c checksums.sha256
rm -f checksums.sha256
cd ../../..
cd metadata-mapping/
sha256sum -c checksums.sha256
rm -f checksums.sha256
cd ../

declare -a user_roles=(
    "roles/bigquery.jobUser" # Can run BigQuery jobs
    "roles/bigquery.dataEditor" # Can edit BigQuery datasets
    "roles/bigquery.connectionAdmin" # Can manage BigQuery connections
    "roles/dataproc.editor" # Can edit Dataproc clusters
    "roles/aiplatform.admin" # Admin on Vertex AI
    "roles/dataplex.admin" # Admin on Dataplex
    "roles/datalineage.admin" # Admin on data lineage operations
    "roles/compute.admin" # Admin on Compute Engine
    "roles/storage.admin" # Admin on Cloud Storage
    "roles/storage.objectAdmin" # Admin on Cloud Storage objects
    "roles/iam.serviceAccountUser" # Can use service accounts
    "roles/pubsub.admin" # Admin on Pub/Sub
    "roles/resourcemanager.projectIamAdmin" # Project IAM admin
)

# Assign roles to user
for role in "${user_roles[@]}"; do
  echo "Assigning role $role to $USER_EMAIL in project $PROJECT_ID..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:$GCP_USERNAME" --role="$role" >>/dev/null
done

# Retrieve the project number for the default compute service account
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")

# Check if we successfully retrieved the project number
if [ -z "$PROJECT_NUMBER" ]; then
  echo "Failed to get the project number for project ID $PROJECT_ID"
  exit 1
fi
# Define service account email using the project number
COMPUTE_SERVICE_ACCOUNT="$PROJECT_NUMBER-compute@developer.gserviceaccount.com"

# Array of service account roles with descriptions
declare -a service_account_roles=(
    "roles/dataproc.worker" # Can perform actions as a Dataproc worker
    "roles/bigquery.dataEditor" # Can edit BigQuery datasets
    "roles/bigquery.jobUser" # Can run BigQuery jobs
    "roles/storage.objectAdmin" # Admin on Cloud Storage objects
    "roles/storage.admin" # Admin on Cloud Storage
    "roles/iam.serviceAccountUser" # Can use service accounts
    "roles/pubsub.admin" # Admin on Pub/Sub
    "roles/serviceusage.serviceUsageConsumer" # Can use services
    "roles/resourcemanager.projectIamAdmin" # Project IAM admin
)

# Assign roles to the compute service account
for role in "${service_account_roles[@]}"; do
  echo "Assigning role $role to $COMPUTE_SERVICE_ACCOUNT in project $PROJECT_ID..."
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$COMPUTE_SERVICE_ACCOUNT" --role="$role" >>/dev/null
done

# Create default VPC network and enable private access
if $(gcloud compute networks describe default 2>>/dev/null 1>>/dev/null); then
  echo -e "${GREEN}VPC network named 'default' already exists. Not recreating${NC}"
else
  SUBNET="default"
  gcloud compute networks create $SUBNET --project=$PROJECT_ID --subnet-mode=auto --bgp-routing-mode="regional"
  gcloud compute networks subnets update $SUBNET --region=$REGION --enable-private-ip-google-access
  gcloud compute firewall-rules create "default-allow-all-internal" \
    --network="default" \
    --project=$PROJECT_ID \
    --direction=INGRESS \
    --priority=65534 \
    --source-ranges="10.128.0.0/9" \
    --allow=tcp:0-65535,udp:0-65535,icmp
fi

# Create a Google Cloud Storage bucket
BUCKET_NAME="${PROJECT_ID}-bucket"
if ! $(gsutil ls -b gs://${BUCKET_NAME} 2>>/dev/null 1>>/dev/null); then
  gsutil mb -l $REGION gs://${BUCKET_NAME}
fi

# Copy files to GCS
gsutil cp -R data-ingestion/csv/* gs://$BUCKET_NAME/data-ingestion/csv/
gsutil cp -R data-ingestion/jar/* gs://$BUCKET_NAME/data-ingestion/jar/
gsutil cp -R data-ingestion/src/* gs://$BUCKET_NAME/data-ingestion/src/
gsutil cp -R data-ingestion/parquet/* gs://$BUCKET_NAME/data-ingestion/parquet/
gsutil cp -R data-prediction/* gs://$BUCKET_NAME/data-prediction/
gsutil cp metadata-mapping/pca gs://$BUCKET_NAME/metadata-mapping/pca

# Direct upload the JAR file to GCS
gsutil cp gs://spark-lib/bigquery/spark-3.3-bigquery-0.37.0.jar gs://$BUCKET_NAME/jar/

echo "Environment setup complete!"