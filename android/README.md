# Android

Native Kotlin and Jetpack Compose app. The Android project is separate from the root iOS project and is excluded from the XcodeGen target.

## Build

GitHub Actions uses Java 17 and Gradle to build `app/build/outputs/apk/release/app-release.apk`. The workflow also publishes the APK next to the iOS IPA in each default-branch GitHub Release.

For local builds with Android SDK and Gradle installed:

```sh
gradle assembleRelease
```

`GoogleService-Info.plist` must be in the repository root. The Android Gradle build reads its Firebase `API_KEY` and `DATABASE_URL` values; no separate Android Firebase app registration or `google-services.json` is needed.

## Persistent APK updates

The workflow uses a persistent keystore when all four repository Actions secrets are set: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. Without them, it signs APKs with the runner's debug key, which is installable but can require uninstalling the previous APK before updating.
