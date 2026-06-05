import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/time_formatter.dart'; 

void main() {
  group('Denbora Formatuaren Probak (Unit Test)', () {
    test('Segundoak minutu eta ordu formatura ongi bihurtzen ditu', () {
      // 59 segundo -> 00:59
      expect(formatTimer(59), '00:59');
      
      // 61 segundo -> 01:01
      expect(formatTimer(61), '01:01');
      
      // Ordu bat zehatz -> 01:00:00
      expect(formatTimer(3600), '01:00:00');

      // Ordu bat, minutu bat eta segundo bat -> 01:01:01
      expect(formatTimer(3661), '01:01:01');
    });
  });
}