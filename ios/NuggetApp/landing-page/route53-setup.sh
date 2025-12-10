#!/bin/bash

# Route53 Configuration Script for Nugget Landing Page
# This script creates DNS records to point your domain to the S3 bucket

set -e

DOMAIN="nuggetdotcom.com"
BUCKET_NAME="nuggetdotcom.com"
REGION="us-east-1"
WEBSITE_ENDPOINT="${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"

echo "=========================================="
echo "Route53 Configuration for ${DOMAIN}"
echo "=========================================="
echo ""

# Get the hosted zone ID for the domain
echo "Finding hosted zone for ${DOMAIN}..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --query "HostedZones[?Name=='${DOMAIN}.'].Id" \
    --output text | cut -d'/' -f3)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Error: Could not find hosted zone for ${DOMAIN}"
    echo "Please ensure the domain is registered in Route53"
    exit 1
fi

echo "Found hosted zone: ${HOSTED_ZONE_ID}"
echo ""

# Create change batch for apex domain (nuggetdotcom.com)
echo "Creating DNS record for apex domain (${DOMAIN})..."
cat > /tmp/route53-change-apex.json <<EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "${DOMAIN}",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z3AQBSTGFYJSTF",
                    "DNSName": "${WEBSITE_ENDPOINT}",
                    "EvaluateTargetHealth": false
                }
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch file:///tmp/route53-change-apex.json

echo "DNS record created for ${DOMAIN}"
echo ""

# Create change batch for www subdomain
echo "Creating DNS record for www.${DOMAIN}..."
cat > /tmp/route53-change-www.json <<EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "www.${DOMAIN}",
                "Type": "CNAME",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "${WEBSITE_ENDPOINT}"
                    }
                ]
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets \
    --hosted-zone-id ${HOSTED_ZONE_ID} \
    --change-batch file:///tmp/route53-change-www.json

echo "DNS record created for www.${DOMAIN}"
echo ""

echo "=========================================="
echo "Route53 Configuration Complete!"
echo "=========================================="
echo ""
echo "Your domain is now configured:"
echo "  - ${DOMAIN} -> ${WEBSITE_ENDPOINT}"
echo "  - www.${DOMAIN} -> ${WEBSITE_ENDPOINT}"
echo ""
echo "Note: DNS propagation may take 5-60 minutes"
echo "Test your site at: http://${DOMAIN}"
echo ""
echo "IMPORTANT: For HTTPS support, consider using CloudFront"
echo "Run cloudfront-setup.sh for HTTPS configuration"
echo ""
