# Keep/ignore optional classes referenced by Jackson/OkHttp on Android
-dontwarn java.beans.**
-dontwarn org.w3c.dom.bootstrap.**
-dontwarn org.conscrypt.**

# Keep Jackson annotations and core classes
-keepclassmembers class * {
    @com.fasterxml.jackson.annotation.* *;
}
-keep class com.fasterxml.jackson.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep device_calendar plugin classes
-keep class com.builttoroam.devicecalendar.** { *; }
-dontwarn com.builttoroam.devicecalendar.**

# Flutter WebRTC
-keep class com.cloudwebrtc.webrtc.** { *; }
-keep class org.webrtc.** { *; }
-keep class org.jni_zero.** { *; }