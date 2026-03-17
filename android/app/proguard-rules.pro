-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

-keep class com.hivemq.** { *; }
-keep class org.hive.** { *; }

-keep class com.echoelysium.gra.models.** { *; }


-dontwarn com.google.android.play.core.**

-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# Если вдруг используете deferred components — раскомментируйте:
# dependencies {
#     implementation 'com.google.android.play:core:1.10.3'
#     implementation 'com.google.android.play:core-ktx:1.8.1'
# }
