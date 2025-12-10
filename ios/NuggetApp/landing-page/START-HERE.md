# START HERE - Deploy Your Nugget Landing Page

## What You Have

A beautiful, production-ready landing page for your Nugget iOS app with:
- Clean, modern design with purple/glass aesthetic
- Fully responsive (works on all devices)
- Dark mode support
- Professional animations and effects
- App Store download button
- 4 key feature highlights

## Deploy in 3 Steps

### Step 1: Open Terminal
```bash
cd /Users/jason/nugget/ios/NuggetApp/landing-page
```

### Step 2: Make Scripts Executable
```bash
chmod +x *.sh
```

### Step 3: Deploy Everything
```bash
./quick-deploy.sh
```

That's it! Your site will be live at:
- http://nuggetdotcom.com
- http://www.nuggetdotcom.com

## Wait 5-10 Minutes

DNS changes need time to propagate. While you wait:

1. Test the S3 direct URL (shown in terminal output)
2. Preview the local files by opening `index.html` in a browser
3. Read the full documentation in `DEPLOYMENT-GUIDE.md`

## Verify Deployment

Check if everything is working:
```bash
./verify-deployment.sh
```

## Before Going Live

Update the App Store link in `index.html` (line 37):
```html
<a href="https://apps.apple.com/app/YOUR-APP-ID" class="app-store-button">
```

Replace `YOUR-APP-ID` with your actual App Store app ID.

## Next: Add HTTPS (Recommended)

For production, add HTTPS support:

1. Request SSL certificate:
```bash
aws acm request-certificate \
    --domain-name nuggetdotcom.com \
    --subject-alternative-names www.nuggetdotcom.com \
    --validation-method DNS \
    --region us-east-1
```

2. Validate certificate in AWS Console (follow DNS validation steps)

3. Set up CloudFront:
```bash
./cloudfront-setup.sh
```

## Need Help?

- **Quick reference:** See `DEPLOYMENT-GUIDE.md`
- **Technical details:** See `README.md`
- **Troubleshooting:** Run `./verify-deployment.sh`

## Preview Locally

Want to see the page before deploying? Just open:
```
/Users/jason/nugget/ios/NuggetApp/landing-page/index.html
```

in any web browser (Chrome, Safari, Firefox, etc.)

---

**Ready?** Run `./quick-deploy.sh` now!
