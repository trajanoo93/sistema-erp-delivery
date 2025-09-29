
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:erp_painel_delivery/models/pedido_state.dart';
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
    Key? key,
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
  }) : super(key: key);

  @override
  State<AddressSection> createState() => _AddressSectionState();
}

class _AddressSectionState extends State<AddressSection> {
  bool _isFetchingStore = false;
  Timer? _debounce;
  String? _storeIndication;
  bool _isEditingShippingCost = false;
  double _tempShippingCost = 0.0;
  final _shippingCostController = TextEditingController();
  late VoidCallback _cepListener;
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

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _shippingCostController.text = widget.pedido?.shippingCostController.text ?? widget.externalShippingCost.toStringAsFixed(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.shippingMethod == 'pickup' && widget.pedido?.cepController.text.isNotEmpty == true) {
        resetSection();
        logToFile('Reset AddressSection due to shippingMethod change to pickup');
      }
      logToFile('AddressSection initialized: cep=${widget.cepController.text}, shippingMethod=${widget.shippingMethod}, listenerActive=${widget.cepController.hasListeners}');
    });
  }

  void _setupListeners() {
    _cepListener = () => _onCepChanged(widget.cepController.text);
    _addressListener = () => _onFieldChanged(widget.addressController.text);
    _numberListener = () => _onFieldChanged(widget.numberController.text);
    _complementListener = () => _onFieldChanged(widget.complementController.text);
    _neighborhoodListener = () => _onFieldChanged(widget.neighborhoodController.text);
    _cityListener = () => _onFieldChanged(widget.cityController.text);

    widget.cepController.addListener(_cepListener);
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

  void _onCepChanged(String cep) {
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '').trim();
    logToFile('CEP listener triggered: $cleanCep, shippingMethod: ${widget.shippingMethod}, lastCep: ${widget.pedido?.lastCep}');
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (cleanCep.length == 8 && cleanCep != widget.pedido?.lastCep) {
        widget.pedido?.lastCep = cleanCep;
        await _fetchAddressFromCep(cleanCep);
        if (widget.shippingMethod == 'delivery' && widget.checkStoreByCep != null) {
          await _debouncedCheckStoreByCep();
        } else if (widget.shippingMethod == 'pickup') {
          final storeFinal = widget.pedido?.storeFinal.isNotEmpty == true &&
                  ['Central Distribuição (Sagrada Família)', 'Unidade Barreiro', 'Unidade Sion']
                      .contains(widget.pedido?.storeFinal)
              ? widget.pedido!.storeFinal
              : 'Central Distribuição (Sagrada Família)';
          final storeId = widget.pedido?.pickupStoreId.isNotEmpty == true &&
                  ['86261', '110727', '127163'].contains(widget.pedido?.pickupStoreId)
              ? widget.pedido!.pickupStoreId
              : '86261';
          widget.onShippingCostUpdated(0.0);
          widget.onStoreUpdated(storeFinal, storeId);
          setState(() {
            _storeIndication = 'Retirada na loja selecionada: $storeFinal';
          });
          if (widget.pedido != null) {
            widget.pedido!.shippingCost = 0.0;
            widget.pedido!.shippingCostController.text = '0.00';
            widget.pedido!.storeFinal = storeFinal;
            widget.pedido!.pickupStoreId = storeId;
          }
          await widget.savePersistedData?.call();
          logToFile('Pickup mode in _onCepChanged: storeFinal=$storeFinal, pickupStoreId=$storeId, shippingCost=0.0');
        }
      } else if (cleanCep.length != 8) {
        widget.onShippingCostUpdated(0.0);
        widget.onStoreUpdated('', '');
        setState(() {
          _storeIndication = null;
        });
        if (widget.pedido != null) {
          widget.pedido!.shippingCost = 0.0;
          widget.pedido!.shippingCostController.text = '0.00';
          widget.pedido!.storeFinal = '';
          widget.pedido!.pickupStoreId = '';
        }
        await widget.savePersistedData?.call();
        logToFile('CEP inválido ou vazio: reset shippingCost=0.0, storeFinal="", pickupStoreId=""');
      }
    });
  }

  @override
  void dispose() {
    widget.cepController.removeListener(_cepListener);
    widget.addressController.removeListener(_addressListener);
    widget.numberController.removeListener(_numberListener);
    widget.complementController.removeListener(_complementListener);
    widget.neighborhoodController.removeListener(_neighborhoodListener);
    widget.cityController.removeListener(_cityListener);
    _debounce?.cancel();
    _shippingCostController.dispose();
    super.dispose();
  }

  Future<void> _debouncedCheckStoreByCep() async {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      if (mounted && widget.checkStoreByCep != null) {
        await widget.checkStoreByCep!();
        if (mounted) {
          final cost = widget.shippingMethod == 'pickup' ? 0.0 : (widget.pedido?.shippingCost ?? 0.0);
          final storeFinal = widget.shippingMethod == 'pickup'
              ? (widget.pedido?.storeFinal.isNotEmpty == true &&
                      ['Central Distribuição (Sagrada Família)', 'Unidade Barreiro', 'Unidade Sion']
                          .contains(widget.pedido?.storeFinal)
                  ? widget.pedido!.storeFinal
                  : 'Central Distribuição (Sagrada Família)')
              : (widget.pedido?.storeFinal ?? '');
          final storeId = widget.shippingMethod == 'pickup'
              ? (widget.pedido?.pickupStoreId.isNotEmpty == true &&
                      ['86261', '110727', '127163'].contains(widget.pedido?.pickupStoreId)
                  ? widget.pedido!.pickupStoreId
                  : '86261')
              : (widget.pedido?.pickupStoreId ?? '');
          widget.onShippingCostUpdated(cost);
          widget.onStoreUpdated(storeFinal, storeId);
          if (widget.pedido != null) {
            widget.pedido!.shippingCost = cost;
            widget.pedido!.shippingCostController.text = cost.toStringAsFixed(2);
            widget.pedido!.storeFinal = storeFinal;
            widget.pedido!.pickupStoreId = storeId;
          }
          setState(() {
            _storeIndication = storeFinal.isNotEmpty && widget.shippingMethod == 'delivery'
                ? (storeFinal == 'Unidade Barreiro'
                    ? 'Este pedido será enviado pela Unidade Barreiro.'
                    : storeFinal == 'Unidade Sion'
                        ? 'Este pedido será enviado pela Unidade Sion.'
                        : null)
                : widget.shippingMethod == 'pickup'
                    ? 'Retirada na loja selecionada: $storeFinal'
                    : null;
          });
          print('Atualizado após debounce: cost=$cost, storeFinal=$storeFinal, storeId=$storeId, _storeIndication=$_storeIndication');
          await widget.savePersistedData?.call();
          logToFile(
              'Debounced checkStoreByCep: shippingMethod=${widget.shippingMethod}, '
              'cost=$cost, storeFinal=$storeFinal, storeId=$storeId, _storeIndication=$_storeIndication');
        }
      }
    });
  }

  Future<void> _fetchAddressFromCep(String cep) async {
    print('Iniciando _fetchAddressFromCep para CEP: $cep');
    logToFile('Fetching address from ViaCEP for CEP: $cep');
    setState(() {
      _isFetchingStore = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
        headers: {'Content-Type': 'application/json'},
      );
      logToFile('ViaCEP response: status=${response.statusCode}, body=${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['erro'] != true) {
          setState(() {
            widget.addressController.text = data['logradouro'] ?? '';
            widget.neighborhoodController.text = data['bairro'] ?? '';
            widget.cityController.text = data['localidade'] ?? '';
            widget.complementController.text = data['complemento'] ?? '';
          });
          widget.onChanged('');
          widget.savePersistedData?.call();
          logToFile('Address updated: logradouro=${data['logradouro']}, bairro=${data['bairro']}, cidade=${data['localidade']}');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CEP não encontrado')),
          );
          logToFile('ViaCEP error: CEP not found for $cep');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao buscar endereço')),
        );
        logToFile('ViaCEP error: status=${response.statusCode}, body=${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na requisição: $e')),
      );
      logToFile('ViaCEP exception: $e');
    } finally {
      setState(() {
        _isFetchingStore = false;
      });
    }
  }

  void _startEditingShippingCost() {
    setState(() {
      _isEditingShippingCost = true;
      _tempShippingCost = widget.pedido?.shippingCost ?? widget.externalShippingCost;
      _shippingCostController.text = _tempShippingCost.toStringAsFixed(2);
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
      }
      widget.savePersistedData?.call();
      logToFile('Shipping cost saved: $newCost');
    }
    setState(() {
      _isEditingShippingCost = false;
    });
  }

  void _cancelEditingShippingCost() {
    setState(() {
      _isEditingShippingCost = false;
      _shippingCostController.text = widget.pedido?.shippingCostController.text ?? widget.externalShippingCost.toStringAsFixed(2);
    });
    logToFile('Shipping cost edit cancelled, reverted to: ${_shippingCostController.text}');
  }

  void resetSection() {
    if (!mounted) return;
    setState(() {
      _storeIndication = null;
      _isEditingShippingCost = false;
      _shippingCostController.text = '0.00';
      _debounce?.cancel();
      _debounce = null;
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
    logToFile(
        'AddressSection reset: shippingMethod=${widget.shippingMethod}, '
        'storeFinal=${widget.pedido?.storeFinal}, pickupStoreId=${widget.pedido?.pickupStoreId}, '
        'shippingCost=${widget.pedido?.shippingCost}');
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
          TextFormField(
            controller: widget.cepController,
            decoration: InputDecoration(
              labelText: 'CEP',
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
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [_cepMaskFormatter],
            onFieldSubmitted: (value) {
              _onCepChanged(value);
              widget.onChanged(value);
            },
            validator: null,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _onCepChanged(widget.cepController.text);
                widget.onChanged(widget.cepController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Consultar CEP',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_storeIndication != null || (widget.shippingMethod == 'delivery' && widget.externalShippingCost > 0)) ...[
            const SizedBox(height: 8),
            if (widget.shippingMethod == 'delivery' && widget.externalShippingCost > 0) ...[
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
                  decoration: InputDecoration(
                    labelText: 'Editar Taxa de Frete (R\$)',
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
                    prefixIcon: Icon(Icons.monetization_on, color: primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    setState(() {
                      _tempShippingCost = double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
                    });
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
                      child: Text('Salvar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ],
            if (_storeIndication != null) ...[
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
                        _storeIndication!,
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
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: widget.addressController,
                  decoration: InputDecoration(
                    labelText: 'Endereço',
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
                    prefixIcon: Icon(Icons.home, color: primaryColor),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onFieldSubmitted: _onFieldChanged,
                  validator: null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: widget.numberController,
                  decoration: InputDecoration(
                    labelText: 'Número',
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
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onFieldSubmitted: _onFieldChanged,
                  validator: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.complementController,
            decoration: InputDecoration(
              labelText: 'Complemento (opcional)',
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
              prefixIcon: Icon(Icons.edit, color: primaryColor),
              filled: true,
              fillColor: Colors.white,
            ),
            onFieldSubmitted: _onFieldChanged,
            validator: null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.neighborhoodController,
            decoration: InputDecoration(
              labelText: 'Bairro',
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
              prefixIcon: Icon(Icons.location_city, color: primaryColor),
              filled: true,
              fillColor: Colors.white,
            ),
            onFieldSubmitted: _onFieldChanged,
            validator: null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.cityController,
            decoration: InputDecoration(
              labelText: 'Cidade',
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
              prefixIcon: Icon(Icons.location_city, color: primaryColor),
              filled: true,
              fillColor: Colors.white,
            ),
            onFieldSubmitted: _onFieldChanged,
            validator: null,
          ),
        ],
      ),
    );
  }
}