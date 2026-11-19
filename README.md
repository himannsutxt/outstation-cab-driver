# Cab Driver (Android)

Flutter app for drivers of the Outstation Cab system. It talks to the website's driver API.

## Get the APK
Every push to `main` builds the APK with GitHub Actions. Download it from the repository's **Releases** page, or from the run's **Artifacts**.

## First use on a phone
1. Install the APK (allow "install from this source" when asked).
2. Enter the office website address once.
3. Log in with the mobile number and PIN set under Admin → Drivers.
4. Switch **On duty** and allow location. For reliable tracking, set battery use for the app to "Unrestricted".

The `android/` folder is generated during the build, so it is not stored here. `ci/debug.keystore` is the signing key: keep this repository private.
