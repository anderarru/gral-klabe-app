import 'dart:async';
import 'package:flutter/material.dart';
import '../domain/models/routine_model.dart';
import '../data/firestore_service.dart';
import '../data/audio_recorder_service.dart';
import '../data/virtual_teacher_service.dart';
import '../data/metronome_service.dart'; // BERRIA: Metronomo zerbitzua

class ActiveRoutineScreen extends StatefulWidget {
  final AgendaEvent event;

  const ActiveRoutineScreen({super.key, required this.event});

  @override
  State<ActiveRoutineScreen> createState() => _ActiveRoutineScreenState();
}

class _ActiveRoutineScreenState extends State<ActiveRoutineScreen> {
  int _currentIndex = 0; 
  late int _remainingSeconds;
  
  Timer? _timer;
  bool _isRunning = false;
  
  // BERRIA: Benetako denbora neurtzeko (segundotan)
  int _actualElapsedSeconds = 0; 
  
  final _oharrakController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final AudioRecorderService _audioRecorder = AudioRecorderService();

  // ── Metronomoaren Aldagaiak ──
  final MetronomeService _metronomeService = MetronomeService();
  double _bpm = 100; 
  bool _metronomoPiztuta = false;
  bool _isMuted = false;
  bool _isTickActive = false;
  StreamSubscription? _tickSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.event.exercises.isNotEmpty) {
      _remainingSeconds = widget.event.exercises[_currentIndex].durationMinutes * 60;
    } else {
      _remainingSeconds = 0;
    }
    _initMiniMetronome();
  }

  Future<void> _initMiniMetronome() async {
    await _metronomeService.init(bpm: _bpm.toInt(), beats: 4);
    
    _tickSubscription = _metronomeService.tickStream.listen((tick) {
      if (!mounted) return;
      setState(() => _isTickActive = true);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) setState(() => _isTickActive = false);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose(); 
    _oharrakController.dispose();
    _tickSubscription?.cancel();
    _metronomeService.pause();
    super.dispose();
  }

  void _toggleTimer() async {
    if (_isRunning) {
      _timer?.cancel();
    } else {
      if (_remainingSeconds == widget.event.exercises[_currentIndex].durationMinutes * 60) {
        await _audioRecorder.startRecording();
      }

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _actualElapsedSeconds++; // BERRIA: Benetan pasatako denbora gehitzen dugu
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _nextExercise();
          }
        });
      });
    }
    setState(() => _isRunning = !_isRunning);
  }

  Future<void> _nextExercise() async {
    _timer?.cancel(); 
    setState(() => _isRunning = false);

    String? path = await _audioRecorder.stopRecording();
    widget.event.exercises[_currentIndex].audioPath = path;

    if (_currentIndex < widget.event.exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _remainingSeconds = widget.event.exercises[_currentIndex].durationMinutes * 60;
      });

      await _audioRecorder.startRecording();
      setState(() => _isRunning = true);
      _toggleTimer(); 

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Oso ondo! Orain: ${widget.event.exercises[_currentIndex].name}')),
      );
    } else {
      _finishPractice();
    }
  }

  Future<void> _finishPractice() async {
    _timer?.cancel();
    
    if (_metronomoPiztuta) _toggleMetronome();

    _mostrarCargandoDialog(context);

    try {
      if (_isRunning || _remainingSeconds < widget.event.exercises[_currentIndex].durationMinutes * 60) {
        String? path = await _audioRecorder.stopRecording();
        widget.event.exercises[_currentIndex].audioPath = path;
      }

      // BERRIA: Benetan igarotako minutuak kalkulatzen ditugu (gutxienez minutu 1 jarrita zero ez izateko)
      int actualMinutes = (_actualElapsedSeconds / 60).round();
      if (actualMinutes == 0 && _actualElapsedSeconds > 0) actualMinutes = 1;

      // Firestore-ra benetako minutuak bidali
      await _firestoreService.updateCompletedRoutine(
        widget.event.id!,
        _oharrakController.text,
        actualMinutes, 
        widget.event.exercises, 
      );

      // Irakasleari benetako denbora esan
      final String feedback = await VirtualTeacherService().getFeedback(
        instrument: 'Klarinetea',
        durationInSeconds: _actualElapsedSeconds,
        notes: _oharrakController.text.isEmpty ? 'Gaurko saioa normal joan da.' : _oharrakController.text,
      );

      if (mounted) {
        Navigator.pop(context); 
        _erakutsiGaldetegiaDialog(context, feedback); 
      }
    } catch (e) {
      print("CONEXION ERROR: $e");
      if (mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errorea datuak gordetzean: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Metronomoaren Funtzioak ──
  void _toggleMetronome() {
    setState(() {
      _metronomoPiztuta = !_metronomoPiztuta;
      if (_metronomoPiztuta) {
        _metronomeService.play();
      } else {
        _metronomeService.pause();
      }
    });
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _metronomeService.setVolume(_isMuted ? 0 : 100);
    });
  }

  void _changeBPM(double balioa) {
    setState(() {
      _bpm = balioa;
    });
    _metronomeService.setBPM(balioa.toInt());
  }

  String _formatTime(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _mostrarCargandoDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple)),
                SizedBox(height: 16),
                Text('Aholkuak sortzen...', style: TextStyle(decoration: TextDecoration.none, color: Colors.black, fontSize: 14)),
              ],
            ),
          ),
        );
      },
    );
  }

  void _erakutsiFeedbackBottomSheet(BuildContext context, String feedbackText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.deepPurple[700], size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Irakasle Birtuala',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                feedbackText,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context); 
                    Navigator.pop(context); 
                  },
                  child: const Text('Ulertuta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _erakutsiGaldetegiaDialog(BuildContext context, String feedbackText) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Saioa gordeta!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Irakasle Birtualak zure entseguaren oharrak aztertu ditu.\n\nNahi al duzu bere aholku pertsonalizatuak ikusi?',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              child: const Text('Ez, eskerrik asko', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(context); 
                _erakutsiFeedbackBottomSheet(context, feedbackText); 
              },
              child: const Text('Bai, aholkuak ikusi', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = Colors.deepPurple;

    if (widget.event.exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.event.title)),
        body: const Center(child: Text("Errutina honek ez du ariketarik.")),
      );
    }

    final currentExercise = widget.event.exercises[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.event.title),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Fasea: ${_currentIndex + 1} / ${widget.event.exercises.length}',
                style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            
            Text(
              currentExercise.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _isRunning ? Colors.orange : Colors.grey.shade300, width: 8),
              ),
              child: Text(
                _formatTime(_remainingSeconds),
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  onPressed: _toggleTimer,
                  backgroundColor: _isRunning ? Colors.orange : Colors.deepPurple,
                  child: Icon(_isRunning ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            if (_isRunning)
              const Text("Grabatzen...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            
            TextButton.icon(
              onPressed: _nextExercise,
              icon: const Icon(Icons.skip_next, color: Colors.grey),
              label: Text(
                _currentIndex < widget.event.exercises.length - 1 ? 'Saltatu hurrengora' : 'Amaitu errutina',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            
            const SizedBox(height: 20),

            // BERRIA: Metronomoaren kaxa hemen integratuta
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Metronomoa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 10),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 50),
                            width: 12, height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _metronomoPiztuta 
                                  ? (_isTickActive ? Colors.orange : Colors.grey.shade300)
                                  : Colors.transparent,
                              boxShadow: _isTickActive ? [BoxShadow(color: Colors.orange.withOpacity(0.6), blurRadius: 8)] : [],
                            ),
                          )
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
                            color: _isMuted ? Colors.redAccent : Colors.grey,
                            tooltip: "Isilarazi grabazioa ez zikintzeko",
                            onPressed: _toggleMute,
                          ),
                          Switch(
                            value: _metronomoPiztuta,
                            activeColor: brandColor,
                            onChanged: (balioa) => _toggleMetronome(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('${_bpm.toInt()} BPM', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: brandColor)),
                      Expanded(
                        child: Slider(
                          value: _bpm,
                          min: 40, max: 220,
                          activeColor: brandColor,
                          inactiveColor: brandColor.withOpacity(0.2),
                          onChanged: _changeBPM,
                        ),
                      ),
                    ],
                  ),
                  if (_isMuted)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        "* Mutututa: Argi laranjari jarraitu erritmoa ez galtzeko.",
                        style: TextStyle(fontSize: 12, color: Colors.redAccent, fontStyle: FontStyle.italic),
                      ),
                    )
                ],
              ),
            ),
            
            const Divider(height: 60),

            TextField(
              controller: _oharrakController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Oharrak (Nola joan da gaur?)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _finishPractice,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: const Text('Amaitu orain eta Gorde', style: TextStyle(color: Colors.white, fontSize: 16)),
            )
          ],
        ),
      ),
    );
  }
}