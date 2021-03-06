#! /usr/bin/env bash

# similar to terraform-aws-cms-ars-saf-ecr repository, removing -e flag to account for nonzero error codes
# Error codes for reference: https://docs.chef.io/inspec/cli/#exec
set -o pipefail

# Set up some variables to make our life easier
OVERLAY_PATH="/home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay"
INPUT_FILE="${OVERLAY_PATH}/inputs.yml"
JSON_OUTFILE="${OVERLAY_PATH}/audit-results.json"

echo "starting cinc-auditor scan"

echo "hydrate config file"
erb "${OVERLAY_PATH}/inputs.yml.erb" > "${INPUT_FILE}"

# cli reporter goes to cloudwatch and JSON goes into a file for other things
cinc-auditor exec "${OVERLAY_PATH}" \
  --input-file="${INPUT_FILE}" \
  --chef-license=accept-silent \
  --no-color \
  --reporter=cli json:"${JSON_OUTFILE}"

# shellcheck disable=SC2154
if [[ -n $s3_bucket_path ]]; then
    echo "s3_bucket_path value found: $s3_bucket_path. Uploading findinds into S3"
    filename="$(date '+%Y-%m-%d-%H-%M-%S').json"
    aws s3 cp "${JSON_OUTFILE}" "$s3_bucket_path/$filename"
    echo "s3 scan results upload complete"
else
    echo "s3_bucket_path variable not found, skipping s3 results upload."
fi


if [[ -n $ENABLE_SECURITYHUB ]]; then
  echo "ENABLE_SECURITYHUB value found: $ENABLE_SECURITYHUB. Uploading findings into security hub"
  "${OVERLAY_PATH}/main" \
    -dry=0 \
    -generatorid="ecs/inspec/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay" \
    -accountid="$ACCOUNTID" \
    -region="$REGION" \
    -resource-arn="$RDSARN" \
    -resource-type="AwsRdsDbInstance" \
    < "${JSON_OUTFILE}"
fi

echo "cinc-auditor scan completed successfully"
