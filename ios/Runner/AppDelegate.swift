import UIKit
import CallKit
import AVFAudio
import PushKit
import Flutter
import Firebase
import FirebaseMessaging
// import flutter_local_notifications
import flutter_callkit_incoming
import AVKit
import ReplayKit
import WebRTC

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate, CallkitIncomingAppDelegate, AVPictureInPictureControllerDelegate {
  
  private let channelName = "com.excellisit.cuapp/navigation"
  private let channelAudioName = "com.excellisit.cuapp/audiomode"
  private var callChannel: FlutterMethodChannel?
  private var screenCaptureChannel: FlutterMethodChannel?

  // iOS system PiP controller; we can use the root Flutter view as content source
  private var pipController: AVPictureInPictureController?
  private var pipIsActive = false

  // track whether a fake screen capture "service" is running (for Flutter logic)
  private var isScreenCaptureRunning = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Optional: Safely call makeSecure (if still needed)
    // self.window?.makeSecure()

    FirebaseApp.configure()
    GeneratedPluginRegistrant.register(with: self)

    // Required for background notification actions:
    // FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
    //   GeneratedPluginRegistrant.register(with: registry)
    // }

    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

  //Setup VOIP
    let mainQueue = DispatchQueue.main
    let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]

    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let navigationChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
    let audioFlutterChannel = FlutterMethodChannel(name: channelAudioName, binaryMessenger: controller.binaryMessenger)

    // setup call service channel used by CallService.dart
    callChannel = FlutterMethodChannel(name: "cuapp/call_service", binaryMessenger: controller.binaryMessenger)
    callChannel?.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "startCallService":
            // no-op on iOS, keep alive using background modes instead
            result(true)
        case "stopCallService":
            result(true)
        case "enterPip":
            self?.enterPip(result: result)
        case "setOverlayActive":
            // nothing to do natively
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

    // screen capture channel (mirrors Android API but simply holds a bool on iOS)
    screenCaptureChannel = FlutterMethodChannel(name: "cuapp/screen_capture", binaryMessenger: controller.binaryMessenger)
    screenCaptureChannel?.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "startScreenCaptureService":
            // iOS does not require a separate service; just track the flag
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
        // We can handle calls from Flutter here if needed
    })

    audioFlutterChannel.setMethodCallHandler({
        (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
        if call.method == "setSpeakerMode" {
            guard let args = call.arguments as? [String: Any],
                let isSpeakerOn = args["speakerOn"] as? Bool else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing speakerOn flag", details: nil))
                return
            }

            self.configureAudioRoute(speakerOn: isSpeakerOn)
            result(nil)
        }
    })




    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }


  // MARK: - Picture-in-Picture support

    /// Create a PiP controller using Objective-C runtime selectors.
    /// Avoids compile-time dependencies on any particular initializer.
    private func makePipController(rootView: UIView, rootVC: UIViewController) -> AVPictureInPictureController? {
        let pipClass: AnyClass = AVPictureInPictureController.self

        // helper to allocate an instance
        // allocate an instance of an Objective-C class using the "alloc" selector
        func allocateClass(_ cls: AnyClass) -> AnyObject? {
            let allocSel = NSSelectorFromString("alloc")
            if let nsCls = cls as? NSObject.Type {
                return nsCls.perform(allocSel)?.takeUnretainedValue()
            }
            return nil
        }

        if (pipClass as? NSObjectProtocol)?.responds(to: NSSelectorFromString("instancesRespondToSelector:")) == true {
            // prefer video-call initializer
            let sel1 = NSSelectorFromString("initWithActiveVideoCallSourceView:contentViewController:")
            if let obj = allocateClass(pipClass) as? NSObject,
               obj.responds(to: sel1) {
                let imp = obj.method(for: sel1)
                typealias InitFunc = @convention(c) (AnyObject, Selector, UIView, UIViewController) -> AnyObject?
                let initFunc = unsafeBitCast(imp, to: InitFunc.self)
                if let pip = initFunc(obj, sel1, rootView, rootVC) as? AVPictureInPictureController {
                    return pip
                }
            }

            // fallback to contentSource initializer; construct the content
            // source object dynamically via Objective-C runtime so that we don't
            // reference `AVPictureInPictureController.ContentSource` directly and
            // avoid availability issues.
            let sel2 = NSSelectorFromString("initWithContentSource:")
            if let obj = allocateClass(pipClass) as? NSObject,
               obj.responds(to: sel2) {
                // create an instance of AVPictureInPictureControllerContentSource
                if let csClass = NSClassFromString("AVPictureInPictureControllerContentSource") as? NSObject.Type {
                    if let csObj = allocateClass(csClass) as? NSObject {
                        let selCsInit = NSSelectorFromString("initWithSourceView:contentRect:")
                        if csObj.responds(to: selCsInit) {
                            let impCs = csObj.method(for: selCsInit)
                            typealias CsInitFunc = @convention(c) (AnyObject, Selector, UIView, CGRect) -> AnyObject?
                            let csInitFunc = unsafeBitCast(impCs, to: CsInitFunc.self)
                            if let csInstance = csInitFunc(csObj, selCsInit, rootView, rootView.bounds) {
                                let imp = obj.method(for: sel2)
                                typealias InitFunc2 = @convention(c) (AnyObject, Selector, AnyObject) -> AnyObject?
                                let initFunc2 = unsafeBitCast(imp, to: InitFunc2.self)
                                if let pip = initFunc2(obj, sel2, csInstance) as? AVPictureInPictureController {
                                    return pip
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    private func ensurePipController() {
        guard pipController == nil else { return }
        // Use the runtime-based Swift factory defined earlier. This avoids
        // any compile-time dependency on particular AVPictureInPictureController
        // initializers which may change across iOS versions.
        guard let rootVC = window?.rootViewController,
              let rootView = rootVC.view else { return }

        if let pip = makePipController(rootView: rootView, rootVC: rootVC) {
            pipController = pip
            pipController?.delegate = self
        }
    }

    private func enterPip(result: @escaping FlutterResult) {
        print("[AppDelegate] enterPip requested")
        ensurePipController()
        let supported = AVPictureInPictureController.isPictureInPictureSupported()
        print("[AppDelegate] pipController=\(String(describing: pipController)), supported=\(supported)")
        guard let pip = pipController, supported else {
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

    // delegate methods
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipIsActive = true
        callChannel?.invokeMethod("onPipStateChanged", arguments: true)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        pipIsActive = false
        callChannel?.invokeMethod("onPipStateChanged", arguments: false)
    }

  // Call this function when you want to navigate to video call
    func navigateToVideoCallScreen(extra: [String: Any]) {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }
        let navigationChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        
        navigationChannel.invokeMethod("goToVideoCall", arguments: extra)
    }

    func groupListRefresh() {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }
        let navigationChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
        
        navigationChannel.invokeMethod("groupListRefresh", arguments: nil)
        print("group list refreshed by native")
    }

    //

    func configureAudioRoute(speakerOn: Bool) {
        // Temporarily unlock the RTCAudioSession so we can change the route.
        // WebRTC's audio unit may hold the lock, preventing AVAudioSession changes.
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.lockForConfiguration()
        defer { rtcSession.unlockForConfiguration() }

        let session = AVAudioSession.sharedInstance()
        do {
            // Include .defaultToSpeaker so video calls default to speaker out of the box,
            // and .allowBluetooth / .allowBluetoothA2DP for headsets.
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

                if session.currentRoute.outputs.contains(where: { $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP }) {
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


  // Call back from Recent history
    override func application(_ application: UIApplication,
                              continue userActivity: NSUserActivity,
                              restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        
        guard let handleObj = userActivity.handle else {
            return false
        }
        
        guard let isVideo = userActivity.isVideo else {
            return false
        }
        let objData = handleObj.getDecryptHandle()
        let nameCaller = objData["nameCaller"] as? String ?? ""
        let handle = objData["handle"] as? String ?? ""
        let data = flutter_callkit_incoming.Data(id: UUID().uuidString, nameCaller: nameCaller, handle: handle, type: isVideo ? 1 : 0)
        //set more data...
        //data.nameCaller = nameCaller
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.startCall(data, fromPushKit: true)
        
        return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
    }



    // Handle updated push credentials
    func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        print(credentials.token)
        let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
        print(deviceToken)
        //Save deviceToken to your server
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
    }
    
    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("didInvalidatePushTokenFor")
        SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
    }
    
  
    
    
    
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("didReceiveIncomingPushWith")
       // guard type == .voIP else { return }
        guard type == .voIP else {
          //  if type == .background {
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
                print("Background push received - ending all CallKit calls")
          //  }
            completion()
            return
        }
        
        let id = payload.dictionaryPayload["id"] as? String ?? ""
        let nameCaller = payload.dictionaryPayload["nameCaller"] as? String ?? ""
        print("from call nameCaller: \(nameCaller)")
        let handle = payload.dictionaryPayload["handle"] as? String ?? ""
        let isVideo = payload.dictionaryPayload["isVideo"] as? Bool ?? false
        let endCall = payload.dictionaryPayload["endCall"] as? Int ?? 0
        print("Incoming call data is endcall step1 ")
        
       
        
        // Create base data object
        let data = flutter_callkit_incoming.Data(id: id, nameCaller: nameCaller, handle: handle, type: isVideo ? 1 : 0)
        
        let extra = payload.dictionaryPayload["extra"] as? [String: Any]
        let isRemoteEndCall = endCall == 1 || (extra?["msgType"] as? String == "incoming_call_ended")

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
                
                // Configure for minimal visibility
                data.duration = 100 // Very short duration (0.5 seconds)
                data.supportsVideo = false
                data.supportsDTMF = false
                data.supportsHolding = false
                data.supportsGrouping = false
                data.supportsUngrouping = false
             //   data.hasVideo = false
                
                // Create the call
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
                
                // End it immediately (within the same run loop)
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
            // Add other iOS properties as needed
        }
        
        // Set additional data
       // data.extra = ["user": "abc@123456", "platform": "ios"]

    // Set dynamic extra data if available
            if let extraPayload = payload.dictionaryPayload["extra"] as? [String: Any] {
                data.extra = extraPayload as NSDictionary
            } else {
                data.extra = [:] as NSDictionary
            }

        print("Incoming call data ios: \(data.toJSON())")


                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.showCallkitIncoming(data, fromPushKit: true)
                print("Incoming call data comes")
        
        
       
       
       
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.groupListRefresh()
           
        }
        completion()
    }
    
    
   
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
    
    
    
    
    
    // Func Call api for Accept
    func onAccept(_ call: Call, _ action: CXAnswerCallAction) {
        let json = ["action": "ACCEPT", "data": call.data.toJSON()] as [String: Any]
        print("have data on call accept \(call.data.toJSON())")
        print("LOG: onAccept")
        // make methods to go to flutter chat screen  
       // 
      
            // Navigate to video call screen via MethodChannel
            if let extra = call.data.extra as? [String: Any] {
                navigateToVideoCallScreen(extra: extra)
                print("LOG: onAccept extra \(extra)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                 // SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
                 let activeCalls = SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []
                if !activeCalls.isEmpty {
                    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
                }
                  print("LOG: calll ending")
                }
                action.fulfill()
            } else {
                action.fulfill()
            }

       
    }
    
    // Func Call API for Decline
    func onDecline(_ call: Call, _ action: CXEndCallAction) {
        let json = ["action": "DECLINE", "data": call.data.toJSON()] as [String: Any]
        print("have data on decline \(call.data.toJSON())")
        print("LOG: onDecline")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
          print("LOG: calll ending")
          
        }
        action.fulfill()

    }

    // Func Call API for End
    func onEnd(_ call: Call, _ action: CXEndCallAction) {
        let json = ["action": "END", "data": call.data.toJSON()] as [String: Any]
        print("LOG: onEnd")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
          print("LOG: calll ending")
         
        }
        action.fulfill()
       
    }
    
    // Func Call API for TimeOut
    func onTimeOut(_ call: Call) {
        let json = ["action": "TIMEOUT", "data": call.data.toJSON()] as [String: Any]
        print("LOG: onTimeOut")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
         // SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
            let activeCalls = SwiftFlutterCallkitIncomingPlugin.sharedInstance?.activeCalls() ?? []
            if !activeCalls.isEmpty {
                SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
            }
            print("LOG: calll ending")
        }
        // close notification
     //   SwiftFlutterCallkitIncomingPlugin.sharedInstance?.actionCallEnded()
    }
    
    // CRITICAL: These callbacks bridge CallKit audio session activation with WebRTC.
    // Without these, WebRTC audio tracks are silent on iOS when calls are accepted
    // via CallKit (lock screen, notification, etc.)
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
    
    func performRequest(parameters: [String: Any], completion: @escaping (Result<Any, Error>) -> Void) {
        if let url = URL(string: "https://webhook.site/e32a591f-0d17-469d-a70d-33e9f9d60727") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            //Add header
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: parameters, options: [])
                request.httpBody = jsonData
            } catch {
                completion(.failure(error))
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "mobile.app", code: 0, userInfo: [NSLocalizedDescriptionKey: "Empty data"])))
                    return
                }

                do {
                    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                    completion(.success(jsonObject))
                } catch {
                    completion(.failure(error))
                }
            }
            task.resume()
        } else {
            completion(.failure(NSError(domain: "mobile.app", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        }
    }
    
   

        // ✅ Called for background/terminated data pushes
      override func application(_ application: UIApplication,
                                didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                                fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
          // Handle "incomming_call_ended" if present anywhere in payload
         // handleIncomingCallEndedIfNeeded(userInfo)
          if let msgType = userInfo["msgType"] as? String {
              print("📩 msgType = \(msgType)")
          } else {
              print("not got exact data")
          }

          if let msgType = userInfo["msgType"] as? String {
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

        private func handleIncomingCallEndIfNeeded(_ userInfo: [AnyHashable: Any]) {
            if let msgType = userInfo["msgType"] as? String {
                print("📩 msgType foreground = \(msgType)")
                if msgType == "incomming_call_ended" {
                    print("📱 Got incoming call end")
                    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endAllCalls()
                    groupListRefresh()
                }
            } else {
                print("📱 Notification without msgType: \(userInfo)")
            }
        }

}

