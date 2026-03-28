import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

// This class provides the default Firebase options for different platforms.
// This required and can not be set on .env because it is used by the Firebase CLI to configure the app.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
      apiKey: "AIzaSyA-RY88TDcTkL96V8rQPugnJ9O8CK7qR7o",
      authDomain: "cu-app-6e0b5.firebaseapp.com",
      projectId: "cu-app-6e0b5",
      storageBucket: "cu-app-6e0b5.firebasestorage.app",
      messagingSenderId: "964360348529",
      appId: "1:964360348529:web:40958a3636642671faccd0",
      measurementId: "G-2J2N5P3D44");

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDBQ3uXK4vIi29JfeJdnRRly6saQ114XWU',
    appId: '1:964360348529:android:2ea480b9c0ead5b0faccd0',
    messagingSenderId: '964360348529',
    projectId: 'cu-app-6e0b5',
    storageBucket: 'cu-app-6e0b5.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCj9zxN0Qb13FxmVYTcsEopdFowUzEnqbY',
    appId: '1:964360348529:ios:2a1576ccee0338c7faccd0',
    messagingSenderId: '964360348529',
    projectId: 'cu-app-6e0b5',
    storageBucket: 'cu-app-6e0b5.firebasestorage.app',
    iosBundleId: 'com.excellisit.cuapp',
  );
}
