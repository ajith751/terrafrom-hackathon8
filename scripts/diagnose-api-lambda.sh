#!/bin/bash
# Diagnose API Gateway + Lambda integration
# Run: export AWS_ACCESS_KEY_ID=xxx AWS_SECRET_ACCESS_KEY=xxx AWS_REGION=us-east-1
#      ./scripts/diagnose-api-lambda.sh

set -e
REGION=${AWS_REGION:-us-east-1}
API_NAME="healthcare-microservices-api-dev"
PATIENT_LAMBDA="healthcare-microservices-patient-dev"
APPOINTMENT_LAMBDA="healthcare-microservices-appointment-dev"

echo "=== 1. Get API ID ==="
API_ID=$(aws apigatewayv2 get-apis --region $REGION --query "Items[?Name=='$API_NAME'].ApiId" --output text)
if [ -z "$API_ID" ] || [ "$API_ID" == "None" ]; then
  echo "ERROR: API '$API_NAME' not found"
  exit 1
fi
echo "API ID: $API_ID"

echo ""
echo "=== 2. List Integrations ==="
aws apigatewayv2 get-integrations --api-id $API_ID --region $REGION --output table

echo ""
echo "=== 3. List Routes (with Integration target) ==="
aws apigatewayv2 get-routes --api-id $API_ID --region $REGION --query 'Items[].[RouteKey,Target]' --output table

echo ""
echo "=== 4. Lambda Resource Policy (Patient) ==="
aws lambda get-policy --function-name $PATIENT_LAMBDA --region $REGION 2>/dev/null | jq -r '.Policy' | jq . || echo "No policy or Lambda not found"

echo ""
echo "=== 5. Lambda Resource Policy (Appointment) ==="
aws lambda get-policy --function-name $APPOINTMENT_LAMBDA --region $REGION 2>/dev/null | jq -r '.Policy' | jq . || echo "No policy or Lambda not found"

echo ""
echo "=== 6. Add Lambda Permission (if missing) ==="
EXECUTION_ARN="arn:aws:execute-api:${REGION}:$(aws sts get-caller-identity --query Account --output text):${API_ID}/*/*"

for FUNC in $PATIENT_LAMBDA $APPOINTMENT_LAMBDA; do
  if ! aws lambda get-policy --function-name $FUNC --region $REGION 2>/dev/null | grep -q "apigateway.amazonaws.com"; then
    echo "Adding permission to $FUNC..."
    aws lambda add-permission \
      --function-name $FUNC \
      --statement-id "AllowAPIGatewayInvoke-$(date +%s)" \
      --action lambda:InvokeFunction \
      --principal apigateway.amazonaws.com \
      --source-arn "$EXECUTION_ARN" \
      --region $REGION 2>/dev/null || echo "  (may already exist)"
  else
    echo "$FUNC: Permission exists"
  fi
done

echo ""
echo "=== 7. Test API ==="
INVOKE_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com"
echo "Testing: $INVOKE_URL/health"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" "$INVOKE_URL/health" || true

echo ""
echo "=== Done ==="
