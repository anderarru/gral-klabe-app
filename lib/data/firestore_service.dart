import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/models/routine_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- ERRUTINEN LIBURUTEGIA KUDEATZEKO ---
  Future<void> saveRoutine(Routine routine) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception("Erabiltzailea ez dago logeatuta");

      await _db.collection('users').doc(userId).collection('routines').add(routine.toMap());
    } catch (e) {
      print("Errorea errutina gordetzean: $e");
      rethrow; 
    }
  }

  Stream<List<Routine>> getUserRoutines() {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]); 

    return _db.collection('users').doc(userId).collection('routines')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Routine.fromMap(doc.data(), doc.id)).toList());
  }

  // --- BERRIA: EGUTEGIKO AGENDA KUDEATZEKO ---
  
  // Errutina bat egun batean esleitu
  Future<void> scheduleRoutine(AgendaEvent event) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _db.collection('users').doc(userId).collection('agenda').add(event.toMap());
    } catch (e) {
      print("Errorea agenda gordetzean: $e");
    }
  }

  // Egun jakin bateko errutinak irakurri
  Stream<List<AgendaEvent>> getAgendaForDay(DateTime date) {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    // Eguna YYYY-MM-DD formatura pasatu bilaketa egiteko
    String dateString = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";

    return _db.collection('users').doc(userId).collection('agenda')
        .where('dateStr', isEqualTo: dateString)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AgendaEvent.fromMap(doc.data(), doc.id)).toList());
  }

  // Agenda-ko gertaera bat osatutzat eman eta oharrak gorde
  Future<void> completeAgendaEvent(String eventId, String oharrak, int iraupena) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _db.collection('users').doc(userId).collection('agenda').doc(eventId).update({
        'completed': true,
        'oharrak': oharrak,
        'iraupena_reala': iraupena, // Zenbat denbora egon den praktikatzen
      });
    } catch (e) {
      print("Errorea osatzean: $e");
    }
  }

  // --- BERRIAK: EZABATZEKO FUNTZIOAK ---

  // 1. Errutina bat liburutegitik betiko ezabatu
  Future<void> deleteRoutine(String routineId) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _db.collection('users').doc(userId).collection('routines').doc(routineId).delete();
    } catch (e) {
      print("Errorea errutina ezabatzean: $e");
    }
  }

  // 2. Agendako gertaera bat ezabatu (egutegitik kendu)
  Future<void> deleteAgendaEvent(String eventId) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _db.collection('users').doc(userId).collection('agenda').doc(eventId).delete();
    } catch (e) {
      print("Errorea agenda gertaera ezabatzean: $e");
    }
  }

  // --- PRAKTIKA LIBREA GORDETZEKO ---
  Future<void> saveFreePractice(String title, String notes, int durationMinutes, String audioPath) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      DateTime now = DateTime.now();
      String dateStr = "${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";

      // Praktika librea "AgendaEvent" gisa gordetzen dugu estatistiketarako
      final freePracticeEvent = AgendaEvent(
        routineId: 'free_practice', 
        title: title,
        dateStr: dateStr,
        completed: true,
        exercises: [],
      );

      // 1. Gorde dokumentu nagusia
      DocumentReference docRef = await _db.collection('users').doc(userId).collection('agenda').add(freePracticeEvent.toMap());
      
      // 2. Eguneratu oharrak, denbora eta AUDIOAREN BIDEA
      await docRef.update({
        'oharrak': notes,
        'iraupena_reala': durationMinutes,
        'audio_path': audioPath, // <-- Lerro hau da gakoa!
      });

    } catch (e) {
      print("Errorea praktika librea gordetzean: $e");
    }
  }

  // --- HISTORIALA: Amaitutako saioak irakurtzeko ---
  Stream<List<AgendaEvent>> getCompletedSessions() {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _db.collection('users').doc(userId).collection('agenda')
        .where('completed', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => AgendaEvent.fromMap(doc.data(), doc.id)).toList();
          // Dart-en bertan ordenatzen ditugu, berrienak lehenengo agertzeko (Z-A)
          list.sort((a, b) => b.dateStr.compareTo(a.dateStr)); 
          return list;
        });
  }
  // Errutina osoa eguneratzeko (audio bideak barne)
  Future<void> updateCompletedRoutine(String eventId, String oharrak, int iraupena, List<Exercise> exercises) async {
    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) return;

      await _db.collection('users').doc(userId).collection('agenda').doc(eventId).update({
        'completed': true,
        'oharrak': oharrak,
        'iraupena_reala': iraupena,
        // Ariketa bakoitzaren toMap() deituta, audio_path-ak barne joango dira
        'exercises': exercises.map((e) => e.toMap()).toList(), 
      });
    } catch (e) {
      print("Errorea errutina eguneratzean: $e");
    }
  }
  
}

