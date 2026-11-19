import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Result of an API call: [ok] plus the decoded body, or a message the driver can read.
class ApiResult {
  final bool ok;
  final Map<String, dynamic> data;
  final String error;
  final bool loggedOut;
  ApiResult(this.ok, this.data, this.error, {this.loggedOut = false});
}

/// Cleans what the driver typed into a usable https address, or returns null.
String? cleanServerAddress(String input) {
  var s = input.trim();
  if (s.isEmpty) return null;
  if (!s.contains('://')) s = 'https://$s';
  final u = Uri.tryParse(s);
  if (u == null || u.host.isEmpty || u.scheme != 'https') return null;
  var path = u.path.replaceAll(RegExp(r'/index\.php$'), '');
  path = path.replaceAll(RegExp(r'/+$'), '');
  return '${u.scheme}://${u.host}${u.hasPort ? ':${u.port}' : ''}$path';
}

bool validMobile(String m) => RegExp(r'^[6-9]\d{9}$').hasMatch(m.replaceAll(RegExp(r'\D'), ''));
bool validPin(String p) => RegExp(r'^\d{4,6}$').hasMatch(p);

class Api {
  String base = '';
  String token = '';
  http.Client client = http.Client();

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    base = p.getString('base') ?? '';
    token = p.getString('token') ?? '';
  }

  Future<void> saveBase(String b) async {
    base = b;
    (await SharedPreferences.getInstance()).setString('base', b);
  }

  Future<void> saveToken(String t) async {
    token = t;
    final p = await SharedPreferences.getInstance();
    t.isEmpty ? await p.remove('token') : await p.setString('token', t);
  }

  /// index.php?r= works whether or not clean URLs are switched on at the server.
  Uri uri(String route) => Uri.parse('$base/index.php').replace(queryParameters: {'r': route});

  Future<bool> ping() async {
    try {
      final r = await client.get(uri('__ping')).timeout(const Duration(seconds: 12));
      return r.statusCode == 200 && r.body.trim() == 'pong';
    } catch (_) {
      return false;
    }
  }

  Future<ApiResult> call(String route, {Map<String, dynamic>? body}) async {
    try {
      final headers = {'Accept': 'application/json', 'Content-Type': 'application/json', if (token.isNotEmpty) 'Authorization': 'Bearer $token'};
      final r = await (body == null ? client.get(uri(route), headers: headers) : client.post(uri(route), headers: headers, body: jsonEncode(body))).timeout(const Duration(seconds: 20));
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
    if (status == 401) return ApiResult(false, j, (j['error'] ?? 'Please log in again.').toString(), loggedOut: true);
    if (j['ok'] == true) return ApiResult(true, j, '');
    return ApiResult(false, j, (j['error'] ?? 'Something went wrong. Please try again.').toString());
  }
}
