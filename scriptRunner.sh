#! /usr/bin/env bash

set -o pipefail

inspec exec /home/default/profiles/cms-ars-3.1-moderate-aws-rds-oracle-mysql-ee-5.7-cis-overlay --target aws:// --chef-license accept-silent --no-color
