import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:erp_painel_delivery/models/pedido_state.dart';
import 'package:intl/intl.dart';
import '../utils/log_utils.dart';

class ShippingSection extends StatefulWidget {
  final String cep;
  final Function(String, String) onStoreUpdated;
  final Function(String) onShippingMethodUpdated;
  final Function(double) onShippingCostUpdated;
  final PedidoState pedido;
  final Function() onSchedulingChanged;
  final Future<void> Function(PedidoState)? savePersistedData;

  const ShippingSection({
    super.key,
    required this.cep,
    required this.onStoreUpdated,
    required this.onShippingMethodUpdated,
    required this.onShippingCostUpdated,
    required this.pedido,
    required this.onSchedulingChanged,
    this.savePersistedData,
  });

  @override
  State<ShippingSection> createState() => _ShippingSectionState();
}

class _ShippingSectionState extends State<ShippingSection> {
  String _shippingMethod = 'delivery';
  String _pickupStore = '';
  String _storeFinal = '';
  String _pickupStoreId = '';

  final List<String> _pickupStores = [
    'Central Distribuição (Sagrada Família)',
    'Unidade Barreiro',
    'Unidade Sion',
  ];

  final Map<String, String> _pickupStoreIds = {
    'Central Distribuição (Sagrada Família)': '86261',
    'Unidade Barreiro': '110727',
    'Unidade Sion': '127163',
  };

