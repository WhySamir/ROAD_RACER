# Android APK export (Godot 4)

## 1. Install Android dependencies

1. Install Android Studio.
2. In SDK Manager, install Android SDK Platform 35 (or the platform supported by your Godot version), Android SDK Build-Tools, Platform-Tools, and Command-line Tools.
3. Install a supported full JDK. JDK 17 is the usual choice for Godot 4.
4. In Godot, open **Editor > Editor Settings > Export > Android** and set:
   - **Android SDK Path**: for example `C:\Users\<you>\AppData\Local\Android\Sdk`
   - **Java SDK Path**: for example `C:\Program Files\Java\jdk-17`

## 2. Create a debug keystore

Godot can use its default debug keystore. If one is missing, create one with:

```text
keytool -genkeypair -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
```

Keep production signing keys out of the repository.

## 3. Create the export preset

1. Open **Project > Export**.
2. Click **Add... > Android** and name it `Android Debug`.
3. Set a lowercase package name such as `com.whysamir.roadracer`.
4. Set the version name and version code.
5. Set screen orientation to **Portrait**.
6. Set minimum SDK to **Android 6.0 / API 23** or newer.
7. Leave debug enabled and use the debug keystore alias `androiddebugkey` with password `android`.
8. Click **Export Project** and choose an `.apk` output path.

The command-line equivalent after creating the preset is:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path . --export-debug "Android Debug" RoadRacer-debug.apk
```

## Common errors

- **Invalid Android SDK path**: select the SDK root containing `platform-tools`, `platforms`, and `build-tools`.
- **Java SDK not found**: use a full JDK 17, not a JRE, and update the Java SDK path.
- **Missing platform/build-tools**: install the exact versions named in the export error.
- **Keystore error**: verify the alias/password match the keystore (`androiddebugkey` / `android`).
- **Invalid package name**: use lowercase dot-separated names such as `com.example.roadracer`.
- **ADB device not found**: enable USB debugging, authorize the device, then run `adb devices`.
- **Black or rotated APK**: verify Portrait orientation and the Compatibility renderer.
- **Export template missing**: install Android templates from **Editor > Manage Export Templates**.
