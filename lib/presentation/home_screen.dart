import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'free_practice_screen.dart';
import 'my_routines_screen.dart'; 
import 'package:google_sign_in/google_sign_in.dart';

import '../domain/models/routine_model.dart';
import '../data/firestore_service.dart';
import 'active_routine_screen.dart'; 
import 'history_screen.dart';
import 'tuner_screen.dart';
import 'dart:ui';
import 'package:flutter_svg/flutter_svg.dart'; 
import 'metronome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _aukeratutakoIndizea = 0;

  static final List<Widget> _pantailak = <Widget>[
    const _HasiPantaila(),      
    const HistoryScreen(),  
    const _TresnakPantaila(),      
  ];

  void _pestainaAldatu(int indizea) {
    setState(() {
      _aukeratutakoIndizea = indizea;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Music App'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await GoogleSignIn().signOut();
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              }
            },
          )
        ],
      ),
      body: _pantailak[_aukeratutakoIndizea],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.play_circle_fill),
            label: 'Hasi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Estatistikak',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune),
            label: 'Tresnak',
          ),
        ],
        currentIndex: _aukeratutakoIndizea,
        selectedItemColor: Colors.deepPurple,
        onTap: _pestainaAldatu,
      ),
    );
  }
}

// ------------------------------------------------------------------------
// 0. PESTAÑA: HASI
// ------------------------------------------------------------------------
class _HasiPantaila extends StatelessWidget {
  const _HasiPantaila();

  // BERRIA: Funtzioa ORAIN HEMEN DAGO, klase honen barruan!
  void _showRoutinePreviewModal(BuildContext context, AgendaEvent event) {
    final totalMins = event.exercises.fold(0, (sum, e) => sum + e.durationMinutes);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.65, 
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();
    final today = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Kaixo, ${user?.email?.split('@')[0] ?? "Musikaria"}!', 
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          const Text(
            'Gaurko lana:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          const SizedBox(height: 10),
          
          StreamBuilder<List<AgendaEvent>>(
            stream: firestoreService.getAgendaForDay(today),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final events = snapshot.data ?? [];

              if (events.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Text(
                    'Ez daukazu ezer planifikatuta gaurko.',
                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
                children: events.map((event) {
                  return Card(
                    color: event.completed ? Colors.green.shade50 : Colors.white,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: event.completed ? Colors.green : Colors.orange,
                        child: Icon(event.completed ? Icons.check : Icons.play_arrow, color: Colors.white),
                      ),
                      title: Text(
                        event.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: event.completed ? TextDecoration.lineThrough : null, // Gaineratu svgarri txiki hau
                        ),
                      ),
                      subtitle: Text('${event.exercises.length} ariketa'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        if (!event.completed) {
                          _showRoutinePreviewModal(context, event);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hau jada amaitu duzu!')),
                          );
                        }
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 30),
          const Text(
            'Zure tresnak:',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 10),

          _BotoiHandia(
            svgBidea: 'assets/icons/clock.svg', 
            izenburua: 'Praktika Librea',
            azpititulua: 'Inprobisatu, grabatu eta neurtu zure denbora.',
            kolorea: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FreePracticeScreen()),
              );
            },
          ),
          
          const SizedBox(height: 20),

          _BotoiHandia(
            svgBidea: 'assets/icons/routines.svg', 
            izenburua: 'Nire Agenda',
            azpititulua: 'Kudeatu zure errutinak eta planifikatu asteak.',
            kolorea: Colors.deepPurple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MyRoutinesScreen()), 
              );
            },
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------
// 1. PESTAÑA: ESTATISTIKAK
// ------------------------------------------------------------------------
class _EstatistikakPantaila extends StatelessWidget {
  const _EstatistikakPantaila();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Aurrerapena eta estatistikak.',
        style: TextStyle(fontSize: 16, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ------------------------------------------------------------------------
// 2. PESTAÑA: TRESNAK
// ------------------------------------------------------------------------
class _TresnakPantaila extends StatelessWidget {
  const _TresnakPantaila();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Lanerako Tresnak',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple),
        ),
        const SizedBox(height: 20),
        
        _ToolCard(
          title: 'Afinadore Kromatikoa',
          icon: Icons.graphic_eq,
          description: 'Zure instrumentua afinatzeko.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TunerScreen())),
        ),
        
        const SizedBox(height: 15),
        
        _ToolCard(
          title: 'Metronomoa',
          icon: Icons.timer, 
          description: 'Erritmoa eta tempoa mantentzeko.',
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MetronomeScreen())),
        ),
      ],
    );
  }
}

// Laguntzailea diseinu bera izateko
class _ToolCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final VoidCallback onTap;

  const _ToolCard({required this.title, required this.icon, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Icon(icon, color: Colors.deepPurple, size: 40),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

// ------------------------------------------------------------------------
// WIDGET LAGUNTZAILEA
// ------------------------------------------------------------------------
class _BotoiHandia extends StatelessWidget {
  final String svgBidea; 
  final String izenburua;
  final String azpititulua;
  final Color kolorea;
  final VoidCallback onTap;

  const _BotoiHandia({
    required this.svgBidea, 
    required this.izenburua,
    required this.azpititulua,
    required this.kolorea,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap, 
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kolorea.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: SvgPicture.asset(
                      svgBidea,
                      width: 30,
                      height: 30,
                      colorFilter: ColorFilter.mode(kolorea, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          izenburua,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          azpititulua,
                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}