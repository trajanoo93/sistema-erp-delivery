import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:erp_painel_delivery/models/pedido_state.dart';

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

  final _cepMaskFormatter = MaskTextInputFormatter(
    mask: '#####-###',
    filter: {'#': RegExp(r'[0-9]')},
    type: MaskAutoCompletionType.lazy,
  );

  @override
void initState() {
  super.initState();
  widget.cepController.addListener(_onCepChanged);
  widget.addressController.addListener(_onFieldChanged);
  widget.numberController.addListener(_onFieldChanged);
  widget.complementController.addListener(_onFieldChanged);
  widget.neighborhoodController.addListener(_onFieldChanged);
  widget.cityController.addListener(_onFieldChanged);
  _shippingCostController.text = widget.pedido?.shippingCostController.text ?? widget.externalShippingCost.toStringAsFixed(2);
}
void _onFieldChanged() {
  widget.onChanged(widget.cepController.text); // Pode usar o campo relevante
  widget.savePersistedData?.call();
}

  @override
void dispose() {
  widget.cepController.removeListener(_onCepChanged);
  widget.addressController.removeListener(_onFieldChanged);
  widget.numberController.removeListener(_onFieldChanged);
  widget.complementController.removeListener(_onFieldChanged);
  widget.neighborhoodController.removeListener(_onFieldChanged);
  widget.cityController.removeListener(_onFieldChanged);
  _debounce?.cancel();
  _shippingCostController.dispose();
  super.dispose();
}

  void _onCepChanged() {
    widget.onChanged(widget.cepController.text);
    final cleanCep = widget.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
    print('CEP alterado: $cleanCep, shippingMethod: ${widget.shippingMethod}');
    if (cleanCep.length == 8) {
      _fetchAddressFromCep(cleanCep);
      if (widget.shippingMethod == 'delivery' && widget.checkStoreByCep != null) {
        _debouncedCheckStoreByCep();
      } else if (widget.shippingMethod == 'pickup') {
        widget.onShippingCostUpdated(0.0);
        widget.onStoreUpdated('Central Distribuição (Sagrada Família)', '86261');
        setState(() {
          _storeIndication = 'Retirada na loja selecionada.';
        });
        widget.savePersistedData?.call();
      }
    } else {
      widget.onShippingCostUpdated(0.0);
      widget.onStoreUpdated('', '');
      setState(() {
        _storeIndication = null;
      });
      widget.savePersistedData?.call();
    }
  }

  void _debouncedCheckStoreByCep() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (mounted && widget.checkStoreByCep != null) {
        await widget.checkStoreByCep!();
        if (mounted) {
          final cost = widget.pedido?.shippingCost ?? 0.0;
          final storeFinal = widget.pedido?.storeFinal ?? '';
          final storeId = widget.pedido?.pickupStoreId ?? '';
          widget.onShippingCostUpdated(cost);
          widget.onStoreUpdated(storeFinal, storeId);
          setState(() {
            _storeIndication = storeFinal.isNotEmpty && widget.shippingMethod == 'delivery'
                ? (storeFinal == 'Unidade Barreiro'
                    ? 'Este pedido será enviado pela Unidade Barreiro.'
                    : storeFinal == 'Unidade Sion'
                        ? 'Este pedido será enviado pela Unidade Sion.'
                        : null)
                : widget.shippingMethod == 'pickup'
                    ? 'Retirada na loja selecionada.'
                    : null;
          });
          print('Atualizado após debounce: cost=$cost, storeFinal=$storeFinal, _storeIndication=$_storeIndication');
          widget.savePersistedData?.call();
        }
      }
    });
  }

  Future<void> _fetchAddressFromCep(String cep) async {
    print('Iniciando _fetchAddressFromCep para CEP: $cep');
    setState(() {
      _isFetchingStore = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://viacep.com.br/ws/$cep/json/'),
        headers: {'Content-Type': 'application/json'},
      );
      print('Resposta do ViaCEP: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['erro'] != true) {
          setState(() {
            widget.addressController.text = data['logradouro'] ?? '';
            widget.neighborhoodController.text = data['bairro'] ?? '';
            widget.cityController.text = data['localidade'] ?? '';
            widget.complementController.text = data['complemento'] ?? '';
          });
          widget.onChanged(widget.addressController.text);
          widget.onChanged(widget.neighborhoodController.text);
          widget.onChanged(widget.cityController.text);
          widget.onChanged(widget.complementController.text);
          widget.savePersistedData?.call();
          print('Endereço atualizado com sucesso');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CEP não encontrado')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao buscar endereço')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na requisição: $e')),
      );
      print('Erro na requisição ViaCEP: $e');
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
  }

  void resetSection() {
  if (!mounted) return;
  setState(() {
    _storeIndication = null;
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
  if (widget.pedido != null) {
    widget.pedido!.cepController.clear();
    widget.pedido!.addressController.clear();
    widget.pedido!.numberController.clear();
    widget.pedido!.complementController.clear();
    widget.pedido!.neighborhoodController.clear();
    widget.pedido!.cityController.clear();
    widget.pedido!.storeFinal = '';
    widget.pedido!.pickupStoreId = '';
  }
  widget.onReset?.call();
}

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFF28C38);

    return Padding(
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
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [_cepMaskFormatter],
            onChanged: (value) {
              _onCepChanged();
            },
            validator: null,
          ),
          if (_storeIndication != null || (widget.shippingMethod == 'delivery' && widget.externalShippingCost > 0)) ...[
            const SizedBox(height: 8),
            if (widget.shippingMethod == 'delivery' && widget.externalShippingCost > 0) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                decoration: BoxDecoration(
                  color: isDarkMode ? primaryColor.withOpacity(0.2) : Colors.orange[50],
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
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
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
                  color: isDarkMode ? primaryColor.withOpacity(0.2) : Colors.orange[50],
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
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                  ),
                  onChanged: widget.onChanged,
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
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: widget.onChanged,
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
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            onChanged: widget.onChanged,
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
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            onChanged: widget.onChanged,
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
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
            ),
            onChanged: widget.onChanged,
            validator: null,
          ),
        ],
      ),
    );
  }
}