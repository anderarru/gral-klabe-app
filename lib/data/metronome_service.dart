import 'package:metronome/metronome.dart';

class MetronomeService {
  // Singleton patroia: Instantzia bakarra aplikazio osoan
  static final MetronomeService _instance = MetronomeService._internal();
  factory MetronomeService() => _instance;
  MetronomeService._internal();

  final Metronome _plugin = Metronome();
  bool _isInitialized = false;

  // Egoera sinkronizatzeko korrontea (UI-ak entzuteko)
  Stream<int> get tickStream => _plugin.tickStream;

  Future<void> init({int bpm = 100, int beats = 4}) async {
    if (_isInitialized) return;
    await _plugin.init(
      'assets/audio/click_low.wav',
      accentedPath: 'assets/audio/click_high.wav',
      bpm: bpm,
      timeSignature: beats,
      enableTickCallback: true,
    );
    _isInitialized = true;
  }

  void play() => _plugin.play();
  void pause() => _plugin.pause();
  void stop() => _plugin.stop();
  void setBPM(int bpm) => _plugin.setBPM(bpm);
  void setVolume(int vol) => _plugin.setVolume(vol);
}