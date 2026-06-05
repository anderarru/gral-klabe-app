import 'dart:io';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart'; 

import '../domain/models/routine_model.dart';
import '../data/firestore_service.dart';
import '../data/audio_player_service.dart';
import '../data/virtual_teacher_service.dart'; // BERRIA: IA zerbitzua inportatu
import 'widgets/audio_progress_bar.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirestoreService firestoreService = FirestoreService();
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  
  late Stream<List<AgendaEvent>> _sessionsStream;
  String? _currentlyPlayingId;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _showOverlay = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('eu'); 
    _sessionsStream = firestoreService.getCompletedSessions();
    _selectedDay = _focusedDay; 
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }

  void _handlePlayback(String? path, String identifier) async {
    if (path == null || path.isEmpty) return;

    if (_currentlyPlayingId == identifier) {
      await _audioPlayerService.stopAudio();
      setState(() => _currentlyPlayingId = null);
    } else {
      if (await File(path).exists()) {
        await _audioPlayerService.stopAudio();
        await _audioPlayerService.playLocalAudio(path);
        setState(() => _currentlyPlayingId = identifier);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Audio fitxategia ez da aurkitu.")),
        );
      }
    }
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime? _parseDateString(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      }
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  void _closeOverlay() {
    setState(() {
      _showOverlay = false;
      _currentlyPlayingId = null;
    });
    _audioPlayerService.stopAudio();
  }

  // BERRIA: IA Diagnostikoa sortzeko funtzioa
  void _generateEvolutionReport(BuildContext context, List<AgendaEvent> completedSessions) async {
    // 1. Azken 10 saioetako oharrak soilik hartu eta hutsik daudenak iragazi
    List<String> oharrakList = completedSessions
        .map((e) => e.oharrak ?? "")
        .where((text) => text.isNotEmpty)
        .take(10)
        .toList();

    if (oharrakList.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gutxienez 3 saiotan oharrak idatzi behar dituzu azterketa egiteko!'), backgroundColor: Colors.orange),
      );
      return;
    }

    // 2. Karga koadroa erakutsi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
    );

    // 3. IA-ri txostena eskatu
    final String report = await VirtualTeacherService().getEvolutionReport(pastNotes: oharrakList);

    // 4. Karga koadroa itxi
    if (context.mounted) Navigator.pop(context);

    // 5. Emaitza BottomSheet dotore batean erakutsi
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics_outlined, color: Colors.deepPurple, size: 28),
                  SizedBox(width: 10),
                  Text('Ikaskuntza Diagnostikoa', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Text(report, style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800])),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Ulertuta'),
                ),
              )
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = Colors.deepPurple;

    return StreamBuilder<List<AgendaEvent>>(
      stream: _sessionsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final allSessions = snapshot.data ?? [];
        
        // Egunka taldekatu (puntuak jartzeko)
        Map<DateTime, List<AgendaEvent>> groupedSessions = {};
        for (var session in allSessions) {
          DateTime? date = _parseDateString(session.dateStr);
          if (date != null) {
            DateTime normalized = _normalizeDate(date);
            if (groupedSessions[normalized] == null) {
              groupedSessions[normalized] = [];
            }
            groupedSessions[normalized]!.add(session);
          }
        }

        // Aukeratutako eguneko saioak lortu
        List<AgendaEvent> selectedDaySessions = [];
        if (_selectedDay != null) {
          selectedDaySessions = groupedSessions[_normalizeDate(_selectedDay!)] ?? [];
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          body: Stack(
            children: [
              // 1. GERUZA: EGUTEGIA ETA BOTOIA
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nire Historiala',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                        ),
                        // BERRIA: Botoia IA diagnostikoa sortzeko
                        ElevatedButton.icon(
                          onPressed: () => _generateEvolutionReport(context, allSessions),
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('IA Diagnostikoa', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
                      ),
                      child: TableCalendar<AgendaEvent>(
                        locale: 'eu',
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(color: brandColor.withOpacity(0.2), shape: BoxShape.circle),
                          selectedDecoration: BoxDecoration(color: brandColor, shape: BoxShape.circle),
                          markerDecoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          markersMaxCount: 1,
                        ),
                        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                        eventLoader: (day) => groupedSessions[_normalizeDate(day)] ?? [],
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                            if (groupedSessions[_normalizeDate(selectedDay)] != null) {
                              _showOverlay = true;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),

              // 2. GERUZA: POP-UP (PANEL GARBIA ETA PROFESIONALA)
              if (_showOverlay)
                Positioned(
                  top: 180, // Egutegiaren goiko aldea pixka bat ikusteko uzten du
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(
                          color: brandColor.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Burualdea: Titulua eta Ixteko botoia
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}",
                                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                  ),
                                  const Text(
                                    "Eguneko Saioak",
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.grey.shade400, size: 30),
                                onPressed: _closeOverlay,
                              ),
                            ],
                          ),
                        ),
                        
                        // Zerrenda (selectedDaySessions erabiliz)
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: selectedDaySessions.length,
                            itemBuilder: (context, index) {
                              final session = selectedDaySessions[index];
                              final bool isFreePractice = session.routineId == 'free_practice';

                              return Card(
                                elevation: 0,
                                color: const Color(0xFFF8F9FA), // Atzealde gris oso argia txarteletarako
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ExpansionTile(
                                  key: PageStorageKey(session.id),
                                  iconColor: brandColor,
                                  collapsedIconColor: Colors.grey.shade400,
                                  shape: const Border(), // Zabaltzean marra itsusiak kentzeko
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isFreePractice ? Colors.orange.withOpacity(0.1) : brandColor.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isFreePractice ? Icons.whatshot : Icons.assignment,
                                      color: isFreePractice ? Colors.orange : brandColor,
                                    ),
                                  ),
                                  title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                                  subtitle: Text("${session.iraupenaReala ?? 0} minutu", style: TextStyle(color: Colors.grey.shade600)),
                                  children: [
                                    if (session.oharrak != null && session.oharrak!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.grey.shade200),
                                          ),
                                          child: Text(
                                            session.oharrak!, 
                                            style: TextStyle(fontSize: 14, color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                                          ),
                                        ),
                                      ),
                                    
                                    if (isFreePractice)
                                      ListTile(
                                        title: const Text("Grabazioa", style: TextStyle(fontWeight: FontWeight.w500)),
                                        trailing: IconButton(
                                          icon: Icon(
                                            _currentlyPlayingId == "${session.id}_full" ? Icons.stop_circle : Icons.play_circle_fill,
                                            color: brandColor, size: 36,
                                          ),
                                          onPressed: () => _handlePlayback(session.audioPath, "${session.id}_full"),
                                        ),
                                      )
                                    else
                                      ...session.exercises.asMap().entries.map((entry) {
                                        int idx = entry.key;
                                        Exercise ex = entry.value;
                                        return ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                          title: Text(ex.name, style: const TextStyle(fontSize: 15)),
                                          trailing: (ex.audioPath != null && ex.audioPath!.isNotEmpty)
                                              ? IconButton(
                                                  icon: Icon(
                                                    _currentlyPlayingId == "${session.id}_$idx" ? Icons.stop_circle : Icons.play_circle_fill,
                                                    color: brandColor,
                                                    size: 32,
                                                  ),
                                                  onPressed: () => _handlePlayback(ex.audioPath, "${session.id}_$idx"),
                                                )
                                              : const Icon(Icons.music_off, color: Colors.grey, size: 24),
                                        );
                                      }),
                                      
                                    if (_currentlyPlayingId != null && _currentlyPlayingId!.startsWith("${session.id}"))
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: AudioProgressBar(
                                          playerService: _audioPlayerService,
                                          color: brandColor,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}