import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'pedido_detail_dialog.dart';

class PedidosPage extends StatefulWidget {
  const PedidosPage({Key? key}) : super(key: key);

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  List<dynamic> _allPedidos = [];
  List<dynamic> _filteredPedidos = [];
  String _searchText = '';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String _selectedStatus = 'Todos';
  bool isLoading = false;

  // Adicione FocusNodes
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _startDateFocusNode = FocusNode();
  final FocusNode _endDateFocusNode = FocusNode();

  // Cor laranja principal
  final Color primaryColor = const Color(0xFFF28C38);

  final List<String> _statusOptions = [
    'Todos',
    'Registrado',
    'Saiu pra Entrega',
    'Concluído',
    'Cancelado',
  ];

  @override
  void initState() {
    super.initState();
    _fetchPedidos();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _startDateFocusNode.dispose();
    _endDateFocusNode.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchPedidos() async {
    if (!mounted) return; // Evita setState se o widget foi descartado
    debugPrint('Chamando _fetchPedidos');
    setState(() => isLoading = true);
    try {
      final data = await ApiService.fetchPedidos();
      if (mounted) {
        setState(() {
          _allPedidos = data..sort((a, b) => _compareAgendamento(a, b));
          _filteredPedidos = List.from(_allPedidos);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao buscar pedidos: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _filterPedidos() {
    List<dynamic> tempList = List.from(_allPedidos);

    if (_searchText.isNotEmpty) {
      final searchLower = _searchText.toLowerCase();
      tempList = tempList.where((pedido) {
        final idStr = (pedido['id'] ?? '').toString().toLowerCase();
        final nome = (pedido['nome'] ?? '').toString().toLowerCase();
        return idStr.contains(searchLower) || nome.contains(searchLower);
      }).toList();
    }

    if (_startDate != null && _endDate != null) {
      tempList = tempList.where((pedido) {
        final dataStr = pedido['data_agendamento']?.toString() ?? '';
        if (dataStr.isEmpty) return false;
        final dt = DateTime.tryParse(dataStr);
        if (dt == null) return false;
        return dt.isAfter(_startDate!.subtract(const Duration(seconds: 1))) &&
            dt.isBefore(_endDate!.add(const Duration(seconds: 1)));
      }).toList();
    }

    if (_selectedStatus != 'Todos') {
      tempList = tempList.where((pedido) {
        final status = (pedido['status'] ?? '').toString().trim().toLowerCase();
        return status == _selectedStatus.toLowerCase();
      }).toList();
    }

    tempList.sort((a, b) => _compareAgendamento(a, b));
    if (mounted) {
      setState(() => _filteredPedidos = tempList);
    }
  }

  // Converte data_agendamento + horario_agendamento em DateTime
  DateTime? _parseAgendamentoToDateTime(
      String dataAgendamento, String horarioAgendamento) {
    try {
      if (dataAgendamento.isEmpty || horarioAgendamento.isEmpty) return null;
      final date = DateTime.parse(dataAgendamento);

      final horarioParts = horarioAgendamento.split(' - ');
      if (horarioParts.isEmpty || horarioParts[0].isEmpty) return null;

      final timeFormat = DateFormat('HH:mm');
      final time = timeFormat.parse(horarioParts[0].trim());

      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (e) {
      debugPrint(
          'Erro ao parsear data/horário: $e (data: $dataAgendamento, horario: $horarioAgendamento)');
      return null;
    }
  }

  // Converte o horário de criação em DateTime
  DateTime? _parseHorarioCriacao(String horario) {
    try {
      if (horario.isEmpty) return null;
      final timeFormat = DateFormat('HH:mm');
      return timeFormat.parse(horario);
    } catch (e) {
      debugPrint('Erro ao parsear horário criação: $e');
      return null;
    }
  }

  // Ordena os pedidos por data/hora de agendamento e horário de criação
  int _compareAgendamento(dynamic a, dynamic b) {
    final dataAgendamentoA = a['data_agendamento']?.toString() ?? '';
    final horarioAgendamentoA = a['horario_agendamento']?.toString() ?? '';
    final dataCriacaoA = a['data']?.toString() ?? ''; // Coluna B
    final horarioCriacaoA = a['horario']?.toString() ?? ''; // Coluna C
    final dataAgendamentoB = b['data_agendamento']?.toString() ?? '';
    final horarioAgendamentoB = b['horario_agendamento']?.toString() ?? '';
    final dataCriacaoB = b['data']?.toString() ?? ''; // Coluna B
    final horarioCriacaoB = b['horario']?.toString() ?? ''; // Coluna C

    // Parseia o agendamento (para pedidos do WooCommerce)
    final dateTimeAgendamentoA = _parseAgendamentoToDateTime(dataAgendamentoA, horarioAgendamentoA);
    final dateTimeAgendamentoB = _parseAgendamentoToDateTime(dataAgendamentoB, horarioAgendamentoB);

    // Parseia a data e horário de criação (para pedidos do app ou fallback)
    DateTime? dateTimeCriacaoA = _parseCriacaoToDateTime(dataCriacaoA, horarioCriacaoA);
    DateTime? dateTimeCriacaoB = _parseCriacaoToDateTime(dataCriacaoB, horarioCriacaoB);

    // Se ambos têm agendamento, compara os agendamentos
    if (dateTimeAgendamentoA != null && dateTimeAgendamentoB != null) {
      return dateTimeAgendamentoA.compareTo(dateTimeAgendamentoB);
    }

    // Se A tem agendamento e B não, A vem antes (B é do app ou indefinido)
    if (dateTimeAgendamentoA != null) {
      return -1;
    }

    // Se B tem agendamento e A não, B vem antes (A é do app ou indefinido)
    if (dateTimeAgendamentoB != null) {
      return 1;
    }

    // Ambos sem agendamento (provavelmente pedidos do app), compara pela criação
    if (dateTimeCriacaoA == null && dateTimeCriacaoB == null) return 0;
    if (dateTimeCriacaoA == null) return 1;
    if (dateTimeCriacaoB == null) return -1;
    return dateTimeCriacaoA.compareTo(dateTimeCriacaoB);
  }

  // Nova função para parsear data e horário de criação
  DateTime? _parseCriacaoToDateTime(String dataCriacao, String horarioCriacao) {
    try {
      if (dataCriacao.isEmpty) return null;
      final date = DateFormat('dd/MM/yyyy').parse(dataCriacao); // Formato da coluna B
      if (horarioCriacao.isEmpty) return date;

      final timeFormat = DateFormat('HH:mm');
      final time = timeFormat.parse(horarioCriacao); // Coluna C
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (e) {
      debugPrint('Erro ao parsear data/horário de criação: $e (data: $dataCriacao, horario: $horarioCriacao)');
      return null;
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
      _startDateController.text = DateFormat('dd/MM/yyyy').format(_startDate!);
      _filterPedidos();
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      _endDateController.text = DateFormat('dd/MM/yyyy').format(_endDate!);
      _filterPedidos();
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _formatHorario(String raw) {
    final reg = RegExp(r'(\d{2}):(\d{2}):(\d{2})');
    final match = reg.firstMatch(raw);
    if (match != null) {
      final hh = match.group(1);
      final mm = match.group(2);
      if (hh != null && mm != null) {
        return '$hh:$mm';
      }
    }
    return raw;
  }

  String _formatDataAgendamento(String iso) {
    if (iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt != null) {
      return DateFormat('dd/MM/yyyy').format(dt);
    }
    return iso;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('PedidosPage'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lista de Pedidos',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFilterCard(),
          const SizedBox(height: 16),
          _buildTableHeader(),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      strokeWidth: 4.0,
                    ),
                  )
                : _filteredPedidos.isEmpty
                    ? const Center(child: Text('Nenhum pedido encontrado.'))
                    : ListView.builder(
                        itemCount: _filteredPedidos.length,
                        itemBuilder: (context, index) {
                          return _buildPedidoItem(
                            _filteredPedidos[index],
                            index,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  /// Card que agrupa os campos de filtro com contador
  Widget _buildFilterCard() {
    // Calcula o número de pedidos filtrados
    final int filteredCount = _filteredPedidos.length;
    final String counterText = '$filteredCount Pedido${filteredCount != 1 ? 's' : ''}';

    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center, // Alinha o contador ao centro
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                focusNode: _searchFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Buscar ID ou Nome',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  _searchText = value;
                  _filterPedidos();
                },
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                focusNode: _startDateFocusNode,
                controller: _startDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Data Inicial',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onTap: _pickStartDate,
              ),
            ),
            SizedBox(
              width: 120,
              child: TextField(
                focusNode: _endDateFocusNode,
                controller: _endDateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Data Final',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onTap: _pickEndDate,
              ),
            ),
            SizedBox(
              width: 250, // Aumentei a largura para acomodar textos longos como "Saiu pra Entrega"
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isDense: true,
                          isExpanded: true,
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedStatus = value;
                                _filterPedidos();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8), // Espaçamento entre o dropdown e o contador
                  Text(
                    counterText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cabeçalho da tabela
  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: const [
          SizedBox(
            width: 60,
            child: Text(
              'ID',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 16),
          Expanded(flex: 1, child: Text('Horário', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Nome', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Bairro', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Entrega', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Data Agend.', style: _headerStyle)),
          Expanded(flex: 2, child: Text('Horário Agend.', style: _headerStyle)),
          SizedBox(width: 40),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 15,
    color: Colors.black87,
  );

  /// Constrói cada "linha" (card) de pedido
  Widget _buildPedidoItem(dynamic pedido, int index) {
    final rawId = (pedido['id'] ?? '').toString();
    final rawHorario = (pedido['horario'] ?? '').toString();
    final nome = (pedido['nome'] ?? '').toString();
    final bairro = (pedido['bairro'] ?? '').toString();
    final status = (pedido['status'] ?? '').toString();
    final tipoEntrega = (pedido['tipo_entrega'] ?? '').toString().toLowerCase();
    final rawDataAgend = (pedido['data_agendamento'] ?? '').toString();
    final horarioAgend = (pedido['horario_agendamento'] ?? '').toString();

    final horario = _formatHorario(rawHorario);
    final dataAgendamento = _formatDataAgendamento(rawDataAgend);

    // Troquei a cor "funebre" por um tom de pastel laranja (orange.shade50)
    final backgroundColor =
        index % 2 == 0 ? Colors.white : Colors.orange.shade50;

    bool isHovered = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: Card(
            color: backgroundColor,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            elevation: isHovered ? 4 : 1,
            // Sombra suave na cor primária
            shadowColor: primaryColor.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              // Borda do card mais clara e sutil
              side: BorderSide(
                color: primaryColor.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Container(
              // Faixa lateral laranja (mais clara que antes)
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: primaryColor.withOpacity(0.7),
                    width: 3,
                  ),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: _buildIdChip(rawId),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Text(horario, style: _rowTextStyle),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        nome,
                        style: _rowTextStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        bairro,
                        style: _rowTextStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        status,
                        style: _rowTextStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildEntregaChip(tipoEntrega),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        dataAgendamento,
                        style: _rowTextStyle,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        horarioAgend,
                        style: _rowTextStyle,
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        tooltip: 'Ver Detalhes',
                        icon: Icon(
                          Icons.remove_red_eye,
                          // Ícone mais destacado ao hover
                          color: isHovered
                              ? primaryColor.withOpacity(0.8)
                              : primaryColor.withOpacity(0.6),
                        ),
                        onPressed: () {
                          debugPrint('Abrindo diálogo para pedido ID: ${pedido['id']}');
                          final produtosParsed = parseProdutos(
                            pedido['produtos']?.toString() ?? '',
                          );
                          showDialog(
                            context: context,
                            builder: (context) => PedidoDetailDialog(
                              pedido: pedido,
                              produtosParsed: produtosParsed,
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
        );
      },
    );
  }

  static const _rowTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
  );

  /// Chip com o ID do pedido
  Widget _buildIdChip(String id) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade600,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        id,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Chip de tipo de entrega
  Widget _buildEntregaChip(String tipoEntrega) {
    switch (tipoEntrega) {
      case 'delivery':
        return Chip(
          avatar: const Icon(Icons.local_shipping, color: Colors.green, size: 18),
          label: const Text(
            'Delivery',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.green.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 1,
        );
      case 'pickup':
        return Chip(
          avatar: const Icon(Icons.person, color: Colors.blue, size: 18),
          label: const Text(
            'Retirada',
            style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.blue.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 1,
        );
      default:
        return Chip(
          avatar: const Icon(Icons.help_outline, color: Colors.grey, size: 18),
          label: const Text(
            'Indefinido',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.grey.shade50,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 1,
        );
    }
  }

  /// Faz o parse dos produtos no formato "Nome do Produto (Qtd: X)"
  List<Map<String, String>> parseProdutos(String produtosRaw) {
    final List<Map<String, String>> produtos = [];
    final List<String> items = produtosRaw
        .split('*\n')
        .where((item) => item.trim().isNotEmpty)
        .toList();

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