import 'package:flutter_test/flutter_test.dart';
import 'package:outstation_driver/api.dart';

void main() {
  test('server address is cleaned', () {
    expect(cleanServerAddress('cabs.example.com'), 'https://cabs.example.com');
    expect(cleanServerAddress(' https://example.com/cab/public/ '), 'https://example.com/cab/public');
    expect(cleanServerAddress('https://example.com/index.php'), 'https://example.com');
    expect(cleanServerAddress('http://example.com'), null, reason: 'plain http is refused');
    expect(cleanServerAddress(''), null);
  });
  test('mobile and PIN checks', () {
    expect(validMobile('98765 43210'), true);
    expect(validMobile('12345'), false);
    expect(validPin('4827'), true);
    expect(validPin('12'), false);
    expect(validPin('abcd'), false);
  });
  test('api responses are parsed', () {
    expect(Api.parse(200, '{"ok":true,"token":"x"}').ok, true);
    final bad = Api.parse(400, '{"ok":false,"error":"Wrong OTP."}');
    expect(bad.ok, false);
    expect(bad.error, 'Wrong OTP.');
    expect(Api.parse(401, '{"ok":false}').loggedOut, true);
    expect(Api.parse(500, '<html>oops').ok, false);
  });
  test('route address works without clean URLs', () {
    final a = Api()..base = 'https://example.com/cab/public';
    expect(a.uri('api/driver/me').toString(), 'https://example.com/cab/public/index.php?r=api%2Fdriver%2Fme');
  });
}
