#!/bin/bash
# Usage for cleaning and updating iOS dependencies

rm -rf ios/Pods ios/Podfile.lock ios/DerivedData ios/build
flutter clean
flutter pub get
cd ios/ 
pod install && pod update && pod install --repo-update