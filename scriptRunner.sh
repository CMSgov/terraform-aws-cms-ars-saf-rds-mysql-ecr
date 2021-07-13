#! /usr/bin/env bash

# similar to terraform-aws-cms-ars-saf-ecr repository, removing -e flag to account for nonzero error codes
# Error codes for reference: https://docs.chef.io/inspec/cli/#exec
set -o pipefail
OVERLAY_PATH="/home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay"
INPUT_FILE="${OVERLAY_PATH}/inputs.yml"
JSON_OUTFILE="${OVERLAY_PATH}/audit-results.json"

echo "starting cinc-auditor scan"

echo "hydrate config file"

erb "${OVERLAY_PATH}/inputs.yml.erb" > "${INPUT_FILE}"

# log to cloudwatch

cinc-auditor exec "${OVERLAY_PATH}" \
  --input-file="${INPUT_FILE}" \
  --chef-license=accept-silent \
  --no-color \
  --reporter=cli json:"${JSON_OUTFILE}"

# shellcheck disable=SC2154
if [[ -n $s3_bucket_path ]]; then
    echo "s3_bucket_path values found: $s3_bucket_path"
    filename="$(date '+%Y-%m-%d-%H-%M-%S').json"
    aws s3 cp "${JSON_OUTFILE}" "$s3_bucket_path/$filename"
    echo "s3 scan results upload complete"
else
    echo "s3_bucket_path variable not found, skipping s3 results upload."
fi

echo "uploading findings into security hub"

if [[ -n $PRODUCTARN ]]; then
  echo "PRODUCTARN values found: $PRODUCTARN. Uploading findings into security hub"
  "${OVERLAY_PATH}/main" \
    -dry=0 \
    -accountid="$AWSACCOUNTID" \
    -product-arn="$PRODUCTARN" \
    -rds-arn="$RDSARN" \
    < "${JSON_OUTFILE}"
fi

echo "cinc-auditor scan completed successfully"
