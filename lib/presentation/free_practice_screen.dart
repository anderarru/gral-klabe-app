import 'package:flutter/material.dart';
import 'dart:async';
import '../data/firestore_service.dart';
import '../data/audio_recorder_service.dart'; 
import '../data/metronome_service.dart';
import '../data/virtual_teacher_service.dart'; // BERRIA: Irakasle birtuala inportatu

class FreePracticeScreen extends StatefulWidget {
  const FreePracticeScreen({super.key});

  @override
  State<FreePracticeScreen> createState() => _FreePracticeScreenState();
}

class _FreePracticeScreenState extends State<FreePracticeScreen> {
  // ── Kronometroaren Aldagaiak ──
  int _segundoak = 0;
  Timer? _timer;
  bool _martxanDa = false; 

  // ── Grabazio Aldagaiak ──
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  String? _audioPath;

  // ── Metronomoaren Aldagaiak (Mini bertsioa) ──
  final MetronomeService _metronomeService = MetronomeService();
  double _bpm = 100; 
  bool _metronomoPiztuta = false;
  bool _isMuted = false;
  bool _isTickActive = false;
  StreamSubscription? _tickSubscription;

  // ── Oharren Aldagaia ──
  final TextEditingController _oharrakController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
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

  String _denboraFormatua() {
    int orduak = _segundoak ~/ 3600;
    int minutuak = (_segundoak % 3600) ~/ 60;
    int segunduHondarra = _segundoak % 60;
    
    if (orduak > 0) {
      return '${orduak.toString().padLeft(2, '0')}:${minutuak.toString().padLeft(2, '0')}:${segunduHondarra.toString().padLeft(2, '0')}';
    }
    return '${minutuak.toString().padLeft(2, '0')}:${segunduHondarra.toString().padLeft(2, '0')}';
  }

  void _hasiPraktika() async {
    if (_segundoak == 0) {
      await _audioRecorder.startRecording();
    }
    _timer?.cancel();
    setState(() => _martxanDa = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _segundoak++);
    });
  }

  void _pausatuKronometroa() {
    _timer?.cancel();
    setState(() => _martxanDa = false);
  }

  // BERRIA: Funtzio eguneratua IA integratzeko
 // BERRIA: Funtzio eguneratua IA integratzeko (Context errorea konponduta)
  void _amaituSaioa() async {
    _pausatuKronometroa();
    
    if (_metronomoPiztuta) _toggleMetronome();

    _audioPath = await _audioRecorder.stopRecording();

    if (!mounted) return;

    // 1. Lehenengo dialogoa: Saioaren izena eskatu
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (dialogContext) { // <-- ALDAKETA GARRANTZITSUA: 'dialogContext' izena jarri diogu
        String saioarenIzena = "";
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Saioa amaitu da! 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Guztira: ${_denboraFormatua()} landu duzu.', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Zer landu duzu?',
                  hintText: 'Adib: Eskalak, Inprobisazioa...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (balioa) => saioarenIzena = balioa,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _hasiPraktika(); 
                Navigator.pop(dialogContext); // <-- dialogContext erabili
              },
              child: const Text('Jarraitu', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (saioarenIzena.isEmpty) saioarenIzena = "Praktika Librea";
                
                // 2. Itxi izena eskatzen duen dialogoa
                Navigator.pop(dialogContext); // <-- dialogContext erabili ixteko
                
                // 3. Karga-pantaila erakutsi (Pantaila nagusiaren 'context' garbia erabiliz)
                _mostrarCargandoDialog(context); 

                try {
                  int iraupenaSegunduak = _segundoak;
                  
                  // 4. Datuak Firestore-n gorde
                  print("1. Firebase gordetzen...");
                  await _firestoreService.saveFreePractice(
                    saioarenIzena, 
                    _oharrakController.text, 
                    iraupenaSegunduak,
                    _audioPath ?? "" 
                  );

                  // 5. IArekin konektatu feedback-a lortzeko (Groq)
                  print("2. Firebase OK. Groq deitzen...");
                  final String feedback = await VirtualTeacherService().getFeedback(
                    instrument: 'Klarinetea', 
                    durationInSeconds: iraupenaSegunduak,
                    notes: _oharrakController.text.isEmpty ? 'Gaurko saioa normal joan da.' : _oharrakController.text,
                  );
                  print("3. Groq OK!");
                  // 6. Karga-pantaila itxi eta GALDETEGIA erakutsi
                  if (mounted) {
                    Navigator.pop(context); // Karga-adierazlea itxi
                    _erakutsiGaldetegiaDialog(context, feedback); 
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Karga-adierazlea itxi errorea bada
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Errorea datuak gordetzean. Saiatu berriro.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Gorde'),
            ),
          ],
        );
      },
    );
  }
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

  @override
  void dispose() {
    _timer?.cancel();
    _oharrakController.dispose();
    _audioRecorder.dispose(); 
    _tickSubscription?.cancel();
    _metronomeService.pause();
    super.dispose();
  }

  // ── IA INTERFAZE ELEMENTUAK (Rutinetatik ekarriak) ──
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
                Navigator.pop(context); // Dialog-a itxi
                Navigator.pop(context); // Praktika Libre pantailatik atera
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
                Navigator.pop(context); // Dialog-a itxi
                _erakutsiFeedbackBottomSheet(context, feedbackText); // BottomSheet-a ireki
              },
              child: const Text('Bai, aholkuak ikusi', style: TextStyle(fontSize: 16)),
            ),
          ],
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
                    Navigator.pop(context); // BottomSheet-a itxi
                    Navigator.pop(context); // Praktika Libre pantailatik atera
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

  @override
  Widget build(BuildContext context) {
    final brandColor = Colors.deepPurple;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text('Praktika Librea', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: _martxanDa ? Colors.orange : Colors.grey.shade300, 
                  width: 8
                ),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
              ),
              child: Text(
                _denboraFormatua(),
                style: const TextStyle(fontSize: 50, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 30),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  onPressed: _martxanDa ? _pausatuKronometroa : _hasiPraktika,
                  backgroundColor: _martxanDa ? Colors.orange : brandColor,
                  child: Icon(_martxanDa ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 40),
                ),
                const SizedBox(width: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: const Text('Amaitu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: _segundoak > 0 ? _amaituSaioa : null,
                ),
              ],
            ),
            
            const SizedBox(height: 40),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
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
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Saioaren Oharrak', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _oharrakController,
                    maxLines: 4, 
                    decoration: InputDecoration(
                      hintText: 'Idatzi hemen landu duzuna...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}