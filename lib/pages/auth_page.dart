import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../globals.dart';
import '../provider.dart';
import '../main.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({Key? key}) : super(key: key);

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final codeString = _codeController.text.trim();
    final code = int.tryParse(codeString);

    if (code != null && users.containsKey(code)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userId', code);
      Provider.of<AuthProvider>(context, listen: false).setUser(code, users[code]!);
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } else {
      setState(() {
        _errorMessage = 'Código inválido. Tente novamente.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFF28C38);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = screenWidth > 600 ? 400.0 : screenWidth * 0.8;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: maxCardWidth,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(
                  'https://aogosto.com.br/delivery/wp-content/uploads/2025/03/go-laranja-maior-1.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 32),
                Text(
                  'Bem-vindo ao Painel ERP',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Digite seu código de acesso',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Ex: 7',
                    hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    errorText: _errorMessage,
                    errorStyle: GoogleFonts.poppins(color: Colors.red[700]),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  ),
                ),
                const SizedBox(height: 24),
                MouseRegion(
                  onEnter: (_) => _animationController.forward(),
                  onExit: (_) => _animationController.reverse(),
                  child: GestureDetector(
                    onTapDown: (_) => _animationController.forward(),
                    onTapUp: (_) => _animationController.reverse(),
                    onTap: _isLoading ? null : _login,
                    child: AnimatedBuilder(
                      animation: _scaleAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: _isLoading
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'Entrar',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}