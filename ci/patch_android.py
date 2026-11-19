"""Adds the permissions and app name to the Android files that `flutter create` generates in CI."""
import re, pathlib
m = pathlib.Path('android/app/src/main/AndroidManifest.xml'); s = m.read_text()
perms = ['INTERNET', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'FOREGROUND_SERVICE', 'FOREGROUND_SERVICE_LOCATION', 'POST_NOTIFICATIONS', 'WAKE_LOCK']
block = ''.join(f'    <uses-permission android:name="android.permission.{p}"/>\n' for p in perms if f'permission.{p}"' not in s)
block += '    <queries>\n        <intent><action android:name="android.intent.action.DIAL"/></intent>\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n    </queries>\n'
s = s.replace('    <application', block + '    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Cab Driver"', s, count=1)
m.write_text(s)
print('Manifest patched')

# Dark navy launch background, so there is no white flash before the splash image appears.
xml = '<?xml version="1.0" encoding="utf-8"?>\n<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n    <item><shape android:shape="rectangle"><solid android:color="#0B1736"/></shape></item>\n</layer-list>\n'
for f in pathlib.Path('android/app/src/main/res').glob('drawable*/launch_background.xml'):
    f.write_text(xml); print('Launch background set:', f)
