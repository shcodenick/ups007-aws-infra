1. .env file:
TF_VAR_AWS_REGION=us-east-2
TF_VAR_STATE_BUCKET=s3bucketname
TF_VAR_STATE_KEY=tfstate
TF_VAR_STATE_TABLE=dynamodbtablename
etc.

2. load vars
set -a; . .env; set +a

3. terraform init -backend-config="bucket=${TF_VAR_STATE_BUCKET}" -backend-config="key=${TF_VAR_STATE_KEY}" -backend-config="region=${TF_VAR_AWS_REGION}" -backend-config="dynamodb_table=${TF_VAR_STATE_TABLE}"