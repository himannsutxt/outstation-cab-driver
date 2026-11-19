import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'api.dart';
import 'main.dart';

String two(int n) => n.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';
String dmy(DateTime d) => '${two(d.day)}-${two(d.month)}-${d.year}';
String hm(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';
List<String> strings(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];

Widget statusPill(String s) {
  const map = {
    'enquiry': ['Enquiry', Color(0xFF5B6880), Color(0xFFEEF1F6)], 'pending': ['Pay to confirm', Color(0xFF8A5200), Color(0xFFFFF3E0)], 'confirmed': ['Confirmed', Color(0xFF2459C9), Color(0xFFE7EFFF)],
    'assigned': ['Driver assigned', Color(0xFF6A3FE0), Color(0xFFF0EAFE)], 'ongoing': ['On trip', Color(0xFF6A3FE0), Color(0xFFF0EAFE)], 'completed': ['Completed', Color(0xFF11845A), Color(0xFFE3F7EE)], 'cancelled': ['Cancelled', Color(0xFFC2304A), Color(0xFFFDE8EC)],
  };
  final m = map[s] ?? [s, muted, const Color(0xFFEEF1F6)];
  return Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: m[2] as Color, borderRadius: BorderRadius.circular(99)), child: Text(m[0] as String, style: TextStyle(color: m[1] as Color, fontWeight: FontWeight.w700, fontSize: 11)));
}

// ---------------------------------------------------------------- Home (tabs)
class HomeScreen extends StatefulWidget {
  final int tab;
  const HomeScreen({super.key, this.tab = 0});
  @override
  State<HomeScreen> createState() => _HomeState();
}

class _HomeState extends State<HomeScreen> {
  late int tab = widget.tab;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(['Book a cab', 'My trips', 'Account'][tab])),
        body: [const SearchTab(), const TripsTab(), const AccountTab()][tab],
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.local_taxi_outlined), selectedIcon: Icon(Icons.local_taxi), label: 'Book', tooltip: 'Search fares and book an outstation cab.'),
            NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'My trips', tooltip: 'Your bookings, live tracking and SOS.'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account', tooltip: 'Your details, help and log out.'),
          ],
        ),
      );
}

// ---------------------------------------------------------------- Search
class SearchTab extends StatefulWidget {
  const SearchTab({super.key});
  @override
  State<SearchTab> createState() => _SearchState();
}

class _SearchState extends State<SearchTab> {
  String tripType = 'round';
  String? from;
  final to = TextEditingController(), days = TextEditingController(text: '1');
  DateTime date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay time = const TimeOfDay(hour: 7, minute: 0);
  bool busy = false;

  @override
  void initState() {
    super.initState();
    if (appConfig.isEmpty) loadConfig();
  }

  Future<void> loadConfig() async {
    final r = await api.get('api/app/config');
    if (r.ok && mounted) setState(() => appConfig = r.data);
  }

  Future<void> search() async {
    final cities = strings(appConfig['cities']);
    final f = from ?? (cities.isNotEmpty ? cities.first : '');
    if (to.text.trim().isEmpty) return toast(context, 'Please enter where you want to go.');
    setState(() => busy = true);
    final trip = {'from': f, 'to': to.text.trim(), 'trip_type': tripType, 'date': ymd(date), 'time': hm(time), 'days': tripType == 'oneway' ? '1' : (int.tryParse(days.text) ?? 1).clamp(1, 60).toString()};
    final r = await api.get('api/app/quote', trip);
    if (!mounted) return;
    setState(() => busy = false);
    if (r.loggedOut) return logoutLocal(context);
    if (!r.ok) return toast(context, r.error);
    push(context, QuotesScreen(trip: Map<String, dynamic>.from(r.data['trip'] ?? {}), quotes: List<dynamic>.from(r.data['quotes'] ?? [])));
  }

