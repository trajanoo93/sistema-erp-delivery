import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:erp_painel_delivery/models/pedido_state.dart';
import 'package:flutter/scheduler.dart'; // Para addPostFrameCallback

class ShippingSection extends StatefulWidget {
  final String cep;
  final Function(String, String) onStoreUpdated;
  final Function(String) onShippingMethodUpdated;
  final Function(String) onPaymentMethodUpdated;
  final Function(double) onShippingCostUpdated;
  final PedidoState pedido;

  const ShippingSection({
    Key? key,
    required this.cep,
    required this.onStoreUpdated,
    required this.onShippingMethodUpdated,
    required this.onPaymentMethodUpdated,
    required this.onShippingCostUpdated,
    required this.pedido,
  }) : super(key: key);

  @override
  State<ShippingSection> createState() => _ShippingSectionState();
}

class _ShippingSectionState extends State<ShippingSection> {
  String _shippingMethod = 'delivery';
  String _pickupStore = '';
  String _storeFinal = '';
  String _pickupStoreId = '';
  List<String> _pickupStores = [
    'Central Distribuição (Sagrada Família)',
    'Unidade Barreiro',
    'Unidade Sion',
  ];
  List<String> _paymentMethods = [];
  String _selectedPaymentMethod = '';

  final Map<String, String> _pickupStoreIds = {
    'Central Distribuição (Sagrada Família)': '86261',
    'Unidade Barreiro': '110727',
    'Unidade Sion': '127163',
  };

