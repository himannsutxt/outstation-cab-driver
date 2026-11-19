import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'config.dart';
import 'screens.dart';

const navy = Color(0xFF0B1736);
const orange = Color(0xFFF7941D);
const blue = Color(0xFF2F6FED);
const green = Color(0xFF1FB57A);
const red = Color(0xFFEC5B6F);
const bg = Color(0xFFF4F7FC);
const line = Color(0xFFDCE2EE);
const muted = Color(0xFF4A5672);

final api = Api();
Map<String, dynamic> appConfig = {};
Map<String, dynamic> customer = {};
bool firebaseUp = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await api.load();
  if (Config.firebaseReady) {
    try {
      await Firebase.initializeApp(options: const FirebaseOptions(apiKey: Config.firebaseApiKey, appId: Config.firebaseAppId, messagingSenderId: Config.firebaseSenderId, projectId: Config.firebaseProjectId));
      firebaseUp = true;
    } catch (_) {
      firebaseUp = false;
    }
  }
  runApp(const CabsApp());
}

class CabsApp extends StatelessWidget {
  const CabsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Aravalli Cabs',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: orange, surface: Colors.white),
          scaffoldBackgroundColor: bg,
          appBarTheme: const AppBarTheme(backgroundColor: navy, foregroundColor: Colors.white),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFC9D1E0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFC9D1E0))),
          ),
          filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        ),
        home: const SplashScreen(),
      );
}

void go(BuildContext c, Widget w) => Navigator.of(c).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => w), (_) => false);
void push(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 4)));
void openUrl(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

/// Small "i" icon that explains the item next to it when tapped.
class Tip extends StatelessWidget {
  final String text;
  const Tip(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Tooltip(
        message: text,
        triggerMode: TooltipTriggerMode.tap,
        showDuration: const Duration(seconds: 6),
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.info_outline, size: 18, color: blue)),
      );
}

Widget label(String text, String tip) => Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Row(children: [Flexible(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: navy))), Tip(tip)]),
    );

Widget card(Widget child, {EdgeInsets? padding}) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: child,
    );

Future<void> logoutLocal(BuildContext context) async {
  await api.saveToken('');
  customer = {};
  if (firebaseUp) {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
  if (context.mounted) go(context, const LoginScreen());
}

// ---------------------------------------------------------------- Splash
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    final wait = Future.delayed(const Duration(seconds: 2));
    final cfg = await api.get('api/app/config');
    if (cfg.ok) appConfig = cfg.data;
    var loggedIn = false;
    if (api.token.isNotEmpty) {
      final me = await api.get('api/app/me');
      if (me.ok) {
        customer = Map<String, dynamic>.from(me.data['customer'] ?? {});
        loggedIn = true;
      } else if (me.loggedOut) {
        await api.saveToken('');
      } else {
        loggedIn = true; // no network right now: keep the session and let the screens retry
      }
    }
    await wait;
    if (mounted) go(context, loggedIn ? const HomeScreen() : const LoginScreen());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: navy,
        body: SizedBox.expand(child: Image.asset('assets/splash.jpg', fit: BoxFit.cover, semanticLabel: 'Aravalli Cabs')),
      );
}

// ---------------------------------------------------------------- Login
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  bool busy = false;
  String err = '';

  String get setupMessage {
    if (!Config.serverReady) return 'This app is not connected to the booking website yet.';
    if (!firebaseUp) return 'Login is being set up. Please check back soon.';
    return '';
  }

  /// Sends the Firebase proof of login to our server and opens the app.
  Future<void> finish(User? user) async {
    final idToken = await user?.getIdToken();
    if (idToken == null) return fail('Login did not complete. Please try again.');
    final r = await api.post('api/app/login', {'id_token': idToken});
    if (!r.ok) return fail(r.error);
    await api.saveToken(r.data['token'].toString());
    customer = Map<String, dynamic>.from(r.data['customer'] ?? {});
    if (mounted) go(context, const HomeScreen());
  }

  void fail(String m) {
    if (mounted) setState(() { busy = false; err = m; });
  }

  Future<void> google() async {
    if (setupMessage.isNotEmpty) return fail(setupMessage);
    setState(() { busy = true; err = ''; });
    try {
      final g = GoogleSignIn(serverClientId: Config.googleWebClientId.isEmpty ? null : Config.googleWebClientId, scopes: const ['email']);
      final acc = await g.signIn();
      if (acc == null) return fail('');
      final a = await acc.authentication;
      final uc = await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken));
      await finish(uc.user);
    } catch (_) {
      fail('Google login did not work. Please try again or use your mobile number.');
    }
  }

  void facebook() {
    if (setupMessage.isNotEmpty) return fail(setupMessage);
    fail('Facebook login will be switched on soon. Please use Google or your mobile number for now.');
  }

  void mobile() {
    if (setupMessage.isNotEmpty) return fail(setupMessage);
    setState(() => err = '');
    push(context, PhoneLoginScreen(onDone: finish));
  }

  Widget badge(String letter, Color fg, Color bgc, {bool border = false}) => Container(
        width: 26, height: 26, alignment: Alignment.center,
        decoration: BoxDecoration(color: bgc, shape: BoxShape.circle, border: border ? Border.all(color: const Color(0xFFC9D1E0), width: 1.5) : null),
        child: Text(letter, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final heroH = w * 1030 / 852;
    final note = err.isNotEmpty ? err : setupMessage;
    return Scaffold(
      backgroundColor: navy,
      body: Stack(children: [
        Positioned(top: 0, left: 0, right: 0, height: heroH, child: Image.asset('assets/login-hero.jpg', fit: BoxFit.cover, semanticLabel: 'Aravalli Cabs. Ride Smart, Travel Easy.')),
        Positioned.fill(
          top: (heroH - 67).clamp(160.0, MediaQuery.of(context).size.height * 0.55).toDouble(),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Welcome aboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: navy)),
                  const SizedBox(height: 4),
                  const Text('Log in or sign up to book your outstation cab.', style: TextStyle(fontSize: 14, color: muted, fontWeight: FontWeight.w500)),
                  if (note.isNotEmpty) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(10)), child: Text(note, style: const TextStyle(color: Color(0xFF8A5200), fontWeight: FontWeight.w600))),
                  const SizedBox(height: 18),
                  Tooltip(message: 'Log in with your Google account. We receive only your name and email.', child: OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: const BorderSide(color: Color(0xFFC9D1E0), width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), foregroundColor: navy),
                    onPressed: busy ? null : google,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [badge('G', navy, Colors.white, border: true), const SizedBox(width: 12), const Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))]),
                  )),
                  const SizedBox(height: 12),
                  Tooltip(message: 'Log in with your Facebook account.', child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1565D8)),
                    onPressed: busy ? null : facebook,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [badge('f', const Color(0xFF1565D8), Colors.white), const SizedBox(width: 12), const Text('Continue with Facebook')]),
                  )),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Row(children: [Expanded(child: Divider(color: line)), Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600))), Expanded(child: Divider(color: line))])),
                  Tooltip(message: 'Log in with a one-time code sent by SMS to your mobile number.', child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: orange, foregroundColor: navy),
                    onPressed: busy ? null : mobile,
                    icon: const Icon(Icons.smartphone),
                    label: const Text('Continue with mobile number'),
                  )),
                  const SizedBox(height: 16),
                  Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    const Text('By continuing you accept our ', style: TextStyle(fontSize: 12, color: muted)),
                    InkWell(onTap: () => openLink('terms_url'), child: const Text('Terms', style: TextStyle(fontSize: 12, color: navy, decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                    const Text(' and ', style: TextStyle(fontSize: 12, color: muted)),
                    InkWell(onTap: () => openLink('privacy_url'), child: const Text('Privacy Policy', style: TextStyle(fontSize: 12, color: navy, decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
                  ]),
                ]),
              ),
            ),
          ),
        ),
        if (busy) const Positioned.fill(child: ColoredBox(color: Color(0x660B1736), child: Center(child: CircularProgressIndicator(color: Colors.white)))),
      ]),
    );
  }
}

