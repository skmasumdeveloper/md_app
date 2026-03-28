# CU Apps - Advanced Group Communication Platform

A comprehensive Flutter-based group communication application featuring real-time messaging, video/audio calls, meeting scheduling, and advanced user management. Built with modern technologies including WebRTC for peer-to-peer communication, Firebase for push notifications, and Socket.IO for real-time messaging.

![Flutter](https://img.shields.io/badge/Flutter-3.5.4-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![Firebase](https://img.shields.io/badge/Firebase-Latest-orange.svg)
![WebRTC](https://img.shields.io/badge/WebRTC-Enabled-green.svg)
![License](https://img.shields.io/badge/License-Private-red.svg)

## 📱 Table of Contents

- [Features](#features)
- [Technologies Used](#technologies-used)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [API Documentation](#api-documentation)
- [Contributing](#contributing)
- [Known Issues](#known-issues)
- [License](#license)
- [Contact](#contact)

## Features

### Core Features

- **Real-time Group Messaging**: Instant messaging with delivery and read receipts
- **Video/Audio Calls**: Multi-participant video conferencing with WebRTC
- **Meeting Scheduling**: Create and manage scheduled meetings with time-based controls
- **Push Notifications**: Background notifications with CallKit integration (iOS/Android)
- **File Sharing**: Support for images, videos, documents, and audio files
- **User Management**: Admin controls for user roles and account status
- **Call History**: Comprehensive call logs and meeting history

### Advanced Features

- **Admin Dashboard**: Super admin and admin role management
- **Meeting Timer**: Automatic meeting end controls
- **Screen Recording**: Picture-in-picture mode support
- **Smart Notifications**: In-app notifications with custom actions
- **Contact Management**: Add and manage organization contacts
- **Network Resilience**: Automatic reconnection and error handling
- **Security**: End-to-end message encryption and secure file transfers

### Platform Support

- ✅ iOS (15.0+)
- ✅ Android (API 24+)
- ✅ Background operation support
- ✅ CallKit integration for native call experience

## Technologies Used

### Frontend Framework

- **Flutter** (3.5.4+) - Cross-platform mobile development
- **Dart** (3.0+) - Programming language
- **GetX** - State management and dependency injection

### Real-time Communication

- **WebRTC** - Peer-to-peer video/audio communication
- **Socket.IO** - Real-time bidirectional communication
- **Flutter CallKit Incoming** - Native call interface

### Backend Services

- **Firebase Messaging** - Push notifications
- **RESTful APIs** - HTTP communication with custom backend

### Media & Files

- **Image Picker** - Camera and gallery access
- **File Picker** - Document selection
- **Video Player** - Media playback
- **Cached Network Image** - Optimized image loading

### Storage & Persistence

- **Shared Preferences** - Local key-value storage
- **Get Storage** - Reactive local storage
- **Path Provider** - File system access

### UI/UX Components

- **Cupertino Icons** - iOS-style icons
- **Font Awesome Flutter** - Icon library
- **Shimmer** - Loading animations
- **Pull to Refresh** - Gesture interactions

## Prerequisites

Before you begin, ensure you have the following installed on your development machine:

### Development Environment

- **Flutter SDK** (3.5.4 or higher)
- **Dart SDK** (3.0 or higher)
- **Android Studio** or **VS Code** with Flutter extensions
- **Xcode** (for iOS development, macOS only)
- **Git** for version control

### Platform-Specific Requirements

#### For iOS Development:

- macOS (15.5 or higher)
- Xcode (Use latest version)
- iOS Simulator or physical iOS device (iOS 15.0+)
- Apple Developer Account (for device testing)

#### For Android Development:

- Android SDK (API level 24 or higher)
- Android Studio with Android SDK tools
- Android Emulator or physical Android device

### Backend Services

- Firebase project with authentication and messaging enabled
- Backend API server (Node.js recommended)
- Socket.IO server for real-time communication
- Turn server for WebRTC connections

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/excellis-it/CU-Apps.git
cd cu_app
```

### 2. Install Flutter Dependencies

```bash
flutter pub get
```

### 3. iOS Setup (macOS only)

```bash
cd ios
pod install
cd ..
```

### 4. Generate Application Icons

```bash
flutter pub run flutter_launcher_icons:main
```

### 5. Verify Installation

```bash
flutter doctor
```

Ensure all checkmarks are green before proceeding.

## Configuration

### 1. Firebase Configuration

#### Create Firebase Project:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project or use existing one
3. Enable Firestore, and Cloud Messaging

#### Add Firebase to Your App:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Configure Firebase for Flutter
dart pub global activate flutterfire_cli
flutterfire configure
```

#### Update Firebase Options:

Replace the values in `lib/firebase_options.dart` with your project credentials:

```dart
// Update these values with your Firebase project configuration
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'your-android-api-key',
  appId: 'your-android-app-id',
  messagingSenderId: 'your-sender-id',
  projectId: 'your-project-id',
  storageBucket: 'your-storage-bucket',
);

static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'your-ios-api-key',
  appId: 'your-ios-app-id',
  messagingSenderId: 'your-sender-id',
  projectId: 'your-project-id',
  storageBucket: 'your-storage-bucket',
  iosBundleId: 'com.excellisit.cuapp',
);
```

### 2. Backend API Configuration

Create a `.env` file in your project root directory and configure the following environment variables:

```env
# Environment: production or development
ENV='development'

# Application name
APP_NAME='CU'

# Application logo URL
APP_LOGO_LINK='https://example.com/demo-logo.svg'

# Base URL for the API
API_BASE_URL='https://demo-api.example.com'

# Socket URL for WebSocket connections
SOCKET_URL='https://demo-socket.example.com'

# STUN Server URL
# This is used for NAT traversal in WebRTC applications.
# It helps in establishing peer-to-peer connections.
STUN_URL=stun:demo.stun.server.com:3478

# TURN Servers
# TURN servers are used to relay media streams when direct peer-to-peer connections cannot be established.
# These URLs include the transport protocol (UDP or TCP) and credentials for authentication.
TURN_URL_1=turn:demo.turn.server.com:3478
TURN_URL_UDP=turn:demo.turn.server.com:3478?transport=udp
TURN_URL_TCP=turn:demo.turn.server.com:3478?transport=tcp

# TURN server credentials
# These credentials are used to authenticate with the TURN server.
TURN_USERNAME=demo_turn_user
TURN_CREDENTIAL=demo_turn_password_123

# WebRTC configuration
# This configuration is used for WebRTC connections, including ICE servers and SDP semantics.
SDP_SEMANTICS=unified-plan
ICE_POOL_SIZE=0
ICE_POLICY=all

# Audio method channel for iOS
# This is used to communicate with the native iOS audio handling code.
IOS_AUDIO_METHOD_CHANNEL=com.example.demoapp/audiomode

# iOS navigation method channel
IOS_NAVIGATION_METHOD_CHANNEL=com.example.demoapp/navigation
```

#### Important Configuration Notes:

- **Development Environment**: Set `ENV='development'` for testing and development
- **Demo Servers**: Replace with your actual STUN/TURN server configurations
- **ICE Policy**: Set to `all` for development, `relay` for production security
- **iOS Method Channels**: Update bundle identifiers to match your app configuration
- **Security**: Replace all demo values with actual production credentials before deployment

Make sure to keep your `.env` file secure and never commit it to version control. Add `.env` to your `.gitignore` file.

### 3. iOS Configuration

#### Info.plist Updates:

Add the following permissions to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for video calls</string>
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for voice calls</string>
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs local network access for peer-to-peer communication</string>
```

#### CallKit Configuration:

The app includes CallKit integration for native iOS call experience. Ensure your Apple Developer account has the necessary entitlements.

### 4. Android Configuration

#### Permissions:

The required permissions are already configured in `android/app/src/main/AndroidManifest.xml`:

- Camera and microphone access
- Network permissions
- Notification permissions
- Phone call permissions

#### Notification Icons:

Ensure notification icons are properly configured in the Android manifest.

## Usage

### Starting the Application

#### Development Mode:

```bash
# Run on connected device/emulator
flutter run

# Run with hot reload
flutter run --hot

# Run in debug mode with verbose logging
flutter run --debug --verbose
```

#### Production Build:

```bash
# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release
```

### Key User Flows

#### 1. Authentication

- Users log in with email and password
- NodeJs backend handles authentication and token management
- Automatic session management with persistent login

#### 2. Group Communication

- Create groups with multiple participants
- Send text messages, images, videos, and documents
- Real-time message delivery with read receipts
- Reply to specific messages

#### 3. Video/Audio Calls

- Initiate group video or audio calls
- Join ongoing calls with one-tap
- Toggle camera, microphone, and speaker
- Notifiaction call support with CallKit

#### 4. Meeting Management

- Schedule meetings with start/end times
- Automatic meeting termination
- Meeting history and call logs
- Participant management

#### 5. Admin Features

- User role management (User, Admin, Super Admin)
- Group administration
- Meeting administration
- Members administration

## Project Structure

```
lib/
├── Api/                          # API configuration and endpoints
│   └── urls.dart                # Backend URL configuration
├── Commons/                      # Shared utilities and constants
│   ├── app_colors.dart          # Color palette
│   ├── app_strings.dart         # String constants
│   └── theme.dart              # App theme configuration
├── Features/                    # Feature-based architecture
│   ├── AddContact/             # Add new contacts
│   ├── AddMembers/             # Group member management
│   ├── AllMembers/             # Member list and administration
│   ├── CallHistory/            # Call logs and history
│   ├── Chat/                   # Messaging functionality
│   ├── EditMember/             # Member profile editing
│   ├── ForgetPassword/         # Password recovery
│   ├── Group_Call/             # Video/audio calling
│   ├── Home/                   # Main dashboard
│   ├── Login/                  # Authentication
│   ├── Meetings/               # Meeting management
│   └── Navigation/             # App navigation
├── Utils/                      # Utility functions
├── Widgets/                    # Reusable UI components
├── main.dart                   # Application entry point
├── firebase_options.dart       # Firebase configuration
└── pushNotificationService.dart # Push notification handling
```

### Architecture Patterns

The application follows a **feature-first architecture** with:

- **MVC Pattern**: Model-View-Controller separation
- **Repository Pattern**: Data access abstraction
- **Dependency Injection**: Using GetX for state management
- **Reactive Programming**: Observable state management

## API Documentation

### Authentication Endpoints

```
POST /api/users/sign-in          # User login
POST /api/users/logout           # User logout
GET  /api/users/get-user         # Get user profile
PUT  /api/users/update-user      # Update user profile
```

### Group and Meetings Management

```
GET    /api/groups/getall        # Get all groups
POST   /api/groups/create        # Create new group
GET    /api/groups/get-group-details/:id  # Get group details
PUT    /api/groups/update-group  # Update group information
DELETE /api/groups/removeuser    # Remove user from group
POST   /api/groups/adduser       # Add user to group
```

### Messaging

```
GET  /api/groups/getonegroup     # Get chat messages
POST /api/groups/addnewmsg       # Send new message
POST /api/groups/report-message  # Report message
GET  /api/groups/info-message    # Get message info
```

### Real-time Events (Socket.IO)

```
message                 # New message received
deliver                 # Message delivery confirmation
read                    # Message read confirmation
FE-user-join           # User joined call
FE-user-leave          # User left call
FE-receive-call        # Incoming call signal
FE-call-accepted       # Call accepted
```

## Contributing

We welcome contributions to improve CU App! Please follow these guidelines:

### Development Workflow

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes following our coding standards
4. Write tests for new functionality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Coding Standards

- Follow [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add comments for complex logic
- Ensure responsive UI across different screen sizes
- Test on both iOS and Android platforms

## Known Issues

### Current Limitations

1. **Large File Uploads**: Files larger than 50MB may experience timeouts
2. **Network Connectivity**: Poor network conditions may affect call quality

### Workarounds

- **File Size**: Compress large files before sharing
- **Network Issues**: App includes automatic retry mechanisms
- **Memory Management**: Regular cleanup of unused resources

### Reporting Issues

Please report bugs using the GitHub issue tracker with:

- Device information (iOS/Android version)
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or logs if applicable

## License

This project is private. All rights reserved.

**Copyright © 2024 ExcellisIT Solutions**

This software and associated documentation files (the "Software") are proprietary and confidential. Unauthorized copying, distribution, or modification of this Software, via any medium, is strictly prohibited without explicit written permission from the copyright holder.

### Restrictions

- ❌ No public distribution
- ❌ No commercial use without license
- ❌ No modification without permission
- ❌ No reverse engineering

For licensing inquiries, please contact the development team.

## Credits

### Development Team

- **Lead Developer**: ExcellisIT Team
- **UI/UX Design**: Internal Design Team
- **Backend Architecture**: Node.js Development Team
- **Quality Assurance**: Testing Team

### Third-Party Libraries

- Flutter WebRTC team for real-time communication
- GetX team for state management
- Firebase team for backend services
- Socket.IO team for real-time messaging

### Resources

- Icons from Font Awesome and Cupertino
- Audio assets from royalty-free sources
- Testing devices provided by ExcellisIT

## Contact

### Development Team

- **Email**: support@cu-app.us
- **GitHub Issues**: [https://github.com/excellis-it/CU-Apps/issues](https://github.com/excellis-it/CU-Apps/issues)

### Support

For technical support or feature requests:

1. Check existing GitHub issues
2. Create a new issue with detailed description
3. Contact development team via email

### Business Inquiries

For licensing, partnerships, or business-related questions:

- **Business Email**: --
- **Website**: [https://cu-app.us](https://cu-app.us)

---

**Built with by ExcellisIT**

_Last updated: August 2025_