  @override
  Widget build(BuildContext context) {
    final cities = strings(appConfig['cities']);
    final dests = strings(appConfig['destinations']);
    return ListView(padding: const EdgeInsets.all(14), children: [
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Trip type', style: TextStyle(fontWeight: FontWeight.w600, color: navy)),
          const Tip('Round trip: the car and driver stay with you and bring you back. One way: drop only.'),
        ]),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'round', label: Text('Round trip')), ButtonSegment(value: 'oneway', label: Text('One way'))],
          selected: {tripType},
          onSelectionChanged: (s) => setState(() => tripType = s.first),
        ),
        label('From', 'City where we pick you up.'),
        DropdownButtonFormField<String>(
          value: cities.contains(from) ? from : (cities.isNotEmpty ? cities.first : null),
          items: cities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => from = v),
        ),
        label('To', 'Where you want to go. Pick a popular place below for an instant fare, or type any other place and we will call you with a quote.'),
        TextField(controller: to, textCapitalization: TextCapitalization.words, maxLength: 80, decoration: const InputDecoration(counterText: '', hintText: 'Jaipur, Agra, Shimla…')),
        if (dests.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 6, runSpacing: 2, children: dests.take(14).map((d) => ActionChip(label: Text(d), tooltip: 'Set destination to $d.', onPressed: () => setState(() => to.text = d))).toList())),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Pickup date', 'Day you want to start.'),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), alignment: Alignment.centerLeft),
              icon: const Icon(Icons.calendar_today, size: 18), label: Text(dmy(date)),
              onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))); if (d != null) setState(() => date = d); },
            ),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Time', 'Pickup time. A night charge applies for late-night pickups.'),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), alignment: Alignment.centerLeft),
              icon: const Icon(Icons.schedule, size: 18), label: Text(time.format(context)),
              onPressed: () async { final t = await showTimePicker(context: context, initialTime: time); if (t != null) setState(() => time = t); },
            ),
          ])),
        ]),
        if (tripType == 'round') ...[
          label('Days', 'How many days you need the car.'),
          TextField(controller: days, keyboardType: TextInputType.number, maxLength: 2, decoration: const InputDecoration(counterText: '')),
        ],
        const SizedBox(height: 16),
        Tooltip(message: 'Show fares for every car type. No payment yet.', child: FilledButton(onPressed: busy ? null : search, child: Text(busy ? 'Getting fares…' : 'See fares'))),
      ])),
      card(const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Why(Icons.verified_user_outlined, 'Verified drivers', 'Licence and police verification checked before a driver gets a trip.'),
        _Why(Icons.receipt_long_outlined, 'Fare shown upfront', 'Per-km rate, driver allowance and GST listed before you pay.'),
        _Why(Icons.share_location_outlined, 'Live tracking', 'Share one link and your family can follow the car.'),
        _Why(Icons.sos_outlined, 'Emergency button', 'One press alerts our team with your location.'),
      ])),
    ]);
  }
}

class _Why extends StatelessWidget {
  final IconData icon;
  final String title, text;
  const _Why(this.icon, this.title, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: orange), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: navy)), Text(text, style: const TextStyle(color: muted, fontSize: 13))]))]),
      );
}

// ---------------------------------------------------------------- Quotes + passenger details
class QuotesScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  final List<dynamic> quotes;
  const QuotesScreen({super.key, required this.trip, required this.quotes});
  @override
  State<QuotesScreen> createState() => _QuotesState();
}

