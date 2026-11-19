# Driver app changelog

## 1.0.3 — 20-11-2026
### Built
- Aravalli Cabs app icon (classic and adaptive, so it fits round and square phone icon shapes)

## 1.0.2 — 19-11-2026
### Built
- App renamed to Aravalli Driver (phone label, title, tracking notification); APK file is now aravalli-driver-vX.apk

## 1.0.1 — 19-11-2026
### Built
- Aravalli Cabs splash screen shown for two seconds when the app opens
- Dark navy launch background, so there is no white flash before the splash

## 1.0.0 — 19-11-2026 (compiles and passes unit tests in GitHub Actions; not yet run on a phone)
### Built
- One-time office address setup with connection check
- Login with mobile + PIN, one phone at a time
- On duty switch; location sharing through an Android foreground service, so it keeps running in the background and with the screen off
- Consent screen before the location permission is requested
- Trips: call customer, navigate, start with customer code + odometer, end with odometer, tolls, parking and state tax
- SOS with a 3-second cancel window and a Call 112 button
- Tooltips on every field and button
- APK built by GitHub Actions with a fixed signing key, so new versions install over old ones
### Pending
- Test on a real phone (login, tracking with screen off, trip start and end, SOS)
- Smaller download: build one APK per phone type instead of one 51 MB file
- Stored location points when there is no network (needs a small server change to accept timestamps)
- Push notification for a new trip
- Hindi language option
- Odometer photo capture
