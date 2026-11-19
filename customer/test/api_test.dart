import 'package:flutter_test/flutter_test.dart';
import 'package:aravalli_cabs/api.dart';

void main() {
  test('rupees use Indian grouping', () {
    expect(inr(999), '₹999');
    expect(inr(6930), '₹6,930');
    expect(inr(123456), '₹1,23,456');
    expect(inr(123456789), '₹12,34,56,789');
    expect(inr(-1500), '-₹1,500');
  });
  test('mobile numbers are cleaned and checked', () {
    expect(cleanMobile('+91 98765-43210'), '9876543210');
    expect(cleanMobile('09876543210'), '9876543210');
    expect(validMobile('98765 43210'), true);
    expect(validMobile('12345'), false);
  });
  test('api responses are parsed', () {
    expect(Api.parse(200, '{"ok":true,"token":"x"}').ok, true);
    expect(Api.parse(400, '{"ok":false,"error":"Please accept the terms."}').error, 'Please accept the terms.');
    expect(Api.parse(401, '{"ok":false,"logout":true}').loggedOut, true);
    expect(Api.parse(401, '{"ok":false,"error":"Login could not be verified."}').loggedOut, false);
    expect(Api.parse(500, '<html>').ok, false);
  });
  test('route address', () {
    final a = Api()..base = 'https://example.com';
    expect(a.uri('api/app/booking', {'id': '7'}).toString(), 'https://example.com/index.php?r=api%2Fapp%2Fbooking&id=7');
  });
}
