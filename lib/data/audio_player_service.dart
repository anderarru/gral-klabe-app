import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;
  Stream<Duration> get onDurationChanged => _audioPlayer.onDurationChanged;
  Stream<void> get onPlayerComplete => _audioPlayer.onPlayerComplete;

  Future<void> playLocalAudio(String path) async {
    try {
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (e) {
      print("Errorea audioa erreproduzitzean: $e");
    }
  }

  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // BERRIA: Iraupena eskuz eskatzeko funtzioa
  Future<Duration?> getDuration() async {
    return await _audioPlayer.getDuration();
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}