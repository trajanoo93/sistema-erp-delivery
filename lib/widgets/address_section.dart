// lib/widgets/address_section.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/pedido_state.dart';
import '../utils/log_utils.dart';

class AddressSection extends StatefulWidget {
  final TextEditingController cepController;
  final TextEditingController addressController;
  final TextEditingController numberController;
  final TextEditingController complementController;
  final TextEditingController neighborhoodController;
  final TextEditingController cityController;
  final Function(String) onChanged;
  final Function(double) onShippingCostUpdated;
  final Function(String, String) onStoreUpdated;
  final double externalShippingCost;
  final String shippingMethod;
  final VoidCallback? setStateCallback;
  final Future<void> Function()? savePersistedData;
  final Future<void> Function()? checkStoreByCep;
  final PedidoState? pedido;
  final VoidCallback? onReset;

  const AddressSection({
    super.key,
    required this.cepController,
    required this.addressController,
    required this.numberController,
    required this.complementController,
    required this.neighborhoodController,
    required this.cityController,
    required this.onChanged,
    required this.onShippingCostUpdated,
    required this.onStoreUpdated,
    required this.externalShippingCost,
    required this.shippingMethod,
    this.setStateCallback,
    this.savePersistedData,
    this.checkStoreByCep,
    this.pedido,
    this.onReset,
  });

  @override
  State<AddressSection> createState() => _AddressSectionState();
}

class _AddressSectionState extends State<AddressSection> {
  bool _isFetchingStore = false;
  bool _isEditingShippingCost = false;
  final _shippingCostController = TextEditingController();
  late VoidCallback _addressListener;
  late VoidCallback _numberListener;
  late VoidCallback _complementListener;
  late VoidCallback _neighborhoodListener;
  late VoidCallback _cityListener;

