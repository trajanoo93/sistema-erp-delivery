
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'pedido_detail_dialog.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({Key? key}) : super(key: key);

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> with TickerProviderStateMixin {
  // DATA
  List<dynamic> _allPedidos = [];
  List<dynamic> _filteredPedidos = [];
  String _searchText = '';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String _selectedStatus = 'Todos';
  String? _errorMessage;
  int _totalFilteredCount = 0;
  int _maxDisplayPedidos = 200;
  bool _isLoadingMore = false;

  // ANIMATION
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final AnimationController _skeletonController;
  late final Animation<double> _skeletonAnimation;

  // SCROLL
  final ScrollController _hScrollCtrl = ScrollController();

  // PALETA
  final Color primaryColor = const Color(0xFFF28C38);
  final Color bgSoft = const Color(0xFFF7F8FA);
  final Color textPrimary = const Color(0xFF1F2937);
  final Color textSecondary = const Color(0xFF6B7280);
  final Color borderColor = const Color(0xFFE5E7EB);

  // COLUNAS
  static const double _cId = 110;
  static const double _cHora = 100;
  static const double _cNome = 160;
  static const double _cBairro = 220;
  static const double _cCd = 80;
  static const double _cStatus = 100;
  static const double _cEntrega = 100;
  static const double _cData = 150;
  static const double _cHoraAg = 140;
  static const double _cEndPad = 48;

  double get _tableWidth =>
      _cId + _cHora + _cNome + _cBairro + _cCd + _cStatus + _cEntrega + _cData + _cHoraAg + _cEndPad;

  final List<String> _statusOptions = [
    'Todos',
    'Registrado',
    'Saiu pra Entrega',
    'Concluído',
    'Cancelado',
  ];

  // API
  final String _baseUrl = 'https://script.google.com/macros/s/AKfycbymsq-y46VtSRzpQcfKETBHhUukdVehvtN2_GzxhLL_d2ohpUGCyMxT_vyBN2OTUKjE/exec';
  final Map<String, String> _cdActions = {
    'Central': 'Read',
    'CD Barreiro': 'ReadCDBarreiro',
    'CD Sion': 'ReadCDSion',
    'Agendados': 'ReadAgendados',
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic);
    _skeletonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _skeletonAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _skeletonController, curve: Curves.easeInOut),
    );

    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day, 0, 0, 0);
    _endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate!);
    _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate!);

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _skeletonController.dispose();
    _hScrollCtrl.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _allPedidos.clear();
    _filteredPedidos.clear();
    super.dispose();
  }

  Stream<Map<String, dynamic>> _fetchPedidosStream({bool forceRefresh = false}) async* {
    List<dynamic> combinedPedidos = [];
    final prefs = await SharedPreferences.getInstance();
    final todayKey = DateTime.now().toIso8601String().substring(0, 10);

    // Tenta carregar do cache, a menos que seja refresh
    if (!forceRefresh) {
      final cachedData = prefs.getString('pedidos_$todayKey');
      if (cachedData != null) {
        combinedPedidos = jsonDecode(cachedData);
        yield {'status': 'success', 'data': combinedPedidos, 'progress': 1.0, 'message': 'Dados carregados do cache'};
      }
    }

    // Limpar cache antes de novo fetch
    await prefs.remove('pedidos_$todayKey');

    // Fetch paralelo
    final futures = _cdActions.entries.map((entry) async {
      final cdName = entry.key;
      final action = entry.value;
      final url = '$_baseUrl?action=$action';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is List) {
            return data.map((p) => {...p, 'cd_origem': cdName}).toList();
          } else if (data is Map<String, dynamic> && data['status'] == 'error') {
            return {'error': 'Erro na API $cdName: ${data['message']}'};
          }
          return {'error': 'Formato inesperado da resposta para $cdName'};
        }
        return {'error': 'Erro ao carregar $cdName: ${response.statusCode}'};
      } catch (e) {
        return {'error': 'Erro de conexão em $cdName: $e'};
      }
    }).toList();

    int completed = 0;
    for (var future in await Future.wait(futures)) {
      completed++;
      if (future is List<dynamic>) {
        combinedPedidos.addAll(future);
      } else if (future is Map<String, dynamic> && future.containsKey('error')) {
        yield {'status': 'error', 'message': future['error'], 'progress': completed / _cdActions.length};
      }
      yield {
        'status': 'loading',
        'data': combinedPedidos,
        'progress': completed / _cdActions.length,
        'message': 'Carregando ${_cdActions.keys.elementAt(completed - 1)}...'
      };
    }

    // Salvar no cache
    await prefs.setString('pedidos_$todayKey', jsonEncode(combinedPedidos));
    yield {'status': 'success', 'data': combinedPedidos, 'progress': 1.0, 'message': 'Dados carregados'};
  }

  void _filterPedidos() {
    List<dynamic> temp = List.from(_allPedidos);

    if (_searchText.isNotEmpty) {
      final s = _searchText.toLowerCase();
      temp = temp.where((p) {
        final idStr = (p['id'] ?? '').toString().toLowerCase();
        final nome = (p['nome'] ?? '').toString().toLowerCase();
        return idStr.contains(s) || nome.contains(s);
      }).toList();
    }

    temp = temp.where((p) {
      final dataStr = p['data_agendamento']?.toString() ?? '';
      if (dataStr.isEmpty) return false;
      try {
        final dt = DateTime.parse(dataStr);
        if (_startDate != null && _endDate != null) {
          return dt.isAfter(_startDate!.subtract(const Duration(seconds: 1))) &&
              dt.isBefore(_endDate!.add(const Duration(seconds: 1)));
        }
        return true;
      } catch (_) {
        return false;
      }
    }).toList();

    if (_selectedStatus != 'Todos') {
      temp = temp.where((p) {
        final st = (p['status'] ?? '').toString().trim().toLowerCase();
        return st == _selectedStatus.toLowerCase();
      }).toList();
    }

    _totalFilteredCount = temp.length; // Total real de pedidos filtrados
    temp.sort((a, b) => _compareAgendamento(a, b));
    _filteredPedidos = temp.take(_maxDisplayPedidos).toList();
  }

  void _loadMorePedidos() async {
    setState(() {
      _isLoadingMore = true;
      _maxDisplayPedidos += 200;
      _filterPedidos();
      _isLoadingMore = false;
    });
  }

  DateTime? _parseAgendamentoToDateTime(String dataAgendamento, String horarioAgendamento) {
    try {
      if (dataAgendamento.isEmpty || horarioAgendamento.isEmpty) return null;
      final date = DateTime.parse(dataAgendamento);
      final horarioParts = horarioAgendamento.split(' - ');
      if (horarioParts.isEmpty || horarioParts[0].isEmpty) return null;
      final time = DateFormat('HH:mm').parse(horarioParts[0].trim());
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (_) {
      return null;
    }
  }

  DateTime? _parseCriacaoToDateTime(String dataCriacao, String horarioCriacao) {
    try {
      if (dataCriacao.isEmpty) return null;
      final date = DateFormat('dd-MM').parse(dataCriacao, true);
      final dateWithYear = DateTime(DateTime.now().year, date.month, date.day);
      if (horarioCriacao.isEmpty) return dateWithYear;
      final time = DateFormat('HH:mm').parse(horarioCriacao);
      return DateTime(dateWithYear.year, dateWithYear.month, dateWithYear.day, time.hour, time.minute);
    } catch (_) {
      return null;
    }
  }

  int _compareAgendamento(dynamic a, dynamic b) {
    final daA = a['data_agendamento']?.toString() ?? '';
    final haA = a['horario_agendamento']?.toString() ?? '';
    final dA = a['data']?.toString() ?? '';
    final hA = a['horario']?.toString() ?? '';

    final daB = b['data_agendamento']?.toString() ?? '';
    final haB = b['horario_agendamento']?.toString() ?? '';
    final dB = b['data']?.toString() ?? '';
    final hB = b['horario']?.toString() ?? '';

    final agA = _parseAgendamentoToDateTime(daA, haA);
    final agB = _parseAgendamentoToDateTime(daB, haB);

    if (agA != null && agB != null) return agA.compareTo(agB);
    if (agA != null) return -1;
    if (agB != null) return 1;

    final crA = _parseCriacaoToDateTime(dA, hA);
    final crB = _parseCriacaoToDateTime(dB, hB);
    if (crA == null && crB == null) return 0;
    if (crA == null) return 1;
    if (crB == null) return -1;
    return crA.compareTo(crB);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
        _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate!);
        _filterPedidos();
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate!);
        _filterPedidos();
      });
    }
  }

  String _formatHorario(String raw) {
    final reg = RegExp(r'(\d{2}):(\d{2}):(\d{2})');
    final m = reg.firstMatch(raw);
    if (m != null) return '${m.group(1)}:${m.group(2)}';
    return raw;
  }

  String _formatDataAgendamento(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    return dt == null ? iso : DateFormat('dd/MM/yyyy').format(dt);
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  StreamBuilder<Map<String, dynamic>>(
                    stream: _fetchPedidosStream(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!['status'] == 'loading') {
                        return Column(
                          children: [
                            _buildSkeletonFilterCard(),
                            const SizedBox(height: 16),
                            _buildSkeletonTable(),
                            if (snapshot.hasData && snapshot.data!['status'] == 'loading')
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: Column(
                                  children: [
                                    LinearProgressIndicator(
                                      value: snapshot.data!['progress'],
                                      backgroundColor: primaryColor.withOpacity(0.2),
                                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      snapshot.data!['message'],
                                      style: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      } else if (snapshot.hasError || snapshot.data!['status'] == 'error') {
                        return _ErrorState(
                          message: snapshot.hasError ? 'Erro: ${snapshot.error}' : snapshot.data!['message'],
                          onRetry: () => setState(() {}),
                          primaryColor: primaryColor,
                        );
                      }

                      _allPedidos = snapshot.data!['data'] as List<dynamic>;
                      _filterPedidos();
                      return Column(
                        children: [
                          _buildFilterCard(),
                          const SizedBox(height: 16),
                          _buildTableHeader(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: true,
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, _) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: RefreshIndicator(
                    color: primaryColor,
                    onRefresh: () async => setState(() {}),
                    child: _filteredPedidos.isEmpty
                        ? _EmptyState(primaryColor: primaryColor)
                        : Scrollbar(
                            controller: _hScrollCtrl,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _hScrollCtrl,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: _tableWidth,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ListView.separated(
                                        padding: EdgeInsets.zero,
                                        itemCount: _filteredPedidos.length,
                                        separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
                                        itemBuilder: (context, index) => _PedidoRow(
                                          pedido: _filteredPedidos[index],
                                          index: index,
                                          primaryColor: primaryColor,
                                          textPrimary: textPrimary,
                                          onTap: () {
                                            final produtosParsed = parseProdutos(
                                                _filteredPedidos[index]['produtos']?.toString() ?? '');
                                            showDialog(
                                              context: context,
                                              builder: (_) => PedidoDetailDialog(
                                                pedido: _filteredPedidos[index],
                                                produtosParsed: produtosParsed,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    if (_filteredPedidos.length < _totalFilteredCount)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        child: ElevatedButton(
                                          onPressed: _isLoadingMore ? null : _loadMorePedidos,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: _isLoadingMore
                                              ? const SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Text(
                                                  'Carregar Mais',
                                                  style: GoogleFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(Icons.list_alt, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Text(
          'Lista de Pedidos',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonFilterCard() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: _skeletonAnimation.value,
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(width: 220, height: 48, color: Colors.grey[300]),
                  Container(width: 140, height: 48, color: Colors.grey[300]),
                  Container(width: 140, height: 48, color: Colors.grey[300]),
                  Container(width: 170, height: 48, color: Colors.grey[300]),
                  Container(width: 100, height: 36, color: Colors.grey[300]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkeletonTable() {
    return AnimatedBuilder(
      animation: _skeletonAnimation,
      builder: (context, _) {
        return Opacity(
          opacity: _skeletonAnimation.value,
          child: Column(
            children: [
              Container(
                width: _tableWidth,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(width: _cId, height: 16, color: Colors.grey[300]),
                    Container(width: _cHora, height: 16, color: Colors.grey[300]),
                    Container(width: _cNome, height: 16, color: Colors.grey[300]),
                    Container(width: _cBairro, height: 16, color: Colors.grey[300]),
                    Container(width: _cCd, height: 16, color: Colors.grey[300]),
                    Container(width: _cStatus, height: 16, color: Colors.grey[300]),
                    Container(width: _cEntrega, height: 16, color: Colors.grey[300]),
                    Container(width: _cData, height: 16, color: Colors.grey[300]),
                    Container(width: _cHoraAg, height: 16, color: Colors.grey[300]),
                    const SizedBox(width: _cEndPad),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: List.generate(5, (index) => Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  child: Row(
                    children: [
                      Container(width: _cId, height: 28, color: Colors.grey[300]),
                      Container(width: _cHora, height: 16, color: Colors.grey[300]),
                      Container(width: _cNome, height: 16, color: Colors.grey[300]),
                      Container(width: _cBairro, height: 16, color: Colors.grey[300]),
                      Container(width: _cCd, height: 16, color: Colors.grey[300]),
                      Container(width: _cStatus, height: 16, color: Colors.grey[300]),
                      Container(width: _cEntrega, height: 16, color: Colors.grey[300]),
                      Container(width: _cData, height: 16, color: Colors.grey[300]),
                      Container(width: _cHoraAg, height: 16, color: Colors.grey[300]),
                      Container(width: _cEndPad, height: 16, color: Colors.grey[300]),
                    ],
                  ),
                )),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterCard() {
    final String counterText = '$_totalFilteredCount Pedido${_totalFilteredCount != 1 ? 's' : ''}';

    InputBorder _outline() => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
        );

    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: primaryColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Buscar ID ou Nome',
                  prefixIcon: Icon(Icons.search, color: primaryColor),
                  border: _outline(),
                  enabledBorder: _outline(),
                  focusedBorder: _outline().copyWith(borderSide: BorderSide(color: primaryColor, width: 2)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (v) {
                  _searchText = v;
                  setState(() => _filterPedidos());
                },
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _startDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Data Inicial',
                  prefixIcon: Icon(Icons.date_range, color: primaryColor),
                  border: _outline(),
                  enabledBorder: _outline(),
                  focusedBorder: _outline().copyWith(borderSide: BorderSide(color: primaryColor, width: 2)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onTap: _pickStartDate,
              ),
            ),
            SizedBox(
              width: 140,
              child: TextField(
                controller: _endDateController,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Data Final',
                  prefixIcon: Icon(Icons.date_range, color: primaryColor),
                  border: _outline(),
                  enabledBorder: _outline(),
                  focusedBorder: _outline().copyWith(borderSide: BorderSide(color: primaryColor, width: 2)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onTap: _pickEndDate,
              ),
            ),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.filter_list, color: primaryColor),
                  border: _outline(),
                  enabledBorder: _outline(),
                  focusedBorder: _outline().copyWith(borderSide: BorderSide(color: primaryColor, width: 2)),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _statusOptions
                    .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.poppins(fontSize: 14))))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _selectedStatus = v;
                    _filterPedidos();
                  });
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                counterText,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    TextStyle headStyle = GoogleFonts.poppins(
      fontWeight: FontWeight.w600,
      fontSize: 13.5,
      color: Colors.black87,
    );

    Widget _cell(String text, double w) => SizedBox(
          width: w,
          child: Text(text, style: headStyle, overflow: TextOverflow.ellipsis),
        );

    return SingleChildScrollView(
      controller: _hScrollCtrl,
      scrollDirection: Axis.horizontal,
      child: Container(
        width: _tableWidth,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _cell('ID', _cId),
            _cell('Horário', _cHora),
            _cell('Nome', _cNome),
            _cell('Bairro', _cBairro),
            _cell('CD', _cCd),
            _cell('Status', _cStatus),
            _cell('Entrega', _cEntrega),
            _cell('Data Agend.', _cData),
            _cell('Horário Agend.', _cHoraAg),
            const SizedBox(width: _cEndPad),
          ],
        ),
      ),
    );
  }

  Widget _cdChip(String cd) {
    Color c;
    switch (cd) {
      case 'Central':
        c = primaryColor;
        break;
      case 'CD Barreiro':
        c = Colors.green;
        break;
      case 'CD Sion':
        c = Colors.blue;
        break;
      case 'Agendados':
        c = Colors.teal;
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        cd,
        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'concluído':
        c = Colors.green;
        break;
      case 'saiu pra entrega':
        c = Colors.yellow.shade700;
        break;
      case 'cancelado':
        c = Colors.red;
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }

  Widget _entregaChip(String tipoEntrega) {
    Color c;
    String label;
    switch (tipoEntrega.toLowerCase()) {
      case 'delivery':
        c = Colors.green.shade600;
        label = 'Delivery';
        break;
      case 'pickup':
        c = Colors.blue.shade600;
        label = 'Retirada';
        break;
      default:
        c = Colors.grey.shade600;
        label = 'Indefinido';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tipoEntrega.toLowerCase() == 'delivery'
                ? Icons.local_shipping
                : tipoEntrega.toLowerCase() == 'pickup'
                    ? Icons.person
                    : Icons.help_outline,
            size: 13.5,
            color: c,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }

  Widget _idPill(String id) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        id,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _PedidoRow({
    required dynamic pedido,
    required int index,
    required Color primaryColor,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    final rawId = (pedido['id'] ?? '').toString();
    final rawHorario = (pedido['horario'] ?? '').toString();
    final nome = (pedido['nome'] ?? '').toString();
    final bairro = (pedido['bairro'] ?? '').toString();
    final status = (pedido['status'] ?? '').toString();
    final tipoEntrega = (pedido['tipo_entrega'] ?? '').toString();
    final rawDataAgend = (pedido['data_agendamento'] ?? '').toString();
    final horarioAgend = (pedido['horario_agendamento'] ?? '').toString();
    final cdOrigem = (pedido['cd_origem'] ?? 'Central').toString();

    final horario = _formatHorario(rawHorario);
    final dataAgendamento = _formatDataAgendamento(rawDataAgend);

    return InkWell(
      onTap: onTap,
      hoverColor: primaryColor.withOpacity(0.04),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        color: index % 2 == 0 ? Colors.white : primaryColor.withOpacity(0.02),
        child: Row(
          children: [
            SizedBox(width: _cId, child: _idPill(rawId)),
            const SizedBox(width: 12),
            SizedBox(width: _cHora - 12, child: _cellText(horario)),
            SizedBox(width: _cNome, child: _cellText(nome, ellipsis: true)),
            SizedBox(width: _cBairro, child: _cellText(bairro, ellipsis: true)),
            SizedBox(width: _cCd, child: _cdChip(cdOrigem)),
            const SizedBox(width: 12),
            SizedBox(width: _cStatus, child: _statusChip(status)),
            const SizedBox(width: 12),
            SizedBox(width: _cEntrega, child: _entregaChip(tipoEntrega)),
            const SizedBox(width: 12),
            SizedBox(width: _cData, child: _cellText(dataAgendamento)),
            SizedBox(width: _cHoraAg, child: _cellText(horarioAgend)),
            const SizedBox(width: _cEndPad, child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black26)),
          ],
        ),
      ),
    );
  }

  Widget _cellText(String text, {bool ellipsis = false}) {
    return Text(
      text,
      maxLines: 1,
      overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.visible,
      style: GoogleFonts.poppins(fontSize: 13.5, color: textPrimary, fontWeight: FontWeight.w500),
    );
  }

  List<Map<String, String>> parseProdutos(String produtosRaw) {
    final List<Map<String, String>> produtos = [];
    final List<String> items = produtosRaw.split('*\n').where((item) => item.trim().isNotEmpty).toList();

    for (String item in items) {
      final qtdMatch = RegExp(r'\(Qtd:\s*(\d+)\)').firstMatch(item);
      if (qtdMatch != null) {
        final qtd = qtdMatch.group(1)!;
        final nome = item.split('(Qtd:')[0].trim();
        produtos.add({'nome': nome, 'qtd': qtd});
      }
    }
    return produtos;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.primaryColor});
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, color: Colors.grey[400], size: 64),
          const SizedBox(height: 12),
          Text(
            'Nenhum pedido encontrado para o período selecionado.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry, required this.primaryColor});
  final String message;
  final VoidCallback onRetry;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: primaryColor, size: 48),
          const SizedBox(height: 8),
          Text(
            'Algo deu errado',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh, color: primaryColor),
            label: Text(
              'Tentar novamente',
              style: GoogleFonts.poppins(fontSize: 14, color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}
