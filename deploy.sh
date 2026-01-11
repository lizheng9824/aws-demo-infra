#!/usr/bin/env bash
set -euo pipefail

# Usage: ENV=dev S3_BUCKET=my-bucket ./environments/deploy.sh
ENV=${ENV:-dev}
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
PARAM_YAML="$ROOT_DIR/environments/${ENV}/params.yaml"

# helper to get parameter value from YAML using yq (yq must be installed)
get_param() {
  key=$1
  if ! command -v yq >/dev/null 2>&1; then
    echo "yq is required to read YAML parameters; please install yq" >&2
    return 1
  fi
  if [ ! -f "$PARAM_YAML" ]; then
    echo "Parameter file not found: $PARAM_YAML" >&2
    return 1
  fi
  yq eval -r ".${key}" "$PARAM_YAML"
}

if [ -z "${S3_BUCKET:-}" ]; then
  echo "S3_BUCKET environment variable must be set for packaging templates"
  exit 1
fi

if [ -f "$PARAM_YAML" ]; then
  PARAM_FILE_DESC="$PARAM_YAML"
else
  echo "Parameter file not found: $PARAM_YAML"
  exit 1
fi

get_param VpcCidr >/dev/null 2>&1 || { echo "yq required and params must contain VpcCidr"; exit 1; }

echo "Packaging and deploying network stack..."
aws cloudformation package --template-file common/network.yaml --s3-bucket $S3_BUCKET --output-template-file /tmp/pack-network.yaml
VPC_STACK_NAME="${ENV}-network"
aws cloudformation deploy --template-file /tmp/pack-network.yaml --stack-name $VPC_STACK_NAME --parameter-overrides \
  VpcCidr=$(get_param VpcCidr) \
  PublicSubnet1Cidr=$(get_param PublicSubnet1Cidr) \
  PublicSubnet2Cidr=$(get_param PublicSubnet2Cidr) \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM

echo "Fetching network outputs..."
VPC_ID=$(aws cloudformation describe-stacks --stack-name $VPC_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='VpcId'].OutputValue" --output text)
SUBNET1_ID=$(aws cloudformation describe-stacks --stack-name $VPC_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PublicSubnet1Id'].OutputValue" --output text)
SUBNET2_ID=$(aws cloudformation describe-stacks --stack-name $VPC_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='PublicSubnet2Id'].OutputValue" --output text)

echo "Packaging and deploying ALB stack..."
aws cloudformation package --template-file common/alb.yaml --s3-bucket $S3_BUCKET --output-template-file /tmp/pack-alb.yaml
ALB_STACK_NAME="${ENV}-alb"
aws cloudformation deploy --template-file /tmp/pack-alb.yaml --stack-name $ALB_STACK_NAME --parameter-overrides \
  VpcId=$VPC_ID \
  PublicSubnet1Id=$SUBNET1_ID \
  PublicSubnet2Id=$SUBNET2_ID \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM

echo "Fetching ALB outputs..."
ALB_SG_ID=$(aws cloudformation describe-stacks --stack-name $ALB_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='AlbSecurityGroupId'].OutputValue" --output text)
TARGET_GROUP_ARN=$(aws cloudformation describe-stacks --stack-name $ALB_STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='TargetGroupArn'].OutputValue" --output text)

echo "Packaging and deploying ECS stack..."
aws cloudformation package --template-file common/ecs.yaml --s3-bucket $S3_BUCKET --output-template-file /tmp/pack-ecs.yaml
ECS_STACK_NAME="${ENV}-ecs"
aws cloudformation deploy --template-file /tmp/pack-ecs.yaml --stack-name $ECS_STACK_NAME --parameter-overrides \
  SubnetIds="$SUBNET1_ID,$SUBNET2_ID" \
  AlbSecurityGroupId=$ALB_SG_ID \
  TargetGroupArn=$TARGET_GROUP_ARN \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM

echo "Packaging and deploying DynamoDB stack..."
aws cloudformation package --template-file common/dynamodb.yaml --s3-bucket $S3_BUCKET --output-template-file /tmp/pack-ddb.yaml
DB_STACK_NAME="${ENV}-dynamodb"
aws cloudformation deploy --template-file /tmp/pack-ddb.yaml --stack-name $DB_STACK_NAME --parameter-overrides \
  DynamoTableName=$(get_param DynamoTableName) \
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_IAM

echo "Deployment complete."
