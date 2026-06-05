import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart'; // BERRIA: Euskararako

import '../domain/models/routine_model.dart';
import '../data/firestore_service.dart';
import 'create_routine_screen.dart';
import 'active_routine_screen.dart';
import 'widgets/ai_generator_sheet.dart'; 
class MyRoutinesScreen extends StatefulWidget {
  const MyRoutinesScreen({super.key});

  @override
  State<MyRoutinesScreen> createState() => _MyRoutinesScreenState();
}

class _MyRoutinesScreenState extends State<MyRoutinesScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  final FirestoreService _firestoreService = FirestoreService();

  // Agenda osoa kargatzeko stream-a (egutegian puntuak jartzeko)
  late Stream<List<AgendaEvent>> _agendaStream;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('eu'); // Egutegia euskaraz
    // Suposatzen dugu funtzio hau baduzula agenda osoa ekartzeko
    _agendaStream = _firestoreService.getAgendaForDay(DateTime(2020)); // Aldatu zure funtzio orokorrera behar baduzu
  }

  // --- 1. MODALA: ERRUTINA AUKERATU ---
  void _showAssignModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.75, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              const Text(
                'Liburutegia: Esleitu Errutina',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
              ),
              const Text("Aukeratu errutina bat zure agendara gehitzeko", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              Expanded(
                child: StreamBuilder<List<Routine>>(
                  stream: _firestoreService.getUserRoutines(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    final routines = snapshot.data ?? [];
                    
                    if (routines.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_music_outlined, size: 60, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            const Text("Ez daukazu errutinarik gordeta."),
                          ],
                        )
                      );
                    }

                    return ListView.builder(
                      itemCount: routines.length,
                      itemBuilder: (context, index) {
                        final routine = routines[index];
                        final totalMins = routine.exercises.fold(0, (sum, e) => sum + e.durationMinutes);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          child: ExpansionTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.library_music, color: Colors.deepPurple),
                            ),
                            title: Text(routine.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${routine.exercises.length} ariketa • $totalMins min totala'),
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                width: double.infinity,
                                color: Colors.grey.shade50,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: routine.exercises.map((e) => 
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text('• ${e.name} (${e.durationMinutes} min)', style: const TextStyle(color: Colors.black87)),
                                    )
                                  ).toList(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // BOTOIA: Egun baterako bakarrik
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () => _assignSingleDay(routine),
                                        icon: const Icon(Icons.today, size: 18),
                                        label: Text('Egun honetan (${_selectedDay.day})'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.deepPurple,
                                          side: const BorderSide(color: Colors.deepPurple),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // BOTOIA: Planifikazio aurreratua
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showAdvancedAssignDialog(routine),
                                        icon: const Icon(Icons.date_range, size: 18),
                                        label: const Text('Hainbat egun...'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.deepPurple,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
const SizedBox(height: 10),
              // BERRIA: Botoien blokea (IA + Eskuz)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // Itxi liburutegiko modala
                        
                        // BERRIA: Ireki IAren panela eta pasatu aukeratutako eguna
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                          builder: (context) => AiGeneratorSheet(selectedDate: _selectedDay), // <-- Fitxategi berria!
                        );
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Sortu errutina IA-rekin', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateRoutineScreen()));
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Sortu errutina berria hutsetik', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ESLEIPEN FUNTZIOAK ---

  // Funtzio sinplea (Aukeratutako egunerako bakarrik)
  Future<void> _assignSingleDay(Routine routine) async {
    String dateStr = "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2,'0')}-${_selectedDay.day.toString().padLeft(2,'0')}";
    final newEvent = AgendaEvent(
      routineId: routine.id ?? '',
      title: routine.title,
      dateStr: dateStr,
      exercises: routine.exercises,
    );
    await _firestoreService.scheduleRoutine(newEvent);
    if (mounted) {
      Navigator.pop(context); // Itxi modala
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Errutina agendara gehitu da!'), backgroundColor: Colors.green));
    }
  }

  // --- 2. MODALA: PLANIFIKAZIO AURRERATUA (Hainbat egun) ---
  void _showAdvancedAssignDialog(Routine routine) {
    DateTime start = _selectedDay;
    DateTime end = _selectedDay.add(const Duration(days: 7));
    // Astelehena(1) - Igandea(7). Hasieran guztiak aukeratuta.
    List<int> selectedWeekdays = [1, 2, 3, 4, 5, 6, 7]; 

    final List<String> egunIzenak = ['A', 'A', 'A', 'O', 'O', 'L', 'I']; // Astel, Astear, Asteaz...

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Planifikatu: ${routine.title}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Data tartea:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context, initialDate: start, firstDate: DateTime.now(), lastDate: DateTime(2030),
                              );
                              if (picked != null) setDialogState(() => start = picked);
                            },
                            child: Text("${start.day}/${start.month}/${start.year}"),
                          ),
                        ),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Icon(Icons.arrow_forward_outlined, size: 16)),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context, initialDate: end, firstDate: start, lastDate: DateTime(2030), locale: const Locale('eu', 'ES'),
                              );
                              if (picked != null) setDialogState(() => end = picked);
                            },
                            child: Text("${end.day}/${end.month}/${end.year}"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text("Asteko zein egunetan?", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        int dayValue = index + 1;
                        bool isSelected = selectedWeekdays.contains(dayValue);
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              if (isSelected) {
                                selectedWeekdays.remove(dayValue);
                              } else {
                                selectedWeekdays.add(dayValue);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 35, height: 35,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.deepPurple : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                egunIzenak[index],
                                style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Utzi', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    if (selectedWeekdays.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aukeratu gutxienez egun bat!')));
                      return;
                    }
                    
                    // Loop-a daten artean iteratzeko
                    int count = 0;
                    for (DateTime d = start; d.isBefore(end.add(const Duration(days: 1))); d = d.add(const Duration(days: 1))) {
                      if (selectedWeekdays.contains(d.weekday)) {
                        String dateStr = "${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}";
                        final newEvent = AgendaEvent(
                          routineId: routine.id ?? '', title: routine.title, dateStr: dateStr, exercises: routine.exercises,
                        );
                        await _firestoreService.scheduleRoutine(newEvent);
                        count++;
                      }
                    }

                    if (mounted) {
                      Navigator.pop(context); // Dialogoa itxi
                      Navigator.pop(context); // BottomSheet-a itxi
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$count saio planifikatu dira arrakastaz!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text('Planifikatu', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }
  // BERRIA: Errutina hasi aurretik ariketak erakusteko modala
  void _showRoutinePreviewModal(AgendaEvent event) {
    final totalMins = event.exercises.fold(0, (sum, e) => sum + e.durationMinutes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.65, // Pantailaren %65a hartuko du
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Text(event.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              Text('$totalMins minutu guztira • ${event.exercises.length} ariketa', style: const TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 20),
              const Text('Ariketen zerrenda:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              
              // Ariketen Zerrenda
              Expanded(
                child: ListView.builder(
                  itemCount: event.exercises.length,
                  itemBuilder: (context, index) {
                    final ex = event.exercises[index];
                    return Card(
                      elevation: 0,
                      color: Colors.grey.shade50,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200)
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple.withOpacity(0.1),
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text('${ex.durationMinutes} min', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Hasi Botoia
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Modala itxi
                    Navigator.push( // Kronometroaren pantailara joan
                      context,
                      MaterialPageRoute(builder: (context) => ActiveRoutineScreen(event: event)),
                    );
                  },
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: const Text('Hasi Errutina', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- DATUAK PARSATU ---
  DateTime _normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime? _parseDateString(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        final p = dateStr.split('/');
        return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
      }
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Nire Agenda', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<List<AgendaEvent>>(
        stream: _firestoreService.getAgendaForDay(_selectedDay), // Eguneko stream-a azpiko zerrendarako
        builder: (context, snapshotList) {
          
          return Column(
            children: [
              // --- EGUTEGIA ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                ),
                child: TableCalendar<AgendaEvent>(
                  locale: 'eu', // EUSKERA!
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.week, 
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  
                  // Funtzio honek jartzen ditu puntuak (Karga osoa baduzu)
                  // eventLoader: (day) => groupedSessions[_normalizeDate(day)] ?? [],

                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                    markerDecoration: BoxDecoration(color: Colors.deepPurpleAccent, shape: BoxShape.circle),
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Planifikazioa: ${_selectedDay.day}/${_selectedDay.month}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                ),
              ),

              // --- ZERRENDA ---
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (snapshotList.hasError) return const Center(child: Text('Errorea datuak kargatzean'));
                    if (snapshotList.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                    final events = snapshotList.data ?? [];

                    if (events.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 10),
                            Text('Egun honetan ez daukazu ezer planifikatuta.', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          color: event.completed ? Colors.green.shade50 : Colors.white,
                          elevation: 2,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: event.completed ? Colors.green : Colors.orange.withOpacity(0.2),
                                shape: BoxShape.circle
                              ),
                              child: Icon(event.completed ? Icons.check : Icons.play_arrow, color: event.completed ? Colors.white : Colors.orange),
                            ),
                            title: Text(
                              event.title, 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16,
                                decoration: event.completed ? TextDecoration.lineThrough : null,
                              )
                            ),
                            subtitle: Text(event.completed ? 'Eginda' : 'Zeregina zain...', style: const TextStyle(color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                await _firestoreService.deleteAgendaEvent(event.id!);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Agendatik kendu da')),
                                  );
                                }
                              },
                            ),
                            onTap: () {
                              if (!event.completed) {
                                _showRoutinePreviewModal(event);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Errutina hau jada eginda dago!')),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  }
                ),
              ),
            ],
          );
        }
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignModal,
        backgroundColor: Colors.deepPurple,
        elevation: 4,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Esleitu errutina', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}