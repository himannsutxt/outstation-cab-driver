import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';

const ink = Color(0xFF14254A);
const blue = Color(0xFF2F6FED);
const green = Color(0xFF1FB57A);
const red = Color(0xFFEC5B6F);
const bg = Color(0xFFF4F7FC);
const line = Color(0xFFE4E9F2);
const muted = Color(0xFF6F7D95);

final api = Api();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await api.load();
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aravalli Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue, surface: Colors.white),
        scaffoldBackgroundColor: bg,
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F1B38), foregroundColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCFD7E6))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCFD7E6))),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
      ),
      home: const SplashScreen(),
    );
  }
}

void go(BuildContext c, Widget w) => Navigator.of(c).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => w), (_) => false);
void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 4)));

/// Small "i" icon that explains the field next to it when tapped.
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
      child: Row(children: [Flexible(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: ink))), Tip(tip)]),
    );

Widget card(Widget child) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)),
      child: child,
    );

// ---------------------------------------------------------------- Splash
const splashNavy = Color(0xFF0B1736);

/// Brand screen shown for two seconds when the app opens.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashState();
}

class _SplashState extends State<SplashScreen> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(seconds: 2), next);
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void next() {
    if (!mounted) return;
    go(context, api.base.isEmpty ? const SetupScreen() : (api.token.isEmpty ? const LoginScreen() : const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: splashNavy,
        body: SizedBox.expand(child: Image.asset('assets/splash.jpg', fit: BoxFit.cover, alignment: Alignment.center, semanticLabel: 'Aravalli Cabs')),
      );
}

// ---------------------------------------------------------------- Setup
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupState();
}

class _SetupState extends State<SetupScreen> {
  final ctl = TextEditingController(text: api.base);
  bool busy = false;
  String err = '';

  Future<void> save() async {
    final b = cleanServerAddress(ctl.text);
    if (b == null) return setState(() => err = 'Enter the website address given by the office. It must be an https address.');
    setState(() { busy = true; err = ''; });
    final old = api.base;
    api.base = b;
    final ok = await api.ping();
    if (!mounted) return;
    if (!ok) {
      api.base = old;
      return setState(() { busy = false; err = 'Could not reach that address. Check the spelling and your internet.'; });
    }
    await api.saveBase(b);
    if (mounted) go(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Set up')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Connect to your office', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 6),
            const Text('This is needed only once.', style: TextStyle(color: muted)),
            label('Office website address', 'The web address of the cab booking website, given to you by the office. Example: cabs.example.com'),
            TextField(controller: ctl, keyboardType: TextInputType.url, autocorrect: false, decoration: const InputDecoration(hintText: 'cabs.example.com')),
            if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, style: const TextStyle(color: red, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            Tooltip(message: 'Check the address and continue to login.', child: FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Checking…' : 'Continue'))),
          ])),
        ]),
      );
}

// ---------------------------------------------------------------- Login
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final mobile = TextEditingController(), pin = TextEditingController();
  bool busy = false;
  String err = '';

  Future<void> login() async {
    if (!validMobile(mobile.text)) return setState(() => err = 'Enter your 10-digit mobile number.');
    if (!validPin(pin.text)) return setState(() => err = 'Enter the 4 to 6 digit PIN given by the office.');
    setState(() { busy = true; err = ''; });
    final r = await api.call('api/driver/login', body: {'mobile': mobile.text.trim(), 'pin': pin.text});
    if (!mounted) return;
    if (!r.ok) return setState(() { busy = false; err = r.error; });
    await api.saveToken(r.data['token'].toString());
    if (mounted) go(context, const HomeScreen());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Driver login'), actions: [
          IconButton(tooltip: 'Change the office website address.', icon: const Icon(Icons.settings), onPressed: () => go(context, const SetupScreen())),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Mobile number', 'The mobile number you gave to the office.'),
            TextField(controller: mobile, keyboardType: TextInputType.phone, maxLength: 13, decoration: const InputDecoration(counterText: '')),
            label('PIN', 'The 4 to 6 digit PIN given by the office. Five wrong tries lock the login for 15 minutes.'),
            TextField(controller: pin, keyboardType: TextInputType.number, obscureText: true, maxLength: 6, decoration: const InputDecoration(counterText: ''), onSubmitted: (_) => login()),
            if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(err, style: const TextStyle(color: red, fontWeight: FontWeight.w600))),
            const SizedBox(height: 16),
            Tooltip(message: 'Log in to see your trips.', child: FilledButton(onPressed: busy ? null : login, child: Text(busy ? 'Logging in…' : 'Log in'))),
            const SizedBox(height: 10),
            const Text('Forgot your PIN? Call the office. Logging in here logs you out of any other phone.', style: TextStyle(color: muted, fontSize: 12)),
          ])),
        ]),
      );
}

