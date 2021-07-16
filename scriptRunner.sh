#! /usr/bin/env bash

# similar to terraform-aws-cms-ars-saf-ecr repository, removing -e flag to account for nonzero error codes
# Error codes for reference: https://docs.chef.io/inspec/cli/#exec
set -xo pipefail

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


if [[ -n $PRODUCTARN ]]; then
  echo "PRODUCTARN value found: $PRODUCTARN. Uploading findings into security hub"
  # "${OVERLAY_PATH}/main" \
  #   -dry=0 \
  #   -accountid="$AWSACCOUNTID" \
  #   -product-arn="$PRODUCTARN" \
  #   -rds-arn="$RDSARN" \
  #   < "${JSON_OUTFILE}"

  # Let's test if we can get even a test finding in security hub
  aws securityhub batch-import-findings --findings '
    [{
        "AwsAccountId": "123456789012",
        "CreatedAt": "2019-08-07T17:05:54.832Z",
        "Description": "Vulnerability in a CloudTrail trail - TESTING ONLY",
        "FindingProviderFields": {
            "Severity": {
                "Original": "0"
            },
            "Types": [
                "Software and Configuration Checks/Vulnerabilities/CVE"
            ]
        },
        "GeneratorId": "TestGeneratorId",
        "Id": "Id1",
        "ProductArn": "arn:aws:securityhub:us-east-1:123456789012:product/123456789012/default",
        "Resources": [
            {
                "Id": "arn:aws:cloudtrail:us-east-1:123456789012:trail/TrailName",
                "Partition": "aws",
                "Region": "us-east-1",
                "Type": "AwsCloudTrailTrail"
            }
        ],
        "SchemaVersion": "2018-10-08",
        "Title": "CloudTrail trail vulnerability - TESTING ONLY",
        "UpdatedAt": "2020-06-02T16:05:54.832Z"
    }]'
fi

echo "cinc-auditor scan completed successfully"
