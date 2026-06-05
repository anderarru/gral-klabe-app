import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart'; 
import '../data/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // BERRIAK: Erregistrorako eremu berriak
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  
  // Pantaila zein modutan dagoen jakiteko (Login ala Erregistroa)
  bool _isLogin = true; 

  final AuthService _authService = AuthService();

  // ── Email / Password ──────────────────────────────────────────────────────
  void _autentikatu() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    // Erregistroaren balidazioak
    if (!_isLogin) {
      final izena = _nameController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (izena.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
        _mezuaErakutsi('Mesedez, bete eremu guztiak');
        return;
      }

      if (password != confirmPassword) {
        _mezuaErakutsi('Errorea: Pasahitzak ez dira berdinak');
        return;
      }
    } else {
      // Login-aren balidazioak
      if (email.isEmpty || password.isEmpty) {
        _mezuaErakutsi('Mesedez, bete eremu guztiak');
        return;
      }
    }

    setState(() => _isLoading = true);
    User? user;

    try {
      if (_isLogin) {
        // SAIOA HASI
        user = await _authService.saioaHasi(email, password);
        if (user == null) {
          _mezuaErakutsi('Errorea: Pasahitza edo posta okerrak dira.');
        }
      } else {
        // KONTUA SORTU
        user = await _authService.erabiltzaileaErregistratu(email, password);
        if (user == null) {
          _mezuaErakutsi('Errorea: Ezin izan da sortu. Posta erabilita dago?');
        } else {
          // Erabiltzailearen izena Firebasen gorde!
          await user.updateDisplayName(_nameController.text.trim());
          await user.reload(); // Datuak eguneratzeko
          user = FirebaseAuth.instance.currentUser; 
        }
      }
    } catch (e) {
      _mezuaErakutsi('Errorea: $e');
    }

    setState(() => _isLoading = false);

    if (user != null) {
      // Orain izena badu, izenaz agurtuko dugu
      String agurra = user.displayName != null && user.displayName!.isNotEmpty 
          ? user.displayName! 
          : user.email!;
          
      _mezuaErakutsi('Ongi etorri, $agurra!');
      
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _googleSaioaHasi() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; 
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      setState(() => _isLoading = false);

      if (user != null && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mezuaErakutsi('Google errorea: $e');
    }
  }

  // ── GitHub Sign-In ────────────────────────────────────────────────────────
  Future<void> _githubSaioaHasi() async {
    setState(() => _isLoading = true);
    try {
      final GithubAuthProvider githubProvider = GithubAuthProvider();
      final userCredential = await FirebaseAuth.instance.signInWithProvider(githubProvider);
      final user = userCredential.user;

      setState(() => _isLoading = false);

      if (user != null && context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mezuaErakutsi('GitHub errorea: $e');
    }
  }

  void _mezuaErakutsi(String testua) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(testua)),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Izenburua (Dinamikoa) ──
              Text(
                _isLogin ? 'Saioa hasi' : 'Kontua sortu',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              
              // ── Login/Erregistroa txandakatzeko testua ──
              Row(
                children: [
                  Text(
                    _isLogin ? 'Erabiltzaile berria? ' : 'Baduzu kontua? ',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        // Garbitu eremuak moduz aldatzean
                        _emailController.clear();
                        _passwordController.clear();
                        _nameController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    child: Text(
                      _isLogin ? 'Eman izena' : 'Sartu hemen',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Izena (Bakarrik erregistroan) ──
              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Zure izena',
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.black45),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Email ──
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Posta elektronikoa',
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.black45),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),

              // ── Pasahitza ──
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Pasahitza (gutxienez 6 karaktere)',
                  prefixIcon: const Icon(Icons.lock_outline, color: Colors.black45),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.black45,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              // ── Pasahitza Errepikatu (Bakarrik erregistroan) ──
              if (!_isLogin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Errepikatu pasahitza',
                    prefixIcon: const Icon(Icons.lock_reset_outlined, color: Colors.black45),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.black45,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // ── Botoi Nagusia (Dinamikoa) ──
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _autentikatu,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _isLogin ? 'Sartu' : 'Erregistratu',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Banatzailea ──
              Row(
                children: const [
                  Expanded(child: Divider(color: Colors.black26)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('edo',
                        style: TextStyle(color: Colors.black45, fontSize: 13)),
                  ),
                  Expanded(child: Divider(color: Colors.black26)),
                ],
              ),
              const SizedBox(height: 20),

              // ── Sare sozialen testua ──
              const Center(
                child: Text(
                  'Sartu zure sare sozialekin',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 20),

              // ── Sare sozialak: Google + GitHub ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialButton(
                    onTap: _isLoading ? null : _googleSaioaHasi,
                    child: SvgPicture.asset(
                      'assets/icons/google.svg', 
                      height: 24,
                      width: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _SocialButton(
                    onTap: _isLoading ? null : _githubSaioaHasi,
                    child: SvgPicture.asset(
                      'assets/icons/github.svg', 
                      height: 24,
                      width: 24,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Botoi biribilentzako widget laguntzailea ──────────────────────────────
class _SocialButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _SocialButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}