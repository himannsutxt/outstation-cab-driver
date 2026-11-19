"""Adds permissions, app name, launch colour and icon to the Android files that `flutter create` generates in CI."""
import re, pathlib, shutil
m = pathlib.Path('android/app/src/main/AndroidManifest.xml'); s = m.read_text()
perms = ['INTERNET', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION']
block = ''.join(f'    <uses-permission android:name="android.permission.{p}"/>\n' for p in perms if f'permission.{p}"' not in s)
block += '    <queries>\n        <intent><action android:name="android.intent.action.DIAL"/></intent>\n        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>\n    </queries>\n'
s = s.replace('    <application', block + '    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="Aravalli Cabs"', s, count=1)
m.write_text(s); print('Manifest patched')
res = pathlib.Path('android/app/src/main/res')
xml = '<?xml version="1.0" encoding="utf-8"?>\n<layer-list xmlns:android="http://schemas.android.com/apk/res/android">\n    <item><shape android:shape="rectangle"><solid android:color="#0B1736"/></shape></item>\n</layer-list>\n'
for f in res.glob('drawable*/launch_background.xml'): f.write_text(xml)
for f in pathlib.Path('ci/icon').rglob('*'):
    if f.is_file():
        dest = res / f.relative_to('ci/icon'); dest.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(f, dest)
# Firebase login needs Android 6.0 (API 23) or newer.
for g in pathlib.Path('android/app').glob('build.gradle*'):
    t = g.read_text(); t2 = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = maxOf(flutter.minSdkVersion, 23)', t); t2 = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion Math.max(flutter.minSdkVersion, 23)', t2)
    if t2 != t: g.write_text(t2); print('minSdk raised to at least 23 in', g)
print('Icon and launch colour installed')
