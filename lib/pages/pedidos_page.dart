import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as mobile;
import 'package:firedart/firestore/firestore.dart' as desktop;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:async';

class PedidosPage extends StatefulWidget {
  const PedidosPage({super.key});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _allPedidos = [];
  List<Map<String, dynamic>> _filteredPedidos = [];
  String _searchText = '';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String _selectedStatus = 'Todos';
  int _totalFilteredCount = 0;
  int _maxDisplayPedidos = 300;
  bool _isInitialLoading = true;
  String? _errorMessage;
  late final dynamic firestore;
  bool _isDesktop = false;
  Timer? _pollingTimer;
  StreamSubscription? _streamSubscription;
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();

  // Cores
  final Color primaryColor = const Color(0xFFF28C38);
  final Color textPrimary = const Color(0xFF1F2937);
  final Color borderColor = const Color(0xFFE5E7EB);
  final Color surfaceColor = const Color(0xFFFAFAFA);
  final Color cardColor = Colors.white;

  // Larguras das colunas
  static const double _cId = 90;
  static const double _cHora = 100;
  static const double _cNome = 170;
  static const double _cBairro = 160;
  static const double _cCd = 90;
  static const double _cStatus = 130;
  static const double _cEntrega = 110;
  static const double _cData = 110;
  static const double _cEndPad = 60;

  double get _tableWidth =>
      _cId + _cHora + _cNome + _cBairro + _cCd + _cStatus + _cEntrega + _cData + _cEndPad;

  final List<String> _statusOptions = [
    'Todos',
    'Registrado',
    'Saiu pra Entrega',
    'Concluído',
    'Cancelado',
    '-',
  ];

  // FUNÇÃO CORRIGIDA: pega o CD corretamente em qualquer situação
  String getCdName(Map<String, dynamic> pedido) {
  final agendamentoCd = pedido['agendamento']?['cd']?.toString();
  if (agendamentoCd != null && agendamentoCd.trim().isNotEmpty && agendamentoCd != '-') {
    final trimmed = agendamentoCd.trim();
    if (trimmed.contains('Sion')) return 'Sion';
    if (trimmed.contains('Barreiro')) return 'Barreiro';
    if (trimmed.contains('Central')) return 'Central';
    return trimmed; // caso tenha algo diferente no futuro
  }

  final rootCd = pedido['cd']?.toString();
  if (rootCd != null && rootCd.trim().isNotEmpty && rootCd != '-') {
    final trimmed = rootCd.trim();
    if (trimmed.contains('Sion')) return 'Sion';
    if (trimmed.contains('Barreiro')) return 'Barreiro';
    if (trimmed.contains('Central')) return 'Central';
    return trimmed;
  }

  final loja = (pedido['loja_origem']?.toString() ?? '').toLowerCase();
  if (loja.contains('sion')) return 'Sion';
  if (loja.contains('barreiro')) return 'Barreiro';
  if (loja.contains('central')) return 'Central';

  return 'Central'; // fallback
}

Color getCdColor(String cd) {
  switch (cd) {
    case 'Sion':
      return Colors.purple.shade600;
    case 'Barreiro':
      return Colors.teal.shade600;
    case 'Central':
      return Colors.orange.shade700;
    default:
      return primaryColor;
  }
}
String getNomeCurto(String? nomeCompleto) {
    if (nomeCompleto == null || nomeCompleto.trim().isEmpty) return '-';

    final partes = nomeCompleto.trim().split(RegExp(r'\s+'));
    if (partes.length <= 1) return partes[0];

    // Pega os dois primeiros nomes significativos (ignora "de", "da", "do", etc.)
    final nomesLimpos = partes
        .map((e) => e.toLowerCase())
        .where((e) => !{'de', 'da', 'do', 'dos', 'das', 'e', 'di', 'del'}.contains(e))
        .toList();

    if (nomesLimpos.isEmpty) return partes.take(2).join(' ');
    if (nomesLimpos.length == 1) return nomesLimpos[0];

    return nomesLimpos.take(2).map((e) => e[0].toUpperCase() + e.substring(1)).join(' ');
  }

