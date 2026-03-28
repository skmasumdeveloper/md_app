#!/bin/bash
# Script to clean and update Flutter project dependencies
flutter clean
flutter pub get
flutter clean cache
flutter pub get