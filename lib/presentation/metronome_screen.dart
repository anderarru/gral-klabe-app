import 'dart:math';
import 'package:flutter/material.dart';
import 'package:metronome/metronome.dart';

class MetronomeScreen extends StatefulWidget {
  const MetronomeScreen({super.key});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> with SingleTickerProviderStateMixin {
  int _bpm = 100;
  bool _isPlaying = false;
  
  final List<String> _compases = [
    '1/4', '2/4', '3/4', '4/4',
    '5/4', '6/4', '3/8', '5/8',
    '6/8', '7/8', '9/8', '12/8'
  ];
  String _selectedCompas = '4/4';
  int _currentBeat = 1;
  
  final List<DateTime> _tapTimes = []; 
  final Metronome _metronomePlugin = Metronome();

  late AnimationController _animationController;
  late Animation<double> _pendulumAnimation;
  bool _swingRight = true;

  @override
  void initState() {
    super.initState();
    _initMetronome();

    _animationController = AnimationController(
      vsync: this,
      duration: _getDurationFromBpm(_bpm),
    );

    _pendulumAnimation = Tween<double>(begin: -pi / 4, end: pi / 4).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  String _getTempoMarking(int bpm) {
    if (bpm < 60) return "Largo";
    if (bpm < 66) return "Larghetto";
    if (bpm < 76) return "Adagio";
    if (bpm < 108) return "Andante";
    if (bpm < 120) return "Moderato";
    if (bpm < 168) return "Allegro";
    if (bpm < 200) return "Presto";
    return "Prestissimo";
  }

  int _getBeatsFromCompas(String compas) {
    return int.parse(compas.split('/')[0]);
  }

  Future<void> _initMetronome() async {
    try {
      await _metronomePlugin.init(
        'assets/audio/click_low.wav',
        accentedPath: 'assets/audio/click_high.wav',
        bpm: _bpm,
        volume: 100,
        timeSignature: _getBeatsFromCompas(_selectedCompas),
        enableTickCallback: true,
      );

      // ESTA ES LA CLAVE: El listener es el que mueve los puntos y el péndulo
      _metronomePlugin.tickStream.listen((int tick) {
        if (mounted && _isPlaying) {
          setState(() {
            int totalBeats = _getBeatsFromCompas(_selectedCompas);
            _currentBeat = (tick % totalBeats) + 1;

            // Movimiento del péndulo sincronizado pero sin tirones
            if (_swingRight) {
              _animationController.forward();
            } else {
              _animationController.reverse();
            }
            _swingRight = !_swingRight;
          });
        }
      });
    } catch (e) {
      print("Error al inicializar el metrónomo: $e");
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _metronomePlugin.pause();
      _animationController.stop();
      setState(() => _isPlaying = false);
    } else {
      setState(() {
        _isPlaying = true;
        _currentBeat = 1;
        _swingRight = true;
      });
      _metronomePlugin.play();
      // Empezamos la animación en el primer golpe
      _animationController.forward();
    }
  }

  void _changeBpm(int newBpm) {
    setState(() {
      _bpm = newBpm;
      _animationController.duration = _getDurationFromBpm(_bpm);
    });
    _metronomePlugin.setBPM(_bpm);
  }

  void _changeCompas(String newCompas) {
    setState(() {
      _selectedCompas = newCompas;
      _currentBeat = 1;
    });
    _metronomePlugin.setTimeSignature(_getBeatsFromCompas(newCompas));
  }

  void _handleTapTempo() {
    final now = DateTime.now();
    _tapTimes.add(now);
    if (_tapTimes.length > 4) _tapTimes.removeAt(0);
    if (_tapTimes.length >= 2) {
      final durations = <int>[];
      for (int i = 1; i < _tapTimes.length; i++) {
        durations.add(_tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds);
      }
      final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
      _changeBpm((60000 / avgDuration).round().clamp(40, 220));
    }
  }

  Duration _getDurationFromBpm(int bpm) {
    return Duration(milliseconds: (60000 / bpm).round());
  }

  void _showCompassSelector(Color brandColor, Color lightColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Konpasa aukeratu", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12, runSpacing: 12,
                alignment: WrapAlignment.center,
                children: _compases.map((compas) {
                  bool isSelected = _selectedCompas == compas;
                  return GestureDetector(
                    onTap: () {
                      _changeCompas(compas);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: (MediaQuery.of(context).size.width - 48 - 36) / 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? brandColor : lightColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(compas, style: TextStyle(color: isSelected ? Colors.white : brandColor, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _metronomePlugin.destroy();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = const Color(0xFF3B486A); 
    final lightColor = const Color(0xFFE4E9FC); 
    int currentBeats = _getBeatsFromCompas(_selectedCompas);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Metronomoa', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)), 
        elevation: 0, backgroundColor: Colors.transparent, centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => _showCompassSelector(brandColor, lightColor),
              icon: Icon(Icons.music_note, color: brandColor),
              label: Text("Konpasa: $_selectedCompas", style: TextStyle(color: brandColor, fontWeight: FontWeight.bold, fontSize: 16)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: brandColor.withOpacity(0.5), width: 2),
              ),
            ),
            const Spacer(),
            RepaintBoundary(
              child: SizedBox(
                height: 160, width: 200,
                child: AnimatedBuilder(
                  animation: _pendulumAnimation,
                  builder: (context, child) => CustomPaint(painter: MetronomePainter(_pendulumAnimation.value, brandColor)),
                ),
              ),
            ),
            const Spacer(),
            Text('$_bpm', style: TextStyle(fontSize: 90, fontWeight: FontWeight.bold, color: brandColor, height: 1.0)),
            const Text('BPM', style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Slider(
                value: _bpm.toDouble(), min: 40, max: 220,
                activeColor: brandColor, inactiveColor: lightColor,
                onChanged: (val) => _changeBpm(val.toInt()),
              ),
            ),
            Text(_getTempoMarking(_bpm), style: TextStyle(fontSize: 22, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: brandColor.withOpacity(0.8), letterSpacing: 1.2)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleTapTempo,
              style: ElevatedButton.styleFrom(backgroundColor: lightColor, foregroundColor: brandColor, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text("TAP TEMPO", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            if (currentBeats > 1)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(currentBeats, (i) {
                  bool isActive = _isPlaying && _currentBeat == (i + 1);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: isActive ? 18 : 12, height: isActive ? 18 : 12,
                    decoration: BoxDecoration(
                      color: isActive ? (i == 0 ? Colors.orange : brandColor) : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      boxShadow: isActive ? [BoxShadow(color: (i == 0 ? Colors.orange : brandColor).withOpacity(0.5), blurRadius: 6)] : [],
                    ),
                  );
                }),
              ),
            const SizedBox(height: 30),
            FloatingActionButton.large(
              onPressed: _togglePlay,
              backgroundColor: _isPlaying ? Colors.orange : brandColor,
              elevation: 4,
              child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class MetronomePainter extends CustomPainter {
  final double angle; 
  final Color brandColor;
  MetronomePainter(this.angle, this.brandColor);

  @override
  void paint(Canvas canvas, Size size) {
    final centerBottom = Offset(size.width / 2, size.height - 10);
    final basePaint = Paint()..color = Colors.grey.shade200..style = PaintingStyle.fill;
    final path = Path()..moveTo(size.width * 0.25, size.height)..lineTo(size.width * 0.75, size.height)..lineTo(size.width * 0.6, 20)..lineTo(size.width * 0.4, 20)..close();
    canvas.drawPath(path, basePaint);
    final pendulumPaint = Paint()..color = Colors.black87..strokeWidth = 5..strokeCap = StrokeCap.round;
    final pendulumLength = size.height - 30;
    final pendulumTip = Offset(centerBottom.dx + pendulumLength * sin(angle), centerBottom.dy - pendulumLength * cos(angle));
    canvas.drawLine(centerBottom, pendulumTip, pendulumPaint);
    final weightDist = pendulumLength * 0.7;
    final weightCenter = Offset(centerBottom.dx + weightDist * sin(angle), centerBottom.dy - weightDist * cos(angle));
    canvas.save();
    canvas.translate(weightCenter.dx, weightCenter.dy);
    canvas.rotate(angle);
    canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 20, height: 16), Paint()..color = brandColor);
    canvas.restore();
    canvas.drawCircle(centerBottom, 6, Paint()..color = Colors.black);
  }
  @override
  bool shouldRepaint(MetronomePainter old) => old.angle != angle;
}