  DateTime _toDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is mobile.Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    try {
      final typeName = value.runtimeType.toString();
      if (typeName.contains('Timestamp')) {
        final result = value.toDate();
        if (result is DateTime) return result;
      }
    } catch (_) {}
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
    _endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
    _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
    _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate);

    _isDesktop = !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS;

    if (_isDesktop) {
      try {
        desktop.Firestore.initialize('ao-gosto-app-c0b31');
      } catch (_) {}
      firestore = desktop.Firestore.instance;
      _loadPedidosDesktop();
      _startPolling();
    } else {
      firestore = mobile.FirebaseFirestore.instance;
      _initMobileStream();
    }

    _bodyScrollController.addListener(() {
      if (_headerScrollController.hasClients) {
        _headerScrollController.jumpTo(_bodyScrollController.offset);
      }
    });
  }

  void _initMobileStream() {
    final stream = (firestore as mobile.FirebaseFirestore)
        .collection('pedidos')
        .orderBy('created_at', descending: true)
        .snapshots();

    _streamSubscription = stream.listen((snapshot) {
      final List<Map<String, dynamic>> pedidos = snapshot.docs.map((doc) {
        final Map<String, dynamic> data = doc.data();
        return {'id_doc': doc.id, ...data};
      }).toList();

      setState(() {
        _allPedidos = pedidos;
        _filterPedidos();
        _isInitialLoading = false;
      });
    }, onError: (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar pedidos: $e';
        _isInitialLoading = false;
      });
    });
  }

  Future<void> _loadPedidosDesktop() async {
    try {
      final collection = (firestore as desktop.Firestore).collection('pedidos');
      final docs = await collection.orderBy('created_at', descending: true).get();

      final List<Map<String, dynamic>> pedidos = docs.map((doc) {
        final Map data = doc.map;
        final String id = doc.id;
        return {'id_doc': id, ...Map<String, dynamic>.from(data)};
      }).toList();

      setState(() {
        _allPedidos = pedidos;
        _filterPedidos();
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar pedidos: $e';
        _isInitialLoading = false;
      });
    }
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _loadPedidosDesktop();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _streamSubscription?.cancel();
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _filterPedidos() {
    List<Map<String, dynamic>> temp = List.from(_allPedidos);

    if (_searchText.isNotEmpty) {
      final s = _searchText.toLowerCase();
      temp = temp.where((p) {
        final id = (p['id'] ?? '').toString().toLowerCase();
        final nome = (p['cliente']?['nome'] ?? '').toString().toLowerCase();
        return id.contains(s) || nome.contains(s);
      }).toList();
    }

    temp = temp.where((p) {
      final date = _toDateTime(p['created_at']);
      return date.isAfter(_startDate.subtract(const Duration(seconds: 1))) &&
          date.isBefore(_endDate.add(const Duration(seconds: 1)));
    }).toList();

  if (_selectedStatus != 'Todos') {
  temp = temp.where((p) {
    final statusBanco = (p['status'] ?? '').toString().trim().toLowerCase();

    switch (_selectedStatus) {
      case 'Registrado':
        return statusBanco == '' || 
               statusBanco == '-' || 
               statusBanco.contains('registrad');

      case 'Saiu pra Entrega':
        return statusBanco.contains('saiu') || 
               statusBanco.contains('entrega');

      case 'Concluído':
        return statusBanco.contains('concluid') || 
               statusBanco.contains('concluido');

      case 'Cancelado':
        return statusBanco.contains('cancel');

      case '-':
        return statusBanco == '' || statusBanco == '-';

      default:
        return statusBanco.contains(_selectedStatus.toLowerCase());
    }
  }).toList();
}
    temp.sort((a, b) {
      final agA = a['agendamento']?['data'];
      final agB = b['agendamento']?['data'];
      if (agA != null && agB != null) {
        return _toDateTime(agB).compareTo(_toDateTime(agA));
      }
      if (agA != null) return -1;
      if (agB != null) return 1;
      return _toDateTime(b['created_at']).compareTo(_toDateTime(a['created_at']));
    });

    _totalFilteredCount = temp.length;
    _filteredPedidos = temp.take(_maxDisplayPedidos).toList();
    setState(() {});
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate);
        _filterPedidos();
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
        _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate);
        _filterPedidos();
      });
    }
  }

  String _formatHorario(String? h) => h != null && h.length >= 5 ? h.substring(0, 5) : '-';
  String _formatDataAgendamento(dynamic ts) => ts == null ? '-' : DateFormat('dd/MM/yyyy').format(_toDateTime(ts));
  String _getJanela(dynamic ag) => ag?['janela_texto']?.toString() ?? '-';

  List<Map<String, String>> parseProdutos(String raw) {
    final list = <Map<String, String>>[];
    if (raw.trim().isEmpty) return list;
    final items = raw.split('*').where((e) => e.trim().isNotEmpty);
    for (var item in items) {
      final match = RegExp(r'\(Qtd:\s*(\d+)\)').firstMatch(item);
      final nome = match != null ? item.split('(Qtd:')[0].trim() : item.trim();
      final qtd = match?.group(1) ?? '1';
      list.add({'nome': nome, 'qtd': qtd});
    }
    return list;
  }

  Color _getStatusColor(String status) {
    if (status.contains('Concluído') || status.contains('Concluido')) return Colors.green;
    if (status.contains('Cancelado')) return Colors.red;
    if (status.contains('Saiu')) return Colors.blue;
    return Colors.orange;
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('Concluído') || status.contains('Concluido')) return Icons.check_circle;
    if (status.contains('Cancelado')) return Icons.cancel;
    if (status.contains('Saiu')) return Icons.local_shipping;
    return Icons.schedule;
  }

  void _showPedidoDetail(Map<String, dynamic> pedido) {
    final produtos = parseProdutos(pedido['lista_produtos_texto']?.toString() ?? '');
    final status = pedido['status']?.toString() ?? '-';
    final cdName = getCdName(pedido);

    String formatarTelefone(String? tel) {
      if (tel == null || tel.isEmpty) return '-';
      String numeros = tel.replaceAll(RegExp(r'\D'), '');
      if (numeros.startsWith('55') && numeros.length >= 12) {
        numeros = numeros.substring(2);
      }
      if (numeros.length == 11) {
        return '(${numeros.substring(0, 2)}) ${numeros.substring(2, 7)}-${numeros.substring(7)}';
      } else if (numeros.length == 10) {
        return '(${numeros.substring(0, 2)}) ${numeros.substring(2, 6)}-${numeros.substring(6)}';
      }
      return tel;
    }

    final telefoneFormatado = formatarTelefone(pedido['cliente']?['telefone']?.toString());
    final agendamento = pedido['agendamento'];
    final temAgendamento = agendamento != null && agendamento['data'] != null;
    final dataAgendamento = temAgendamento ? _formatDataAgendamento(agendamento['data']) : '-';
    final janelaTexto = agendamento?['janela_texto']?.toString() ?? '-';
    final entregador = pedido['entregador']?.toString();
    final lojaOrigem = pedido['loja_origem']?.toString();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 8,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryColor, primaryColor.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.receipt_long, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pedido #${pedido['id'] ?? '-'}',
                              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(_getStatusIcon(status), color: Colors.white.withOpacity(0.9), size: 16),
                              const SizedBox(width: 6),
                              Text(status,
                                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.2)),
                    ),
                  ],
                ),
              ),

              // CONTEÚDO
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModernDetailSection('Cliente', Icons.person, [
                        _buildModernDetailRow('Nome', pedido['cliente']?['nome']),
                        _buildModernDetailRow('Telefone', telefoneFormatado),
                      ]),
                      const SizedBox(height: 24),
                      _buildModernDetailSection('Endereço de Entrega', Icons.location_on, [
                        _buildModernDetailRow('Logradouro', pedido['endereco']?['rua'] ?? pedido['endereco']?['logradouro']),
                        _buildModernDetailRow('Número', pedido['endereco']?['numero']),
                        _buildModernDetailRow('Bairro', pedido['endereco']?['bairro']),
                        if (pedido['endereco']?['complemento']?.toString().isNotEmpty == true)
                          _buildModernDetailRow('Complemento', pedido['endereco']?['complemento']),
                        if (pedido['endereco']?['cep'] != null) _buildModernDetailRow('CEP', pedido['endereco']?['cep']),
                      ]),
                      const SizedBox(height: 24),
                      _buildModernDetailSection('Agendamento e Entrega', Icons.schedule, [
                        _buildModernDetailRow('Tipo de Entrega', pedido['tipo_entrega'] == 'delivery' ? 'Delivery' : 'Retirada'),
                        _buildModernDetailRow('Data do Pedido', _formatDataAgendamento(pedido['created_at'])),
                        _buildModernDetailRow('Horário do Pedido', _formatHorario(pedido['horario_pedido']?.toString())),
                        _buildModernDetailRow('Agendado para', dataAgendamento),
                        if (temAgendamento) _buildModernDetailRow('Janela de Entrega', janelaTexto),
                        _buildModernDetailRow('CD', cdName), // CORRIGIDO
                        if (entregador != null && entregador != '-' && entregador.isNotEmpty)
                          _buildModernDetailRow('Entregador', entregador),
                        if (lojaOrigem != null && lojaOrigem.isNotEmpty) _buildModernDetailRow('Loja Origem', lojaOrigem),
                      ]),

                      if (produtos.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.shopping_bag, color: primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text('Produtos', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: produtos.length,
                            separatorBuilder: (_, __) => const Divider(height: 20),
                            itemBuilder: (_, i) {
                              final p = produtos[i];
                              return Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.7)]),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                        child: Text('${p['qtd']}x',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16))),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(child: Text(p['nome'] ?? '-', style: GoogleFonts.poppins(fontSize: 15, color: textPrimary))),
                                ],
                              );
                            },
                          ),
                        ),
                      ],

                      if (pedido['pagamento'] != null) ...[
                        const SizedBox(height: 24),
                        _buildModernDetailSection('Pagamento', Icons.payment, [
                          _buildModernDetailRow('Método', pedido['pagamento']?['metodo_principal']),
                          _buildModernDetailRow('Valor Total', 'R\$ ${(pedido['pagamento']?['valor_total'] ?? 0).toStringAsFixed(2)}'),
                          _buildModernDetailRow('Valor Líquido', 'R\$ ${(pedido['pagamento']?['valor_liquido'] ?? 0).toStringAsFixed(2)}'),
                          if ((pedido['pagamento']?['taxa_entrega'] ?? 0) > 0)
                            _buildModernDetailRow('Taxa de Entrega', 'R\$ ${(pedido['pagamento']?['taxa_entrega'] ?? 0).toStringAsFixed(2)}'),
                        ]),
                      ],

                      if (pedido['observacao']?.toString().isNotEmpty == true) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.note, color: primaryColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text('Observações', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
                          child: Text(pedido['observacao'].toString(),
                              style: GoogleFonts.poppins(fontSize: 14, color: textPrimary, height: 1.5)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // RODAPÉ
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Fechar', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernDetailSection(String title, IconData icon, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          padding: const EdgeInsets.all(20),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildModernDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text('$label:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: Colors.grey[600], fontSize: 14)),
          ),
          Expanded(
            child: Text(value?.toString() ?? '-',
                style: GoogleFonts.poppins(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              if (_isInitialLoading)
                _buildSkeletonLoader()
              else if (_errorMessage != null)
                _buildErrorState()
              else ...[
                _buildFilterCard(),
                const SizedBox(height: 24),
                _buildTableCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.list_alt, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lista de Pedidos',
                  style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary, letterSpacing: -0.5)),
              Text('Gerencie todos os pedidos em um só lugar', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]),
          child: Column(
            children: [
              Row(children: [Expanded(child: _buildSkeletonBox(height: 56)), const SizedBox(width: 12), _buildSkeletonBox(width: 150, height: 56), const SizedBox(width: 12), _buildSkeletonBox(width: 150, height: 56)]),
              const SizedBox(height: 12),
              Row(children: [_buildSkeletonBox(width: 180, height: 56), const SizedBox(width: 12), _buildSkeletonBox(width: 150, height: 56)]),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ]),
          child: Column(children: List.generate(5, (i) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildSkeletonBox(height: 60)))),
        ),
      ],
    );
  }

  Widget _buildSkeletonBox({double? width, double? height}) {
    return Container(
      width: width,
      height: height ?? 20,
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
      ]),
      child: Center(
        child: Column(
          children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle), child: Icon(Icons.error_outline, size: 64, color: Colors.red[400])),
            const SizedBox(height: 24),
            Text('Erro ao carregar pedidos', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    final counter = '$_totalFilteredCount Pedido${_totalFilteredCount != 1 ? 's' : ''}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: primaryColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: primaryColor, size: 24),
              const SizedBox(width: 12),
              Text('Filtros', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Text(counter, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar ID ou Nome do Cliente',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: primaryColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primaryColor, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onChanged: (v) {
                    _searchText = v.trim();
                    _filterPedidos();
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _startDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Data Inicial',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primaryColor, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onTap: _pickStartDate,
                ),
              ),
              SizedBox(
                width: 170,
                child: TextField(
                  controller: _endDateController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Data Final',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    prefixIcon: Icon(Icons.calendar_today, color: primaryColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primaryColor, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  onTap: _pickEndDate,
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status do Pedido',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    prefixIcon: Icon(Icons.local_offer, color: primaryColor),
                    filled: true,
                    fillColor: surfaceColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primaryColor, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  items: _statusOptions
                      .map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.poppins(fontSize: 14))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedStatus = v;
                        _filterPedidos();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard() {
    if (_filteredPedidos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(64),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ]),
        child: Center(
          child: Column(
            children: [
              Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle), child: Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400])),
              const SizedBox(height: 24),
              Text('Nenhum pedido encontrado', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
              const SizedBox(height: 8),
              Text('Tente ajustar os filtros para ver mais resultados', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
      ]),
      child: Column(
        children: [
          // Header da tabela
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
            ),
            child: SingleChildScrollView(
              controller: _headerScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _tableWidth,
                child: Row(
                  children: [
                    _buildTableHeaderCell('ID', _cId),
                    _buildTableHeaderCell('Horário', _cHora),
                    _buildTableHeaderCell('Cliente', _cNome),
                    _buildTableHeaderCell('Bairro', _cBairro),
                    _buildTableHeaderCell('CD', _cCd),
                    _buildTableHeaderCell('Status', _cStatus),
                    _buildTableHeaderCell('Entrega', _cEntrega),
                    _buildTableHeaderCell('Data Ag.', _cData),
                    const SizedBox(width: _cEndPad),
                  ],
                ),
              ),
            ),
          ),
          // Corpo da tabela
          Scrollbar(
            controller: _bodyScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _bodyScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _tableWidth,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredPedidos.length,
                  itemBuilder: (context, i) => _buildPedidoRow(pedido: _filteredPedidos[i], index: i),
                ),
              ),
            ),
          ),
          // Botão Carregar Mais
          if (_filteredPedidos.length < _totalFilteredCount)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _maxDisplayPedidos += 200;
                      _filterPedidos();
                    });
                  },
                  icon: const Icon(Icons.expand_more),
                  label: Text('Carregar Mais ($_totalFilteredCount total)', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, double width) {
    return SizedBox(
      width: width,
      child: Text(text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12.5, color: textPrimary.withOpacity(0.9), letterSpacing: 0.2)),
    );
  }

  Widget _buildPedidoRow({required Map<String, dynamic> pedido, required int index}) {
    final id = pedido['id']?.toString() ?? '-';
    final horario = _formatHorario(pedido['horario_pedido']?.toString());
    final nomeCompleto = pedido['cliente']?['nome']?.toString();
    final nome = getNomeCurto(nomeCompleto);
    final bairro = pedido['endereco']?['bairro']?.toString() ?? '-';
    final status = pedido['status']?.toString() ?? '-';
    final tipo = pedido['tipo_entrega']?.toString() == 'delivery' ? 'Delivery' : 'Retirada';
    final cdName = getCdName(pedido);
    final dataAg = _formatDataAgendamento(pedido['agendamento']?['data']);
    final statusColor = _getStatusColor(status);
    final entregaColor = tipo == 'Delivery' ? Colors.green.shade600 : Colors.blue.shade600;
    final cdColor = getCdColor(cdName);

    return InkWell(
      onTap: () => _showPedidoDetail(pedido),
      hoverColor: primaryColor.withOpacity(0.06),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          color: index % 2 == 0 ? Colors.white : surfaceColor,
          border: Border(bottom: BorderSide(color: borderColor.withOpacity(0.6))),
        ),
        child: Row(
          children: [
            SizedBox(width: _cId, child: Center(child: _badgeId(id))),
            SizedBox(width: _cHora, child: Text(horario, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w500))),
            SizedBox(width: _cNome, child: Text(nome, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600))),
            SizedBox(width: _cBairro, child: Text(bairro, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 13.5))),
            SizedBox(width: _cCd, child: Center(child: _badgeCompact(cdName, cdColor))),
            SizedBox(width: _cStatus, child: Center(child: _badgeCompact(status, statusColor, icon: _getStatusIcon(status)))),
            SizedBox(width: _cEntrega, child: Center(child: _badgeCompact(tipo, entregaColor, icon: tipo == 'Delivery' ? Icons.delivery_dining : Icons.store_mall_directory))),
            SizedBox(width: _cData, child: Text(dataAg, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 13.5))),
            SizedBox(width: _cEndPad, child: Center(child: Icon(Icons.arrow_forward_ios_rounded, size: 17, color: primaryColor.withOpacity(0.7)))),
          ],
        ),
      ),
    );
  }

  Widget _badgeId(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.9)]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5)),
    );
  }

  Widget _badgeCompact(String text, Color color, {IconData? icon}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 68),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 5)],
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}