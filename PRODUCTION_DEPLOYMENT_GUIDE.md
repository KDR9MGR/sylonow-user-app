# Sylonow User App - Production Deployment Guide

## 🎯 Overview

This guide covers all the changes made to fix App Store and Play Store rejection issues and prepare the app for production deployment.

---

## ✅ Completed Fixes

### 1. **Sign in with Apple Implementation** (App Store Requirement - Guideline 4.8)

**What was fixed:**
- Added `sign_in_with_apple: ^6.1.3` package to pubspec.yaml
- Implemented Apple Sign-In in `auth_service.dart`
- Updated login screen with Apple Sign-In button (shown only on iOS devices)
- Apple button appears after Google Sign-In button with black styling

**Files modified:**
- `pubspec.yaml` - Added package dependency
- `lib/features/auth/services/auth_service.dart` - Added `signInWithApple()` and `isAppleSignInAvailable()` methods
- `lib/features/auth/screens/login_screen.dart` - Added Apple Sign-In button

**What you need to do:**
1. Configure Sign in with Apple in Apple Developer Console:
   - Go to https://developer.apple.com/account
   - Select your app identifier
   - Enable "Sign in with Apple" capability
   - Configure service ID and domain verification
2. Add capability in Xcode:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner target → Signing & Capabilities
   - Click "+ Capability" → Add "Sign in with Apple"
3. Configure in Supabase Dashboard:
   - Go to Authentication → Providers → Apple
   - Add your Service ID
   - Add your Key ID and Team ID
   - Upload your private key (.p8 file)

---

### 2. **SMS Permissions Removed** (Google Play Requirement)

**What was fixed:**
- Removed `RECEIVE_SMS` and `READ_SMS` permissions from AndroidManifest.xml
- Added comments explaining that `sms_autofill` package handles runtime permissions

**Why:**
Google Play rejects apps with SMS permissions in the manifest unless the app is a default SMS handler. The `sms_autofill` package only needs runtime permissions, which it requests automatically.

**Files modified:**
- `android/app/src/main/AndroidManifest.xml`

**Impact:**
- SMS autofill for OTP will still work
- No action needed from your side
- App will request SMS permission at runtime when needed

---

### 3. **iOS Permissions Updated** (App Store Requirement - Guideline 5.1.1)

**What was fixed:**
- Added camera permission (`NSCameraUsageDescription`)
- Added photo library permission (`NSPhotoLibraryUsageDescription`)
- Added photo library add permission (`NSPhotoLibraryAddUsageDescription`)
- Updated location permission descriptions to be more specific and user-friendly

**Files modified:**
- `ios/Runner/Info.plist`

**New permission descriptions:**
- **Location**: "Sylonow needs your location to show nearby service providers, calculate accurate delivery times, and help vendors reach your address."
- **Camera**: "Sylonow needs camera access to let you take photos for your profile and scan QR codes for vendor verification."
- **Photo Library**: "Sylonow needs access to your photo library to let you upload profile pictures and share booking details."

---

### 4. **App Version Updated**

**What was fixed:**
- Updated version from `0.1.0` to `1.0.0+1`
- Updated description to be more professional

**Files modified:**
- `pubspec.yaml`

---

### 5. **Debug Logging Wrapped** (Production Best Practice)

**What was fixed:**
- Wrapped all `//` statements in `kDebugMode` checks
- Debug logs will not appear in production builds

**Files modified:**
- `lib/main.dart`
- `lib/features/auth/services/auth_service.dart`

**Benefits:**
- Smaller app size
- Better performance
- No sensitive information in production logs

---

### 6. **Android Release Signing Configuration**

**What was created:**
- ProGuard rules file for code obfuscation
- Signing configuration in build.gradle.kts
- Template for key.properties file

**Files modified/created:**
- `android/app/build.gradle.kts` - Added signing config and ProGuard
- `android/app/proguard-rules.pro` - Created ProGuard rules
- `android/key.properties.template` - Created template for keystore config