class _QuotesState extends State<QuotesScreen> {
  int? carId;
  final name = TextEditingController(text: (customer['name'] ?? '').toString()), mobile = TextEditingController(text: (customer['mobile'] ?? '').toString());
  final address = TextEditingController(), emergency = TextEditingController(), notes = TextEditingController();
  bool agree = false, busy = false;
  bool get otpVerified => customer['provider'] == 'phone' && (customer['mobile'] ?? '').toString().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.quotes.isNotEmpty) carId = widget.quotes.first['car_type_id'] as int?;
    final cars = appConfig['cars'];
    if (carId == null && cars is List && cars.isNotEmpty) carId = cars.first['id'] as int?;
  }

  Future<void> book() async {
    if (name.text.trim().length < 2) return toast(context, 'Please enter the passenger name.');
    if (!validMobile(mobile.text)) return toast(context, 'Please enter a valid 10-digit mobile number.');
    if (emergency.text.trim().isNotEmpty && !validMobile(emergency.text)) return toast(context, 'Emergency contact must be a valid 10-digit mobile number.');
    if (!agree) return toast(context, 'Please accept the terms and cancellation policy.');
    setState(() => busy = true);
    final t = widget.trip;
    final r = await api.post('api/app/book', {
      'from_city': t['from_city'], 'to_city': t['to_city'], 'trip_type': t['trip_type'], 'days': t['days'], 'pickup_at': t['pickup_at'], 'car_type_id': carId ?? 0,
      'customer_name': name.text.trim(), 'mobile': cleanMobile(mobile.text), 'email': (customer['email'] ?? '').toString(), 'pickup_address': address.text.trim(), 'emergency_mobile': cleanMobile(emergency.text), 'notes': notes.text.trim(), 'agree': 1,
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (r.loggedOut) return logoutLocal(context);
    if (!r.ok) return toast(context, r.error);
    final id = (r.data['booking']?['id'] ?? 0) as int;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen(tab: 1)), (_) => false);
    push(context, BookingScreen(id: id));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final has = widget.quotes.isNotEmpty;
    final cars = appConfig['cars'] is List ? List<dynamic>.from(appConfig['cars']) : <dynamic>[];
    return Scaffold(
      appBar: AppBar(title: Text('${t['from_city']} to ${t['to_city']}')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${t['trip_type'] == 'oneway' ? 'One way' : 'Round trip, ${t['days']} day(s)'} · Pickup ${t['date'].toString().split('-').reversed.join('-')} ${t['time']}', style: const TextStyle(color: muted))),
        if (has) ...[
          Row(children: const [Text('1. Choose your car', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)), Tip('The price includes the per-km fare, driver allowance and GST. Tolls, parking and state tax are extra, at actuals.')]),
          const SizedBox(height: 6),
          ...widget.quotes.map((q) {
            final id = q['car_type_id'] as int?;
            final sel = id == carId;
            return InkWell(
              onTap: () => setState(() => carId = id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: sel ? const Color(0xFFF5F8FF) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? blue : line, width: 2)),
                child: Row(children: [
                  Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? blue : muted),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${q['name']} · ${q['seats']} seats', style: const TextStyle(fontWeight: FontWeight.w700, color: navy)),
                    Text('${q['examples']}', style: const TextStyle(color: muted, fontSize: 12)),
                    Text(t['trip_type'] == 'oneway' ? 'One-way fare + driver allowance + GST' : '${q['billed_km']} km included + driver allowance + GST', style: const TextStyle(color: muted, fontSize: 12)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(inr(num.tryParse('${q['total']}') ?? 0), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: navy)),
                    Text('Pay ${inr(num.tryParse('${q['advance_due']}') ?? 0)} now', style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ]),
              ),
            );
          }),
          const Text('Tolls, parking and state tax are paid at actuals. Extra km on a round trip are charged at the same per-km rate.', style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 12),
        ] else ...[
          card(Text('We do not have a fixed fare for ${t['to_city']} yet. Send your details and we will call you with a quote.', style: const TextStyle(color: Color(0xFF2459C9), fontWeight: FontWeight.w600))),
          if (cars.isNotEmpty) ...[
            label('Preferred car', 'The type of car you would like. We confirm the price on call.'),
            DropdownButtonFormField<int>(value: carId, items: cars.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text('${c['name']} · ${c['seats']} seats'))).toList(), onChanged: (v) => setState(() => carId = v)),
            const SizedBox(height: 12),
          ],
        ],
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(has ? '2. Passenger details' : 'Your details', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
          label('Full name', 'Name of the person travelling.'),
          TextField(controller: name, textCapitalization: TextCapitalization.words, maxLength: 100, decoration: const InputDecoration(counterText: '')),
          label('Mobile number', otpVerified ? 'Your verified mobile number. Driver details and the trip start code are sent here.' : '10-digit mobile. Driver details and the trip start code are sent here.'),
          TextField(controller: mobile, enabled: !otpVerified, keyboardType: TextInputType.phone, maxLength: 13, decoration: const InputDecoration(counterText: '')),
          label('Pickup address', 'House or building, street and a landmark, so the driver finds you easily.'),
          TextField(controller: address, maxLength: 255, decoration: const InputDecoration(counterText: '')),
          label('Emergency contact mobile', 'Optional. If you press SOS during the trip, this person gets a link to your live location.'),
          TextField(controller: emergency, keyboardType: TextInputType.phone, maxLength: 13, decoration: const InputDecoration(counterText: '')),
          label('Anything we should know?', 'Extra stops, luggage, child seat, elderly passengers.'),
          TextField(controller: notes, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(counterText: '')),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Checkbox(value: agree, onChanged: (v) => setState(() => agree = v ?? false), semanticLabel: 'I accept the terms, cancellation policy and privacy policy'),
            Expanded(child: Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(children: [
              const Text('I accept the '), InkWell(onTap: () => openLink('terms_url'), child: const Text('terms', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
              const Text(', '), InkWell(onTap: () => openLink('cancellation_url'), child: const Text('cancellation policy', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600))),
              const Text(' and '), InkWell(onTap: () => openLink('privacy_url'), child: const Text('privacy policy', style: TextStyle(decoration: TextDecoration.underline, fontWeight: FontWeight.w600))), const Text('.'),
            ]))),
          ]),
          const SizedBox(height: 10),
          Tooltip(message: has ? 'Create your booking. You pay the advance on the next screen.' : 'Send your request. No payment now.', child: FilledButton(onPressed: busy ? null : book, child: Text(busy ? 'Please wait…' : (has ? 'Book now' : 'Request a quote')))),
        ])),
      ]),
    );
  }
}

