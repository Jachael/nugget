#!/bin/bash

# Quick deployment script - runs all steps in sequence
# Usage: ./quick-deploy.sh [--with-cloudfront]

set -e

echo "=========================================="
echo "Nugget Landing Page - Quick Deploy"
echo "=========================================="
echo ""

# Make all scripts executable
chmod +x deploy.sh route53-setup.sh cloudfront-setup.sh

# Step 1: Deploy to S3
echo "Starting S3 deployment..."
./deploy.sh

# Step 2: Configure Route53
echo ""
echo "Configuring Route53 DNS..."
./route53-setup.sh

# Step 3: Optional CloudFront
if [ "$1" == "--with-cloudfront" ]; then
    echo ""
    echo "Setting up CloudFront + HTTPS..."
    ./cloudfront-setup.sh
fi

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Your landing page is live at:"
echo "  http://nuggetdotcom.com"
echo "  http://www.nuggetdotcom.com"
echo ""
echo "Wait 5-10 minutes for DNS to propagate worldwide."
echo ""

if [ "$1" != "--with-cloudfront" ]; then
    echo "For HTTPS support, run: ./cloudfront-setup.sh"
    echo ""
fi
