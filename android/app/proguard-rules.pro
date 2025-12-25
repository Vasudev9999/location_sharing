# ProGuard rules for location_sharing app

# Keep all Flutter-related code
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep all Firebase classes
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep Google Maps classes
-keep class com.google.maps.** { *; }
-keep class com.google.android.maps.** { *; }

# Keep all native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom application classes
-keep class com.example.myproject.** { *; }

# Keep location plugin classes
-keep class com.lyokone.location.** { *; }
-keep class android.location.** { *; }

# Keep permission handler classes
-keep class com.baseflow.permissionhandler.** { *; }

# Keep Serializable classes
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Remove logging in release builds
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Keep model classes that might be reflected
-keepclassmembers class ** {
    @com.google.firebase.database.Exclude <fields>;
    @com.google.firebase.database.PropertyName <methods>;
}

# Preserve line numbers for crash reporting
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