// ---------------------------------------------------------------- My trips
class TripsTab extends StatefulWidget {
  const TripsTab({super.key});
  @override
  State<TripsTab> createState() => _TripsState();
}

class _TripsState extends State<TripsTab> {
  List<dynamic>? rows;
  String err = '', filter = 'all', sort = 'pickup_desc';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await api.get('api/app/bookings');
    if (!mounted) return;
    if (r.loggedOut) return logoutLocal(context);
    setState(() { if (r.ok) { rows = List<dynamic>.from(r.data['bookings'] ?? []); err = ''; } else { rows ??= []; err = r.error; } });
  }

  @override
  Widget build(BuildContext context) {
    if (rows == null) return const Center(child: CircularProgressIndicator());
    const upcoming = ['enquiry', 'pending', 'confirmed', 'assigned', 'ongoing'];
    var list = rows!.where((b) => filter == 'all' || (filter == 'upcoming' ? upcoming.contains(b['status']) : !upcoming.contains(b['status']))).toList();
    list.sort((a, b) {
      final c = '${a['pickup_at']}'.compareTo('${b['pickup_at']}');
      return sort == 'pickup_asc' ? c : -c;
    });
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.all(14), children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Show', 'Filter your trips: upcoming ones, or past and cancelled ones.'),
            DropdownButtonFormField<String>(value: filter, items: const [DropdownMenuItem(value: 'all', child: Text('All trips')), DropdownMenuItem(value: 'upcoming', child: Text('Upcoming')), DropdownMenuItem(value: 'past', child: Text('Past'))], onChanged: (v) => setState(() => filter = v ?? 'all')),
          ])),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            label('Sort by', 'Order trips by pickup date.'),
            DropdownButtonFormField<String>(value: sort, items: const [DropdownMenuItem(value: 'pickup_desc', child: Text('Newest first')), DropdownMenuItem(value: 'pickup_asc', child: Text('Oldest first'))], onChanged: (v) => setState(() => sort = v ?? 'pickup_desc')),
          ])),
        ]),
        const SizedBox(height: 12),
        if (err.isNotEmpty) card(Text(err, style: const TextStyle(color: Color(0xFFC2304A), fontWeight: FontWeight.w600))),
        if (list.isEmpty && err.isEmpty) card(Padding(padding: const EdgeInsets.symmetric(vertical: 18), child: Center(child: Text(rows!.isEmpty ? 'No trips yet.\nBook your first cab from the Book tab.' : 'No trips match this filter.', textAlign: TextAlign.center, style: const TextStyle(color: muted))))),
        ...list.map((b) => InkWell(
              onTap: () async { await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingScreen(id: b['id'] as int))); load(); },
              child: card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text('${b['from_city']} → ${b['to_city']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy))), statusPill('${b['status']}')]),
                const SizedBox(height: 4),
                Text('${b['pickup_at_text']} · ${b['trip_type'] == 'oneway' ? 'one way' : 'round trip, ${b['days']} day(s)'}', style: const TextStyle(color: muted)),
                Text('${b['ref']} · ${b['car']}${(num.tryParse('${b['total']}') ?? 0) > 0 ? ' · ${inr(num.tryParse('${b['total']}') ?? 0)}' : ''}', style: const TextStyle(color: muted, fontSize: 12)),
              ])),
            )),
      ]),
    );
  }
}

