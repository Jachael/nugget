#!/bin/bash

# CloudFront + HTTPS Configuration (Optional but Recommended)
# This provides HTTPS support and better performance

DOMAIN="nuggetdotcom.com"
BUCKET_NAME="nuggetdotcom.com"
REGION="us-east-1"

echo "=========================================="
echo "CloudFront + HTTPS Setup"
echo "=========================================="
echo ""
echo "This script will help you set up CloudFront for HTTPS support."
echo ""
echo "Prerequisites:"
echo "1. Request an ACM (AWS Certificate Manager) certificate in us-east-1"
echo "2. Validate the certificate via DNS or email"
echo ""
echo "To request a certificate, run:"
echo "aws acm request-certificate \\"
echo "    --domain-name ${DOMAIN} \\"
echo "    --subject-alternative-names www.${DOMAIN} \\"
echo "    --validation-method DNS \\"
echo "    --region us-east-1"
echo ""
echo "After getting the certificate ARN, you can create a CloudFront distribution."
echo ""

read -p "Enter your ACM Certificate ARN (or press Enter to skip): " CERT_ARN

if [ -z "$CERT_ARN" ]; then
    echo "Skipping CloudFront setup. Your site will use HTTP only."
    exit 0
fi

echo ""
echo "Creating CloudFront distribution..."

# Create CloudFront distribution configuration
cat > /tmp/cloudfront-config.json <<EOF
{
    "CallerReference": "nugget-landing-$(date +%s)",
    "Comment": "Nugget Landing Page CDN",
    "Enabled": true,
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-${BUCKET_NAME}",
                "DomainName": "${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com",
                "CustomOriginConfig": {
                    "HTTPPort": 80,
                    "HTTPSPort": 443,
                    "OriginProtocolPolicy": "http-only"
                }
            }
        ]
    },
    "DefaultRootObject": "index.html",
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-${BUCKET_NAME}",
        "ViewerProtocolPolicy": "redirect-to-https",
        "AllowedMethods": {
            "Quantity": 2,
            "Items": ["GET", "HEAD"],
            "CachedMethods": {
                "Quantity": 2,
                "Items": ["GET", "HEAD"]
            }
        },
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            }
        },
        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000,
        "Compress": true
    },
    "Aliases": {
        "Quantity": 2,
        "Items": ["${DOMAIN}", "www.${DOMAIN}"]
    },
    "ViewerCertificate": {
        "ACMCertificateArn": "${CERT_ARN}",
        "SSLSupportMethod": "sni-only",
        "MinimumProtocolVersion": "TLSv1.2_2021"
    },
    "PriceClass": "PriceClass_100"
}
EOF

aws cloudfront create-distribution \
    --distribution-config file:///tmp/cloudfront-config.json

echo ""
echo "CloudFront distribution created!"
echo ""
echo "Next steps:"
echo "1. Wait for CloudFront distribution to deploy (15-20 minutes)"
echo "2. Get the CloudFront domain name from the AWS Console"
echo "3. Update Route53 to point to CloudFront instead of S3"
echo ""
