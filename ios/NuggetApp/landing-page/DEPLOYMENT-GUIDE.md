# Nugget Landing Page - Deployment Guide

## Quick Start (Easiest Method)

```bash
cd /Users/jason/nugget/ios/NuggetApp/landing-page
chmod +x quick-deploy.sh
./quick-deploy.sh
```

This will:
1. Create and configure the S3 bucket
2. Upload your website files
3. Configure Route53 DNS records
4. Make your site live at http://nuggetdotcom.com

## What's Been Created

### 1. Landing Page Files
- **index.html** - Beautiful, minimal landing page with:
  - Purple/glass aesthetic matching your app
  - Responsive design (mobile, tablet, desktop)
  - Dark mode support (automatic based on system)
  - App Store download button
  - 4 key feature highlights
  - Smooth animations and glassmorphism effects

- **styles.css** - Complete styling with:
  - CSS variables for easy customization
  - Backdrop blur effects
  - Gradient animations
  - Responsive breakpoints
  - Dark/light mode support

### 2. Deployment Scripts

| Script | Purpose |
|--------|---------|
| `quick-deploy.sh` | One-command deployment (recommended) |
| `deploy.sh` | S3 bucket setup and file upload |
| `route53-setup.sh` | DNS configuration |
| `cloudfront-setup.sh` | HTTPS/CDN setup (optional) |
| `verify-deployment.sh` | Check deployment status |

## Deployment Steps

### Option 1: Quick Deploy (Recommended)

```bash
cd /Users/jason/nugget/ios/NuggetApp/landing-page
./quick-deploy.sh
```

Wait 5-10 minutes for DNS propagation, then visit:
- http://nuggetdotcom.com
- http://www.nuggetdotcom.com

### Option 2: Step-by-Step Deploy

```bash
cd /Users/jason/nugget/ios/NuggetApp/landing-page

# Step 1: Deploy to S3
./deploy.sh

# Step 2: Configure DNS
./route53-setup.sh

# Step 3: Verify everything works
./verify-deployment.sh
```

### Option 3: Manual Deploy

See the detailed manual steps in README.md

## URLs After Deployment

- **S3 Direct URL:** http://nuggetdotcom.com.s3-website-us-east-1.amazonaws.com
- **Custom Domain:** http://nuggetdotcom.com
- **WWW Subdomain:** http://www.nuggetdotcom.com

## Important Notes

### DNS Propagation
After running the deployment scripts, DNS changes can take 5-60 minutes to propagate worldwide. During this time:
- The S3 direct URL will work immediately
- Your custom domain may not work yet
- Use `verify-deployment.sh` to check status

### HTTPS Support
The basic deployment uses HTTP only. For HTTPS (recommended for production):

1. Request an SSL certificate:
```bash
aws acm request-certificate \
    --domain-name nuggetdotcom.com \
    --subject-alternative-names www.nuggetdotcom.com \
    --validation-method DNS \
    --region us-east-1
```

2. Validate the certificate via DNS (follow AWS Console instructions)

3. Run CloudFront setup:
```bash
./cloudfront-setup.sh
```

### App Store Link
Update the App Store button link in `index.html` once your app is published:

```html
<a href="https://apps.apple.com/app/YOUR-APP-ID" class="app-store-button">
```

Replace `YOUR-APP-ID` with your actual App Store app ID.

## Customization

### Change Colors
Edit CSS variables in `styles.css`:

```css
:root {
    --purple-500: #8b5cf6;  /* Main brand color */
    --purple-400: #a78bfa;  /* Lighter variant */
    --purple-600: #7c3aed;  /* Darker variant */
}
```

### Update Content
Edit `index.html` to change:
- App name and tagline
- Feature descriptions
- Footer text

After changes, redeploy:
```bash
./deploy.sh
```

## Troubleshooting

### Site Not Loading
1. Check DNS propagation: `./verify-deployment.sh`
2. Try the S3 direct URL first
3. Wait 15-30 minutes for DNS to fully propagate
4. Clear browser cache

### Permission Errors
Make sure AWS CLI is configured:
```bash
aws configure
```

Ensure you have permissions for:
- S3 bucket creation and management
- Route53 record management
- ACM certificate requests (for HTTPS)

### Bucket Already Exists
If the bucket name is taken, you'll need to:
1. Choose a different bucket name
2. Update all scripts with the new name
3. Re-run deployment

### Files Not Uploading
Check that you're in the correct directory:
```bash
cd /Users/jason/nugget/ios/NuggetApp/landing-page
```

Make scripts executable:
```bash
chmod +x *.sh
```

## Design Features

### Responsive Design
- Desktop (>768px): Full feature grid layout
- Tablet/Mobile (≤768px): Stacked single-column layout
- Small mobile (≤480px): Optimized typography

### Dark Mode
Automatically respects system preferences:
- Dark background with purple accents (dark mode)
- Light background with purple accents (light mode)
- Smooth transitions between modes

### Performance
- Minimal dependencies (only Google Fonts)
- Optimized animations using GPU acceleration
- Compressed assets with cache headers
- Fast loading times (<1s on 3G)

## Cost Estimate

AWS costs for this setup:
- **S3 Storage:** ~$0.023/month for 1GB
- **S3 Requests:** ~$0.01/month for 10,000 requests
- **Route53 Hosted Zone:** $0.50/month
- **Data Transfer:** First 1GB free, then $0.09/GB

**Total:** ~$0.50-1.00/month for basic traffic

With CloudFront (HTTPS):
- **CloudFront:** $0.085/GB + $0.01 per 10,000 requests
- **SSL Certificate:** Free with ACM
- **Total:** Add ~$1-5/month depending on traffic

## Support

For issues or questions:
1. Check `verify-deployment.sh` output
2. Review AWS Console for error messages
3. Check CloudWatch logs (if using CloudFront)
4. Ensure AWS CLI is properly configured

## Next Steps

After deployment:

1. **Test the site** on multiple devices and browsers
2. **Update App Store link** when your app is published
3. **Set up HTTPS** with CloudFront for production
4. **Add analytics** (Google Analytics, Plausible, etc.)
5. **Test loading speed** with PageSpeed Insights
6. **Submit to search engines** for SEO

## Files Overview

```
landing-page/
├── index.html                 # Main landing page
├── styles.css                 # Stylesheet with animations
├── deploy.sh                  # S3 deployment
├── route53-setup.sh           # DNS configuration
├── cloudfront-setup.sh        # HTTPS/CDN setup
├── quick-deploy.sh            # One-command deploy
├── verify-deployment.sh       # Status checker
├── README.md                  # Technical documentation
└── DEPLOYMENT-GUIDE.md        # This file
```

## Success Checklist

- [ ] Run deployment script
- [ ] Verify S3 bucket created
- [ ] Verify files uploaded (index.html, styles.css)
- [ ] Verify Route53 records created
- [ ] Wait for DNS propagation (5-60 min)
- [ ] Test http://nuggetdotcom.com
- [ ] Test http://www.nuggetdotcom.com
- [ ] Test on mobile devices
- [ ] Update App Store link
- [ ] Set up HTTPS (optional but recommended)
- [ ] Add to browser bookmarks
- [ ] Share with beta testers

---

**Ready to deploy?** Run `./quick-deploy.sh` and your landing page will be live in minutes!
