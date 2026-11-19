import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiResult {
  final bool ok;
  final Map<String, dynamic> data;
  final String error;
  final bool loggedOut;
  ApiResult(this.ok, this.data, this.error, {this.loggedOut = false});
}

bool validMobile(String m) => RegExp(r'^[6-9]\d{9}$').hasMatch(cleanMobile(m));

String cleanMobile(String m) {
  var d = m.replaceAll(RegExp(r'\D'), '');
  if (d.length == 12 && d.startsWith('91')) d = d.substring(2);
  if (d.length == 11 && d.startsWith('0')) d = d.substring(1);
  return d;
}

/// ₹ with Indian digit grouping: 123456 → ₹1,23,456
String inr(num n) {
  final neg = n < 0;
  var s = n.abs().round().toString();
  if (s.length > 3) {
    final last = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last';
  }
  return '${neg ? '-' : ''}₹$s';
}

class Api {
  String base = Config.serverBase;
  String token = '';
  http.Client client = http.Client();

  Future<void> load() async => token = (await SharedPreferences.getInstance()).getString('token') ?? '';

  Future<void> saveToken(String t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    t.isEmpty ? await p.remove('token') : await p.setString('token', t);
  }

  Uri uri(String route, [Map<String, String>? q]) => Uri.parse('$base/index.php').replace(queryParameters: {'r': route, ...?q});

  Future<ApiResult> get(String route, [Map<String, String>? q]) => _send(() => client.get(uri(route, q), headers: _headers()));
  Future<ApiResult> post(String route, Map<String, dynamic> body) => _send(() => client.post(uri(route), headers: _headers(), body: jsonEncode(body)));

  Map<String, String> _headers() => {'Accept': 'application/json', 'Content-Type': 'application/json', if (token.isNotEmpty) 'Authorization': 'Bearer $token'};

  Future<ApiResult> _send(Future<http.Response> Function() f) async {
    if (base.isEmpty) return ApiResult(false, {}, 'This app is not connected to the booking website yet.');
    try {
      final r = await f().timeout(const Duration(seconds: 20));
      return parse(r.statusCode, r.body);
    } catch (_) {
      return ApiResult(false, {}, 'No network. Please try again.');
    }
  }

  static ApiResult parse(int status, String body) {
    Map<String, dynamic> j = {};
    try {
      final d = jsonDecode(body);
      if (d is Map<String, dynamic>) j = d;
    } catch (_) {}
    if (status == 401 && j['logout'] == true) return ApiResult(false, j, (j['error'] ?? 'Please log in again.').toString(), loggedOut: true);
    if (j['ok'] == true) return ApiResult(true, j, '');
    return ApiResult(false, j, (j['error'] ?? 'Something went wrong. Please try again.').toString());
  }
}
