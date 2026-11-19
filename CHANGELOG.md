# Driver app changelog

## 1.0.0 — 19-11-2026 (source written, not yet compiled)
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
- First compile and test on a real phone
- Stored location points when there is no network (needs a small server change to accept timestamps)
- Push notification for a new trip
- Hindi language option
- Odometer photo capture