**What you need to do:**
Follow the "Android Release Setup" section below to create your keystore.

---

## 📱 App Store Connect - Action Items

### 1. **Update Privacy Labels** (CRITICAL)

**Issue:** App Store rejection for App Tracking Transparency (Guideline 5.1.2)

**Solution:**
Go to App Store Connect → Your App → App Privacy

Update the following:
- **Phone Number**: Used for "App Functionality" (NOT for tracking)
- **Physical Address**: Used for "App Functionality" (NOT for tracking)
- Uncheck any "Tracking" purposes

**Do NOT implement App Tracking Transparency** - You're not tracking users for advertising.

---

### 2. **Provide Demo Account** (CRITICAL)

**Issue:** Apple couldn't test all features (Guideline 2.1)

**Solution:**
1. Create a test account with sample data:
   - Phone number: +1234567890 (or real test number)
   - Add sample addresses
   - Create sample bookings
   - Add funds to wallet

2. Add credentials in App Store Connect:
   - Go to App Review Information
   - Add demo account phone number
   - Add demo account password (if using password auth)
   - Add notes: "Use phone number +XXXXXXXXXXXX with OTP 123456"

---

### 3. **Fix iPad Login Bug** (CRITICAL)

**Issue:** Login failed on iPad Air (5th gen), iPadOS 26.0

**What to test:**
1. Run app on iPad simulator (iPad Air 5th gen)
2. Test phone number login
3. Test Google Sign-In
4. Test Apple Sign-In
5. Check network connectivity
6. Check error messages

**Possible fixes (check these):**
- Ensure responsive layout works on iPad screen sizes
- Verify network requests work on iPad
- Check if Google Sign-In is configured for iPad
- Add better error handling and user-friendly messages

**Files to check:**
- `lib/features/auth/screens/login_screen.dart` - Layout issues
- `lib/features/auth/screens/phone_input_screen.dart` - OTP flow
- `lib/features/auth/services/auth_service.dart` - Error handling

---

### 4. **Update App Screenshots**

**Action Required:**
- Take new screenshots showing Apple Sign-In button
- Include iPad screenshots (required for iPad support)
- Show all three login options: Phone, Google, Apple

---

## 🤖 Google Play Console - Action Items

### 1. **Create Android Release Keystore**

```bash
# Navigate to android folder
cd android

# Create a new keystore (run this command)
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# You'll be prompted for:
# - Keystore password (save this securely!)
# - Key password (save this securely!)
# - Your name, organization, city, state, country

# IMPORTANT: Backup upload-keystore.jks file securely!
# If you lose it, you cannot update your app on Play Store!
```

**After creating keystore:**

1. Create `android/key.properties` file:
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

2. **NEVER commit key.properties or upload-keystore.jks to Git!** (Already in .gitignore)

---

### 2. **Fill Out Data Safety Form**

Go to Google Play Console → App Content → Data Safety

**Data collected:**
- ✓ Location (precise)
- ✓ Name
- ✓ Email address (optional)
- ✓ Phone number
- ✓ Photos (optional)

**Why collected:**
- App functionality
- Fraud prevention
- Account management

**Data shared:**
- ✓ With service providers (name, phone, location)
- ✓ With payment processors (transaction data)

**Data security:**
- ✓ Data is encrypted in transit
- ✓ Users can request deletion
- ✓ Committed to Google Play Families Policy

---

### 3. **Test Release Build**

```bash
# Build release APK
flutter build apk --release

# Or build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Test the release build on a physical device
flutter install --release
```

**Test these features:**
- Login with phone OTP (without SMS permissions!)
- Google Sign-In
- Location services
- Image picking
- Camera access
- Payment flow
- QR code scanning

---

## 🔐 Security Considerations

### Current Setup:
- ✅ Supabase keys are in source code (anon key is meant to be public)
- ✅ ProGuard enabled for code obfuscation
- ✅ Debug logging removed in production
- ✅ Keystore in gitignore

