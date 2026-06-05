import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:pitch_detector_dart/pitch_detector_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_generator/sound_generator.dart';
import 'package:sound_generator/waveTypes.dart';

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  String _selectedInstrument = 'Klarinetea Sib';
  bool _useSolfege = true;
  double _referenceHz = 440.0;

  double _currentHz = 0.0;
  double _cents = 0.0;
  String _currentNote = "--";
  bool _isListening = false;
  bool _isPlayingTone = false;

  // Motor de audio y detector
  final FlutterAudioCapture _audioCapture = FlutterAudioCapture();
  late PitchDetector _pitchDetector;

  @override
  void initState() {
    super.initState();
    // Iniciar generador de sonido
    SoundGenerator.init(44100);
    SoundGenerator.setWaveType(waveTypes.SINUSOIDAL);
    // Inicializamos el detector
    _pitchDetector = PitchDetector(audioSampleRate: 44100.0, bufferSize: 2000);
    _requestPermissionsAndStart();
  }

  Future<void> _requestPermissionsAndStart() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      await _audioCapture.init();
      await _audioCapture.start(
        _onAudioCaptured, 
        (error) => print("Error capturando audio: $error"),
        sampleRate: 44100, 
        bufferSize: 3000
      );
      setState(() => _isListening = true);
    } else {
      print("No hay permisos de micrófono");
    }
  }

  // Esta función se ejecuta MUCHAS veces por segundo con el audio real
  void _onAudioCaptured(dynamic obj) async {
    List<double> audioSample = obj.cast<double>().toList();
    PitchDetectorResult result = await _pitchDetector.getPitchFromFloatBuffer(audioSample);
    
    if (result.pitched && result.pitch > 50 && result.pitch < 3000) {
      _processPitch(result.pitch);
    }
  }

  void _processPitch(double hz) {
    // 1. Calcular la nota MIDI real que está sonando (Concert Pitch)
    int realMidiNote = (12 * (log(hz / _referenceHz) / log(2))).round() + 69;
    
    // 2. Transponer según el instrumento
    int transpositionOffset = 0;
    if (_selectedInstrument == 'Klarinetea Sib') {
      transpositionOffset = 2; // Suena Bb, lee C (Sube 2)
    } else if (_selectedInstrument == 'Klarinetea Mib') {
      transpositionOffset = -3; // Suena Eb, lee C (Baja 3)
    }
    
    int displayMidi = realMidiNote + transpositionOffset;

    // 3. Calcular la frecuencia exacta que DEBERÍA tener esa nota
    double targetHz = _referenceHz * pow(2, (realMidiNote - 69) / 12);
    
    // 4. Calcular el error en céntimos
    double cents = 1200 * (log(hz / targetHz) / log(2));

    // 5. Nombres de las notas
    List<String> notesEnglish = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    List<String> notesSolfege = ['Do', 'Do#', 'Re', 'Re#', 'Mi', 'Fa', 'Fa#', 'Sol', 'Sol#', 'La', 'La#', 'Si'];
    
    String noteName = _useSolfege 
        ? notesSolfege[displayMidi % 12] 
        : notesEnglish[displayMidi % 12];
    
    int octave = (displayMidi / 12).floor() - 1;

    // Actualizar la interfaz
    setState(() {
      _currentHz = hz;
      _cents = cents;
      _currentNote = "$noteName$octave";
    });
  }

  @override
  void dispose() {
    _audioCapture.stop();
    SoundGenerator.release();
    super.dispose();
  }

  void _toggleTone() {
    if (_isPlayingTone) {
      SoundGenerator.stop();
    } else {
      SoundGenerator.setFrequency(_referenceHz); // Reproduce tu referencia exacta
      SoundGenerator.play();
    }
    setState(() {
      _isPlayingTone = !_isPlayingTone;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isInTune = _cents.abs() < 5 && _currentHz > 0;
    final Color brandColor = Colors.deepPurple;
    final Color statusColor = isInTune ? Colors.green : Colors.redAccent;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54),
          onPressed: () {
            Navigator.pop(context); // Esto te devuelve a la pantalla anterior
          },
        ),
        centerTitle: true,
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: brandColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: brandColor.withOpacity(0.2))
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedInstrument,
              icon: Icon(Icons.music_note, size: 18, color: brandColor),
              style: TextStyle(color: brandColor, fontWeight: FontWeight.bold),
              onChanged: (val) => setState(() => _selectedInstrument = val!),
              items: ['Klarinetea Sib', 'Klarinetea Mib'].map((String value) {
                return DropdownMenuItem<String>(value: value, child: Text(value));
              }).toList(),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black54),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => StatefulBuilder( // Necesario para actualizar el modal
                  builder: (BuildContext context, StateSetter setModalState) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Selector de Notación ──
                        ListTile(
                          title: const Text("Notazioa"),
                          subtitle: Text(_useSolfege ? "Solfeo (Do, Re, Mi)" : "Ingelesa (C, D, E)"),
                          trailing: Switch(
                            value: _useSolfege,
                            activeColor: brandColor,
                            onChanged: (val) {
                              setModalState(() => _useSolfege = val); // Actualiza modal
                              setState(() {}); // Actualiza pantalla trasera
                            },
                          ),
                        ),
                        
                        // ── Selector de Frecuencia (Hz) ──
                        ListTile(
                          title: const Text("Erreferentzia (La4)"),
                          subtitle: const Text("Estandarra: 440 Hz | Banda: 442 Hz"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: brandColor,
                                onPressed: () {
                                  if (_referenceHz > 410) {
                                    setModalState(() => _referenceHz--);
                                    setState(() {}); 
                                  }
                                },
                              ),
                              Text(
                                "${_referenceHz.toInt()} Hz", 
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: brandColor,
                                onPressed: () {
                                  if (_referenceHz < 470) {
                                    setModalState(() => _referenceHz++);
                                    setState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    );
                  }
                ),
              );
            },
          )
        ],
      ),
      // ── ÚNICO BODY ──
      body: Column(
        children: [
          const SizedBox(height: 40),
          Text(
            _currentNote,
            style: TextStyle(fontSize: 90, fontWeight: FontWeight.w900, color: brandColor, letterSpacing: -2),
          ),
          const Spacer(),
          Container(
            height: 250,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: _cents), 
              duration: const Duration(milliseconds: 150), 
              curve: Curves.easeOutCubic, 
              builder: (context, animatedCents, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: ProTunerPainter(animatedCents, brandColor),
                );
              },
            ),
          ),    
          
          // ── Row con los Hz y el botón del diapasón ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _currentHz == 0.0 ? '-- Hz' : '${_currentHz.toStringAsFixed(1)} Hz',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300, color: Colors.black87),
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: Icon(
                  _isPlayingTone ? Icons.volume_up : Icons.volume_off,
                  color: _isPlayingTone ? brandColor : Colors.grey,
                  size: 32,
                ),
                onPressed: _toggleTone, // Enciende/apaga el sonido
              ),
            ],
          ),

          Text(
            _currentHz == 0.0 ? 'Itxaroten...' : (isInTune ? 'AFINATUTA' : 'DESAFINATUTA'),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _currentHz == 0.0 ? Colors.grey : statusColor, letterSpacing: 2),
          ),
          const Spacer(),
          Opacity(
            opacity: 0.6,
            child: Icon(Icons.library_music, size: 100, color: brandColor.withOpacity(0.2)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class ProTunerPainter extends CustomPainter {
  final double cents;
  final Color brandColor;

  ProTunerPainter(this.cents, this.brandColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.45;

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi, false, bgPaint);

    final centerZonePaint = Paint()
      ..color = brandColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi + (pi/2) - 0.1, 0.2, true, centerZonePaint
    );

    final tickPaint = Paint()..color = Colors.grey.shade400..strokeWidth = 2;
    for (int i = -50; i <= 50; i += 10) {
      double angle = pi + (pi / 2) + (i * (pi / 2) / 50);
      final p1 = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      final p2 = Offset(center.dx + (radius - 15) * cos(angle), center.dy + (radius - 15) * sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
      
      if (i % 20 == 0) {
        _drawText(canvas, i.toString(), center.dx + (radius - 35) * cos(angle), center.dy + (radius - 35) * sin(angle));
      }
    }

    final needlePaint = Paint()
      ..color = brandColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    double needleAngle = pi + (pi / 2) + (cents.clamp(-50, 50) * (pi / 2) / 50);
    final needleEnd = Offset(
      center.dx + (radius - 5) * cos(needleAngle),
      center.dy + (radius - 5) * sin(needleAngle),
    );

    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 8, needlePaint);
  }

  void _drawText(Canvas canvas, String text, double x, double y) {
    TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout()..paint(canvas, Offset(x - 5, y - 5));
  }

  @override
  bool shouldRepaint(ProTunerPainter old) => old.cents != cents;
}