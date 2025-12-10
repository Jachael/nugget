#!/bin/bash

# Nugget Landing Page Deployment Script
# This script sets up S3 bucket and deploys the landing page

set -e  # Exit on error

BUCKET_NAME="nuggetdotcom.com"
REGION="us-east-1"
DOMAIN="nuggetdotcom.com"

echo "=========================================="
echo "Nugget Landing Page Deployment"
echo "=========================================="
echo ""

# Step 1: Create S3 bucket
echo "Step 1: Creating S3 bucket..."
aws s3 mb s3://${BUCKET_NAME} --region ${REGION} 2>/dev/null || echo "Bucket already exists"

# Step 2: Enable static website hosting
echo "Step 2: Enabling static website hosting..."
aws s3 website s3://${BUCKET_NAME} \
    --index-document index.html \
    --error-document index.html

# Step 3: Set bucket policy for public read access
echo "Step 3: Setting bucket policy for public access..."
cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy \
    --bucket ${BUCKET_NAME} \
    --policy file:///tmp/bucket-policy.json

# Step 4: Disable Block Public Access settings
echo "Step 4: Configuring public access settings..."
aws s3api put-public-access-block \
    --bucket ${BUCKET_NAME} \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

# Step 5: Upload files
echo "Step 5: Uploading website files..."
aws s3 sync . s3://${BUCKET_NAME} \
    --exclude "deploy.sh" \
    --exclude "README.md" \
    --exclude ".DS_Store" \
    --cache-control "max-age=3600" \
    --content-type "text/html" \
    --exclude "*" \
    --include "*.html"

aws s3 sync . s3://${BUCKET_NAME} \
    --exclude "deploy.sh" \
    --exclude "README.md" \
    --exclude ".DS_Store" \
    --cache-control "max-age=86400" \
    --content-type "text/css" \
    --exclude "*" \
    --include "*.css"

# Get the website endpoint
WEBSITE_ENDPOINT="${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "S3 Website URL: http://${WEBSITE_ENDPOINT}"
echo ""
echo "Next steps:"
echo "1. Configure Route53 to point ${DOMAIN} to the S3 bucket"
echo "2. Run the Route53 configuration commands (see route53-setup.sh)"
echo ""