// ---------------------------------------------------------------- One booking
class BookingScreen extends StatefulWidget {
  final int id;
  const BookingScreen({super.key, required this.id});
  @override
  State<BookingScreen> createState() => _BookingState();
}

class _BookingState extends State<BookingScreen> {
  Map<String, dynamic>? b;
  String err = '';
  Timer? poll, sosTimer;
  int sosLeft = 0;

  @override
  void initState() {
    super.initState();
    load();
    poll = Timer.periodic(const Duration(seconds: 15), (_) => load());
  }

  @override
  void dispose() {
    poll?.cancel();
    sosTimer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final r = await api.get('api/app/booking', {'id': '${widget.id}'});
    if (!mounted) return;
    if (r.loggedOut) return logoutLocal(context);
    setState(() { if (r.ok) { b = Map<String, dynamic>.from(r.data['booking'] ?? {}); err = ''; } else if (b == null) { err = r.error; } });
  }

  void sosTap() {
    if (sosTimer != null) {
      sosTimer?.cancel();
      setState(() { sosTimer = null; sosLeft = 0; });
      toast(context, 'Cancelled. No alert was sent.');
      return;
    }
    setState(() => sosLeft = 3);
    sosTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (sosLeft <= 1) { t.cancel(); setState(() { sosTimer = null; sosLeft = 0; }); sosSend(); } else { setState(() => sosLeft--); }
    });
  }

  Future<void> sosSend() async {
    Position? p;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6)));
      }
    } catch (_) {
      try { p = await Geolocator.getLastKnownPosition(); } catch (_) {}
    }
    final r = await api.post('api/app/sos', {'id': widget.id, if (p != null) 'lat': p.latitude, if (p != null) 'lng': p.longitude});
    if (!mounted) return;
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(r.ok ? 'Alert sent' : 'Alert could not be sent'),
      content: Text(r.ok ? 'Our team has been informed and will call you now. If you are in danger, call 112.' : '${r.error}\n\nCall 112 now.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(120, 44), backgroundColor: red), onPressed: () => openUrl('tel:112'), child: const Text('Call 112'))],
    ));
  }

  Widget kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 92, child: Text(k, style: const TextStyle(color: muted, fontWeight: FontWeight.w600))), Expanded(child: Text(v, style: const TextStyle(color: navy)))]));
  Widget head(String t, String tip) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: navy)), Tip(tip)]));

  @override
  Widget build(BuildContext context) {
    final x = b;
    if (x == null) return Scaffold(appBar: AppBar(title: const Text('Booking')), body: Center(child: err.isEmpty ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(err, textAlign: TextAlign.center))));
    final status = '${x['status']}';
    final driver = x['driver'] is Map ? Map<String, dynamic>.from(x['driver']) : null;
    final loc = x['location'] is Map ? Map<String, dynamic>.from(x['location']) : null;
    final payDue = num.tryParse('${x['pay_due']}') ?? 0;
    final total = num.tryParse('${x['total']}') ?? 0;
    final lines = x['fare_lines'] is List ? List<dynamic>.from(x['fare_lines']) : <dynamic>[];
    final live = status == 'assigned' || status == 'ongoing';
    const stages = ['pending', 'confirmed', 'assigned', 'ongoing', 'completed'];
    const stageNames = ['Booked', 'Confirmed', 'Driver', 'On trip', 'Done'];
    final pos = stages.indexOf(status);
    return Scaffold(
      appBar: AppBar(title: Text('${x['ref']}'), actions: [IconButton(tooltip: 'Check for updates now.', icon: const Icon(Icons.refresh), onPressed: load)]),
      body: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(14), children: [
        if (status == 'cancelled') card(Text('This booking is cancelled.${'${x['cancel_reason']}'.isEmpty ? '' : ' ${x['cancel_reason']}'}', style: const TextStyle(color: Color(0xFFC2304A), fontWeight: FontWeight.w600)))
        else if (status == 'enquiry') card(Text('Thank you. We have your request for ${x['to_city']} and will call you on ${x['mobile']} with a quote.', style: const TextStyle(color: Color(0xFF2459C9), fontWeight: FontWeight.w600)))
        else Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: List.generate(stages.length, (i) => Expanded(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center,
          decoration: BoxDecoration(color: i < pos ? const Color(0xFFE3F7EE) : (i == pos ? navy : const Color(0xFFEEF1F6)), borderRadius: BorderRadius.circular(8)),
          child: Text(stageNames[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: i < pos ? const Color(0xFF11845A) : (i == pos ? Colors.white : const Color(0xFF5B6880)))),
        ))))),

        if (payDue > 0 && status != 'cancelled') card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head(status == 'pending' ? 'Pay the advance to confirm' : 'Balance to pay', status == 'pending' ? 'Your booking is confirmed once the advance is received.' : 'Pay online, or pay the driver in cash or by UPI.'),
          Text('${inr(payDue)}${status == 'pending' ? ' of ${inr(total)} estimated fare' : ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: navy)),
          const SizedBox(height: 8),
          if (x['pay_online'] == true) Tooltip(message: 'Opens our secure payment page (UPI, card or net banking).', child: FilledButton(onPressed: () => openUrl('${x['track_url']}'), child: Text('Pay ${inr(payDue)} now')))
          else ...[
            if ('${x['upi_id']}'.isNotEmpty) Text('Pay by UPI to ${x['upi_id']} and mention booking number ${x['ref']}.'),
            Text('${x['pay_note']}', style: const TextStyle(color: muted)),
          ],
        ])),

        if (driver != null) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head('Your driver', 'The driver and car given to your trip.'),
          Text('${driver['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: navy)),
          Text('${driver['car']}', style: const TextStyle(color: muted)),
          if (live && '${driver['mobile'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Tooltip(message: 'Call your driver.', child: OutlinedButton.icon(onPressed: () => openUrl('tel:${driver['mobile']}'), icon: const Icon(Icons.call), label: Text('Call driver ${driver['mobile']}')))),
          if ('${x['start_code']}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: const [Text('Your trip start code', style: TextStyle(fontWeight: FontWeight.w600, color: navy)), Tip('Tell this code to the driver only when you are seated in the car. The trip cannot start without it.')]),
            Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF0EAFE), borderRadius: BorderRadius.circular(10)), child: Text('${x['start_code']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 8, color: Color(0xFF6A3FE0)))),
          ],
        ])),

        if (live) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head('Live location', 'Shows where the car is while the trip is running. Updates every 15 seconds.'),
          if (loc != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(height: 240, child: FlutterMap(
              key: ValueKey('${loc['lat']},${loc['lng']}'),
              options: MapOptions(initialCenter: LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()), initialZoom: 13),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.aravallicabs.customer'),
                MarkerLayer(markers: [Marker(point: LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()), width: 40, height: 40, child: const Icon(Icons.local_taxi, color: blue, size: 34))]),
              ],
            ))),
            const SizedBox(height: 6),
            Text(loc['stale'] == true ? 'The car has not sent its location for a while. This can happen in areas with weak network.' : 'Updated ${loc['at']} · Map © OpenStreetMap contributors', style: const TextStyle(color: muted, fontSize: 12)),
          ] else Text(status == 'assigned' ? 'Live location appears here once your trip starts.' : 'Waiting for the car\'s location…', style: const TextStyle(color: muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            Tooltip(message: 'Copy a link your family can open to follow the car. It hides your phone number, fare and start code.', child: OutlinedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: '${x['share_url']}')); if (context.mounted) toast(context, 'Link copied. Paste it in any message.'); }, icon: const Icon(Icons.copy), label: const Text('Copy family link'))),
            Tooltip(message: 'Send the live trip link on WhatsApp.', child: OutlinedButton.icon(onPressed: () => openUrl('https://wa.me/?text=${Uri.encodeComponent('Follow my cab trip live: ${x['share_url']}')}'), icon: const Icon(Icons.share), label: const Text('Share on WhatsApp'))),
          ]),
        ])),

        if (x['can_sos'] == true) card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          head('Emergency', 'Press only in a real emergency. Our team is alerted at once with your location, and your emergency contact gets your live-location link.'),
          Tooltip(message: 'Sends an emergency alert after a 3-second countdown. Tap again to cancel.', child: FilledButton(style: FilledButton.styleFrom(backgroundColor: sosLeft > 0 ? navy : red, minimumSize: const Size.fromHeight(58)), onPressed: sosTap, child: Text(sosLeft > 0 ? 'Sending in $sosLeft… tap to cancel' : 'SOS — I NEED HELP', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))),
          const SizedBox(height: 8),
          Tooltip(message: 'Call the national emergency number.', child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: const Color(0xFFC2304A)), onPressed: () => openUrl('tel:112'), child: const Text('Call 112 (Police / Ambulance)'))),
        ])),

        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head('Trip details', 'What you booked.'),
          kv('Route', '${x['from_city']} → ${x['to_city']} (${x['trip_type'] == 'oneway' ? 'one way' : 'round trip, ${x['days']} day(s)'})'),
          kv('Pickup', '${x['pickup_at_text']}${'${x['pickup_address']}'.isEmpty ? '' : '\n${x['pickup_address']}'}'),
          kv('Passenger', '${x['customer_name']}, ${x['mobile']}'),
          kv('Car', '${x['car']}'),
        ])),

        if (lines.isNotEmpty) card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          head(status == 'completed' ? 'Final bill' : 'Fare estimate', status == 'completed' ? 'Based on the car\'s odometer readings, plus tolls and parking at actuals.' : 'Tolls, parking and state tax are added at actuals. Extra km are charged at the same per-km rate.'),
          ...lines.map((l) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text('${l[0]}')), Text(inr(num.tryParse('${l[1]}') ?? 0))]))),
          const Divider(),
          Row(children: [const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), Text(inr(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
          Row(children: [const Expanded(child: Text('Paid')), Text(inr(num.tryParse('${x['paid']}') ?? 0))]),
          if ('${x['invoice_url']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Tooltip(message: 'Open your GST invoice. You can print it or save it as PDF.', child: OutlinedButton.icon(onPressed: () => openUrl('${x['invoice_url']}'), icon: const Icon(Icons.receipt_long), label: const Text('Invoice')))),
        ])),

        if ('${appConfig['support_phone'] ?? ''}'.isNotEmpty) Center(child: Tooltip(message: 'Call us to change or cancel this booking.', child: TextButton.icon(onPressed: () => openUrl('tel:+91${appConfig['support_phone']}'), icon: const Icon(Icons.support_agent), label: Text('Need to change or cancel? Call ${appConfig['support_phone']}')))),
      ])),
    );
  }
}