// ---------------------------------------------------------------- Home
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> with WidgetsBindingObserver {
  Map<String, dynamic> driver = {};
  List<dynamic> trips = [];
  String supportPhone = '', gps = 'Location sharing is off.';
  int interval = 15;
  bool loading = true, busy = false;
  StreamSubscription<Position>? sub;
  Position? last;
  DateTime lastSent = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? refreshTimer, sosTimer;
  int sosLeft = 0;

  bool get onDuty => driver['on_duty'] == true;
  bool get consent => driver['tracking_consent'] == true;
  bool get running => trips.any((t) => t['status'] == 'ongoing');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) => refresh(quiet: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    refreshTimer?.cancel();
    sosTimer?.cancel();
    sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh(quiet: true);
  }

  Future<void> loggedOut() async {
    await sub?.cancel();
    sub = null;
    await api.saveToken('');
    if (mounted) go(context, const LoginScreen());
  }

  Future<void> refresh({bool quiet = false}) async {
    final r = await api.call('api/driver/me');
    if (!mounted) return;
    if (r.loggedOut) return loggedOut();
    if (r.ok) {
      setState(() {
        driver = Map<String, dynamic>.from(r.data['driver'] ?? {});
        trips = List<dynamic>.from(r.data['trips'] ?? []);
        supportPhone = (r.data['support_phone'] ?? '').toString();
        interval = int.tryParse('${r.data['track_interval']}') ?? 15;
        loading = false;
      });
      track();
    } else {
      setState(() => loading = false);
      if (!quiet) toast(context, r.error);
    }
  }

  // ---- location sharing: only on duty or on a trip, and only with consent on record at the office
  Future<void> track() async {
    final want = consent && (onDuty || running);
    if (!want) {
      if (sub != null) { await sub?.cancel(); sub = null; last = null; }
      if (mounted) setState(() => gps = consent ? 'Location sharing is off.' : 'Location sharing is not switched on for you. Please sign the consent form at the office.');
      return;
    }
    if (sub != null) return;
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => gps = 'GPS is off. Switch on Location in your phone settings.');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      if (!mounted) return;
      final agree = await showDialog<bool>(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
        title: const Text('Share your location'),
        content: const Text('This app sends your location to the office while you are on duty or on a trip, even when the app is in the background or the screen is off. It is used to show the car to the office and to the customer during the trip, and for safety. Sharing stops when you go off duty.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Not now')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 44)), onPressed: () => Navigator.pop(c, true), child: const Text('I agree'))],
      ));
      if (agree != true) { if (mounted) setState(() => gps = 'Location permission is needed while on duty.'); return; }
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (mounted) setState(() => gps = 'Location permission is blocked. Allow it in phone Settings → Apps → Aravalli Driver → Permissions.');
      return;
    }
    if (mounted) setState(() => gps = 'Getting location…');
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: Duration(seconds: interval < 5 ? 5 : interval),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Aravalli Driver is sharing your location',
        notificationText: 'You are on duty. Go off duty in the app to stop.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    sub = Geolocator.getPositionStream(locationSettings: settings).listen((p) { last = p; send(); }, onError: (_) { if (mounted) setState(() => gps = 'Cannot get location. Check that GPS is on.'); });
  }

  Future<void> send() async {
    final p = last;
    if (p == null || DateTime.now().difference(lastSent).inSeconds < 5) return;
    lastSent = DateTime.now();
    final r = await api.call('api/driver/location', body: {'lat': p.latitude, 'lng': p.longitude, 'speed': p.speed * 3.6, 'accuracy': p.accuracy});
    if (r.loggedOut) return loggedOut();
    if (!mounted) return;
    final t = TimeOfDay.now();
    setState(() => gps = r.ok ? 'Location shared at ${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}.' : r.error);
  }

  Future<void> setDuty(bool on) async {
    setState(() => busy = true);
    final r = await api.call('api/driver/duty', body: {'on': on ? 1 : 0});
    if (!mounted) return;
    setState(() => busy = false);
    if (r.loggedOut) return loggedOut();
    if (!r.ok) return toast(context, r.error);
    setState(() => driver['on_duty'] = on);
    track();
  }

  // ---- SOS with a 3-second cancel window
  void sosTap() {
    if (sosTimer != null) {
      sosTimer?.cancel();
      setState(() { sosTimer = null; sosLeft = 0; });
      toast(context, 'SOS cancelled. Nothing was sent.');
      return;
    }
    setState(() => sosLeft = 3);
    sosTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (sosLeft <= 1) { t.cancel(); setState(() { sosTimer = null; sosLeft = 0; }); sosSend(); } else { setState(() => sosLeft--); }
    });
  }

  Future<void> sosSend() async {
    Position? p = last;
    if (p == null) { try { p = await Geolocator.getLastKnownPosition(); } catch (_) {} }
    final r = await api.call('api/driver/sos', body: p == null ? {} : {'lat': p.latitude, 'lng': p.longitude});
    if (!mounted) return;
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(r.ok ? 'SOS sent' : 'SOS could not be sent'),
      content: Text(r.ok ? 'The office has been alerted and will call you. If you are in danger, call 112 now.' : '${r.error}\n\nCall 112 now.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(120, 44), backgroundColor: red), onPressed: () => launchUrl(Uri.parse('tel:112')), child: const Text('Call 112'))],
    ));
  }

  // ---- trips
  Future<void> startTrip(Map t) async {
    final otp = TextEditingController(), odo = TextEditingController();
    final go = await sheet('Start trip ${t['ref']}', [
      label('Customer start code', 'Ask the customer for the 4-digit code after they sit in the car.'),
      TextField(controller: otp, keyboardType: TextInputType.number, maxLength: 4, decoration: const InputDecoration(counterText: '')),
      label('Odometer now (km)', 'The km reading on the car meter right now.'),
      TextField(controller: odo, keyboardType: TextInputType.number, maxLength: 7, decoration: const InputDecoration(counterText: '')),
    ], 'Start trip');
    if (go != true) return;
    await tripCall('api/driver/trip/start', {'id': t['id'], 'otp': otp.text.trim(), 'odo': int.tryParse(odo.text.trim()) ?? 0}, 'Trip started. Drive safely.');
  }

  Future<void> endTrip(Map t) async {
    final odo = TextEditingController(), toll = TextEditingController(text: '0'), park = TextEditingController(text: '0'), tax = TextEditingController(text: '0');
    final go = await sheet('End trip ${t['ref']}', [
      Text('Start reading was ${t['start_odo']} km.', style: const TextStyle(color: muted)),
      label('Odometer now (km)', 'The km reading on the car meter at the end of the trip.'),
      TextField(controller: odo, keyboardType: TextInputType.number, maxLength: 7, decoration: const InputDecoration(counterText: '')),
      label('Tolls paid (₹)', 'Total toll you paid. Keep the receipts.'),
      TextField(controller: toll, keyboardType: TextInputType.number),
      label('Parking paid (₹)', 'Total parking you paid.'),
      TextField(controller: park, keyboardType: TextInputType.number),
      label('State tax paid (₹)', 'Border entry tax you paid.'),
      TextField(controller: tax, keyboardType: TextInputType.number),
    ], 'Confirm end of trip');
    if (go != true) return;
    await tripCall('api/driver/trip/finish', {'id': t['id'], 'odo': int.tryParse(odo.text.trim()) ?? 0, 'toll': num.tryParse(toll.text.trim()) ?? 0, 'parking': num.tryParse(park.text.trim()) ?? 0, 'state_tax': num.tryParse(tax.text.trim()) ?? 0}, 'Trip completed. Thank you.');
  }

  Future<void> tripCall(String route, Map<String, dynamic> body, String done) async {
    setState(() => busy = true);
    final r = await api.call(route, body: body);
    if (!mounted) return;
    setState(() => busy = false);
    if (r.loggedOut) return loggedOut();
    if (!r.ok) return toast(context, r.error);
    toast(context, done);
    await refresh(quiet: true);
  }

  Future<bool?> sheet(String title, List<Widget> fields, String action) => showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        builder: (c) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(c).viewInsets.bottom + 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ink)),
            ...fields,
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
            const SizedBox(height: 6),
            Center(child: TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel'))),
          ])),
        ),
      );

  Future<void> logout() async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text('You will go off duty and location sharing stops.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, log out'))],
    ));
    if (yes != true) return;
    await api.call('api/driver/logout', body: {});
    await loggedOut();
  }

  void open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  String nav(String q) => 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(q)}';

  Widget kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 92, child: Text(k, style: const TextStyle(color: muted, fontWeight: FontWeight.w600))), Expanded(child: Text(v, style: const TextStyle(color: ink)))]),
      );

  Widget tripCard(Map t) {
    final status = t['status'];
    final pill = status == 'ongoing' ? ['On trip', const Color(0xFF6A3FE0), const Color(0xFFF0EAFE)] : (status == 'assigned' ? ['Upcoming', const Color(0xFF2459C9), const Color(0xFFE7EFFF)] : ['Completed', const Color(0xFF11845A), const Color(0xFFE3F7EE)]);
    final mobile = (t['mobile'] ?? '').toString();
    final addr = (t['pickup_address'] ?? '').toString();
    return card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('${t['from_city']} → ${t['to_city']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: pill[2] as Color, borderRadius: BorderRadius.circular(99)), child: Text(pill[0] as String, style: TextStyle(color: pill[1] as Color, fontWeight: FontWeight.w700, fontSize: 11))),
      ]),
      const SizedBox(height: 8),
      kv('Booking', '${t['ref']} · ${t['trip_type'] == 'oneway' ? 'one way' : 'round trip, ${t['days']} day(s)'}'),
      kv('Pickup', '${t['pickup_at_text']}${addr.isEmpty ? '' : '\n$addr'}'),
      kv('Customer', '${t['customer_name']}'),
      kv('Car', '${t['reg_no'] ?? ''}'),
      if (status != 'completed') kv('To collect', '₹${(num.tryParse('${t['balance']}') ?? 0).round()} (final amount after trip end)'),
      if ((t['notes'] ?? '').toString().isNotEmpty) kv('Notes', '${t['notes']}'),
      if (status != 'completed') ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (mobile.isNotEmpty) Tooltip(message: 'Call the customer.', child: OutlinedButton.icon(onPressed: () => open('tel:$mobile'), icon: const Icon(Icons.call), label: const Text('Call customer'))),
          Tooltip(message: 'Open Google Maps with directions.', child: OutlinedButton.icon(onPressed: () => open(nav(status == 'assigned' ? '${addr.isEmpty ? '' : '$addr, '}${t['from_city']}' : '${t['to_city']}')), icon: const Icon(Icons.navigation), label: Text(status == 'assigned' ? 'Navigate to pickup' : 'Navigate to ${t['to_city']}'))),
        ]),
        const SizedBox(height: 10),
        if (status == 'assigned') Tooltip(message: 'Start the trip with the customer\'s 4-digit code and the odometer reading.', child: FilledButton(onPressed: busy ? null : () => startTrip(t), child: const Text('Start trip'))),
        if (status == 'ongoing') Tooltip(message: 'End the trip with the odometer reading and what you paid for tolls and parking.', child: FilledButton(style: FilledButton.styleFrom(backgroundColor: green), onPressed: busy ? null : () => endTrip(t), child: const Text('End trip'))),
      ],
    ]));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text((driver['name'] ?? 'My trips').toString()), actions: [
        IconButton(tooltip: 'Check for new trips now.', icon: const Icon(Icons.refresh), onPressed: () => refresh()),
        IconButton(tooltip: 'Log out and go off duty.', icon: const Icon(Icons.logout), onPressed: logout),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => refresh(),
              child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 12), children: [
                card(Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: const [Text('On duty', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)), Tip('Switch on when you are available for trips. Your location is shared with the office only while you are on duty or on a trip.')]),
                    Text(gps, style: const TextStyle(color: muted, fontSize: 12)),
                  ])),
                  Switch(value: onDuty, activeColor: green, onChanged: busy ? null : setDuty),
                ])),
                if (trips.isEmpty) card(const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: Text('No trips given to you yet.\nNew trips appear here.', textAlign: TextAlign.center, style: TextStyle(color: muted))))),
                ...trips.map((t) => tripCard(Map.from(t as Map))),
                if (supportPhone.isNotEmpty) Center(child: Tooltip(message: 'Call the office.', child: OutlinedButton.icon(onPressed: () => open('tel:+91$supportPhone'), icon: const Icon(Icons.support_agent), label: Text('Call office $supportPhone')))),
                const SizedBox(height: 8),
              ]),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Tooltip(
            message: 'Emergency only. Alerts the office with your location.',
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: sosLeft > 0 ? ink : red, minimumSize: const Size.fromHeight(58)),
              onPressed: sosTap,
              child: Text(sosLeft > 0 ? 'Sending in $sosLeft… tap to cancel' : 'SOS — EMERGENCY', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: .5)),
            ),
          ),
        ),
      ),
    );
  }
}
