import 'package:flutter/material.dart';
import '../../data/virtual_teacher_service.dart'; // Egokitu bidea behar baduzu
import '../../data/firestore_service.dart'; 
import '../../domain/models/routine_model.dart'; 

class AiGeneratorSheet extends StatefulWidget {
  final DateTime selectedDate; 

  const AiGeneratorSheet({super.key, required this.selectedDate});

  @override
  State<AiGeneratorSheet> createState() => _AiGeneratorSheetState();
}

class _AiGeneratorSheetState extends State<AiGeneratorSheet> {
  double _minutes = 30; 
  final TextEditingController _focusController = TextEditingController();
  bool _isLoading = false;

  Future<void> _generateWithAI() async {
    if (_focusController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesedez, idatzi zer landu nahi duzun.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 1. Groq-era deitu JSON-a lortzeko
    final routineData = await VirtualTeacherService().generateRoutine(
      instrument: 'Klarinetea', 
      totalMinutes: _minutes.toInt(),
      focus: _focusController.text,
    );

    if (routineData != null && mounted) {
      try {
        // 2. JSON-a zure Exercise modelora pasatu
        List<Exercise> ariketak = routineData.map((data) => Exercise(
          name: data['name'] ?? 'Ariketa',
          durationMinutes: data['durationMinutes'] ?? 5,
        )).toList();

        // 3. Eguna ondo formatu (YYYY-MM-DD) zure Firestore zerbitzuak eskatzen duen bezala
        String dateStr = "${widget.selectedDate.year}-${widget.selectedDate.month.toString().padLeft(2,'0')}-${widget.selectedDate.day.toString().padLeft(2,'0')}";

        // 4. AgendaEvent sortu (ID faltsu batekin sortzen dugu, Firestore-k berea jarriko dio)
        final newEvent = AgendaEvent(
          routineId: 'IA_GENERATED', 
          title: 'AA: ${_focusController.text}',
          dateStr: dateStr,
          exercises: ariketak,
        );

        // 5. Zure Firestore zerbitzua erabili egutegian gordetzeko
        await FirestoreService().scheduleRoutine(newEvent);

        if (mounted) {
          Navigator.pop(context); // Panela itxi
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✨ Errutina magikoki sortu eta agendara gehitu da!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        print("Errorea JSON-a parseatzean edo gordetzean: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Errorea datuak prozesatzean.'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errorea errutina sortzean. Saiatu berriro.'), backgroundColor: Colors.red),
        );
      }
    }
    
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.deepPurple[700], size: 28),
              const SizedBox(width: 10),
              const Text('AA Errutina Sortzailea', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          
          Text('1. Zenbat denbora daukazu gaur? (${widget.selectedDate.day}/${widget.selectedDate.month})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${_minutes.toInt()} min', style: TextStyle(color: Colors.deepPurple[700], fontWeight: FontWeight.bold, fontSize: 18)),
              Expanded(
                child: Slider(
                  value: _minutes,
                  min: 10, max: 120, divisions: 22,
                  activeColor: Colors.deepPurple,
                  onChanged: (val) => setState(() => _minutes = val),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Text('2. Zer landu nahi duzu zehazki?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(
            controller: _focusController,
            decoration: InputDecoration(
              hintText: 'Adib: Artikulazioa, nota luzeak, eskalak...',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          
          const SizedBox(height: 30),
          
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _generateWithAI,
              child: _isLoading 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('✨ Sortu Errutina', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}