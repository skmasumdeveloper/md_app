import AVFAudio
import AVKit
import CallKit
import Firebase
import FirebaseMessaging
import Flutter
import PushKit
import ReplayKit
import UIKit
import WebRTC
import flutter_callkit_incoming

@main
@objc
class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate,
    AVPictureInPictureControllerDelegate
{

    private let channelName = "com.excellisit.cuapp/navigation"
    private let channelAudioName = "com.excellisit.cuapp/audiomode"
    private var callChannel: FlutterMethodChannel?
    private var screenCaptureChannel: FlutterMethodChannel?

    // iOS system PiP controller
    private var pipController: AVPictureInPictureController?
    private var pipVideoCallVC: AVPictureInPictureVideoCallViewController?
    private var pipIsActive = false

    // track whether a fake screen capture "service" is running (for Flutter logic)
    private var isScreenCaptureRunning = false

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        FirebaseApp.configure()
        GeneratedPluginRegistrant.register(with: self)

        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()

        // Setup VOIP
        let mainQueue = DispatchQueue.main
        let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [PKPushType.voIP]

        let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
        let navigationChannel = FlutterMethodChannel(
            name: channelName, binaryMessenger: controller.binaryMessenger)
        let audioFlutterChannel = FlutterMethodChannel(
            name: channelAudioName, binaryMessenger: controller.binaryMessenger)

        // setup call service channel used by CallService.dart
        callChannel = FlutterMethodChannel(
            name: "cuapp/call_service", binaryMessenger: controller.binaryMessenger)
        callChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "startCallService":
                result(true)
            case "stopCallService":
                result(true)
            case "enterPip":
                self?.enterPip(result: result)
            case "setOverlayActive":
                result(true)
            case "setScreenSharing":
                if let active = call.arguments as? Bool {
                    self?.isScreenCaptureRunning = active
                }
                result(true)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // screen capture channel
        screenCaptureChannel = FlutterMethodChannel(
            name: "cuapp/screen_capture", binaryMessenger: controller.binaryMessenger)
        screenCaptureChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "startScreenCaptureService":
                self?.isScreenCaptureRunning = true
                result(true)
            case "stopScreenCaptureService":
                self?.isScreenCaptureRunning = false
                result(true)
            case "isScreenCaptureRunning":
                result(self?.isScreenCaptureRunning ?? false)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        navigationChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        })

        audioFlutterChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "setSpeakerMode" {
                guard let args = call.arguments as? [String: Any],
                    let isSpeakerOn = args["speakerOn"] as? Bool
                else {
                    result(
                        FlutterError(
                            code: "INVALID_ARGUMENT", message: "Missing speakerOn flag",
                            details: nil))
                    return
                }
                self.configureAudioRoute(speakerOn: isSpeakerOn)
                result(nil)
            }
        })

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // MARK: - Picture-in-Picture support (iOS 15+ official API)

    private func ensurePipController() {
        guard pipController == nil,
            AVPictureInPictureController.isPictureInPictureSupported(),
            let rootView = window?.rootViewController?.view
        else { return }

        if #available(iOS 15.0, *) {
            // AVPictureInPictureVideoCallViewController is the required type
            // for the contentViewController parameter.
            let pipVC = AVPictureInPictureVideoCallViewController()
            pipVC.preferredContentSize = CGSize(width: 360, height: 640)
            pipVC.view.backgroundColor = .black
            pipVideoCallVC = pipVC

            let contentSource = AVPictureInPictureController.ContentSource(
                activeVideoCallSourceView: rootView,
                contentViewController: pipVC
            )
            let pip = AVPictureInPictureController(contentSource: contentSource)
            pip.delegate = self
            pip.canStartPictureInPictureAutomaticallyFromInline = true
            pipController = pip
        }
    }

    private func enterPip(result: @escaping FlutterResult) {
        print("[AppDelegate] enterPip requested")
        ensurePipController()
        guard let pip = pipController,
            AVPictureInPictureController.isPictureInPictureSupported()
        else {
            print("[AppDelegate] PiP not supported or controller nil")
            result(false)
            return
        }
        if !pip.isPictureInPictureActive {
            pip.startPictureInPicture()
            result(true)
        } else {
            result(true)
        }
    }

    // PiP delegate methods
    func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        pipIsActive = true
        callChannel?.invokeMethod("onPipStateChanged", arguments: true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        pipIsActive = false
        callChannel?.invokeMethod("onPipStateChanged", arguments: false)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("[AppDelegate] PiP failed to start: \(error.localizedDescription)")
        pipIsActive = false
        callChannel?.invokeMethod("onPipStateChanged", arguments: false)
    }

    // MARK: - Navigation

    func navigateToVideoCallScreen(extra: [String: Any]) {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }
        let navigationChannel = FlutterMethodChannel(
            name: channelName, binaryMessenger: controller.binaryMessenger)
        navigationChannel.invokeMethod("goToVideoCall", arguments: extra)
    }

    func groupListRefresh() {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }
        let navigationChannel = FlutterMethodChannel(
            name: channelName, binaryMessenger: controller.binaryMessenger)
        navigationChannel.invokeMethod("groupListRefresh", arguments: nil)
        print("group list refreshed by native")
    }

    // MARK: - Audio routing

    func configureAudioRoute(speakerOn: Bool) {
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.lockForConfiguration()
        defer { rtcSession.unlockForConfiguration() }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            try session.setMode(.voiceChat)

            if speakerOn {
                try session.overrideOutputAudioPort(.speaker)
                print("[Audio] Forced audio to speaker.")
            } else {
                try session.overrideOutputAudioPort(.none)
                if session.currentRoute.outputs.contains(where: {
                    $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP
                }) {
                    print("[Audio] Bluetooth connected, routing to Bluetooth.")
                } else {
                    print("[Audio] No Bluetooth, using earpiece.")
                }
            }

            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("[Audio] Failed to configure audio route: \(error.localizedDescription)")
        }
    }

    // MARK: - Recent call history callback

    override func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard let handleObj = userActivity.handle else { return false }
        guard let isVideo = userActivity.isVideo else { return false }

        let objData = handleObj.getDecryptHandle()
        let nameCaller = objData["nameCaller"] as? String ?? ""
        let handle = objData["handle"] as? String ?? ""
        let data = flutter_callkit_incoming.Data(
            id: UUID().uuidString, nameCaller: nameCaller, handle: handle, type: isVideo ? 1 : 0)
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.startCall(data, fromPushKit: true)

        return super.application(
            application, continue: userActivity, restorationHandler: restorationHandler)
    }

    // MARK: - VoIP Push (PushKit)

    func pushRegistry(
        _ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType
    ) {
        print(credentials.token)
        let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
        print(deviceToken)
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("didInvalidatePushTokenFor")
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
    }

    func pushRegistry(
        _ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType, completion: @escaping () -> Void
    ) {
        print("didReceiveIncomingPushWith")
        guard type == .voIP else {
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
            print("Background push received - ending all CallKit calls")
            completion()
            return
        }

        let id = payload.dictionaryPayload["id"] as? String ?? ""
        let nameCaller = payload.dictionaryPayload["nameCaller"] as? String ?? ""
        print("from call nameCaller: \(nameCaller)")
        let handle = payload.dictionaryPayload["handle"] as? String ?? ""
        let isVideo = payload.dictionaryPayload["isVideo"] as? Bool ?? false
        let endCall = payload.dictionaryPayload["endCall"] as? Int ?? 0

        let data = flutter_callkit_incoming.Data(
            id: id, nameCaller: nameCaller, handle: handle, type: isVideo ? 1 : 0)

        let extra = payload.dictionaryPayload["extra"] as? [String: Any]
        let isRemoteEndCall =
            endCall == 1 || (extra?["msgType"] as? String == "incoming_call_ended")

        if isRemoteEndCall {
            print("Incoming call is being ended remotely.")

            let activeCalls = SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []
            let hasActiveCallWithId = activeCalls.contains(where: { ($0["id"] as? String) == id })

            if hasActiveCallWithId {
                print("Found active call with ID \(id). Ending it.")
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(data)
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
            } else {
                print("No active CallKit call found. Creating silent call to satisfy PushKit.")
                data.duration = 100
                data.supportsVideo = false
                data.supportsDTMF = false
                data.supportsHolding = false
                data.supportsGrouping = false
                data.supportsUngrouping = false

                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
                    data, fromPushKit: true)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(data)
                    print("Silent call ended immediately to satisfy PushKit")
                }
            }

            groupListRefresh()
            completion()
            return
        }

        // Set iOS-specific properties from payload
        if let iosPayload = payload.dictionaryPayload["ios"] as? [String: Any] {
            data.supportsVideo = iosPayload["supportsVideo"] as? Bool ?? false
            data.supportsDTMF = iosPayload["supportsDTMF"] as? Bool ?? false
            data.supportsHolding = iosPayload["supportsHolding"] as? Bool ?? false
            data.supportsGrouping = iosPayload["supportsGrouping"] as? Bool ?? false
            data.supportsUngrouping = iosPayload["supportsUngrouping"] as? Bool ?? false
            data.audioSessionActive = iosPayload["audioSessionActive"] as? Bool ?? false
        }

        if let extraPayload = payload.dictionaryPayload["extra"] as? [String: Any] {
            data.extra = extraPayload as NSDictionary
        } else {
            data.extra = [:] as NSDictionary
        }

        print("Incoming call data ios: \(data.toJSON())")
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(
            data, fromPushKit: true)
        print("Incoming call data comes")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.groupListRefresh()
        }
        completion()
    }

    // MARK: - CallKit callbacks

    func onEndCallkit() {
        print("LOG: onEndCallkit called")
        let activeCalls = SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if !activeCalls.isEmpty {
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
                print("LOG: CallKit calls ended via plugin")
            }
        }
    }

    func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
        let json = ["action": "ACCEPT", "data": call.data.toJSON()] as [String: Any]
        print("have data on call accept \(call.data.toJSON())")
        print("LOG: onAccept")

        if let extra = call.data.extra as? [String: Any] {
            navigateToVideoCallScreen(extra: extra)
            print("LOG: onAccept extra \(extra)")
            // Delay endAllCalls to give Flutter enough time to read the call data.
            // checkAndNavigationCallingPage needs ~3.5s total, so wait 5s.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                let activeCalls =
                    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []
                if !activeCalls.isEmpty {
                    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
                }
                print("LOG: call ending (delayed)")
            }
            action.fulfill()
        } else {
            action.fulfill()
        }
    }

    func onDecline(_ call: Call, _ action: CXEndCallAction) {
        print("LOG: onDecline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
            print("LOG: call ending")
        }
        action.fulfill()
    }

    func onEnd(_ call: Call, _ action: CXEndCallAction) {
        print("LOG: onEnd")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
            print("LOG: call ending")
        }
        action.fulfill()
    }

    func onTimeOut(_ call: Call) {
        print("LOG: onTimeOut")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let activeCalls = SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []
            if !activeCalls.isEmpty {
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
            }
            print("LOG: call ending")
        }
    }

    // MARK: - WebRTC Audio Session bridging

    func didActivateAudioSession(_ audioSession: AVAudioSession) {
        print("[AppDelegate] didActivateAudioSession — enabling RTCAudioSession")
        RTCAudioSession.sharedInstance().audioSessionDidActivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = true
    }

    func didDeactivateAudioSession(_ audioSession: AVAudioSession) {
        print("[AppDelegate] didDeactivateAudioSession — disabling RTCAudioSession")
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = false
    }

    // MARK: - Background remote notifications

    override func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let msgType = userInfo["msgType"] as? String {
            print("📩 msgType = \(msgType)")
            if msgType == "incomming_call_ended" {
                print("📱 Got incoming call end")
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
                groupListRefresh()
            } else {
                print("📱 Got background notification → \(msgType)")
            }
        } else {
            print("📱 Background remote notification (no msgType): \(userInfo)")
        }
        completionHandler(.newData)
    }
}
