import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ConferirPagamentosPage extends StatefulWidget {
  const ConferirPagamentosPage({super.key});

  @override
  State<ConferirPagamentosPage> createState() => _ConferirPagamentosPageState();
}

class _ConferirPagamentosPageState extends State<ConferirPagamentosPage> {
  // --- ESTADO ---
  String _paymentMethod = 'pix';
  String? _selectedUnidade;
  String _statusFilter = 'todos';
  String _nameFilter = '';
  
  // Controle de Paginação
  int _currentPage = 1;             // Usado pelo Pagar.me
  String? _stripeNextPageToken;     // Usado pelo Stripe
  
  bool _isLoading = false;
  List<dynamic> _payments = [];
  bool _hasMore = true;

  final List<String> _unidadesPix = ['Unidade Delivery', 'Unidade Barreiro', 'Unidade Sion'];
  final List<String> _unidadesStripe = ['Unidade Delivery', 'Unidade Barreiro', 'Unidade Sion'];

  final TextEditingController _nameFilterController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedUnidade = _paymentMethod == 'pix' ? _unidadesPix[0] : _unidadesStripe[0];
    _fetchPayments();
  }

  // --- LÓGICA DE BUSCA ---
  Future<void> _fetchPayments({bool append = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      // Pega os últimos 90 dias
      final startDate = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 90)));
      final endDate = DateFormat('yyyy-MM-dd').format(now);

      String url;

      // Montagem da URL baseada no método (Lógica de Paginação Diferente)
      if (_paymentMethod == 'pix') {
        // PAGAR.ME: Usa paginação numérica (page=1, page=2...)
        url = 'https://aogosto.com.br/proxy/consulta-pagarme.php?page=$_currentPage&size=20&unidade=$_selectedUnidade&start_date=$startDate&end_date=$endDate';
      } else {
        // STRIPE: Usa token de cursor (page=cus_xyz...)
        url = 'https://aogosto.com.br/proxy/consulta-stripe.php?unidade=$_selectedUnidade&start_date=$startDate&end_date=$endDate&limit=20';
        
        // Se estamos carregando mais e temos um token, adicionamos na URL
        if (append && _stripeNextPageToken != null) {
          url += '&page=$_stripeNextPageToken';
        }
      }

      print('Requisição: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar pagamentos: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final List<dynamic> newPayments = data['data'] ?? [];
      
      // Atualiza controles de paginação para a próxima chamada
      if (_paymentMethod == 'credit_card') {
         // Stripe retorna o token da próxima página
         _stripeNextPageToken = data['next_page']; 
         _hasMore = data['has_more'] ?? false;
      } else {
         // Pagar.me usa lógica simples de "tem mais se veio cheio" ou flag do backend
         _hasMore = data['has_more'] ?? (newPayments.length >= 20);
      }

      setState(() {
        if (append) {
          _payments.addAll(newPayments);
        } else {
          _payments = newPayments;
        }
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadMore() {
    if (!_hasMore || _isLoading) return;
    
    // Apenas incrementa contador visual/lógico para Pagar.me
    // Para Stripe, o token já foi salvo no _fetchPayments anterior
    if (_paymentMethod == 'pix') {
      setState(() {
        _currentPage++;
      });
    }
    
    _fetchPayments(append: true);
  }

  void _refreshPayments() {
    setState(() {
      _currentPage = 1;
      _stripeNextPageToken = null; // Reseta o token do Stripe
      _hasMore = true;
      _payments.clear();
      _nameFilter = '';
      _nameFilterController.clear();
    });
    _fetchPayments();
  }

  // --- TRADUÇÃO E CORES DE STATUS ---
  String _getStatusLabel(String status) {
    final s = status.toLowerCase();
    
    if (['succeeded', 'paid'].contains(s)) return 'Pago';
    if (['pending', 'processing', 'waiting_payment', 'requires_action', 'requires_confirmation'].contains(s)) return 'Pendente';
    if (['failed', 'refused', 'requires_payment_method'].contains(s)) return 'Falhou';
    if (['canceled', 'cancelled'].contains(s)) return 'Cancelado';
    if (['refunded', 'voided', 'partial_refunded'].contains(s)) return 'Reembolsado';
    
    return status; 
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();

    if (['succeeded', 'paid'].contains(s)) return Colors.green.shade600;
    if (['pending', 'processing', 'waiting_payment', 'requires_action', 'requires_confirmation'].contains(s)) return Colors.orange.shade600;
    if (['failed', 'refused', 'requires_payment_method'].contains(s)) return Colors.red.shade600;
    if (['canceled', 'cancelled'].contains(s)) return Colors.red.shade900;
    if (['refunded', 'voided', 'partial_refunded'].contains(s)) return Colors.purple.shade600;
    
    return Colors.grey.shade600;
  }

  IconData _getStatusIcon(String status) {
    final s = status.toLowerCase();
    
    if (['succeeded', 'paid'].contains(s)) return Icons.check_circle_outline;
    if (['pending', 'processing', 'waiting_payment', 'requires_action', 'requires_confirmation'].contains(s)) return Icons.access_time;
    if (['failed', 'refused', 'requires_payment_method'].contains(s)) return Icons.error_outline;
    if (['canceled', 'cancelled'].contains(s)) return Icons.cancel_outlined;
    if (['refunded', 'voided', 'partial_refunded'].contains(s)) return Icons.undo;
    
    return Icons.help_outline;
  }

  // --- FILTROS LOCAIS ---
  List<dynamic> get _filteredPayments {
    List<dynamic> filtered = _payments;

    if (_statusFilter != 'todos') {
      filtered = filtered.where((payment) {
        final rawStatus = payment['status'].toString().toLowerCase();
        
        // Mapeamento local dos filtros do dropdown para os status da API
        if (_statusFilter == 'pago') {
          return ['paid', 'succeeded'].contains(rawStatus);
        } else if (_statusFilter == 'pendente') {
          return ['pending', 'processing', 'waiting_payment', 'requires_action', 'requires_confirmation'].contains(rawStatus);
        } else if (_statusFilter == 'falhou') {
          return ['failed', 'refused', 'requires_payment_method'].contains(rawStatus);
        } else if (_statusFilter == 'cancelado') {
          return ['canceled', 'cancelled'].contains(rawStatus);
        } else if (_statusFilter == 'reembolsado') {
          return ['refunded', 'voided', 'partial_refunded'].contains(rawStatus);
        }
        return true;
      }).toList();
    }

    if (_nameFilter.isNotEmpty) {
      filtered = filtered.where((payment) {
        final nomeCliente = _paymentMethod == 'pix'
            ? (payment['customer']?['name'] ?? 'N/A')
            : (payment['customer']?['name'] ?? payment['description'] ?? 'N/A');
        return nomeCliente.toString().toLowerCase().contains(_nameFilter.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  @override
  void dispose() {
    _nameFilterController.dispose();
    super.dispose();
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione o método de pagamento e a unidade para consultar:',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 16),

          // --- CARD DE CONTROLES ---
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, Colors.orange.shade50.withOpacity(0.5)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: _inputDecoration('Método', Icons.payment),
                          items: const [
                            DropdownMenuItem(value: 'pix', child: Text('PIX (Pagar.me)')),
                            DropdownMenuItem(value: 'credit_card', child: Text('Cartão (Stripe)')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                              _selectedUnidade = _paymentMethod == 'pix' ? _unidadesPix[0] : _unidadesStripe[0];
                              _refreshPayments(); // Reseta tudo ao mudar método
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedUnidade,
                          decoration: _inputDecoration('Unidade', Icons.store),
                          items: (_paymentMethod == 'pix' ? _unidadesPix : _unidadesStripe)
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedUnidade = value;
                              _refreshPayments();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameFilterController,
                          decoration: _inputDecoration('Buscar Nome', Icons.search),
                          onChanged: (value) => setState(() => _nameFilter = value),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: _inputDecoration('Status', Icons.filter_list),
                          items: const [
                            DropdownMenuItem(value: 'todos', child: Text('Todos')),
                            DropdownMenuItem(value: 'pendente', child: Text('Pendente')),
                            DropdownMenuItem(value: 'pago', child: Text('Pago')),
                            DropdownMenuItem(value: 'falhou', child: Text('Falhou')),
                            DropdownMenuItem(value: 'cancelado', child: Text('Cancelado')),
                            DropdownMenuItem(value: 'reembolsado', child: Text('Reembolsado')),
                          ],
                          onChanged: (value) => setState(() => _statusFilter = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _refreshPayments,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Atualizar Lista', style: GoogleFonts.poppins(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- LISTA DE DADOS ---
          Expanded(
            child: _filteredPayments.isEmpty && !_isLoading
                ? Center(child: Text('Nenhum pagamento encontrado.', style: GoogleFonts.poppins(color: Colors.grey)))
                : Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.all(8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 20,
                            horizontalMargin: 12,
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                            columns: [
                              DataColumn(label: Text('Data', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Cliente', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Status', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Valor', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                            ],
                            rows: _filteredPayments.map((payment) {
                              // Parsing de Dados
                              final nome = _paymentMethod == 'pix'
                                  ? (payment['customer']?['name'] ?? 'N/A')
                                  : (payment['customer']?['name'] ?? payment['description'] ?? 'N/A');
                              final nomeCurto = nome.length > 25 ? '${nome.substring(0, 25)}...' : nome;
                              
                              final val = (payment['amount'] is int) ? payment['amount'] / 100 : double.tryParse(payment['amount'].toString()) ?? 0.0;
                              final valorFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(val);
                              
                              final status = payment['status'] ?? '';
                              
                              String dataFmt = '-';
                              if (payment['created_at'] != null) {
                                try {
                                  dataFmt = DateFormat('dd/MM HH:mm').format(DateTime.parse(payment['created_at']).toLocal());
                                } catch (_) {}
                              }

                              return DataRow(
                                cells: [
                                  DataCell(Text(dataFmt, style: GoogleFonts.poppins(fontSize: 13))),
                                  DataCell(Text(nomeCurto, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: _getStatusColor(status).withOpacity(0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_getStatusIcon(status), size: 14, color: _getStatusColor(status)),
                                          const SizedBox(width: 4),
                                          Text(_getStatusLabel(status), style: GoogleFonts.poppins(color: _getStatusColor(status), fontWeight: FontWeight.w600, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(valorFmt, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold))),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),

          if (_hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _loadMore,
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  label: Text('Carregar Mais', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(foregroundColor: Colors.orange.shade700),
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.black54, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.orange.shade600, width: 2)),
      prefixIcon: Icon(icon, color: Colors.orange.shade600, size: 20),
      filled: true,
      fillColor: Colors.white,
    );
  }
}