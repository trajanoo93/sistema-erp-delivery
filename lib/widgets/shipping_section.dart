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
  // Removido _selectedDate, pois a data será gerenciada em outro lugar

  final Map<String, String> _pickupStoreIds = {
    'Central Distribuição (Sagrada Família)': '86261',
    'Unidade Barreiro': '110727',
    'Unidade Sion': '127163',
  };

  @override
  void initState() {
    super.initState();
    _shippingMethod = widget.pedido.shippingMethod.isNotEmpty ? widget.pedido.shippingMethod : 'delivery';
    _selectedPaymentMethod = ''; // Inicializa vazio, será atualizado após a API
    _pickupStore = _pickupStores.contains(widget.pedido.storeFinal) ? widget.pedido.storeFinal : _pickupStores.first;
    _storeFinal = _pickupStore;
    _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '';

    print('ShippingSection initState: _shippingMethod=$_shippingMethod, _selectedPaymentMethod=$_selectedPaymentMethod, _pickupStore=$_pickupStore, _storeFinal=$_storeFinal, _pickupStoreId=$_pickupStoreId');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onShippingMethodUpdated(_shippingMethod);
      if (_shippingMethod == 'pickup') {
        widget.onShippingCostUpdated(0.0);
        widget.onStoreUpdated(_storeFinal, _pickupStoreId);
      }
      _fetchStoreDecision(widget.cep);
    });
  }

  @override
  void didUpdateWidget(ShippingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cep != widget.cep || oldWidget.pedido.storeFinal != widget.pedido.storeFinal) {
      setState(() {
        _pickupStore = _pickupStores.contains(widget.pedido.storeFinal) ? widget.pedido.storeFinal : _pickupStores.first;
        _storeFinal = _pickupStore;
        _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '';
      });
      _fetchStoreDecision(widget.cep);
    }
  }

  void _fetchStoreDecision(String cep) async {
    print('Fetching store decision for CEP: $cep, Shipping Method: $_shippingMethod, Pickup Store: $_pickupStore, Pedido StoreFinal: ${widget.pedido.storeFinal}');

    if (cep.length != 8 && _shippingMethod != 'pickup') {
      print('CEP is incomplete, skipping store decision fetch.');
      setState(() {
        _paymentMethods = [];
        _selectedPaymentMethod = '';
      });
      widget.onPaymentMethodUpdated('');
      widget.pedido.selectedPaymentMethod = '';
      widget.onShippingCostUpdated(0.0);
      return;
    }

    try {
      final storeDecisionResponse = await http.post(
        Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/store-decision'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'cep': cep,
          'shipping_method': _shippingMethod,
          'pickup_store': _pickupStore,
          // Removido 'scheduling_date', pois a data será gerenciada externamente
        }),
      );

      print('Store decision response status: ${storeDecisionResponse.statusCode}');
      print('Store decision response body: ${storeDecisionResponse.body}');

      if (storeDecisionResponse.statusCode != 200) {
        throw Exception('Erro ao buscar opções de entrega: ${storeDecisionResponse.statusCode} - ${storeDecisionResponse.body}');
      }

      final storeDecision = jsonDecode(storeDecisionResponse.body);

      setState(() {
        _paymentMethods = (storeDecision['payment_methods'] as List<dynamic>)
            .map((method) => method['title'].toString())
            .toSet()
            .toList();

        print('Processed payment methods (deduplicated): $_paymentMethods');

        if (_paymentMethods.isNotEmpty) {
          _selectedPaymentMethod = _paymentMethods.contains(widget.pedido.selectedPaymentMethod)
              ? widget.pedido.selectedPaymentMethod
              : _paymentMethods.first;
        } else {
          _selectedPaymentMethod = '';
        }

        if (_shippingMethod == 'pickup') {
          if (_pickupStore.isNotEmpty && _pickupStores.contains(_pickupStore)) {
            _storeFinal = _pickupStore;
            _pickupStoreId = _pickupStoreIds[_pickupStore]!;
          } else {
            _pickupStore = _pickupStores.first;
            _storeFinal = _pickupStore;
            _pickupStoreId = _pickupStoreIds[_pickupStore]!;
          }
        } else {
          _storeFinal = storeDecision['store_final']?.toString() ?? '';
          _pickupStoreId = storeDecision['pickup_store_id']?.toString() ?? '';
        }

        widget.pedido.selectedPaymentMethod = _selectedPaymentMethod;
      });

      print('Updated state - Pickup Stores: $_pickupStores, Payment Methods: $_paymentMethods, Store Final: $_storeFinal, Pickup Store ID: $_pickupStoreId, Selected Payment Method: $_selectedPaymentMethod');

      widget.onStoreUpdated(_storeFinal, _pickupStoreId);
      widget.onPaymentMethodUpdated(_selectedPaymentMethod);
      if (_shippingMethod == 'delivery') {
        final cost = double.tryParse(storeDecision['shipping_options']?.first['cost']?.toString() ?? '0.0') ?? 0.0;
        widget.onShippingCostUpdated(cost);
        widget.pedido.shippingCost = cost;
        widget.pedido.shippingCostController.text = cost.toStringAsFixed(2);
      } else {
        widget.onShippingCostUpdated(0.0);
        widget.pedido.shippingCost = 0.0;
        widget.pedido.shippingCostController.text = '0.00';
      }
    } catch (error) {
      print('Error fetching store decision: $error');
      setState(() {
        _paymentMethods = [];
        _selectedPaymentMethod = '';
      });
      widget.onPaymentMethodUpdated('');
      widget.pedido.selectedPaymentMethod = '';
      widget.onShippingCostUpdated(0.0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar opções de entrega: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    print('Building ShippingSection: _shippingMethod=$_shippingMethod, _selectedPaymentMethod=$_selectedPaymentMethod, _paymentMethods=$_paymentMethods, _pickupStore=$_pickupStore, Pedido StoreFinal=${widget.pedido.storeFinal}');

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
                DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                DropdownMenuItem(value: 'pickup', child: Text('Retirada na Unidade')),
              ],
              onChanged: (value) {
                if (value != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _shippingMethod = value;
                        _paymentMethods = [];
                        _selectedPaymentMethod = '';
                        widget.pedido.selectedPaymentMethod = '';
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
                    }
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
          // Removido o InkWell para seleção de data aqui
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
              value: _paymentMethods.isNotEmpty && _paymentMethods.contains(_selectedPaymentMethod)
                  ? _selectedPaymentMethod
                  : _paymentMethods.isNotEmpty
                      ? _paymentMethods.first
                      : null,
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
                if (value != null) {
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
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}