  @override
  void initState() {
    super.initState();
    _shippingMethod = widget.pedido.shippingMethod.isNotEmpty ? widget.pedido.shippingMethod : 'delivery';
    _pickupStore = _pickupStores.contains(widget.pedido.storeFinal) ? widget.pedido.storeFinal : _pickupStores.first;
    _storeFinal = _pickupStore;
    _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '86261';

    // Salva o valor atual ao iniciar (se for pickup)
    if (_shippingMethod == 'pickup') {
      widget.pedido.originalShippingCost = widget.pedido.shippingCost;
      widget.pedido.shippingCost = 0.0;
      widget.pedido.shippingCostController.text = '0.00';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onShippingMethodUpdated(_shippingMethod);
        widget.onStoreUpdated(_storeFinal, _pickupStoreId);
        widget.onShippingCostUpdated(widget.pedido.shippingCost);
        _fetchStoreDecision(widget.cep);
        logToFile('initState: shippingMethod=$_shippingMethod, storeFinal=$_storeFinal, pickupStoreId=$_pickupStoreId, shippingCost=${widget.pedido.shippingCost}');
      }
    });
  }

  @override
  void didUpdateWidget(ShippingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cep != widget.cep || oldWidget.pedido.storeFinal != widget.pedido.storeFinal) {
      setState(() {
        _pickupStore = _pickupStores.contains(widget.pedido.storeFinal) ? widget.pedido.storeFinal : _pickupStores.first;
        _storeFinal = _pickupStore;
        _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '86261';
        widget.pedido.storeFinal = _storeFinal;
        widget.pedido.pickupStoreId = _pickupStoreId;

        if (_shippingMethod == 'pickup') {
          widget.pedido.originalShippingCost = widget.pedido.shippingCost;
          widget.pedido.shippingCost = 0.0;
          widget.pedido.shippingCostController.text = '0.00';
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onStoreUpdated(_storeFinal, _pickupStoreId);
          widget.onShippingCostUpdated(widget.pedido.shippingCost);
          _fetchStoreDecision(widget.cep);
          logToFile('didUpdateWidget: cep=${widget.cep}, storeFinal=$_storeFinal, pickupStoreId=$_pickupStoreId, shippingCost=${widget.pedido.shippingCost}');
        }
      });
    }
  }

  Future<void> _fetchStoreDecision(String cep) async {
    await logToFile('Fetching store decision for CEP: $cep, Shipping Method: $_shippingMethod');

    if (_shippingMethod == 'pickup') {
      if (mounted) {
        setState(() {
          _storeFinal = _pickupStore.isNotEmpty && _pickupStores.contains(_pickupStore)
              ? _pickupStore
              : _pickupStores.first;
          _pickupStoreId = _pickupStoreIds[_storeFinal] ?? '86261';
          widget.pedido.storeFinal = _storeFinal;
          widget.pedido.pickupStoreId = _pickupStoreId;
        });
      }
      widget.onShippingCostUpdated(0.0);
      widget.onStoreUpdated(_storeFinal, _pickupStoreId);
      widget.pedido.notifyListeners();
      await logToFile('Pickup mode: Reset shippingCost to 0.0');
      widget.savePersistedData?.call(widget.pedido);
      return;
    }

    if (cep.length != 8) {
      await logToFile('CEP is incomplete, resetting store and cost.');
      if (mounted) {
        setState(() {
          _storeFinal = '';
          _pickupStoreId = '';
          widget.pedido.availablePaymentMethods = [];
          widget.pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
          widget.pedido.shippingCost = 0.0;
          widget.pedido.shippingCostController.text = '0.00';
          widget.pedido.storeFinal = '';
          widget.pedido.pickupStoreId = '';
        });
      }
      widget.onShippingCostUpdated(0.0);
      widget.onStoreUpdated('', '');
      widget.pedido.notifyListeners();
      widget.savePersistedData?.call(widget.pedido);
      return;
    }

    try {
      final normalizedDate = widget.pedido.schedulingDate.isEmpty
          ? DateFormat('yyyy-MM-dd').format(DateTime.now())
          : widget.pedido.schedulingDate;

      final requestBody = {
        'cep': cep,
        'shipping_method': _shippingMethod,
        'pickup_store': _shippingMethod == 'pickup' ? _pickupStore : '',
        'delivery_date': _shippingMethod == 'delivery' ? normalizedDate : '',
        'pickup_date': _shippingMethod == 'pickup' ? normalizedDate : '',
      };

      await logToFile('Sending request to store-decision endpoint: ${jsonEncode(requestBody)}');
      final storeResponse = await http.post(
        Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/store-decision'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw Exception('Timeout ao buscar opções de entrega');
      });

      await logToFile('Store decision response status: ${storeResponse.statusCode}, body: ${storeResponse.body}');

     double shippingCost = 0.0;
if (_shippingMethod == 'delivery') {
  if (!widget.pedido.isShippingCostManuallyEdited) {
    await logToFile('Recalculando frete (não editado manualmente)');
    final costResponse = await http.get(
      Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/shipping-cost?cep=$cep'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(Duration(seconds: 15), onTimeout: () {
      throw Exception('Timeout ao buscar custo de frete');
    });

    await logToFile('Shipping cost response status: ${costResponse.statusCode}, body: ${costResponse.body}');
    if (costResponse.statusCode == 200) {
      final costData = jsonDecode(costResponse.body);
      if (costData['status'] == 'success' && costData['shipping_options'] != null && costData['shipping_options'].isNotEmpty) {
        shippingCost = double.tryParse(costData['shipping_options'][0]['cost']?.toString() ?? '0.0') ?? 0.0;
        widget.pedido.shippingCost = shippingCost;
        widget.pedido.shippingCostController.text = shippingCost.toStringAsFixed(2);
      } else {
        await logToFile('Nenhuma opção de frete válida retornada para CEP: $cep');
        shippingCost = 0.0;
      }
    } else {
      throw Exception('Erro ao buscar custo de frete: ${costResponse.statusCode} - ${costResponse.body}');
    }
  } else {
    await logToFile('Mantendo frete editado manualmente: ${widget.pedido.shippingCost}');
    shippingCost = widget.pedido.shippingCost; // Usa o valor editado
  }
}

      if (storeResponse.statusCode == 200) {
        final storeDecision = jsonDecode(storeResponse.body);
        await logToFile('Parsed JSON: ${jsonEncode(storeDecision)}');

        if (mounted) {
          setState(() {
            if (_shippingMethod == 'pickup') {
              _storeFinal = _pickupStore.isNotEmpty && _pickupStores.contains(_pickupStore)
                  ? _pickupStore
                  : _pickupStores.first;
              _pickupStoreId = _pickupStoreIds[_storeFinal] ?? '86261';
            } else {
              _storeFinal = storeDecision['effective_store_final']?.toString() ??
                  storeDecision['store_final']?.toString() ??
                  'Central Distribuição (Sagrada Família)';
              _pickupStoreId = storeDecision['pickup_store_id']?.toString() ?? '86261';
            }

            widget.pedido.storeFinal = _storeFinal;
            widget.pedido.pickupStoreId = _pickupStoreId;

            final rawPaymentMethods = List<Map<String, dynamic>>.from(storeDecision['payment_methods'] ?? []);
            widget.pedido.availablePaymentMethods = [];
            final seenTitles = <String>{};

            for (var m in rawPaymentMethods) {
              final id = m['id']?.toString() ?? '';
              final title = m['title']?.toString() ?? '';
              if (id == 'woo_payment_on_delivery' && !seenTitles.contains('Dinheiro na Entrega')) {
                widget.pedido.availablePaymentMethods.add({'id': 'cod', 'title': 'Dinheiro na Entrega'});
                seenTitles.add('Dinheiro na Entrega');
              } else if ((id == 'stripe' || id == 'stripe_cc' || id == 'eh_stripe_pay') &&
                  !seenTitles.contains('Cartão de Crédito On-line')) {
                widget.pedido.availablePaymentMethods.add({
                  'id': storeDecision['payment_accounts']['stripe']?.toString() ?? 'stripe',
                  'title': 'Cartão de Crédito On-line'
                });
                seenTitles.add('Cartão de Crédito On-line');
              } else if (!seenTitles.contains(title)) {
                widget.pedido.availablePaymentMethods.add({'id': id, 'title': title});
                seenTitles.add(title);
              }
            }

            final paymentAccounts = storeDecision['payment_accounts'] as Map?;
            widget.pedido.paymentAccounts = paymentAccounts != null
                ? paymentAccounts.map((key, value) => MapEntry(key.toString(), value))
                : {'stripe': 'stripe', 'pagarme': 'central'};

            if (widget.pedido.selectedPaymentMethod.isNotEmpty &&
                !widget.pedido.availablePaymentMethods.any((m) => m['title'] == widget.pedido.selectedPaymentMethod)) {
              widget.pedido.selectedPaymentMethod = widget.pedido.availablePaymentMethods.isNotEmpty
                  ? widget.pedido.availablePaymentMethods.first['title'] ?? ''
                  : '';
            }

            // Só atualiza se NÃO foi editado manualmente
            if (!widget.pedido.isShippingCostManuallyEdited) {
              widget.pedido.shippingCost = _shippingMethod == 'pickup' ? 0.0 : shippingCost;
              widget.pedido.shippingCostController.text = widget.pedido.shippingCost.toStringAsFixed(2);
            }
          });
        }

        await logToFile('Updated state - Store Final: $_storeFinal, Pickup Store ID: $_pickupStoreId, Shipping Cost: ${widget.pedido.shippingCost}');
        widget.onStoreUpdated(_storeFinal, _pickupStoreId);
        widget.onShippingCostUpdated(widget.pedido.shippingCost);
        widget.pedido.notifyListeners();
        widget.savePersistedData?.call(widget.pedido);
      } else {
        throw Exception('Erro ao buscar opções de entrega: ${storeResponse.statusCode}');
      }
    } catch (error, stackTrace) {
      await logToFile('Error fetching store decision: $error, StackTrace: $stackTrace');
      if (mounted) {
        setState(() {
          _storeFinal = 'Central Distribuição (Sagrada Família)';
          _pickupStoreId = '86261';
          widget.pedido.storeFinal = _storeFinal;
          widget.pedido.pickupStoreId = _pickupStoreId;
          widget.pedido.availablePaymentMethods = [
            {'id': 'pagarme_custom_pix', 'title': 'Pix'},
            {'id': 'stripe', 'title': 'Cartão de Crédito On-line'},
            {'id': 'cod', 'title': 'Dinheiro na Entrega'},
            {'id': 'custom_729b8aa9fc227ff', 'title': 'Cartão na Entrega'},
            {'id': 'custom_e876f567c151864', 'title': 'Vale Alimentação'},
          ];
          widget.pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
          if (!widget.pedido.isShippingCostManuallyEdited) {
            widget.pedido.shippingCost = 0.0;
            widget.pedido.shippingCostController.text = '0.00';
          }
        });
      }
      widget.onStoreUpdated(_storeFinal, _pickupStoreId);
      widget.onShippingCostUpdated(widget.pedido.shippingCost);
      widget.pedido.notifyListeners();
      widget.savePersistedData?.call(widget.pedido);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFF28C38);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: Colors.white,
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
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
                prefixIcon: Icon(Icons.local_shipping, color: primaryColor),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
              ),
              items: [
                DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                DropdownMenuItem(value: 'pickup', child: Text('Retirada na Unidade')),
              ],
              onChanged: (value) {
                if (value != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    if (mounted) {
                      setState(() {
                        _shippingMethod = value;

                        if (_shippingMethod == 'pickup') {
                          // SALVA O VALOR ANTES DE ZERAR
                          widget.pedido.originalShippingCost = widget.pedido.shippingCost;

                          _pickupStore = _pickupStores.first;
                          _storeFinal = _pickupStore;
                          _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '86261';
                          widget.pedido.shippingCost = 0.0;
                          widget.pedido.shippingCostController.text = '0.00';
                          widget.pedido.isShippingCostManuallyEdited = false;
                          widget.pedido.storeFinal = _storeFinal;
                          widget.pedido.pickupStoreId = _pickupStoreId;
                        } else {
                          // RESTAURA O VALOR ORIGINAL
                          widget.pedido.shippingCost = widget.pedido.originalShippingCost;
                          widget.pedido.shippingCostController.text = widget.pedido.shippingCost.toStringAsFixed(2);
                          widget.pedido.isShippingCostManuallyEdited = true;

                          _pickupStore = '';
                          _storeFinal = '';
                          _pickupStoreId = '';
                          widget.pedido.storeFinal = '';
                          widget.pedido.pickupStoreId = '';
                        }
                      });

                      widget.onShippingMethodUpdated(_shippingMethod);
                      widget.onStoreUpdated(_storeFinal, _pickupStoreId);
                      widget.onShippingCostUpdated(widget.pedido.shippingCost);
                      widget.pedido.notifyListeners();
                      await widget.savePersistedData?.call(widget.pedido);
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
                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                  prefixIcon: Icon(Icons.store, color: primaryColor),
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
                    setState(() {
                      _pickupStore = value;
                      _storeFinal = _pickupStore;
                      _pickupStoreId = _pickupStoreIds[_pickupStore] ?? '86261';
                      widget.pedido.storeFinal = _storeFinal;
                      widget.pedido.pickupStoreId = _pickupStoreId;
                      widget.pedido.shippingCost = 0.0;
                      widget.pedido.shippingCostController.text = '0.00';
                      widget.pedido.isShippingCostManuallyEdited = false;
                    });
                    widget.onStoreUpdated(_storeFinal, _pickupStoreId);
                    widget.onShippingCostUpdated(0.0);
                    widget.pedido.notifyListeners();
                    widget.savePersistedData?.call(widget.pedido);
                  }
                },
                validator: (value) => _shippingMethod == 'pickup' && (value == null || value.isEmpty)
                    ? 'Por favor, selecione uma loja para retirada'
                    : null,
              ),
            ),
          ],
          // CAMPO DE TAXA REMOVIDO (agora só no SummarySection)
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}