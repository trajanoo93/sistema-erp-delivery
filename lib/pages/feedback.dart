
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../provider.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> with SingleTickerProviderStateMixin {
  List<dynamic> _feedbacks = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterType = 'todos';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _newFeedbackCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _fetchFeedbacks();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchFeedbacks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = Provider.of<AuthProvider>(context, listen: false).userId;
      final response = await http.get(
        Uri.parse('https://aogosto.store/feedback/get_feedbacks.php?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        int newCount = 0;
        for (var feedback in data) {
          if (await _isFeedbackNew(feedback['date'])) {
            newCount++;
          }
        }
        setState(() {
          _feedbacks = data;
          _newFeedbackCount = newCount;
          _isLoading = false;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_feedback_view', DateTime.now().toIso8601String());
      } else {
        setState(() {
          _errorMessage = 'Erro ao carregar feedbacks: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro de conexão: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _isFeedbackNew(String feedbackDate) async {
    final prefs = await SharedPreferences.getInstance();
    final lastView = prefs.getString('last_feedback_view');
    if (lastView == null) return true;
    final lastViewDate = DateTime.parse(lastView);
    final feedbackDateTime = DateTime.parse(feedbackDate);
    return feedbackDateTime.isAfter(lastViewDate);
  }

  Future<void> _markAsRead(int feedbackId) async {
    // Para ativar, crie um endpoint update_feedback.php
    /*
    try {
      final response = await http.post(
        Uri.parse('https://aogosto.store/feedback/update_feedback.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': feedbackId, 'is_new': 0}),
      );
      if (response.statusCode == 200) {
        await _fetchFeedbacks();
      }
    } catch (e) {
      // Tratar erro
    }
    */
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFF28C38);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = screenWidth > 800 ? 600.0 : screenWidth * 0.9;
    final userName = Provider.of<AuthProvider>(context).currentUser ?? 'Usuário';

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _fetchFeedbacks,
        color: primaryColor,
        child: Center(
          child: Container(
            width: maxContentWidth,
            margin: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    children: [
                      Icon(Icons.feedback, color: primaryColor, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Feedbacks de $userName${_newFeedbackCount > 0 ? ' ($_newFeedbackCount novos)' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Confira seus destaques e melhore seu desempenho!',
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

                // Filtro com chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Todos', 'todos', primaryColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('Destaque Positivo', 'positivo', primaryColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('Ponto de Atenção', 'atencao', primaryColor),
                      const SizedBox(width: 8),
                      _buildFilterChip('Venda Extra', 'venda_extra', primaryColor),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Lista de Feedbacks
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: primaryColor))
                      : _errorMessage != null
                          ? Center(
                              child: Text(
                                _errorMessage!,
                                style: GoogleFonts.poppins(color: Colors.red[700], fontSize: 16),
                              ),
                            )
                          : _feedbacks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.feedback_outlined, color: Colors.grey[400], size: 48),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Nenhum feedback novo. Aguarde atualizações!',
                                        style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                )
                              : AnimatedList(
                                  key: GlobalKey<AnimatedListState>(),
                                  initialItemCount: _feedbacks.length,
                                  itemBuilder: (context, index, animation) {
                                    final feedback = _feedbacks[index];
                                    if (_filterType != 'todos' && feedback['type'] != _filterType) {
                                      return const SizedBox.shrink();
                                    }

                                    final iconData = feedback['type'] == 'positivo'
                                        ? Icons.thumb_up_alt
                                        : feedback['type'] == 'atencao'
                                            ? Icons.warning_amber_rounded
                                            : Icons.star_rounded;
                                    final iconColor = feedback['type'] == 'positivo'
                                        ? Colors.green[600]
                                        : feedback['type'] == 'atencao'
                                            ? Colors.yellow[700]
                                            : primaryColor;

                                    return FutureBuilder<bool>(
                                      future: _isFeedbackNew(feedback['date']),
                                      builder: (context, snapshot) {
                                        final isNew = snapshot.data ?? false;

                                        return SizeTransition(
                                          sizeFactor: animation,
                                          child: Card(
                                            elevation: 6,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                              side: BorderSide(
                                                color: isNew ? primaryColor.withOpacity(0.5) : Colors.grey[200]!,
                                              ),
                                            ),
                                            margin: const EdgeInsets.symmetric(vertical: 10),
                                            child: Padding(
                                              padding: const EdgeInsets.all(16.0),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: iconColor?.withOpacity(0.1),
                                                    ),
                                                    child: Icon(
                                                      iconData,
                                                      color: iconColor,
                                                      size: 28,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                          children: [
                                                            Text(
                                                              feedback['type'] == 'positivo'
                                                                  ? 'Destaque Positivo'
                                                                  : feedback['type'] == 'atencao'
                                                                      ? 'Ponto de Atenção'
                                                                      : 'Venda Extra',
                                                              style: GoogleFonts.poppins(
                                                                fontSize: 18,
                                                                fontWeight: FontWeight.w600,
                                                                color: iconColor,
                                                              ),
                                                            ),
                                                            if (isNew)
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(
                                                                  horizontal: 10,
                                                                  vertical: 5,
                                                                ),
                                                                decoration: BoxDecoration(
                                                                  color: primaryColor,
                                                                  borderRadius: BorderRadius.circular(12),
                                                                ),
                                                                child: Text(
                                                                  'Novo!',
                                                                  style: GoogleFonts.poppins(
                                                                    color: Colors.white,
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 10),
                                                        Text(
                                                          feedback['description'],
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 15,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 10),
                                                        Text(
                                                          'Recebido em: ${feedback['date'].substring(0, 10)}',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 13,
                                                            color: Colors.grey[600],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.check_circle, color: primaryColor),
                                                    tooltip: 'Marcar como Lido',
                                                    onPressed: () => _markAsRead(feedback['id']),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, Color primaryColor) {
    final isSelected = _filterType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.15) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? primaryColor : Colors.black87,
          ),
        ),
      ),
    );
  }
}