// ---------------------------------------------------------------- Account
class AccountTab extends StatefulWidget {
  const AccountTab({super.key});
  @override
  State<AccountTab> createState() => _AccountState();
}

class _AccountState extends State<AccountTab> {
  late final name = TextEditingController(text: '${customer['name'] ?? ''}'), mobile = TextEditingController(text: '${customer['mobile'] ?? ''}');
  bool busy = false;
  bool get otp => customer['provider'] == 'phone';

  Future<void> save() async {
    setState(() => busy = true);
    final r = await api.post('api/app/profile', {'name': name.text.trim(), 'mobile': cleanMobile(mobile.text)});
    if (!mounted) return;
    setState(() => busy = false);
    if (r.loggedOut) return logoutLocal(context);
    if (!r.ok) return toast(context, r.error);
    customer = Map<String, dynamic>.from(r.data['customer'] ?? {});
    toast(context, 'Saved.');
  }

  Future<void> logout() async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Log out?'), content: const Text('Your bookings stay safe. Log in again any time to see them.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, log out'))]));
    if (yes != true) return;
    await api.post('api/app/logout', {});
    if (mounted) await logoutLocal(context);
  }

  @override
  Widget build(BuildContext context) {
    final phone = '${appConfig['support_phone'] ?? ''}', wa = '${appConfig['support_whatsapp'] ?? ''}';
    const methods = {'google.com': 'Google', 'facebook.com': 'Facebook', 'phone': 'Mobile OTP'};
    return ListView(padding: const EdgeInsets.all(14), children: [
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('My details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
        label('Name', 'Used as the passenger name on new bookings.'),
        TextField(controller: name, textCapitalization: TextCapitalization.words, maxLength: 100, decoration: const InputDecoration(counterText: '')),
        label('Mobile number', otp ? 'Verified by OTP, so it cannot be edited here. Log in with a different number to change it.' : 'Used on new bookings. Driver details are sent to this number.'),
        TextField(controller: mobile, enabled: !otp, keyboardType: TextInputType.phone, maxLength: 13, decoration: const InputDecoration(counterText: '')),
        if ('${customer['email'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text('Email: ${customer['email']}', style: const TextStyle(color: muted))),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Logged in with ${methods[customer['provider']] ?? 'your account'}', style: const TextStyle(color: muted))),
        const SizedBox(height: 14),
        Tooltip(message: 'Save your name and mobile number.', child: FilledButton(onPressed: busy ? null : save, child: Text(busy ? 'Saving…' : 'Save'))),
      ])),
      card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Help', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 8),
        if (phone.isNotEmpty) Tooltip(message: 'Call our office.', child: OutlinedButton.icon(onPressed: () => openUrl('tel:+91$phone'), icon: const Icon(Icons.call), label: Text('Call $phone'))),
        if (wa.isNotEmpty) Tooltip(message: 'Chat with us on WhatsApp.', child: OutlinedButton.icon(onPressed: () => openUrl('https://wa.me/91$wa'), icon: const Icon(Icons.chat), label: const Text('WhatsApp us'))),
        Tooltip(message: 'Read the terms and conditions.', child: TextButton(onPressed: () => openLink('terms_url'), child: const Text('Terms and conditions'))),
        Tooltip(message: 'Read the cancellation and refund policy.', child: TextButton(onPressed: () => openLink('cancellation_url'), child: const Text('Cancellation and refunds'))),
        Tooltip(message: 'Read how we use your information.', child: TextButton(onPressed: () => openLink('privacy_url'), child: const Text('Privacy policy'))),
      ])),
      Tooltip(message: 'Log out of this phone.', child: OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), foregroundColor: const Color(0xFFC2304A)), onPressed: logout, icon: const Icon(Icons.logout), label: const Text('Log out'))),
    ]);
  }
}