### Recommendations:
1. **Environment Variables** (Optional but recommended):
   - Move Supabase URL and anon key to `--dart-define`
   - Use different Supabase projects for dev/prod

2. **Supabase RLS Policies**:
   - Ensure Row Level Security is enabled
   - Users can only access their own data
   - Verify policies in Supabase dashboard

3. **API Keys**:
   - Keep Razorpay keys secret
   - Use test keys for development
   - Production keys only in release builds

---

## 📋 Pre-Submission Checklist

### iOS (App Store)

- [ ] Sign in with Apple configured in Apple Developer Console
- [ ] Sign in with Apple capability added in Xcode
- [ ] Supabase Apple auth provider configured
- [ ] Privacy labels updated in App Store Connect (NO tracking)
- [ ] Demo account created and credentials provided
- [ ] iPad login bug fixed and tested
- [ ] New screenshots with Apple Sign-In uploaded
- [ ] App tested on iPad simulator/device
- [ ] Build number incremented (currently 1.0.0+1)
- [ ] All features tested on physical device

### Android (Google Play)

- [ ] Release keystore created and backed up
- [ ] key.properties file created (not committed to Git!)
- [ ] Data Safety form filled out
- [ ] Release APK/AAB built and tested
- [ ] SMS autofill tested (without manifest permissions)
- [ ] Location permissions tested
- [ ] Camera and photo permissions tested
- [ ] ProGuard tested (app works after obfuscation)
- [ ] Version code incremented (currently 1)

### Both Platforms

- [ ] Privacy policy accessible in-app
- [ ] Terms of service accessible in-app
- [ ] App icon is correct and high quality
- [ ] App description updated
- [ ] Support email set (info@sylonow.com)
- [ ] Contact phone numbers working (9741338102 / 8867266638)
- [ ] All third-party services tested (Firebase, Supabase, Razorpay)
- [ ] Payment flow tested end-to-end
- [ ] QR code vendor verification tested

---

## 🚀 Build and Submit Commands

### iOS - App Store

```bash
# Build iOS release
flutter build ios --release

# Open in Xcode to archive and upload
open ios/Runner.xcworkspace

# In Xcode:
# 1. Product → Archive
# 2. Distribute App
# 3. App Store Connect
# 4. Upload
```

### Android - Google Play

```bash
# Build App Bundle (recommended)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab

# Upload this file to Google Play Console
```

---

## 🐛 Known Issues and Workarounds

### Issue 1: SMS Autofill not working
**Cause**: Removed SMS permissions from manifest
**Solution**: The `sms_autofill` package will request runtime permissions. Make sure you're testing on Android 6.0+ and granting permissions when prompted.

### Issue 2: Sign in with Apple not showing
**Cause**: Only available on iOS 13+ and macOS 10.15+
**Solution**: This is expected behavior. The button only appears on supported devices.

### Issue 3: Release build crashes
**Cause**: ProGuard removing required classes
**Solution**: Check `proguard-rules.pro` and add keep rules for any classes causing issues.

---

## 📞 Support and Resources

### Documentation:
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Sign in with Apple for Supabase](https://supabase.com/docs/guides/auth/social-login/auth-apple)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policy](https://play.google.com/about/developer-content-policy/)

### Contacts:
- Email: info@sylonow.com
- Phone: 9741338102 / 8867266638
- Company: Sylonow Vision Private Limited
- Location: Bengaluru, Karnataka, India

---

## 🎉 Next Steps After Approval

1. **Monitor Crash Reports**:
   - Firebase Crashlytics
   - App Store Connect
   - Google Play Console

2. **Track Analytics**:
   - User acquisition
   - Feature usage
   - Conversion rates

3. **Gather Feedback**:
   - In-app feedback
   - Store reviews
   - User support tickets

4. **Plan Updates**:
   - Bug fixes
   - New features
   - Performance improvements

---

**Good luck with your submission! 🚀**
