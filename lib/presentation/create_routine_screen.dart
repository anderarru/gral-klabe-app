import 'package:flutter/material.dart';
import '../domain/models/routine_model.dart';
import '../data/firestore_service.dart';

class CreateRoutineScreen extends StatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _titleController = TextEditingController();
  final _exerciseNameController = TextEditingController();
  final _exerciseTimeController = TextEditingController();
  
  final List<Exercise> _exercises = [];
  bool _isLoading = false;
  
  // Instanciamos nuestro servicio de la capa Data
  final FirestoreService _firestoreService = FirestoreService();

  void _addExercise() {
    if (_exerciseNameController.text.isNotEmpty && _exerciseTimeController.text.isNotEmpty) {
      setState(() {
        _exercises.add(Exercise(
          name: _exerciseNameController.text,
          durationMinutes: int.parse(_exerciseTimeController.text),
        ));
        _exerciseNameController.clear();
        _exerciseTimeController.clear();
      });
    }
  }

  Future<void> _handleSave() async {
    if (_titleController.text.isEmpty || _exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesedez, sartu errutinaren izena eta gutxienez ariketa bat.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Sortu objektua (Capa Domain)
      final newRoutine = Routine(
        title: _titleController.text,
        exercises: _exercises,
        createdAt: DateTime.now(),
      );

      // 2. Gorde Firebase-n (Capa Data erabiltzen dugu)
      await _firestoreService.saveRoutine(newRoutine);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Errutina gorde da hodeian!')),
        );
        Navigator.pop(context); // Itzuli hasierako pantailara
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errorea: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Errutina Berria'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Errutinaren izena (adib. Beroketa)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _exerciseNameController,
                    decoration: const InputDecoration(labelText: 'Ariketa (adib. Eskalak)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _exerciseTimeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutuak'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.deepPurple, size: 35),
                  onPressed: _addExercise,
                )
              ],
            ),
            const SizedBox(height: 20),
            
            // HEMEN DAGO ALDAKETA: Zerrenda askoz politagoa (Card erabiliz)
            Expanded(
              child: ListView.builder(
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.music_note, color: Colors.deepPurple),
                      title: Text(
                        _exercises[index].name, 
                        style: const TextStyle(fontWeight: FontWeight.bold)
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_exercises[index].durationMinutes} min',
                          style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Gorde botoia ere estilo hobetuarekin utzi dut
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Gorde hodeian', style: TextStyle(fontSize: 18, color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}