void openLink(String key) {
  final u = (appConfig[key] ?? '').toString();
  if (u.startsWith('https://')) openUrl(u);
}

// ---------------------------------------------------------------- Mobile OTP login
class PhoneLoginScreen extends StatefulWidget {
  final Future<void> Function(User?) onDone;
  const PhoneLoginScreen({super.key, required this.onDone});
  @override
  State<PhoneLoginScreen> createState() => _PhoneState();
}

class _PhoneState extends State<PhoneLoginScreen> {
  final mobile = TextEditingController(), code = TextEditingController();
  String verificationId = '', err = '';
  bool busy = false;

  Future<void> sendCode() async {
    if (!validMobile(mobile.text)) return setState(() => err = 'Enter your 10-digit mobile number.');
    setState(() { busy = true; err = ''; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91${cleanMobile(mobile.text)}',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          try {
            final uc = await FirebaseAuth.instance.signInWithCredential(cred);
            await done(uc.user);
          } catch (_) {}
        },
        verificationFailed: (e) { if (mounted) setState(() { busy = false; err = e.code == 'too-many-requests' ? 'Too many tries. Please wait a while and try again.' : 'Could not send the code. Check the number and try again.'; }); },
        codeSent: (id, _) { if (mounted) setState(() { verificationId = id; busy = false; }); },
        codeAutoRetrievalTimeout: (id) { verificationId = id; },
      );
    } catch (_) {
      if (mounted) setState(() { busy = false; err = 'Could not send the code. Please try again.'; });
    }
  }

  Future<void> verify() async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.text.trim())) return setState(() => err = 'Enter the 6-digit code from the SMS.');
    setState(() { busy = true; err = ''; });
    try {
      final uc = await FirebaseAuth.instance.signInWithCredential(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code.text.trim()));
      await done(uc.user);
    } catch (_) {
      if (mounted) setState(() { busy = false; err = 'That code is not right or has expired.'; });
    }
  }

  Future<void> done(User? u) async {
    if (!mounted) return;
    Navigator.of(context).pop();
    await widget.onDone(u);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mobile login')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Mobile number', 'Your 10-digit Indian mobile number. We send a one-time code by SMS to check it is yours.'),
            TextField(controller: mobile, enabled: verificationId.isEmpty, keyboardType: TextInputType.phone, maxLength: 13, decoration: const InputDecoration(counterText: '', prefixText: '+91 ')),
            if (verificationId.isNotEmpty) ...[
              label('Code from SMS', 'The 6-digit code we just sent. It is valid for a few minutes.'),
              TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, autofocus: true, decoration: const InputDecoration(counterText: ''), onSubmitted: (_) => verify()),
            ],
            if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, style: const TextStyle(color: Color(0xFFC2304A), fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            if (verificationId.isEmpty) Tooltip(message: 'Send a one-time code to this number by SMS.', child: FilledButton(onPressed: busy ? null : sendCode, child: Text(busy ? 'Sending…' : 'Send code')))
            else ...[
              Tooltip(message: 'Check the code and log in.', child: FilledButton(onPressed: busy ? null : verify, child: Text(busy ? 'Checking…' : 'Verify and continue'))),
              Center(child: Tooltip(message: 'Go back and enter a different mobile number.', child: TextButton(onPressed: busy ? null : () => setState(() { verificationId = ''; code.clear(); err = ''; }), child: const Text('Change number')))),
            ],
          ])),
        ]),
      );
}
