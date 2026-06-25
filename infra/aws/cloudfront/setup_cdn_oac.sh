#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-central-1}"
ACCOUNT_ID="${ACCOUNT_ID:-707605821946}"
PROCESSED_BUCKET="${PROCESSED_BUCKET:-vitrin-optimized-photos-707605821946-eu-central-1-an}"
ORIGIN_DOMAIN="${ORIGIN_DOMAIN:-${PROCESSED_BUCKET}.s3.${AWS_REGION}.amazonaws.com}"
OAC_NAME="${OAC_NAME:-vitrin-processed-oac}"
DIST_COMMENT="${DIST_COMMENT:-Vitrin processed images CDN}"
PRICE_CLASS="${PRICE_CLASS:-PriceClass_100}"

echo "[1/5] Create OAC"
OAC_ID="$(aws cloudfront list-origin-access-controls \
  --query "OriginAccessControlList.Items[?Name=='${OAC_NAME}'].Id | [0]" \
  --output text)"

if [[ -z "$OAC_ID" || "$OAC_ID" == "None" ]]; then
  OAC_CFG_FILE="$(mktemp)"
  cat > "$OAC_CFG_FILE" <<JSON
{
  "Name": "${OAC_NAME}",
  "Description": "Vitrin processed bucket OAC",
  "SigningProtocol": "sigv4",
  "SigningBehavior": "always",
  "OriginAccessControlOriginType": "s3"
}
JSON

  OAC_ID="$(aws cloudfront create-origin-access-control \
    --origin-access-control-config "file://${OAC_CFG_FILE}" \
    --query 'OriginAccessControl.Id' \
    --output text)"
  rm -f "$OAC_CFG_FILE"
fi

echo "[2/5] Create CloudFront distribution"
EXISTING_DIST_ID="$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Comment=='${DIST_COMMENT}'].Id | [0]" \
  --output text)"

if [[ -n "$EXISTING_DIST_ID" && "$EXISTING_DIST_ID" != "None" ]]; then
  DIST_ID="$EXISTING_DIST_ID"
  DIST_DOMAIN="$(aws cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DomainName' --output text)"
  DIST_ARN="arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${DIST_ID}"
else
CFG_FILE="$(mktemp)"
cat > "$CFG_FILE" <<JSON
{
  "CallerReference": "vitrin-processed-$(date +%s)",
  "Comment": "${DIST_COMMENT}",
  "Enabled": true,
  "PriceClass": "${PRICE_CLASS}",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "s3-vitrin-processed-origin",
        "DomainName": "${ORIGIN_DOMAIN}",
        "OriginAccessControlId": "${OAC_ID}",
        "S3OriginConfig": { "OriginAccessIdentity": "" }
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "s3-vitrin-processed-origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"],
      "CachedMethods": { "Quantity": 2, "Items": ["GET", "HEAD"] }
    },
    "Compress": true,
    "CachePolicyId": "658327ea-f89d-4fab-a63d-7e88639e58f6"
  },
  "ViewerCertificate": { "CloudFrontDefaultCertificate": true },
  "Restrictions": { "GeoRestriction": { "RestrictionType": "none", "Quantity": 0 } },
  "HttpVersion": "http2",
  "IsIPV6Enabled": true
}
JSON

DIST_ID="$(aws cloudfront create-distribution --distribution-config "file://${CFG_FILE}" --query 'Distribution.Id' --output text)"
DIST_DOMAIN="$(aws cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.DomainName' --output text)"
DIST_ARN="arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${DIST_ID}"
rm -f "$CFG_FILE"
fi

echo "[3/5] Apply processed bucket policy for CloudFront"
POLICY_FILE="$(mktemp)"
cat > "$POLICY_FILE" <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipalReadOnly",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${PROCESSED_BUCKET}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "${DIST_ARN}"
        }
      }
    }
  ]
}
JSON

aws s3api put-bucket-policy --bucket "$PROCESSED_BUCKET" --policy "file://${POLICY_FILE}"
rm -f "$POLICY_FILE"

echo "[4/5] Enforce public access block on processed bucket"
aws s3api put-public-access-block \
  --bucket "$PROCESSED_BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "[5/5] Summary"
echo "DIST_ID=${DIST_ID}"
echo "DIST_DOMAIN=${DIST_DOMAIN}"
echo "DIST_ARN=${DIST_ARN}"
echo "OAC_ID=${OAC_ID}"
