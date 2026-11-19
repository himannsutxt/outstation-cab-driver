/// Values that connect this app to your website and your Firebase project.
/// They are filled in once and built into the APK. None of them is a secret.
class Config {
  /// Address of the booking website, for example https://cabs.example.com
  static const serverBase = '';

  /// Firebase Console → Project settings → Your apps → Android app.
  static const firebaseApiKey = '';
  static const firebaseAppId = '';
  static const firebaseSenderId = '';
  static const firebaseProjectId = '';

  /// Firebase Console → Authentication → Sign-in method → Google → Web client ID.
  static const googleWebClientId = '';

  /// Switched on after the Facebook app is created and added to the build.
  static const facebookReady = false;

  static bool get serverReady => serverBase.startsWith('https://');
  static bool get firebaseReady => firebaseApiKey.isNotEmpty && firebaseAppId.isNotEmpty && firebaseProjectId.isNotEmpty;
}
