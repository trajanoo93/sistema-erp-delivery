import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

class ConferirPagamentosPage extends StatefulWidget {
  const ConferirPagamentosPage({Key? key}) : super(key: key);

  @override
  State<ConferirPagamentosPage> createState() => _ConferirPagamentosPageState();
}

class _ConferirPagamentosPageState extends State<ConferirPagamentosPage> {
  String _paymentMethod = 'pix';
  String? _selectedUnidade;
  String _statusFilter = 'todos';
  String _nameFilter = '';
  int _currentPage = 1;
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

  Future<void> _fetchPayments({bool append = false}) async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 90)));
      final endDate = DateFormat('yyyy-MM-dd').format(now);

      final url = _paymentMethod == 'pix'
          ? 'https://aogosto.com.br/proxy/consulta-pagarme.php?page=$_currentPage&size=10&unidade=$_selectedUnidade&start_date=$startDate&end_date=$endDate'
          : 'https://aogosto.com.br/proxy/consulta-stripe.php?unidade=$_selectedUnidade&start_date=$startDate&end_date=$endDate';

      print('Requisição ao proxy: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Erro ao buscar pagamentos: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final List<dynamic> newPayments = data['data'];
      final bool hasMore = data['has_more'] ?? (newPayments.length == 10);

      setState(() {
        if (append) {
          _payments.addAll(newPayments);
        } else {
          _payments = newPayments;
        }
        _hasMore = hasMore;
        print('Has more: $_hasMore, New payments: ${newPayments.length}');
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar pagamentos: $error')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadMore() {
    if (!_hasMore || _isLoading) return;
    setState(() {
      _currentPage++;
      print('Loading more, page: $_currentPage');
    });
    _fetchPayments(append: true);
  }

  void _refreshPayments() {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _payments.clear();
      _nameFilter = '';
      _nameFilterController.clear();
    });
    _fetchPayments();
  }

  List<dynamic> get _filteredPayments {
    List<dynamic> filtered = _payments;

    if (_statusFilter != 'todos') {
      filtered = filtered.where((payment) {
        final status = payment['status'];
        return status == (_statusFilter == 'pendente' ? 'pending' : 'paid');
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecione o método de pagamento e a unidade para consultar os pagamentos:',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.orange.shade50.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: InputDecoration(
                            labelText: 'Método de Pagamento',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade600,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.payment,
                              color: Colors.orange.shade600,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pix',
                              child: Text('PIX (Pagar.me)'),
                            ),
                            DropdownMenuItem(
                              value: 'credit_card',
                              child: Text('Cartão de Crédito (Stripe)'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value!;
                              _selectedUnidade = _paymentMethod == 'pix'
                                  ? _unidadesPix[0]
                                  : _unidadesStripe[0];
                              _currentPage = 1;
                              _hasMore = true;
                              _payments.clear();
                              _nameFilter = '';
                              _nameFilterController.clear();
                            });
                            _fetchPayments();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedUnidade,
                          decoration: InputDecoration(
                            labelText: 'Unidade da Loja',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade600,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.store,
                              color: Colors.orange.shade600,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: (_paymentMethod == 'pix' ? _unidadesPix : _unidadesStripe)
                              .map((unidade) => DropdownMenuItem(
                                    value: unidade,
                                    child: Text(unidade),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedUnidade = value;
                              _currentPage = 1;
                              _hasMore = true;
                              _payments.clear();
                              _nameFilter = '';
                              _nameFilterController.clear();
                            });
                            _fetchPayments();
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
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Nome',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade600,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.orange.shade600,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _nameFilter = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: InputDecoration(
                            labelText: 'Filtrar por Status',
                            labelStyle: GoogleFonts.poppins(
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade200,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.orange.shade600,
                                width: 2,
                              ),
                            ),
                            prefixIcon: Icon(
                              Icons.filter_list,
                              color: Colors.orange.shade600,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'todos',
                              child: Text('Todos'),
                            ),
                            DropdownMenuItem(
                              value: 'pendente',
                              child: Text('Pendente'),
                            ),
                            DropdownMenuItem(
                              value: 'pago',
                              child: Text('Pago'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _statusFilter = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _refreshPayments,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          shadowColor: Colors.orange.withOpacity(0.3),
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
                            : Text(
                                'Atualizar',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _filteredPayments.isEmpty && !_isLoading
                ? Center(
                    child: Text(
                      'Nenhum pagamento encontrado.',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                  )
                : Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white,
                            Colors.orange.shade50.withOpacity(0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: DataTable(
                          columnSpacing: 16.0,
                          horizontalMargin: 16.0,
                          columns: [
                            DataColumn(
                              label: Text(
                                'Nome do Cliente',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Valor (R\$)',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Data de Criação',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                          rows: _filteredPayments.map((payment) {
                            final nomeCliente = _paymentMethod == 'pix'
                                ? (payment['customer']?['name'] ?? 'N/A')
                                : (payment['customer']?['name'] ?? payment['description'] ?? 'N/A');
                            final truncatedNomeCliente = nomeCliente.length > 15
                                ? '${nomeCliente.substring(0, 15)}...'
                                : nomeCliente;
                            final valorReais = (payment['amount'] / 100).toStringAsFixed(2);
                            final status = payment['status'];
                            final dataCriacao = DateFormat('dd/MM/yyyy HH:mm')
                                .format(DateTime.parse(payment['created_at']).toLocal());

                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    truncatedNomeCliente,
                                    style: GoogleFonts.poppins(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    'R\$ $valorReais',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Chip(
                                    label: Text(
                                      status == 'pending' || status == 'unpaid' || status == 'failed'
                                          ? 'Pendente'
                                          : 'Pago',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    backgroundColor: status == 'pending' || status == 'unpaid' || status == 'failed'
                                        ? Colors.orange.shade600
                                        : Colors.green.shade600,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    dataCriacao,
                                    style: GoogleFonts.poppins(
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                              color: MaterialStateProperty.resolveWith<Color?>(
                                (Set<MaterialState> states) {
                                  return states.contains(MaterialState.hovered)
                                      ? Colors.orange.shade50.withOpacity(0.5)
                                      : null;
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),

          if (_hasMore)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _loadMore,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                      shadowColor: Colors.orange.withOpacity(0.3),
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
                        : Text(
                            'Carregar Mais',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}