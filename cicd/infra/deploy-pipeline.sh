#!/usr/bin/env bash
set -euo pipefail

STACK_NAME=${1:-aws-demo-pipeline}
CONNECTION_ARN=${2:-}
FULL_REPO_ID=${3:-lizheng9824/aws-demo-infra}

if [ -z "$CONNECTION_ARN" ]; then
  echo "Usage: $0 <stack-name> <codestar-connection-arn> [full-repo-id]"
  echo "Example: $0 aws-demo-pipeline arn:aws:codeconnections:ap-northeast-1:488111252725:connection/19b52adb-397c-412c-826d-7bfa28670ec8 lizheng9824/aws-demo-infra"
  exit 1
fi

echo "Deploying CodePipeline CloudFormation stack: $STACK_NAME (Repo: $FULL_REPO_ID)"

aws cloudformation deploy \
  --template-file pipeline.yaml \
  --stack-name "$STACK_NAME" \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM \
  --parameter-overrides ConnectionArn="$CONNECTION_ARN" FullRepositoryId="$FULL_REPO_ID"

echo "Deployment complete. After the stack is created, push this repo to GitHub (or ensure the repo exists and is accessible via the provided CodeStar Connection)."