  @override
  void initState() {
    super.initState();
    _initializeState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateState();
      _fetchStoreDecision(widget.cep);
    });
  }

  @override
  void didUpdateWidget(ShippingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cep != widget.cep || oldWidget.pedido.shippingMethod != widget.pedido.shippingMethod) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeState();
        _updateState();
        _fetchStoreDecision(widget.cep);
      });
    }
  }

  void _initializeState() {
    _shippingMethod = widget.pedido.shippingMethod.isNotEmpty ? widget.pedido.shippingMethod : 'delivery';
    _selectedPaymentMethod = widget.pedido.selectedPaymentMethod.isNotEmpty ? widget.pedido.selectedPaymentMethod : '';
    _pickupStore = _pickupStores.contains(widget.pedido.storeFinal) ? widget.pedido.storeFinal : _pickupStores.first;
    _storeFinal = _pickupStore;
    _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '';
    print('Initialized state: _shippingMethod=$_shippingMethod, _pickupStore=$_pickupStore, _storeFinal=$_storeFinal, _pickupStoreId=$_pickupStoreId');
  }

  void _updateState() {
    if (!mounted) return;
    setState(() {
      _shippingMethod = widget.pedido.shippingMethod.isNotEmpty ? widget.pedido.shippingMethod : 'delivery';
      _selectedPaymentMethod = widget.pedido.selectedPaymentMethod.isNotEmpty ? widget.pedido.selectedPaymentMethod : '';
      _pickupStore = _pickupStores.contains(widget.pedido.storeFinal) ? widget.pedido.storeFinal : _pickupStores.first;
      _storeFinal = _pickupStore;
      _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '';
      widget.onShippingCostUpdated(widget.pedido.shippingCost);
      widget.onStoreUpdated(_storeFinal, _pickupStoreId);
      widget.onPaymentMethodUpdated(_selectedPaymentMethod);
    });
    print('State updated: _shippingMethod=$_shippingMethod, _pickupStore=$_pickupStore, shippingCost=${widget.pedido.shippingCost}');
  }

  void _fetchStoreDecision(String cep) async {
    print('Fetching store decision for CEP: $cep, Shipping Method: $_shippingMethod, Pickup Store: $_pickupStore');

    if (cep.length != 8 && _shippingMethod != 'pickup') {
      print('CEP is incomplete, skipping store decision fetch.');
      if (mounted) {
        setState(() {
          _paymentMethods = [];
          _selectedPaymentMethod = '';
        });
        widget.onPaymentMethodUpdated('');
        widget.pedido.selectedPaymentMethod = '';
      }
      return;
    }

    try {
      final storeDecisionResponse = await http.post(
        Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/store-decision'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'cep': cep,
          'shipping_method': _shippingMethod,
          'pickup_store': _pickupStore,
        }),
      );

      print('Store decision response status: ${storeDecisionResponse.statusCode}');
      print('Store decision response body: ${storeDecisionResponse.body}');

      if (storeDecisionResponse.statusCode != 200) {
        throw Exception('Erro ao buscar opções de entrega: ${storeDecisionResponse.statusCode} - ${storeDecisionResponse.body}');
      }

      final storeDecision = jsonDecode(storeDecisionResponse.body);

      if (mounted) {
        setState(() {
          _paymentMethods = (storeDecision['payment_methods'] as List<dynamic>?)
              ?.map((method) => method['title'].toString() == 'Pagamento Online' ? 'Cartão de Crédito On-line' : method['title'].toString())
              .toList() ?? [];

          _selectedPaymentMethod = _paymentMethods.isNotEmpty && !_paymentMethods.contains(_selectedPaymentMethod)
              ? _paymentMethods.first
              : _selectedPaymentMethod.isNotEmpty
                  ? _selectedPaymentMethod
                  : '';

          if (_shippingMethod == 'pickup') {
            _pickupStore = _pickupStores.contains(widget.pedido.storeFinal) ? widget.pedido.storeFinal : _pickupStores.first;
            _storeFinal = _pickupStore;
            _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '';
          } else {
            _storeFinal = storeDecision['store_final']?.toString() ?? '';
            _pickupStoreId = storeDecision['pickup_store_id']?.toString() ?? '';
          }
        });

        widget.onStoreUpdated(_storeFinal, _pickupStoreId);
        widget.onPaymentMethodUpdated(_selectedPaymentMethod);
        widget.pedido.selectedPaymentMethod = _selectedPaymentMethod;
        if (_shippingMethod == 'pickup') {
          widget.onShippingCostUpdated(0.0);
          widget.pedido.shippingCost = 0.0;
          widget.pedido.shippingCostController.text = '0.00';
        } else {
          final cost = double.tryParse(storeDecision['shipping_options']?.first['cost']?.toString() ?? '0.0') ?? 0.0;
          widget.onShippingCostUpdated(cost);
          widget.pedido.shippingCost = cost;
          widget.pedido.shippingCostController.text = cost.toStringAsFixed(2);
        }
      }
    } catch (error) {
      print('Error fetching store decision: $error');
      if (mounted) {
        setState(() {
          _paymentMethods = [];
          _selectedPaymentMethod = '';
        });
        widget.onPaymentMethodUpdated('');
        widget.pedido.selectedPaymentMethod = '';
        widget.onShippingCostUpdated(0.0);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar opções de entrega: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    print('Building ShippingSection: _shippingMethod=$_shippingMethod, _pickupStore=$_pickupStore, _paymentMethods=$_paymentMethods');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              'Método de Entrega',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _shippingMethod,
              decoration: InputDecoration(
                labelText: 'Método de Entrega',
                labelStyle: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                ),
                prefixIcon: Icon(Icons.local_shipping, color: Colors.orange.shade600),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
              items: [
                DropdownMenuItem(value: 'delivery', child: Text('Delivery (Motoboy)')),
                DropdownMenuItem(value: 'pickup', child: Text('Retirada na Unidade')),
              ],
              onChanged: (value) {
                if (value != null && mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _shippingMethod = value;
                      _paymentMethods = [];
                      _selectedPaymentMethod = '';
                      widget.pedido.selectedPaymentMethod = '';
                      print('Shipping method changed to: $_shippingMethod');
                      if (_shippingMethod == 'pickup') {
                        _pickupStore = _pickupStores.contains(widget.pedido.storeFinal) ? widget.pedido.storeFinal : _pickupStores.first;
                        _storeFinal = _pickupStore;
                        _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '';
                        widget.onShippingCostUpdated(0.0);
                        widget.pedido.shippingCost = 0.0;
                        widget.pedido.shippingCostController.text = '0.00';
                      } else {
                        _pickupStore = '';
                        _storeFinal = '';
                        _pickupStoreId = '';
                      }
                    });
                    widget.onShippingMethodUpdated(_shippingMethod);
                    widget.onStoreUpdated(_storeFinal, _pickupStoreId);
                    widget.onPaymentMethodUpdated(_selectedPaymentMethod);
                    _fetchStoreDecision(widget.cep);
                  });
                }
              },
              validator: (value) => value == null ? 'Por favor, selecione o método de entrega' : null,
            ),
          ),
          if (_shippingMethod == 'pickup') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: DropdownButtonFormField<String>(
                value: _pickupStores.contains(_pickupStore) ? _pickupStore : _pickupStores.first,
                decoration: InputDecoration(
                  labelText: 'Loja para Retirada',
                  labelStyle: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                  ),
                  prefixIcon: Icon(Icons.store, color: Colors.orange.shade600),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                ),
                items: _pickupStores.map((store) {
                  return DropdownMenuItem<String>(
                    value: store,
                    child: Text(
                      store,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      setState(() {
                        _pickupStore = value;
                        _storeFinal = _pickupStore;
                        _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '';
                        print('Pickup store changed to: $_pickupStore, _storeFinal=$_storeFinal, _pickupStoreId=$_pickupStoreId');
                      });
                      widget.onStoreUpdated(_storeFinal, _pickupStoreId);
                      widget.pedido.storeFinal = _storeFinal;
                      widget.pedido.pickupStoreId = _pickupStoreId;
                      _fetchStoreDecision(widget.cep);
                    });
                  }
                },
                validator: (value) => _shippingMethod == 'pickup' && (value == null || value.isEmpty) ? 'Por favor, selecione uma loja para retirada' : null,
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Método de Pagamento',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonFormField<String>(
              value: _paymentMethods.contains(_selectedPaymentMethod) ? _selectedPaymentMethod : _paymentMethods.isNotEmpty ? _paymentMethods.first : null,
              decoration: InputDecoration(
                labelText: 'Método de Pagamento',
                labelStyle: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                ),
                prefixIcon: Icon(Icons.payment, color: Colors.orange.shade600),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
              items: _paymentMethods.map((method) {
                return DropdownMenuItem<String>(
                  value: method,
                  child: Text(
                    method,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null && mounted) {
                  setState(() {
                    _selectedPaymentMethod = value;
                    print('Payment method selected: $_selectedPaymentMethod');
                  });
                  widget.onPaymentMethodUpdated(_selectedPaymentMethod);
                  widget.pedido.selectedPaymentMethod = _selectedPaymentMethod;
                }
              },
              validator: (value) => value == null || value.isEmpty ? 'Por favor, selecione um método de pagamento' : null,
            ),
          ),
          if (_paymentMethods.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Nenhum método de pagamento disponível para o CEP ou método de entrega selecionado.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          if (_shippingMethod == 'delivery' && widget.pedido.shippingCost > 0.0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Custo de Envio: R\$ ${widget.pedido.shippingCost.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          if (_shippingMethod == 'delivery' && widget.pedido.shippingCost == 0.0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Taxa de entrega não disponível para este CEP.',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}