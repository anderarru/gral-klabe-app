import 'package:flutter_test/flutter_test.dart';
// Asegúrate de que esta ruta coincide con donde tienes guardado tu modelo
import '../lib/domain/models/routine_model.dart'; 

void main() {
  group('Datu-basearen Integrazio Probak (JSON -> Model)', () {
    test('Firestoreko datuetatik AgendaEvent objektua zuzen sortzen da', () {
      
      // 1. Datu faltsuak prestatu (Hodeitik iritsiko litzatekeen JSON mapa)
      final Map<String, dynamic> firestoreMockData = {
        'routineId': 'rutina_001',
        'title': 'Klarinete Beroketa',
        'dateStr': '2026-05-25',
        'completed': true,
        'iraupena_reala': 45,
        'oharrak': 'Soinu garbia gaur',
        'exercises': [
          {'name': 'Eskalak', 'durationMinutes': 10, 'audio_path': '/local/path/audio1.m4a'}
        ]
      };

      // 2. Datuak zure modeloaren bidez prozesatu (Integrazioa)
      final agendaEvent = AgendaEvent.fromMap(firestoreMockData, 'doc_12345');

      // 3. Egiaztatu dena ondo konektatu dela
      expect(agendaEvent.id, 'doc_12345');
      expect(agendaEvent.title, 'Klarinete Beroketa');
      expect(agendaEvent.completed, true);
      expect(agendaEvent.iraupenaReala, 45);
      expect(agendaEvent.exercises.length, 1);
      expect(agendaEvent.exercises.first.name, 'Eskalak');
    });
  });
}