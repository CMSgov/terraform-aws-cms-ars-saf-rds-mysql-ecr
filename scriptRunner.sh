#! /usr/bin/env bash

# similar to terraform-aws-cms-ars-saf-ecr repository, removing -e flag to account for nonzero error codes
# Error codes for reference: https://docs.chef.io/inspec/cli/#exec
set -o pipefail

echo "starting cinc-auditor scan"

echo "hydrate config file"

erb /home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/inputs.yml.erb > /home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/inputs.yml

# log to cloudwatch
cinc-auditor exec /home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay --input-file=/home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/inputs.yml --chef-license accept-silent --no-color

# shellcheck disable=SC2154
if [[ -n $s3_bucket_path ]]; then
    echo "s3_bucket_path values found: $s3_bucket_path"
    filename="$(date '+%Y-%m-%d-%H-%M-%S').json"
    cinc-auditor exec /home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay --input-file=/home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/inputs.yml --reporter json --chef-license accept-silent | tee | aws s3 cp - "$s3_bucket_path/$filename" | /home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay/main -dry=0 -accountid=$AWSACCOUNTID -product-arn=$PRODUCTARN -rds-arn=$RDSARN
    echo "s3 scan results upload complete"
else
    echo "s3_bucket_path variable not found, skipping s3 results upload."
fi

echo "cinc-auditor scan completed successfully"