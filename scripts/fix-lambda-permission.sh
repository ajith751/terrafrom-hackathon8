#!/bin/bash
# Manually add Lambda permission for API Gateway (run if Terraform doesn't apply it)
# Usage: export AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx
#        ./scripts/fix-lambda-permission.sh

set -e
REGION=${AWS_REGION:-us-east-1}

# Get API ID from Terraform or use default
API_ID=$(terraform output -raw api_id 2>/dev/null || echo "")
if [ -z "$API_ID" ]; then
  API_ID=$(aws apigatewayv2 get-apis --region $REGION --query "Items[?Name=='healthcare-microservices-api-dev'].ApiId" --output text)
fi

if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
  echo "ERROR: Could not find API. Run terraform apply first."
  exit 1
fi

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
EXECUTION_ARN="arn:aws:execute-api:${REGION}:${ACCOUNT}:${API_ID}/*/*"

echo "API ID: $API_ID"
echo "Execution ARN: $EXECUTION_ARN"
echo ""

for FUNC in healthcare-microservices-patient-dev healthcare-microservices-appointment-dev; do
  echo "Adding permission to $FUNC..."
  aws lambda add-permission \
    --function-name $FUNC \
    --statement-id "AllowAPIGatewayInvoke" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "$EXECUTION_ARN" \
    --region $REGION 2>/dev/null && echo "  OK" || echo "  (skipped - may exist)"
done

echo ""
echo "Done. Test with: curl https://${API_ID}.execute-api.${REGION}.amazonaws.com/health"
