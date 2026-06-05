import 'package:flutter/material.dart';
import 'login_screen.dart'; // Login pantailara nabigatu ahal izateko inportatzen dugu

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade50, // Atzealde more argia
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikono erraldoia
            const Icon(
              Icons.music_note,
              size: 120,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 24),
            
            // Izenburua
            const Text(
              'Music App',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 12),
            
            // Azpititulua
            const Text(
              'Musika praktikatzeko app-a',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 60), // Espazio handia botoiaren aurretik
            
            // Login pantailara joateko botoia
            ElevatedButton(
              onPressed: () {
                // Login pantailarako nabigazioa
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Botoi borobildua
                ),
              ),
              child: const Text(
                'Hasi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}