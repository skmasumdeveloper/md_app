# CU App - Group Call Features Guide

> Complete developer reference for audio/video group call implementation using **MediaSoup SFU** architecture.
> Last updated: March 2026

---

## Table of Contents

Always check this web frontend and backend github repo to check the latest updates on the group call features:
https://github.com/excellis-it/cu_app_web_new
[repositoryLink] 


1. [Architecture Overview](#1-architecture-overview)
2. [File Structure](#2-file-structure)
3. [State Management](#3-state-management)
4. [Call Lifecycle Flows](#4-call-lifecycle-flows)
5. [MediaSoup SFU Protocol](#5-mediasoup-sfu-protocol)
6. [Socket Events Reference](#6-socket-events-reference)
7. [Web-to-App Interoperability](#7-web-to-app-interoperability)
8. [Audio Session Management](#8-audio-session-management)
9. [Screen Sharing](#9-screen-sharing)
10. [Video Rendering & Grid Layout](#10-video-rendering--grid-layout)
11. [Native Platform Integration](#11-native-platform-integration)
12. [Reconnection & Error Recovery](#12-reconnection--error-recovery)
13. [Method Reference](#13-method-reference)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Architecture Overview

### Before (P2P Mesh) vs After (MediaSoup SFU)

```
OLD: P2P Mesh                          NEW: MediaSoup SFU

  A ──── B                               A ──── Server ──── B
  │ \  / │                               │                  │
  │  \/  │                               │    MediaSoup     │
  │  /\  │                               │    Router        │
  │ /  \ │                               │                  │
  C ──── D                               C ──── Server ──── D

  N*(N-1)/2 connections                  N*2 connections (send + recv)
  Bandwidth: each user sends             Bandwidth: each user sends
  to every other user                    once to server
```

**Key difference**: Each client now has exactly **2 WebRTC transports** to the MediaSoup server:
- **Send Transport** — carries local audio + video (Producers)
- **Recv Transport** — carries all remote audio + video (Consumers)

The server routes media between clients using a Selective Forwarding Unit (SFU).

### Technology Stack

| Layer | Technology |
|-------|-----------|
| Signaling | Socket.IO (shared with chat) |
| Media Transport | MediaSoup SFU via WebRTC |
| Flutter Client | `mediasfu_mediasoup_client` package |
| WebRTC | `flutter_webrtc` ^1.3.0 |
| Native Call UI | `flutter_callkit_incoming` (CallKit on iOS, ConnectionService on Android) |
| State Management | GetX (`GetxController`, `Rx` observables) |
| Audio | `audio_session` plugin + native AVAudioSession/RTCAudioSession |

---

## 2. File Structure

```
lib/
├── Features/Group_Call/
│   ├── controller/
│   │   ├── group_call.dart              # Main controller (state + lifecycle)
│   │   ├── group_call_peer.dart         # MediaSoup SFU: device, transports, produce, consume
│   │   ├── group_call_socket.dart       # Socket event listeners (FE-*, MS-*)
│   │   ├── group_call_call_flow.dart    # Call lifecycle: join, leave, rejoin, reject, cleanup
│   │   ├── group_call_media.dart        # getUserMedia, toggleMic/Camera/switchCamera
│   │   ├── group_call_audio.dart        # Audio session config, speaker mode
│   │   ├── group_call_renderers.dart    # Video renderer lifecycle, trackless check
│   │   ├── group_call_meeting.dart      # Meeting timer (for temp groups)
│   │   ├── group_call_utils.dart        # socketEmitWithAck helper, getUserFullName
│   │   ├── group_call_turn.dart         # TURN/STUN server config (from .env)
│   │   ├── network_controller.dart      # Connectivity monitoring, retry popup
│   │   └── remote_user_info.dart        # RemoteUserInfo data class
│   └── Presentation/
│       ├── video_call_screen.dart       # Call screen UI + controls
│       ├── video_call_grid.dart         # Adaptive video grid layout
│       ├── video_call_meeting.dart      # Meeting countdown timer UI
│       └── video_call_screen_share.dart # Screen share banner (commented out)
│
├── services/
│   ├── call_service.dart                # Android foreground service + PiP bridge
│   ├── call_overlay_manager.dart        # In-app floating mini-call widget
│   ├── screen_share_service.dart        # Screen capture + Producer track replacement
│   └── system_pip_view.dart             # System PiP helper
│
├── Commons/
│   └── platform_channels.dart           # Native method channels (audio, screen capture)
│
└── callkit_incoming.dart                # Native incoming call UI (CallKit/Android heads-up)

android/app/src/main/kotlin/com/excellisit/cuapp/
├── MainActivity.kt                      # Method channels, PiP, broadcast receiver
├── CallService.kt                       # Foreground service (camera+mic type)
└── ScreenCaptureService.kt              # Foreground service (mediaProjection type)

ios/Runner/
└── AppDelegate.swift                    # VoIP push, CallKit, audio routing, PiP
```

### Part File Relationship

All controller files are `part of 'group_call.dart'` using Dart `extension` syntax:

```dart
// group_call.dart
class GroupcallController extends GetxController { ... }

// group_call_peer.dart
extension GroupCallPeerExtension on GroupcallController { ... }

// group_call_socket.dart
extension GroupCallSocketExtension on GroupcallController { ... }
```

This means all extensions share the same state and can call each other's methods.

---

## 3. State Management

### MediaSoup SFU State (private)

| Variable | Type | Purpose |
|----------|------|---------|
| `_msDevice` | `Device?` | MediaSoup Device (loaded with router capabilities) |
| `_sendTransport` | `Transport?` | WebRTC transport for sending local media |
| `_recvTransport` | `Transport?` | WebRTC transport for receiving remote media |
| `_audioProducer` | `Producer?` | Local audio producer |
| `_videoProducer` | `Producer?` | Local video producer |
| `_consumers` | `Map<String, Consumer>` | Active consumers (consumerId -> Consumer) |
| `_consumerToUserMap` | `Map<String, String>` | consumerId -> userId(ObjectId) |
| `_consumedProducerIds` | `Set<String>` | Prevents duplicate consumption |
| `_mediasoupInitialized` | `bool` | Guard against double init |

### User Mapping State

| Variable | Type | Purpose |
|----------|------|---------|
| `_socketToUserMap` | `Map<String, String>` | socket.id -> MongoDB ObjectId |
| `_userToSocketMap` | `Map<String, String>` | MongoDB ObjectId -> socket.id |
| `_existingUserIds` | `Set<String>` | Known remote user ObjectIds |

### Observable UI State (reactive)

| Variable | Type | Purpose |
|----------|------|---------|
| `localStream` | `MediaStream?` | Local camera + mic stream |
| `localRenderer` | `RTCVideoRenderer` | Local video preview |
| `remoteRenderers` | `RxMap<String, RTCVideoRenderer>` | Remote video renderers (keyed by ObjectId) |
| `remoteStreams` | `RxMap<String, MediaStream>` | Remote media streams (keyed by ObjectId) |
| `activeRenderers` | `RxSet<String>` | Which renderers are actively decoding |
| `participantCount` | `RxInt` | Total participants including self |
| `isCallActive` | `RxBool` | Whether we're in an active call |
| `isMicEnabled` | `RxBool` | Microphone on/off |
| `isCameraEnabled` | `RxBool` | Camera on/off |
| `isSpeakerOn` | `RxBool` | Speaker mode on/off |
| `isThisVideoCall` | `RxBool` | Video or audio-only call |
| `userAudioEnabled` | `RxMap<String, bool>` | Per-user audio state (keyed by ObjectId) |
| `userInfoMap` | `RxMap<String, Map>` | Per-user display info (fullName, userName) |

---

## 4. Call Lifecycle Flows

### 4.1 Starting a Call (Outgoing)

```
User taps "Start Call" button
         │
         ▼
outgoingCallEmit(groupId, isVideoCall)
         │
         ├── _showCallConnectingOverlay()
         ├── Leave any existing call
         ├── Set call state: isCallActive=true, store to LocalStorage
         │
         ├── _getUserMedia(isVideoCall) ─── Get camera + mic
         │
         ├── socket.emit("BE-join-room", {...})
         │       Server registers mediasoup peer,
         │       broadcasts FE-user-join to others,
         │       sends push notifications
         │
         ├── activateAudioSession() ─── CRITICAL for iOS
         │
         ├── initializeMediasoup() ─── Setup device, transports, produce, consume
         │       │
         │       ├── MS-get-rtp-capabilities
         │       ├── Device.load()
         │       ├── _createSendTransport()  ─── MS-create-transport (send)
         │       │       ├── on 'connect' ─── MS-connect-transport
         │       │       └── on 'produce' ─── MS-produce (returns producer ID)
         │       ├── _produceLocalTracks() ─── produce(audio) + produce(video)
         │       ├── _createRecvTransport()  ─── MS-create-transport (recv)
         │       │       ├── on 'connect' ─── MS-connect-transport
         │       │       └── consumerCallback ─── _handleConsumerTrack()
         │       └── _consumeExistingProducers() ─── MS-get-producers + MS-consume
         │
         ├── _hideCallConnectingOverlay()
         │
         └── Navigate to GroupVideoCallScreen
```

### 4.2 Joining an Existing Call

```
User taps "Join" on active call indicator
         │
         ▼
joinCall(roomId, userName, userFullName, context)
         │
         ├── Set state, store to LocalStorage
         ├── _getUserMedia()
         ├── socket.emit("BE-join-room", {...})
         ├── activateAudioSession()
         ├── initializeMediasoup()
         └── Navigate to GroupVideoCallScreen
```

### 4.3 Receiving a New Participant (While in Call)

```
Server broadcasts "FE-user-join" to existing users
         │
         ▼
FE-user-join handler (group_call_socket.dart)
         │
         ├── Parse user list, skip self
         ├── Map socket.id ↔ ObjectId
         ├── Store user info (fullName, audio state)
         └── Update participantCount

... then immediately ...

Server broadcasts "MS-new-producer" for each of the new user's tracks
         │
         ▼
MS-new-producer handler (group_call_socket.dart)
         │
         ├── Skip own producers (self-filtering)
         ├── Skip already-consumed producers (dedup)
         └── consumeProducer(roomId, userId, producerId, remoteUserId, kind)
                 │
                 ├── MS-consume (get consumer params from server)
                 ├── _recvTransport.consume() ─── triggers consumerCallback
                 └── consumerCallback:
                         ├── Store consumer + user mapping
                         └── _handleConsumerTrack()
                                 ├── Create/update MediaStream for user
                                 ├── Create RTCVideoRenderer if needed
                                 ├── Attach stream to renderer
                                 └── Update participantCount
```

### 4.4 Leaving a Call

```
User taps "End Call" button
         │
         ▼
leaveCall(roomId, userId)
         │
         ├── isCallActive = false
         ├── stopMeetingEndTimer()
         │
         ├── socket.emit("BE-leave-room", {roomId, leaver})
         ├── socket.emit("call_disconnect", {roomId, userId})
         │       Server removes mediasoup peer,
         │       broadcasts FE-user-leave to others,
         │       marks user as "left" in DB
         │
         ├── cleanupCall()
         │       ├── screenShareService.dispose()
         │       ├── cleanupMediasoup()
         │       │       ├── _audioProducer.close()
         │       │       ├── _videoProducer.close()
         │       │       ├── _sendTransport.close()
         │       │       ├── Close all consumers
         │       │       ├── _recvTransport.close()
         │       │       └── Clear all maps, reset _mediasoupInitialized
         │       ├── Stop all local tracks
         │       ├── Dispose local stream
         │       ├── Stop/dispose all remote streams
         │       └── Clear all state
         │
         ├── FlutterCallkitIncoming.endCall(uuid)  ─── End native call UI
         ├── AudioSession.setActive(false)
         ├── WakelockPlus.disable()
         ├── CallOverlayManager().remove()
         ├── CallService.stopService()
         └── Get.back()  ─── Navigate away
```

### 4.5 Reconnecting After Network Drop

```
Network drops → socket disconnects → socket reconnects
         │
         ▼
reCallConnect()
         │
         ├── Save currentRoom + wasVideoCall
         ├── cleanupCall()  ─── Full cleanup (resets _mediasoupInitialized)
         ├── socket.emit("BE-leave-room")  ─── Tell server we left
         ├── Wait 2 seconds (allow server cleanup)
         │
         ├── Set fresh state
         ├── _getUserMedia(isVideoCall)
         ├── socket.emit("BE-join-room")  ─── Rejoin
         ├── activateAudioSession()
         └── initializeMediasoup()  ─── Fresh SFU setup
```

### 4.6 Remote Call End

```
Server broadcasts "FE-call-ended" (last person left)
         │
         ▼
FE-call-ended handler (group_call_socket.dart)
         │
         ├── cleanupCall()
         ├── FlutterCallkitIncoming.endCall()  (5 retry attempts)
         ├── AudioSession.setActive(false)
         ├── CallOverlayManager().remove()
         ├── WakelockPlus.disable()
         └── Refresh group list + call history
```

---

## 5. MediaSoup SFU Protocol

### Initialization Sequence

```
Flutter App                           Backend Server (MediaSoup)
    │                                        │
    │── BE-join-room ──────────────────────►  │  Register peer (addPeer)
    │◄── FE-user-join (all users) ──────────  │  Broadcast presence
    │                                        │
    │── MS-get-rtp-capabilities ──────────►  │  Return router codecs
    │◄── {ok, rtpCapabilities} ────────────  │  (opus audio, VP8 video)
    │                                        │
    │   Device.load(rtpCapabilities)         │
    │                                        │
    │── MS-create-transport (send) ────────►  │  Create WebRTC transport
    │◄── {id, iceParameters,                 │
    │     iceCandidates, dtlsParameters} ──  │
    │                                        │
    │   createSendTransportFromMap()         │
    │   sendTransport.produce(audio)         │
    │     ├── 'connect' event ──────────────►│  MS-connect-transport
    │     └── 'produce' event ──────────────►│  MS-produce → server creates Producer
    │◄── {id: producerId} ─────────────────  │  Broadcasts MS-new-producer to others
    │                                        │
    │   sendTransport.produce(video)         │
    │     └── 'produce' event ──────────────►│  MS-produce
    │◄── {id: producerId} ─────────────────  │
    │                                        │
    │── MS-create-transport (recv) ────────►  │  Create recv transport
    │◄── {id, iceParameters, ...} ─────────  │
    │                                        │
    │   createRecvTransportFromMap()         │
    │                                        │
    │── MS-get-producers ──────────────────►  │  List existing producers
    │◄── [{producerId, userId, kind}] ─────  │
    │                                        │
    │   For each existing producer:          │
    │── MS-consume ────────────────────────►  │  Create Consumer on server
    │◄── {id, producerId, kind,              │
    │     rtpParameters} ──────────────────  │
    │                                        │
    │   recvTransport.consume()              │
    │   → consumerCallback fires             │
    │   → attach track to renderer           │
    │                                        │
    │   Listen for MS-new-producer:          │
    │◄── MS-new-producer ──────────────────  │  New user started producing
    │── MS-consume ────────────────────────►  │  Subscribe to their media
    │◄── consumer params ──────────────────  │
    │                                        │
```

### Media Codecs

The MediaSoup server is configured with:
- **Audio**: Opus @ 48kHz, 2 channels (payload type 111)
- **Video**: VP8 @ 90kHz (payload type 96, start bitrate 1000kbps)

### Socket Emit with Acknowledgement

All MS-* events use a request-response pattern with socket.io acknowledgements. The `socketEmitWithAck()` helper wraps this in a Future with a 10-second timeout:

```dart
final response = await socketEmitWithAck('MS-get-rtp-capabilities', {
  'roomId': roomId,
});
// response: {'ok': true, 'rtpCapabilities': {...}}
```

---

## 6. Socket Events Reference

### Client -> Server Events

| Event | Payload | Purpose |
|-------|---------|---------|
| `BE-join-room` | `{userName, roomId, fullName, callType, constraints}` | Join a group call room |
| `BE-leave-room` | `{roomId, leaver}` | Leave the call |
| `call_disconnect` | `{roomId, userId}` | Safety disconnect signal |
| `BE-reject-call` | `{roomId}` | Reject incoming call |
| `BE-toggle-camera-audio` | `{roomId, switchTarget: 'audio'\|'video'}` | Toggle mic/camera state |
| `MS-get-rtp-capabilities` | `{roomId}` | Get router capabilities (ack) |
| `MS-create-transport` | `{roomId, userId, direction: 'send'\|'recv'}` | Create WebRTC transport (ack) |
| `MS-connect-transport` | `{roomId, userId, transportId, dtlsParameters}` | DTLS handshake (ack) |
| `MS-produce` | `{roomId, userId, transportId, kind, rtpParameters}` | Start producing media (ack) |
| `MS-get-producers` | `{roomId, userId}` | List existing producers (ack) |
| `MS-consume` | `{roomId, userId, producerId, rtpCapabilities}` | Subscribe to producer (ack) |

### Server -> Client Events

| Event | Payload | Purpose |
|-------|---------|---------|
| `FE-user-join` | `[{userId: socketId, info: {userName, fullName, audio, video}}]` | Users in room (presence) |
| `FE-user-leave` | `{userId, userName, roomId, joinUserCount}` | User left call |
| `FE-user-disconnected` | `{userSocketId, userName, roomId}` | User lost connection |
| `FE-call-ended` | `{roomId}` | Call terminated (no participants left) |
| `FE-toggle-camera` | `{userId, switchTarget}` | Remote user toggled media |
| `FE-leave` | `{userId, roomId, joinUserCount}` | Lighter leave notification |
| `MS-new-producer` | `{producerId, userId, kind}` | New media available to consume |
| `incomming_call` | `{roomId, groupName, callerName, callType}` | Incoming call notification |

### Important: userId Formats

- **`FE-user-join`**: `userId` = socket.id, `info.userName` = MongoDB ObjectId
- **`FE-user-leave`**: `userId` = socket.id, `userName` = MongoDB ObjectId
- **`FE-user-disconnected`**: `userSocketId` = socket.id, `userName` = MongoDB ObjectId
- **`MS-new-producer`**: `userId` = MongoDB ObjectId
- **`FE-toggle-camera`**: `userId` = socket.id

The app maps between socket.id and ObjectId using `_socketToUserMap` / `_userToSocketMap`. All internal state (renderers, streams, userInfo) is keyed by **ObjectId**.

---

## 7. Web-to-App Interoperability

### How Web and App Connect Through the Same Call

Both the React web client and Flutter app use the same backend and the same MediaSoup SFU. They are fully interoperable:

```
Web Browser (React)                    Flutter App
       │                                    │
       │── BE-join-room ──────────────────►  │◄── BE-join-room
       │                                    │
       │   mediasoup-client (JS)             │   mediasfu_mediasoup_client (Dart)
       │   Device.load()                     │   Device.load()
       │   sendTransport.produce()           │   sendTransport.produce()
       │   recvTransport.consume()           │   recvTransport.consume()
       │                                    │
       │◄── MS-new-producer (from app) ────  │
       │── MS-consume ─────────────────────►  │
       │                                    │
       │── MS-new-producer (from web) ─────►  │
       │                                    │◄── MS-consume
```

### Compatibility Notes

| Feature | Web (React) | Flutter App |
|---------|-------------|-------------|
| MediaSoup client | `mediasoup-client` npm ^3.9.2 | `mediasfu_mediasoup_client` ^0.1.3 |
| WebRTC | Browser native | `flutter_webrtc` ^1.3.0 |
| Video codec | VP8 | VP8 |
| Audio codec | Opus | Opus |
| Screen share | `getDisplayMedia()` + producer.replaceTrack | `getDisplayMedia()` + producer.replaceTrack |
| Toggle media | track.enabled + producer.pause/resume | track.enabled + producer.pause/resume |
| Recording | Server-side FFmpeg (mediasoup consumers -> RTP -> FFmpeg) | Not controlled by app |

### What Ensures Compatibility

1. **Same socket events**: Both use `BE-join-room`, `FE-user-join`, `MS-*` events
2. **Same MediaSoup router**: Both connect to the same MediaSoup router per room
3. **Same codecs**: Both use Opus audio + VP8 video
4. **Same signaling flow**: Device -> Transport -> Produce/Consume
5. **userId convention**: Both send MongoDB ObjectId as `userName` in `BE-join-room`

---

## 8. Audio Session Management

### iOS Audio Flow (Critical)

```
                    CallKit                  WebRTC               Flutter
                      │                       │                     │
User accepts call ────┤                       │                     │
                      │── didActivateAudioSession() ──────────────► │
                      │       │                                     │
                      │       ├── RTCAudioSession.audioSessionDidActivate()
                      │       └── RTCAudioSession.isAudioEnabled = true
                      │                       │                     │
                      │                       │ ◄── activateAudioSession()
                      │                       │        AudioSession.setActive(true)
                      │                       │                     │
                      │                       │ ◄── initializeMediasoup()
                      │                       │        produce(audioTrack)
                      │                       │        Audio flows ✓
```

**Without `didActivateAudioSession`** (was commented out before fix):
- CallKit activates the AVAudioSession
- But WebRTC's RTCAudioSession doesn't know about it
- Audio tracks are created but produce silence
- This is the #1 cause of "I can't hear anyone on iOS"

### Audio Session Configuration

**Flutter side** (`configureAudioSession()`):
```
Category: playAndRecord
Options:  allowBluetooth | defaultToSpeaker
Mode:     voiceChat
Android:  voiceCommunication usage, speech content type
```

**iOS native side** (`configureAudioRoute()`):
```
Category: playAndRecord
Options:  allowBluetooth | allowBluetoothA2DP | defaultToSpeaker
Mode:     voiceChat
Speaker:  overrideOutputAudioPort(.speaker) or .none
Lock:     RTCAudioSession.lockForConfiguration() to prevent WebRTC conflicts
```

### Speaker Routing

```dart
toggleSpeaker()
  └── setAudioToSpeaker(isSpeakerOn)
        ├── Helper.setSpeakerphoneOn(speakerOn)   // flutter_webrtc helper
        └── setSpeakerMode(speakerOn)             // iOS native method channel
              └── configureAudioRoute(speakerOn)  // AppDelegate.swift
                    ├── Lock RTCAudioSession
                    ├── AVAudioSession.overrideOutputAudioPort()
                    └── Unlock RTCAudioSession
```

---

## 9. Screen Sharing

### Flow: Start Screen Share

```
toggleScreenShare()
  └── startScreenShare()
        │
        ├── [Android] Helper.requestCapturePermission()  ─── User consent dialog
        ├── [Android] PlatformChannels.startScreenCaptureService()
        │       └── ScreenCaptureService.kt starts foreground service
        │           with FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
        │
        ├── getDisplayMedia({video: 1280x720@15fps})
        │
        ├── Register onEnded / onMute callbacks on screen track
        │
        ├── Save current camera track (disable, don't stop)
        │
        ├── videoProducer.replaceTrack(screenTrack)  ─── Swap on MediaSoup producer
        │       Server forwards screen capture to all consumers
        │       Web/App clients see screen share automatically
        │
        ├── localRenderer.srcObject = screenStream  ─── Show preview
        │
        ├── Start polling timer (2s interval) ─── Detect if OS stopped capture
        │
        └── CallService.setScreenSharing(true)  ─── Block system PiP
```

### Flow: Stop Screen Share

```
stopScreenShare()  (or OS stops capture)
  │
  ├── Detach onEnded/onMute callbacks
  ├── Re-enable saved camera track
  ├── videoProducer.replaceTrack(cameraTrack)  ─── Restore camera on producer
  ├── localRenderer.srcObject = localStream
  ├── [Android] PlatformChannels.stopScreenCaptureService()
  ├── Cleanup screen stream
  └── CallService.setScreenSharing(false)  ─── Allow system PiP again
```

### Why PiP is Blocked During Screen Share

On Android, entering Picture-in-Picture mode stops the `MediaProjection` (screen capture API). This kills the capture stream and can crash the app. The native `CallService` checks `isScreenSharing` before allowing PiP.

---

## 10. Video Rendering & Grid Layout

### Renderer Management

Each remote user gets:
- A `RTCVideoRenderer` (hardware video decoder)
- A `MediaStream` (container for audio + video tracks)

To prevent CPU overload with many participants, only `maxActiveRenderers` renderers are active:

| Participants | Max Active Renderers | Capture Quality |
|-------------|---------------------|-----------------|
| 1-5 | 9 | 480x360 @ 12fps |
| 6-11 | 6 | 480x360 @ 12fps |
| 8+ | (same cap) | 320x240 @ 8fps |
| 12+ | 4 | 320x240 @ 8fps |

Tapping a video tile calls `promoteRenderer(userId)` which activates that decoder (potentially evicting the oldest one).

### Grid Layout Logic

```
1 participant:  Full screen self + "Connecting to others..." spinner
2 participants: Remote full-screen + self PiP (bottom-right corner)
3-4 participants: 2-column grid
5+ participants: 3-column grid
```

Each tile shows:
- Video (if available and renderer is active)
- "Audio only" badge (if no video track)
- Mic-off icon (if remote user muted)
- User name label
- "Reconnecting..." overlay (if ICE disconnected)
- Tap to promote (activate decoder)

---

## 11. Native Platform Integration

### Android

| Component | Purpose |
|-----------|---------|
| `MainActivity.kt` | Method channels (`cuapp/call_service`, `cuapp/screen_capture`), PiP, broadcast receiver |
| `CallService.kt` | Foreground service (camera+mic+mediaPlayback type), keeps call alive in background |
| `ScreenCaptureService.kt` | Foreground service (mediaProjection type), 3s watchdog for revocation |

**Key Android behaviors:**
- `finish()` override: If a call is active, `moveTaskToBack(true)` instead of destroying activity (prevents FlutterJNI crash)
- `onUserLeaveHint()`: Auto-enters PiP when user presses Home (unless screen sharing)
- `BroadcastReceiver`: Receives events from services (end call, screen share stopped)

### iOS

| Component | Purpose |
|-----------|---------|
| `AppDelegate.swift` | VoIP push (PKPushRegistry), CallKit delegate, audio routing, PiP |

**Key iOS behaviors:**
- `didActivateAudioSession`: Bridges CallKit -> RTCAudioSession (CRITICAL for audio)
- `configureAudioRoute`: Locks RTCAudioSession before changing AVAudioSession route
- `PKPushRegistry`: Handles VoIP push for incoming calls even when app is killed
- `AVPictureInPictureController`: System PiP using runtime-based initializer

### Permissions

**Android (AndroidManifest.xml):**
```xml
CAMERA, RECORD_AUDIO, INTERNET, BLUETOOTH,
FOREGROUND_SERVICE, FOREGROUND_SERVICE_CAMERA,
FOREGROUND_SERVICE_MICROPHONE, FOREGROUND_SERVICE_MEDIA_PROJECTION,
POST_NOTIFICATIONS, SYSTEM_ALERT_WINDOW
```

**iOS (Info.plist):**
```xml
NSCameraUsageDescription, NSMicrophoneUsageDescription,
NSBluetoothAlwaysUsageDescription
UIBackgroundModes: voip, audio, remote-notification, processing, fetch
```

---

## 12. Reconnection & Error Recovery

### Socket Reconnect

When the main socket reconnects (detected by `NetworkController`):

```
Network restored → SocketController.reconnectSocket()
  → socketController.socketID changes
  → _initializeSocket() detects new socket
  → _setupSocketListener() re-registers all handlers
  → User can manually trigger reCallConnect() from retry dialog
```

### reCallConnect Flow

```
1. Save current room + video/audio state
2. cleanupCall() — full teardown (resets _mediasoupInitialized)
3. Emit BE-leave-room (tell server we left)
4. Wait 2 seconds (let server cleanup old peer)
5. Set fresh state
6. _getUserMedia() — re-acquire camera/mic
7. Emit BE-join-room — rejoin as new participant
8. activateAudioSession() — ensure audio is active
9. initializeMediasoup() — fresh SFU setup from scratch
```

### Trackless Renderer Cleanup

Every 5 seconds, `_checkForTracklessRenderers()` checks for renderers with no active audio/video tracks and no associated consumers. If a renderer stays trackless for 10+ seconds, it's removed. This handles edge cases where a user disconnected but the leave event was missed.

---

## 13. Method Reference

### GroupcallController (group_call.dart)

| Method | Description |
|--------|-------------|
| `promoteRenderer(userId)` | Activate a specific video decoder |
| `_deactivateRenderer(userId)` | Detach video from renderer |
| `_adaptQualityToNetwork()` | Auto-adjust quality based on participant count |
| `_replaceLocalVideoTrack(w,h,fps)` | Change capture resolution + update producer |
| `startScreenShare()` | Start screen capture via producer track replacement |
| `stopScreenShare()` | Stop screen capture, restore camera |
| `resolveUserId(socketId)` | Map socket.id to MongoDB ObjectId |

### GroupCallPeerExtension (group_call_peer.dart)

| Method | Description |
|--------|-------------|
| `initializeMediasoup()` | Full 6-step SFU initialization |
| `_createSendTransport(roomId, userId)` | Create send transport + event handlers |
| `_createRecvTransport(roomId, userId)` | Create recv transport + consumer callback |
| `_produceLocalTracks()` | Produce audio + video on send transport |
| `_consumeExistingProducers(roomId, userId)` | Consume all current producers in room |
| `consumeProducer(roomId, userId, producerId, remoteUserId, kind)` | Consume a single remote producer |
| `_handleConsumerTrack(userId, consumer, kind)` | Attach consumer track to renderer |
| `removeConsumersForUser(userId)` | Remove all consumers + renderer for a user |
| `cleanupMediasoup()` | Close all MediaSoup resources |

### GroupCallCallFlowExtension (group_call_call_flow.dart)

| Method | Description |
|--------|-------------|
| `outgoingCallEmit(groupId, isVideoCall)` | Start a new outgoing call |
| `joinCall(roomId, userName, userFullName, context)` | Join an existing call |
| `leaveCall(roomId, userId)` | Leave and cleanup everything |
| `reCallConnect()` | Reconnect to same room after disconnect |
| `callReject(groupId)` | Reject an incoming call |
| `cleanupCall()` | Full resource cleanup (MediaSoup + WebRTC + streams) |

### GroupCallMediaExtension (group_call_media.dart)

| Method | Description |
|--------|-------------|
| `_getUserMedia(isVideoCall)` | Acquire camera + mic MediaStream |
| `toggleMic()` | Toggle mic + pause/resume audio producer |
| `toggleCamera()` | Toggle camera + pause/resume video producer |
| `switchCamera()` | Switch front/back camera |

### GroupCallAudioExtension (group_call_audio.dart)

| Method | Description |
|--------|-------------|
| `configureAudioSession()` | One-time audio session config at init |
| `activateAudioSession()` | Activate before producing (critical on iOS) |
| `deactivateAudioSession()` | Deactivate when leaving call |
| `setSpeakerMode(speakerOn)` | iOS native speaker routing |
| `setAudioToSpeaker(speakerOn)` | Cross-platform speaker toggle |
| `toggleSpeaker()` | UI toggle for speaker mode |

### GroupCallUtilsExtension (group_call_utils.dart)

| Method | Description |
|--------|-------------|
| `socketEmitWithAck(event, data, timeout)` | Emit socket event with Future-based ack |
| `getUserFullName(userId)` | Resolve display name from multiple sources |
| `getGroupDetailsById(groupId, field)` | Fetch group details from API |

---

## 14. Troubleshooting

### "No audio on iOS after accepting via CallKit"

**Cause**: `didActivateAudioSession` was not bridging to `RTCAudioSession`.
**Fix**: In `AppDelegate.swift`, ensure:
```swift
func didActivateAudioSession(_ audioSession: AVAudioSession) {
    RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
    RTCAudioSession.sharedInstance().isAudioEnabled = true
}
```

### "Can hear but can't be heard on iOS"

**Cause**: Audio session not activated before MediaSoup produce.
**Fix**: Call `activateAudioSession()` before `initializeMediasoup()` in all entry points.

### "Audio works first call but not after rejoin"

**Cause**: `_mediasoupInitialized` not reset, so `initializeMediasoup()` skips.
**Fix**: `cleanupMediasoup()` sets `_mediasoupInitialized = false`.

### "Remote video shows but my video doesn't appear on web"

**Cause**: Video producer not created (audio-only mode) or producer paused.
**Check**: Ensure `isThisVideoCall.value == true` and `_videoProducer != null`.

### "App crashes when entering PiP during screen share"

**Cause**: Android PiP kills MediaProjection, crashing WebRTC.
**Fix**: `CallService.setScreenSharing(true)` blocks PiP entry.

### "User appears twice in the call"

**Cause**: Socket.id changed but ObjectId didn't — old entries not cleaned.
**Fix**: `FE-user-join` deduplicates by ObjectId via `_existingUserIds`.

### "Consumer track is null"

**Cause**: Recv transport not connected yet when `consume()` was called.
**Fix**: 500ms delay between recv transport creation and consuming. Consumer callback handles attachment.

### "Audio from web user is silent on app"

**Cause**: App might not be consuming the audio producer.
**Debug**: Check `MS-get-producers` response includes audio producers from the web user. Verify `consumeProducer()` is called with `kind='audio'`.

---

## Quick Reference: Call States

```
IDLE ──► CONNECTING ──► IN_CALL ──► LEAVING ──► IDLE
  │                        │           │
  │                        │           └── cleanupCall()
  │                        │                cleanupMediasoup()
  │                        │
  │                        ├── toggleMic()
  │                        ├── toggleCamera()
  │                        ├── switchCamera()
  │                        ├── toggleScreenShare()
  │                        ├── toggleSpeaker()
  │                        └── reCallConnect() ──► CONNECTING
  │
  └── callReject() ──► IDLE
```


[repositoryLink]: https://github.com/excellis-it/cu_app_web_new