  final _cepMaskFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  static const cacheDuration = 86400000; // 24 horas em milissegundos

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _shippingCostController.text = widget.pedido?.shippingCostController.text ??
        widget.externalShippingCost.toStringAsFixed(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.shippingMethod == 'pickup' && widget.cepController.text.isNotEmpty) {
        resetSection();
        logToFile('Reset AddressSection due to shippingMethod change to pickup');
      }
      logToFile(
          'AddressSection initialized: cep=${widget.cepController.text}, shippingMethod=${widget.shippingMethod}');
    });
  }

  void _setupListeners() {
    _addressListener = () => _onFieldChanged(widget.addressController.text);
    _numberListener = () => _onFieldChanged(widget.numberController.text);
    _complementListener = () => _onFieldChanged(widget.complementController.text);
    _neighborhoodListener = () => _onFieldChanged(widget.neighborhoodController.text);
    _cityListener = () => _onFieldChanged(widget.cityController.text);

    widget.addressController.addListener(_addressListener);
    widget.numberController.addListener(_numberListener);
    widget.complementController.addListener(_complementListener);
    widget.neighborhoodController.addListener(_neighborhoodListener);
    widget.cityController.addListener(_cityListener);
  }

  void _onFieldChanged(String value) {
    widget.onChanged(value);
    widget.savePersistedData?.call();
  }

  Future<bool> _isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _fetchAddressFromCep(String cep) async {
    logToFile('Fetching address for CEP: $cep');

    // ✅ RESET DA FLAG AO BUSCAR NOVO CEP
    if (widget.pedido != null && widget.pedido!.lastCep != cep) {
      widget.pedido!.isShippingCostManuallyEdited = false;
      logToFile('CEP changed from ${widget.pedido!.lastCep} to $cep, resetting isShippingCostManuallyEdited');
    }

    if (!await _isConnected()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem conexão com a internet. Verifique sua rede.')),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cep_address_$cep';
    final cachedData = prefs.getString(cacheKey);
    final cachedTimestamp = prefs.getInt('${cacheKey}_timestamp') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (cachedData != null && (now - cachedTimestamp < cacheDuration)) {
      final data = jsonDecode(cachedData);
      setState(() {
        widget.addressController.text = data['logradouro'] ?? '';
        widget.neighborhoodController.text = data['bairro'] ?? '';
        widget.cityController.text = data['localidade'] ?? '';
        widget.complementController.text = data['complemento'] ?? '';
      });
      widget.onChanged('');
      await widget.savePersistedData?.call();
      logToFile('Address loaded from cache for CEP: $cep');
      return;
    }

    setState(() {
      _isFetchingStore = true;
    });

    const maxAttempts = 3;
    try {
      // Tenta ViaCEP primeiro
      final response = await retry(
        () => http
            .get(
              Uri.parse('https://viacep.com.br/ws/$cep/json/'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 8)),
        retryIf: (e) => e is SocketException || e is TimeoutException,
        maxAttempts: maxAttempts,
        delayFactor: const Duration(seconds: 1),
        onRetry: (e) => logToFile('Retrying ViaCEP request due to: $e'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['erro'] != true) {
          setState(() {
            widget.addressController.text = data['logradouro'] ?? '';
            widget.neighborhoodController.text = data['bairro'] ?? '';
            widget.cityController.text = data['localidade'] ?? '';
            widget.complementController.text = data['complemento'] ?? '';
          });
          await prefs.setString(
            cacheKey,
            jsonEncode({
              'logradouro': data['logradouro'] ?? '',
              'bairro': data['bairro'] ?? '',
              'localidade': data['localidade'] ?? '',
              'complemento': data['complemento'] ?? '',
            }),
          );
          await prefs.setInt('${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
          widget.onChanged('');
          await widget.savePersistedData?.call();
          logToFile(
              'Address updated from ViaCEP: logradouro=${data['logradouro']}, bairro=${data['bairro']}, cidade=${data['localidade']}');
          return;
        } else {
          throw Exception('CEP não encontrado no ViaCEP');
        }
      } else {
        throw Exception('Erro ao buscar endereço no ViaCEP: ${response.statusCode}');
      }
    } catch (e) {
      logToFile('ViaCEP failed: $e, falling back to AwesomeAPI');

      // Fallback para AwesomeAPI
      try {
        final response = await retry(
          () => http
              .get(
                Uri.parse('https://cep.awesomeapi.com.br/json/$cep'),
                headers: {'Content-Type': 'application/json'},
              )
              .timeout(const Duration(seconds: 8)),
          retryIf: (e) => e is SocketException || e is TimeoutException,
          maxAttempts: maxAttempts,
          delayFactor: const Duration(seconds: 1),
          onRetry: (e) => logToFile('Retrying AwesomeAPI request due to: $e'),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          setState(() {
            widget.addressController.text = data['address'] ?? '';
            widget.neighborhoodController.text = data['district'] ?? '';
            widget.cityController.text = data['city'] ?? '';
            widget.complementController.text = '';
          });
          await prefs.setString(
            cacheKey,
            jsonEncode({
              'logradouro': data['address'] ?? '',
              'bairro': data['district'] ?? '',
              'localidade': data['city'] ?? '',
              'complemento': '',
            }),
          );
          await prefs.setInt('${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
          widget.onChanged('');
          await widget.savePersistedData?.call();
          logToFile(
              'Address updated from AwesomeAPI: logradouro=${data['address']}, bairro=${data['district']}, cidade=${data['city']}');
        } else {
          throw Exception('Erro ao buscar endereço na AwesomeAPI: ${response.statusCode}');
        }
      } catch (e) {
        String errorMessage = 'Erro ao buscar endereço. Tente novamente.';
        if (e is SocketException) {
          errorMessage = 'Falha na conexão com a internet. Verifique sua rede.';
        } else if (e is TimeoutException) {
          errorMessage = 'Tempo de resposta excedido. Tente novamente.';
        } else if (e.toString().contains('CEP não encontrado')) {
          errorMessage = 'CEP não encontrado';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
        logToFile('AwesomeAPI exception: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingStore = false;
        });
      }
    }
  }

  void _startEditingShippingCost() {
    setState(() {
      _isEditingShippingCost = true;
      _shippingCostController.text = (widget.pedido?.shippingCost ?? widget.externalShippingCost).toStringAsFixed(2);
    });
  }

  void _saveShippingCost() {
    final newCost = double.tryParse(_shippingCostController.text.replaceAll(',', '.')) ?? 0.0;
    if (newCost >= 0) {
      widget.setStateCallback?.call();
      widget.onShippingCostUpdated(newCost);
      if (widget.pedido != null) {
        widget.pedido!.shippingCost = newCost;
        widget.pedido!.shippingCostController.text = newCost.toStringAsFixed(2);
        // ✅ MARCAR COMO EDITADO MANUALMENTE
        widget.pedido!.isShippingCostManuallyEdited = true;
      }
      widget.savePersistedData?.call();
      logToFile('Shipping cost MANUALLY edited and saved: $newCost, isManuallyEdited=true');
    }
    setState(() {
      _isEditingShippingCost = false;
    });
  }

  void _cancelEditingShippingCost() {
    setState(() {
      _isEditingShippingCost = false;
      _shippingCostController.text = widget.pedido?.shippingCostController.text ??
          widget.externalShippingCost.toStringAsFixed(2);
    });
    logToFile('Shipping cost edit cancelled, reverted to: ${_shippingCostController.text}');
  }

  void resetSection() {
    if (!mounted) return;
    setState(() {
      _isEditingShippingCost = false;
      _shippingCostController.text = '0.00';
    });
    widget.cepController.clear();
    widget.addressController.clear();
    widget.numberController.clear();
    widget.complementController.clear();
    widget.neighborhoodController.clear();
    widget.cityController.clear();
    widget.onShippingCostUpdated(0.0);
    widget.onStoreUpdated('', '');
    widget.savePersistedData?.call();
    widget.onReset?.call();
    logToFile('AddressSection reset: shippingMethod=${widget.shippingMethod}, shippingCost=0.0');
  }

  @override
  void dispose() {
    widget.addressController.removeListener(_addressListener);
    widget.numberController.removeListener(_numberListener);
    widget.complementController.removeListener(_complementListener);
    widget.neighborhoodController.removeListener(_neighborhoodListener);
    widget.cityController.removeListener(_cityListener);
    _shippingCostController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    Icon? prefixIcon,
    Widget? suffixIcon,
    bool filled = true,
    Color? fillColor,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFF28C38);

    return InputDecoration(
      labelText: labelText,
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
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: filled,
      fillColor: fillColor ?? Colors.white,
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: widget.cepController,
                  decoration: _buildInputDecoration(
                    labelText: 'CEP',
                    prefixIcon: Icon(Icons.location_on, color: primaryColor),
                    suffixIcon: _isFetchingStore
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [_cepMaskFormatter],
                  onFieldSubmitted: (value) {
                    widget.onChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    final cleanCep = widget.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
                    if (cleanCep.length != 8) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('CEP inválido. Insira 8 dígitos.')),
                        );
                      }
                      return;
                    }
                    await _fetchAddressFromCep(cleanCep);

                    if (widget.shippingMethod == 'delivery' && widget.checkStoreByCep != null) {
                      await widget.checkStoreByCep!();
                    } else if (widget.shippingMethod == 'pickup') {
                      const allowedStores = [
                        'Central Distribuição (Sagrada Família)',
                        'Unidade Barreiro',
                        'Unidade Sion',
                      ];
                      const allowedIds = ['86261', '110727', '127163'];

                      final currentStoreFinal = widget.pedido?.storeFinal ?? '';
                      final storeFinal = currentStoreFinal.isNotEmpty && allowedStores.contains(currentStoreFinal)
                          ? currentStoreFinal
                          : 'Central Distribuição (Sagrada Família)';

                      final currentStoreId = widget.pedido?.pickupStoreId ?? '';
                      final storeId = currentStoreId.isNotEmpty && allowedIds.contains(currentStoreId)
                          ? currentStoreId
                          : '86261';

                      widget.onShippingCostUpdated(0.0);
                      widget.onStoreUpdated(storeFinal, storeId);

                      if (widget.pedido != null) {
                        widget.pedido!
                          ..shippingCost = 0.0
                          ..shippingCostController.text = '0.00'
                          ..storeFinal = storeFinal
                          ..pickupStoreId = storeId;
                      }
                      await widget.savePersistedData?.call();
                    }

                    widget.onChanged(widget.cepController.text);
                    await widget.savePersistedData?.call();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor.withOpacity(0.95), primaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    alignment: Alignment.center,
                    child: _isFetchingStore
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Consultar',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.shippingMethod == 'delivery' && widget.externalShippingCost > 0) ...[
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_shipping, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Taxa de Entrega: R\$ ${widget.externalShippingCost.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: primaryColor),
                    onPressed: _isEditingShippingCost ? null : _startEditingShippingCost,
                  ),
                ],
              ),
            ),
            if (_isEditingShippingCost) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _shippingCostController,
                decoration: _buildInputDecoration(
                  labelText: 'Editar Taxa de Frete (R\$)',
                  prefixIcon: Icon(Icons.monetization_on, color: primaryColor),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cancelEditingShippingCost,
                    child: Text('Cancelar', style: TextStyle(color: primaryColor)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveShippingCost,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                    child: const Text('Salvar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ],
          if ((widget.pedido?.storeFinal ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: primaryColor,
                    width: 4,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.store,
                    color: primaryColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.shippingMethod == 'delivery'
                          ? 'Este pedido será enviado pela ${widget.pedido!.storeFinal}.'
                          : 'Retirada na loja selecionada: ${widget.pedido!.storeFinal}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.orange[300] : Colors.orange[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: widget.addressController,
                  decoration: _buildInputDecoration(
                    labelText: 'Endereço',
                    prefixIcon: Icon(Icons.home, color: primaryColor),
                  ),
                  onFieldSubmitted: _onFieldChanged,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: widget.numberController,
                  decoration: _buildInputDecoration(
                    labelText: 'Número',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onFieldSubmitted: _onFieldChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.complementController,
            decoration: _buildInputDecoration(
              labelText: 'Complemento (opcional)',
              prefixIcon: Icon(Icons.edit, color: primaryColor),
            ),
            onFieldSubmitted: _onFieldChanged,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.neighborhoodController,
            decoration: _buildInputDecoration(
              labelText: 'Bairro',
              prefixIcon: Icon(Icons.location_city, color: primaryColor),
            ),
            onFieldSubmitted: _onFieldChanged,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.cityController,
            decoration: _buildInputDecoration(
              labelText: 'Cidade',
              prefixIcon: Icon(Icons.location_city, color: primaryColor),
            ),
            onFieldSubmitted: _onFieldChanged,
          ),
        ],
      ),
    );
  }
}