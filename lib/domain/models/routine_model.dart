// lib/domain/models/routine_model.dart

class Exercise {
  String name;
  int durationMinutes;
  String? audioPath; // Ariketa bakoitzaren grabazioaren bidea

  // KONTUZ: Hemen audioPath gehitu behar da konstruktorean!
  Exercise({
    required this.name, 
    required this.durationMinutes, 
    this.audioPath
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'durationMinutes': durationMinutes,
      'audio_path': audioPath, // Firebase-n gako honekin gordeko da
    };
  }

  // Faktoria metodoa ariketa bat mapatik sortzeko
  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      name: map['name'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 0,
      audioPath: map['audio_path'],
    );
  }
}

class Routine {
  String? id;
  String title;
  List<Exercise> exercises;
  DateTime createdAt;

  Routine({
    this.id,
    required this.title,
    required this.exercises,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map, String documentId) {
    return Routine(
      id: documentId,
      title: map['title'] ?? 'Izenbururik gabe',
      exercises: (map['exercises'] as List?)?.map((e) => Exercise(
        name: e['name'] ?? '',
        durationMinutes: e['durationMinutes'] ?? 0,
        audioPath: e['audio_path'], 
      )).toList() ?? [],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
} // <--- Hemen falta zen giltza!

class AgendaEvent {
  String? id;
  String routineId;
  String title;
  String dateStr; 
  bool completed;
  List<Exercise> exercises;
  
  String? oharrak;
  int? iraupenaReala;
  String? audioPath; // Praktika librerako audioa

  AgendaEvent({
    this.id, 
    required this.routineId, 
    required this.title, 
    required this.dateStr, 
    this.completed = false,
    required this.exercises,
    this.oharrak,
    this.iraupenaReala,
    this.audioPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'routineId': routineId,
      'title': title,
      'dateStr': dateStr,
      'completed': completed,
      'exercises': exercises.map((e) => e.toMap()).toList(),
      'oharrak': oharrak,
      'iraupena_reala': iraupenaReala,
      'audio_path': audioPath,
    };
  }

  factory AgendaEvent.fromMap(Map<String, dynamic> map, String documentId) {
    return AgendaEvent(
      id: documentId,
      routineId: map['routineId'] ?? '',
      title: map['title'] ?? 'Izenbururik gabe',
      dateStr: map['dateStr'] ?? '',
      completed: map['completed'] ?? false,
      // HEMEN DAGO GAKOA: Ariketak mapeatzean audioPath kargatu behar dugu banan-banan
      exercises: (map['exercises'] as List?)?.map((e) => Exercise(
        name: e['name'] ?? '',
        durationMinutes: e['durationMinutes'] ?? 0,
        audioPath: e['audio_path'], 
      )).toList() ?? [],
      oharrak: map['oharrak'],
      iraupenaReala: map['iraupena_reala'],
      audioPath: map['audio_path'],
    );
  }
}