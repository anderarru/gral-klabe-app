import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderService {
  // 'record' paketearen instantzia
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  // Uneko audioa gordetzen ari den fitxategiaren bidea (path)
  String? _currentFilePath;

  /// Grabazioa hasi eta aplikazioaren barne-memorian gordetzen du
  Future<void> startRecording() async {
    try {
      // 1. Mikrofonoaren baimena dugun egiaztatu
      if (await _audioRecorder.hasPermission()) {
        
        // 2. Aplikazioaren karpeta pribatu eta segurua lortu
        final Directory appDocDir = await getApplicationDocumentsDirectory();
        
        // 3. Fitxategi-izen esklusiboa sortu (data eta ordua milisegundotan erabiliz)
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        _currentFilePath = '${appDocDir.path}/session_$timestamp.m4a';

        // 4. Grabaketa hasi (m4a formatua arina da eta kalitate ona du)
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _currentFilePath!,
        );
        
        print("Grabazioa hasi da hemen: $_currentFilePath");
      } else {
        print("Erabiltzaileak ez du mikrofonoaren baimenik eman");
      }
    } catch (e) {
      print("Errorea grabazioa hastean: $e");
    }
  }

  /// Grabazioa gelditu eta azken fitxategiaren bidea (path) itzultzen du
  Future<String?> stopRecording() async {
    try {
      if (await _audioRecorder.isRecording()) {
        final path = await _audioRecorder.stop();
        print("Grabazioa geldituta. Fitxategia hemen gorde da: $path");
        return path; // Adibidez: /data/user/0/.../session_1234.m4a
      }
    } catch (e) {
      print("Errorea grabazioa gelditzean: $e");
    }
    return null;
  }

  /// Baliabideak askatzeko pantailatik irtetean
  Future<void> dispose() async {
    await _audioRecorder.dispose();
  }
}