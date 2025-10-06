
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SuportePage extends StatefulWidget {
  const SuportePage({super.key});

  @override
  State<SuportePage> createState() => _SuportePageState();
}

class _SuportePageState extends State<SuportePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  bool _isLoading = false;
  bool _isSuccess = false;
  String? _selectedCollaborator;
  AnimationController? _animationController;
  Animation<double>? _scaleAnimation;

  // Lista de colaboradores
  final List<String> _collaborators = [
    'Alline',
    'Maria Eduarda',
    'Cássio Vinicius',
    'Freelancer 1',
    'Carlos Júnior',
    'Kennedy',
  ];

  // Número de telefone do WhatsApp para onde as mensagens serão enviadas
  final String _whatsappNumber = "5531998501560";

  // Configurações da API Evolution
  final String _apiUrl = "http://82.25.71.135:8080/message/sendText/central_delivery";
  final String _apiKey = "3f0d87b1-0c4a-4e9c-bf14-9a07f6b7e9d3";

  // Cor laranja principal
  final Color primaryColor = const Color(0xFFF28C38);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _sendMessageToWhatsApp(String collaborator, String message) async {
    setState(() {
      _isLoading = true;
      _isSuccess = false;
    });

    try {
      final fullMessage = "Mensagem de $collaborator: $message";
      final payload = {
        "number": _whatsappNumber,
        "text": fullMessage,
      };
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          "Content-Type": "application/json",
          "apikey": _apiKey,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          setState(() {
            _isSuccess = true;
          });
          _animationController!.forward().then((_) {
            _animationController!.reverse();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Mensagem enviada com sucesso!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          _messageController.clear();
          setState(() {
            _selectedCollaborator = null;
            _isLoading = false;
          });
          _formKey.currentState!.reset();
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception('Erro ao enviar mensagem: ${errorData['message'] ?? response.statusCode}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erro ao enviar mensagem: $error',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxCardWidth = screenWidth > 800 ? 500.0 : screenWidth * 0.9;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: maxCardWidth,
            margin: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.support_agent,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Suporte',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Envie sugestões, reporte bugs ou peça melhorias:',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 2,
                  color: primaryColor.withOpacity(0.3),
                ),
                const SizedBox(height: 24),

                // Card do Formulário
                Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white, // Fundo branco
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dropdown de Colaborador
                          DropdownButtonFormField<String>(
                            value: _selectedCollaborator,
                            decoration: InputDecoration(
                              labelText: 'Quem está enviando a mensagem?',
                              labelStyle: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primaryColor.withOpacity(0.5),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primaryColor.withOpacity(0.5),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: primaryColor,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _collaborators.map((collaborator) {
                              return DropdownMenuItem<String>(
                                value: collaborator,
                                child: Text(
                                  collaborator,
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedCollaborator = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Por favor, selecione quem está enviando';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Campo de Mensagem
                          TextFormField(
                            controller: _messageController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              labelText: 'Digite sua mensagem',
                              labelStyle: GoogleFonts.poppins(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primaryColor.withOpacity(0.5),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primaryColor.withOpacity(0.5),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.message_outlined,
                                color: primaryColor,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Por favor, digite sua mensagem';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Botão Enviar
                          SizedBox(
                            width: double.infinity,
                            child: AnimatedBuilder(
                              animation: _scaleAnimation!,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _isSuccess ? _scaleAnimation!.value : 1.0,
                                  child: ElevatedButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            if (_formKey.currentState!.validate()) {
                                              _sendMessageToWhatsApp(
                                                _selectedCollaborator!,
                                                _messageController.text,
                                              );
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isSuccess ? Colors.green.shade600 : primaryColor,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 5,
                                      shadowColor: primaryColor.withOpacity(0.3),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 3,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (_isSuccess)
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              if (_isSuccess) const SizedBox(width: 8),
                                              Text(
                                                _isSuccess ? 'Mensagem Enviada!' : 'Enviar Mensagem',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
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
