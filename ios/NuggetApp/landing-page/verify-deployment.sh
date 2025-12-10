#!/bin/bash

# Deployment Verification Script
# Checks if everything is set up correctly

DOMAIN="nuggetdotcom.com"
BUCKET_NAME="nuggetdotcom.com"

echo "=========================================="
echo "Nugget Landing Page - Deployment Check"
echo "=========================================="
echo ""

# Check 1: S3 Bucket exists
echo "✓ Checking S3 bucket..."
if aws s3 ls s3://${BUCKET_NAME} &>/dev/null; then
    echo "  ✓ Bucket exists"

    # Check files
    if aws s3 ls s3://${BUCKET_NAME}/index.html &>/dev/null; then
        echo "  ✓ index.html uploaded"
    else
        echo "  ✗ index.html not found"
    fi

    if aws s3 ls s3://${BUCKET_NAME}/styles.css &>/dev/null; then
        echo "  ✓ styles.css uploaded"
    else
        echo "  ✗ styles.css not found"
    fi
else
    echo "  ✗ Bucket does not exist"
fi

echo ""

# Check 2: S3 Website Configuration
echo "✓ Checking S3 website configuration..."
if aws s3api get-bucket-website --bucket ${BUCKET_NAME} &>/dev/null; then
    echo "  ✓ Static website hosting enabled"
else
    echo "  ✗ Static website hosting not configured"
fi

echo ""

# Check 3: Bucket Policy
echo "✓ Checking bucket policy..."
if aws s3api get-bucket-policy --bucket ${BUCKET_NAME} &>/dev/null; then
    echo "  ✓ Public access policy configured"
else
    echo "  ✗ Bucket policy not set"
fi

echo ""

# Check 4: Route53 Configuration
echo "✓ Checking Route53 DNS records..."
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --query "HostedZones[?Name=='${DOMAIN}.'].Id" \
    --output text 2>/dev/null | cut -d'/' -f3)

if [ -n "$HOSTED_ZONE_ID" ]; then
    echo "  ✓ Hosted zone found: ${HOSTED_ZONE_ID}"

    # Check A record
    A_RECORD=$(aws route53 list-resource-record-sets \
        --hosted-zone-id ${HOSTED_ZONE_ID} \
        --query "ResourceRecordSets[?Name=='${DOMAIN}.'].Type" \
        --output text 2>/dev/null)

    if [ "$A_RECORD" == "A" ]; then
        echo "  ✓ A record configured for ${DOMAIN}"
    else
        echo "  ✗ A record not found for ${DOMAIN}"
    fi

    # Check CNAME record
    CNAME_RECORD=$(aws route53 list-resource-record-sets \
        --hosted-zone-id ${HOSTED_ZONE_ID} \
        --query "ResourceRecordSets[?Name=='www.${DOMAIN}.'].Type" \
        --output text 2>/dev/null)

    if [ "$CNAME_RECORD" == "CNAME" ]; then
        echo "  ✓ CNAME record configured for www.${DOMAIN}"
    else
        echo "  ✗ CNAME record not found for www.${DOMAIN}"
    fi
else
    echo "  ✗ Hosted zone not found for ${DOMAIN}"
fi

echo ""
echo "=========================================="
echo "Status Summary"
echo "=========================================="
echo ""
echo "S3 Website URL:"
echo "  http://${BUCKET_NAME}.s3-website-us-east-1.amazonaws.com"
echo ""
echo "Custom Domain URLs:"
echo "  http://${DOMAIN}"
echo "  http://www.${DOMAIN}"
echo ""
echo "Note: DNS changes may take 5-60 minutes to propagate"
echo ""

# Try to fetch the page
echo "Testing HTTP access..."
if curl -s -o /dev/null -w "%{http_code}" "http://${BUCKET_NAME}.s3-website-us-east-1.amazonaws.com" | grep -q "200"; then
    echo "  ✓ Website is accessible via S3 endpoint"
else
    echo "  ✗ Website not accessible yet"
fi

echo ""
