# Aravalli Cabs customer app changelog

## 0.1.0 — 20-11-2026 (first build; not yet connected or run on a phone)
### Built
- Splash screen and login screen as designed: Google, Facebook, mobile number
- Google login and mobile OTP login through Firebase
- Book tab: trip type, from, to with popular places, date, time, days, fares for each car type, passenger details, booking or quote request
- My trips: list with filter and sort, pull to refresh
- Booking screen: status steps, advance or balance to pay, driver and call button, trip start code, live map, family share link, SOS with 3-second cancel, Call 112, fare lines, invoice
- Account: name, mobile, help, policies, log out
- Tooltips on every field and button
### Pending
- Website address and Firebase values in `lib/config.dart` (the app cannot log in until these are filled)
- Facebook login (needs a Facebook developer app; the button currently explains it is coming soon)
- Payment inside the app (today it opens the secure web payment page)
- Cancel or reschedule from the app
- Push notifications for driver assigned and trip started
- iPhone build
- Test on a real phone
