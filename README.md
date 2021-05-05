# terraform-aws-cms-ars-saf-rds-mysql-ecr

This repo contains a Dockerfile for building a container that can run an
Inspec scan against an RDS instance, as well as a Terraform module that
will create an ECR repo to hold the container and the Github Actions that
will publish a new version of the container when the repo is updated.

## Workflow Steps

This repo is already configured to publish new docker images to ECR. In order to replicate this repo in your environment please fork it and follow these steps.

1. Initialize the terraform module in your terraform code, so that you have an ECR repo.
1. File a ticket to create an Iam user, see manual operation [doc](/docs/0001-IAM-user.md) for more.
    1. The AWS IAM account will be used to push new images in ECR repo
    1. Generate a new AWS access key and secret in AWS console or from CLI for the IAM account generated in step 1
    1. Add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` to github repo secrets
1. Configure static variables as outlined in this [doc](/docs/0002-githubactions-static-variables.md)