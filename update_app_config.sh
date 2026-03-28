#!/bin/bash
 
# Script to update app logo, name, and package details
# Usage: ./update_app_config.sh

# How to use :
# 1. Place your app logo at assets/icons/app-logo.png
# 2. Run this script from the root of your Flutter project
# 3. Ensure you have the change_app_package_name plugin in your pubspec.yaml
# 4. This script will update the app name, package name, and logo path in the necessary files
# 5. It will also run flutter_launcher_icons to update the app icons

 
# Exit on error
set -e
 
# Set constants for app configuration
APP_NAME="CU"
PACKAGE_NAME="com.excellisit.cuapp"
APP_LOGO_PATH="assets/icons/app-logo.png"
 
echo "====================================================="
echo "Updating app with the following configuration:"
echo "App Name: $APP_NAME"
echo "Package Name: $PACKAGE_NAME"
echo "Logo Path: $APP_LOGO_PATH"
echo "====================================================="
 
# Step 1: Update app name in AndroidManifest.xml (label attribute)
echo "Updating Android app name..."
sed -i '' "s/android:label=\"[^\"]*\"/android:label=\"$APP_NAME\"/" android/app/src/main/AndroidManifest.xml
 
# Step 2: Update app name in Info.plist
echo "Updating iOS app name..."
ESCAPED_APP_NAME=$(echo "$APP_NAME" | sed 's/\//\\\//g')
sed -i '' "s/<key>CFBundleName<\/key>\\s*<string>[^<]*<\/string>/<key>CFBundleName<\/key>\\n\\t<string>$ESCAPED_APP_NAME<\/string>/" ios/Runner/Info.plist
sed -i '' "s/<key>CFBundleDisplayName<\/key>\\s*<string>[^<]*<\/string>/<key>CFBundleDisplayName<\/key>\\n\\t<string>$ESCAPED_APP_NAME<\/string>/" ios/Runner/Info.plist
 
# Step 3: Use change_app_package_name plugin to update package name
echo "Updating package name to $PACKAGE_NAME ..."
 
# First ensure the plugin is available
echo "Ensuring change_app_package_name plugin is installed..."
if ! grep -q "change_app_package_name:" pubspec.yaml; then
  echo "Adding change_app_package_name dependency to pubspec.yaml..."
  cat >> pubspec.yaml << EOF
 
# Added by update_app_config.sh script
dev_dependencies:
  change_app_package_name: ^1.4.0
EOF
  flutter pub get
fi
 
# Run the change_app_package_name plugin to update package names
echo "Running change_app_package_name plugin..."
dart run change_app_package_name:main $PACKAGE_NAME
 
# Step 4: Check if the logo file exists
if [ ! -f "$APP_LOGO_PATH" ]; then
  echo "Error: App icon not found at $APP_LOGO_PATH"
  echo "Please place your app icon at this location before continuing."
  exit 1
fi
 
# Step 5: Update the logo path in pubspec.yaml
echo "Ensuring correct logo path in pubspec.yaml..."
if grep -q "image_path:" pubspec.yaml; then
  sed -i '' "s|image_path: \"[^\"]*\"|image_path: \"$APP_LOGO_PATH\"|" pubspec.yaml
else
  echo "Warning: flutter_launcher_icons configuration not found in pubspec.yaml."
  echo "Please ensure the configuration is added correctly."
fi
 
# Step 6: Run flutter_launcher_icons to update app icons
echo "Updating app icons..."
flutter pub get
flutter pub run flutter_launcher_icons
 
# Step 7: Verify the changes
echo "Verifying changes..."
echo "Checking AndroidManifest.xml package name:"
grep -m 1 "package=" android/app/src/main/AndroidManifest.xml
echo "Checking build.gradle applicationId:"
grep -m 1 "applicationId" android/app/build.gradle
 
echo "====================================================="
echo "App configuration update completed!"
echo "====================================================="
echo "Note: Some changes might require cleaning and rebuilding the project:"
echo "  flutter clean"
echo "  flutter pub get"
echo "  flutter build <platform>"
echo "====================================================="