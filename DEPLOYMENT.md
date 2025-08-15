# Deployment Guide

This guide covers deployment for both the backend (Railway) and frontend (TestFlight).

## Backend Deployment (Railway)

### Prerequisites
- Railway account
- GitHub repository connected to Railway
- Backend code ready for deployment

### Steps

1. **Connect Repository to Railway**
   ```bash
   # Install Railway CLI
   npm install -g @railway/cli
   
   # Login to Railway
   railway login
   
   # Link your project
   railway link
   ```

2. **Configure Environment Variables**
   - Go to Railway dashboard
   - Add the following environment variables:
     ```
     NODE_ENV=production
     PORT=8080
     DATABASE_URL=your_database_url
     JWT_SECRET=your_jwt_secret
     CORS_ORIGIN=https://creatist-production.up.railway.app
     ```

3. **Deploy**
   ```bash
   railway up
   ```

4. **Set up Custom Domain (Optional)**
   - In Railway dashboard, go to Settings > Domains
   - Add your custom domain
   - Update DNS records

### Environment URLs
- **Production**: `https://web-production-5d44.up.railway.app`
- **Staging**: `https://web-production-5d44.up.railway.app`

## Frontend Deployment (TestFlight)

### Prerequisites
- Apple Developer Account ($99/year)
- Xcode 15+
- iOS device for testing

### Steps

1. **Configure App for Production**
   - Open `Creatist.xcodeproj` in Xcode
   - Select the project in the navigator
   - Go to "Signing & Capabilities"
   - Select your Team
   - Ensure Bundle Identifier is unique (e.g., `com.yourcompany.creatist`)

2. **Update Environment Configuration**
   - The app automatically uses production URLs in release builds
   - Verify `EnvironmentConfig.swift` has correct production URLs

3. **Build for TestFlight**
   ```bash
   # Archive the app
   xcodebuild -workspace Creatist.xcworkspace -scheme Creatist -configuration Release -archivePath Creatist.xcarchive archive
   
   # Export for App Store
   xcodebuild -exportArchive -archivePath Creatist.xcarchive -exportPath ./build -exportOptionsPlist exportOptions.plist
   ```

4. **Upload to App Store Connect**
   - Open Xcode
   - Go to Window > Organizer
   - Select your archive
   - Click "Distribute App"
   - Choose "App Store Connect"
   - Follow the upload process

5. **Configure TestFlight**
   - Go to App Store Connect
   - Select your app
   - Go to TestFlight tab
   - Add internal testers
   - Submit for Beta App Review (if needed)

### Production Configuration

The app includes several production-ready features:

1. **Environment Management**
   - Automatic environment detection
   - Production URLs for release builds
   - Development URLs for debug builds

2. **Security**
   - Certificate pinning in production
   - Secure network connections
   - Keychain storage for sensitive data

3. **Performance**
   - Image caching
   - Request timeouts
   - Background refresh optimization

4. **Monitoring**
   - Production logging
   - Error tracking
   - Analytics integration ready

## Environment Configuration

### Development
- API: `http://localhost:8080`
- WebSocket: `ws://localhost:8080`

### Staging
- API: `https://web-production-5d44.up.railway.app`
- WebSocket: `wss://web-production-5d44.up.railway.app`

### Production
- API: `https://web-production-5d44.up.railway.app`
- WebSocket: `wss://web-production-5d44.up.railway.app`

## Testing Checklist

### Backend Testing
- [ ] Health check endpoint responds
- [ ] Authentication endpoints work
- [ ] Database connections are stable
- [ ] CORS is properly configured
- [ ] Environment variables are set

### Frontend Testing
- [ ] App launches without crashes
- [ ] Login/signup flows work
- [ ] API calls succeed
- [ ] WebSocket connections work
- [ ] Push notifications (if enabled)
- [ ] Camera/photo library access
- [ ] Location services

## Troubleshooting

### Common Issues

1. **Backend Deployment Fails**
   - Check Railway logs
   - Verify environment variables
   - Ensure all dependencies are in package.json

2. **TestFlight Build Rejected**
   - Check App Store Connect for specific issues
   - Verify app permissions are properly configured
   - Ensure no debug code is in release builds

3. **API Connection Issues**
   - Verify CORS configuration
   - Check SSL certificates
   - Ensure proper authentication headers

### Support

For deployment issues:
1. Check Railway documentation
2. Review Apple Developer documentation
3. Check Xcode build logs
4. Verify network connectivity

## Security Considerations

1. **Backend**
   - Use environment variables for secrets
   - Enable HTTPS only
   - Implement rate limiting
   - Regular security updates

2. **Frontend**
   - No hardcoded secrets
   - Secure token storage
   - Certificate pinning
   - Input validation

## Monitoring

1. **Backend Monitoring**
   - Railway provides built-in monitoring
   - Set up alerts for downtime
   - Monitor API response times

2. **Frontend Monitoring**
   - Use Crashlytics for crash reporting
   - Implement analytics
   - Monitor app performance
