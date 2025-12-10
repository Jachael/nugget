# Nugget Landing Page

A beautiful, minimal landing page for the Nugget iOS app featuring a purple/glass aesthetic with dark mode support.

## Features

- Clean, modern design with purple gradient branding
- Glassmorphism effects with backdrop blur
- Fully responsive (mobile, tablet, desktop)
- Dark mode support (respects system preferences)
- Animated elements and smooth transitions
- App Store download button
- SEO-friendly HTML structure

## Deployment Instructions

### Prerequisites

- AWS CLI installed and configured with appropriate credentials
- Domain `nuggetdotcom.com` already registered in Route53
- Bash shell environment

### Quick Start

1. **Make scripts executable:**
   ```bash
   chmod +x deploy.sh route53-setup.sh cloudfront-setup.sh
   ```

2. **Deploy to S3:**
   ```bash
   cd /Users/jason/nugget/ios/NuggetApp/landing-page
   ./deploy.sh
   ```

3. **Configure DNS:**
   ```bash
   ./route53-setup.sh
   ```

4. **Optional - Set up HTTPS with CloudFront:**
   ```bash
   ./cloudfront-setup.sh
   ```

### Manual Deployment Steps

If you prefer to deploy manually, follow these steps:

#### 1. Create and Configure S3 Bucket

```bash
# Create bucket
aws s3 mb s3://nuggetdotcom.com --region us-east-1

# Enable static website hosting
aws s3 website s3://nuggetdotcom.com \
    --index-document index.html \
    --error-document index.html

# Set bucket policy for public access
aws s3api put-bucket-policy \
    --bucket nuggetdotcom.com \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [{
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::nuggetdotcom.com/*"
        }]
    }'

# Disable block public access
aws s3api put-public-access-block \
    --bucket nuggetdotcom.com \
    --public-access-block-configuration \
    "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
```

#### 2. Upload Files

```bash
# Upload HTML
aws s3 cp index.html s3://nuggetdotcom.com/ \
    --content-type "text/html" \
    --cache-control "max-age=3600"

# Upload CSS
aws s3 cp styles.css s3://nuggetdotcom.com/ \
    --content-type "text/css" \
    --cache-control "max-age=86400"
```

#### 3. Configure Route53

```bash
# Get hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --query "HostedZones[?Name=='nuggetdotcom.com.'].Id" \
    --output text | cut -d'/' -f3)

# Create A record for apex domain
aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch '{
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "nuggetdotcom.com",
                "Type": "A",
                "AliasTarget": {
                    "HostedZoneId": "Z3AQBSTGFYJSTF",
                    "DNSName": "nuggetdotcom.com.s3-website-us-east-1.amazonaws.com",
                    "EvaluateTargetHealth": false
                }
            }
        }]
    }'

# Create CNAME for www subdomain
aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --change-batch '{
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "www.nuggetdotcom.com",
                "Type": "CNAME",
                "TTL": 300,
                "ResourceRecords": [
                    {"Value": "nuggetdotcom.com.s3-website-us-east-1.amazonaws.com"}
                ]
            }
        }]
    }'
```

## URLs

- **S3 Website Endpoint:** http://nuggetdotcom.com.s3-website-us-east-1.amazonaws.com
- **Custom Domain:** http://nuggetdotcom.com (after DNS propagation)
- **With WWW:** http://www.nuggetdotcom.com

## HTTPS Support (Recommended)

For production use, it's highly recommended to set up CloudFront with an SSL certificate:

1. Request an ACM certificate in `us-east-1` region
2. Validate the certificate via DNS
3. Create a CloudFront distribution pointing to the S3 bucket
4. Update Route53 to point to CloudFront instead of S3 directly

This provides:
- HTTPS/SSL encryption
- Better global performance via CDN
- Custom domain support with SSL
- DDoS protection

## Design Details

### Color Palette
- Primary Purple: `#8b5cf6`
- Light Purple: `#a78bfa`
- Dark Purple: `#7c3aed`

### Typography
- Font: Inter (Google Fonts)
- Weights: 300, 400, 500, 600, 700

### Responsive Breakpoints
- Desktop: > 768px
- Mobile: ≤ 768px
- Small Mobile: ≤ 480px

## File Structure

```
landing-page/
├── index.html              # Main HTML file
├── styles.css              # Stylesheet with animations and responsive design
├── deploy.sh               # S3 deployment script
├── route53-setup.sh        # DNS configuration script
├── cloudfront-setup.sh     # HTTPS/CDN setup script
└── README.md               # This file
```

## Customization

### Update App Store Link
Edit the App Store button href in `index.html`:
```html
<a href="https://apps.apple.com/app/YOUR-APP-ID" ...>
```

### Modify Colors
Update CSS variables in `styles.css`:
```css
:root {
    --purple-500: #8b5cf6;  /* Primary color */
    --purple-400: #a78bfa;  /* Light variant */
    --purple-600: #7c3aed;  /* Dark variant */
}
```

### Change Content
Edit the text content in `index.html`:
- Title and tagline in the hero section
- Feature descriptions in the features section
- Footer text

## Browser Support

- Chrome/Edge (latest)
- Firefox (latest)
- Safari 14+
- iOS Safari 14+
- Android Chrome

## Performance

- Optimized for fast loading
- CSS animations use GPU acceleration
- Minimal external dependencies (only Google Fonts)
- Compressed assets
- CDN-ready

## License

Copyright © 2025 Nugget. All rights reserved.
