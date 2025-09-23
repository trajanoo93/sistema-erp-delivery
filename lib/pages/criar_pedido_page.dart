
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:erp_painel_delivery/models/pedido_state.dart';
import 'package:erp_painel_delivery/widgets/customer_section.dart';
import 'package:erp_painel_delivery/widgets/product_section.dart';
import 'package:erp_painel_delivery/widgets/shipping_section.dart';
import 'package:erp_painel_delivery/widgets/address_section.dart';
import 'package:erp_painel_delivery/widgets/scheduling_section.dart';
import 'package:erp_painel_delivery/widgets/summary_section.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/log_utils.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:erp_painel_delivery/criar_pedido_service.dart';
import 'package:erp_painel_delivery/product_selection_dialog.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/scheduler.dart';
import 'package:path_provider/path_provider.dart';

// Garante sempre um intervalo "HH:mm - HH:mm" a partir de "HH:mm"
String ensureTimeRange(String time) {
  final t = time.trim();
  if (t.isEmpty) return '09:00 - 12:00';
  if (t.contains(' - ')) return t;
  final parts = t.split(':');
  if (parts.length != 2) return '09:00 - 12:00';
  final hour = int.tryParse(parts[0]) ?? 0;
  final min = int.tryParse(parts[1]) ?? 0;
  final endHour = (hour + 3).clamp(0, 23); // Ajustado para janelas de 3 horas
  final start = '${hour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  final end = '${endHour.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
  return '$start - $end';
}

// Normaliza data para YYYY-MM-DD
String normalizeYmd(String dateStr) {
  final s = dateStr.trim();
  if (s.isEmpty) return DateFormat('yyyy-MM-dd').format(DateTime.now());
  try {
    DateTime d;
    try {
      d = DateFormat('yyyy-MM-dd').parseStrict(s);
    } catch (_) {
      try {
        d = DateFormat('dd/MM/yyyy').parseStrict(s);
      } catch (_) {
        d = DateFormat('MMMM d, yyyy', 'en_US').parseStrict(s);
      }
    }
    return DateFormat('yyyy-MM-dd').format(d);
  } catch (_) {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}

class StoreNormalize {
  static String getId(String name) {
    switch (name) {
      case "Central Distribuição (Sagrada Família)":
        return "86261";
      case "Unidade Sion":
        return "127163";
      case "Unidade Barreiro":
        return "110727";
      default:
        return "86261";
    }
  }

  static String getName(String id) {
    switch (id) {
      case "86261":
        return "Central Distribuição (Sagrada Família)";
      case "127163":
        return "Unidade Sion";
      case "110727":
        return "Unidade Barreiro";
      default:
        return "Central Distribuição (Sagrada Família)";
    }
  }

  static String getProxyUnit(String name) {
    switch (name) {
      case "Central Distribuição (Sagrada Família)":
        return "Unidade Central";
      case "Unidade Sion":
        return "Unidade Sion";
      case "Unidade Barreiro":
        return "Unidade Barreiro";
      default:
        return "Unidade Central";
    }
  }
}

class CriarPedidoPage extends StatefulWidget {
  const CriarPedidoPage({Key? key}) : super(key: key);

  @override
  State<CriarPedidoPage> createState() => _CriarPedidoPageState();
}

class _CriarPedidoPageState extends State<CriarPedidoPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final List<PedidoState> _pedidos = [];
  int _currentTabIndex = 0;
  bool _isLoading = false;
  bool _isAddingTab = false;
  String? _resultMessage;
  Timer? _debounce;
  bool _isInitialized = false;

  static const List<String> _validPaymentMethods = [
    'Pix',
    'Cartão de Crédito On-line',
    'Pagamento no Dinheiro',
    'Dinheiro',
    'Dinheiro na Entrega',
    'Cartão na Entrega',
    'Cartão de Débito ou Crédito',
    'Vale Alimentação',
    'Vale Alimentação - VA',
  ];

  String _normalizeLabel(String s) {
    final lower = s.toLowerCase().trim();
    return lower
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

String _paymentSlugFromLabel(String uiLabel) {
  final n = _normalizeLabel(uiLabel);
  final currentPedido = _pedidos[_currentTabIndex];
  if (n.contains('pix')) return 'pagarme_custom_pix';
  if (n.contains('cartao de credito on-line') ||
      n.contains('cartao de credito online') ||
      n == 'cartao de credito' ||
      n.contains('stripe')) {
    return currentPedido.paymentAccounts['stripe'] ?? 'stripe';
  }
  if (n.contains('dinheiro')) {
    return 'cod';
  }
  if (n.contains('cartao na entrega') ||
      n.contains('cartao de debito ou credito') ||
      n.contains('maquininha') ||
      n.contains('pos')) {
    return 'custom_729b8aa9fc227ff';
  }
  if (n.contains('vale alimentacao') || n == 'va') {
    return 'custom_e876f567c151864';
  }
  return 'cod';
}

  Future<void> logToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_logs.txt');
      await file.writeAsString('${DateTime.now()} - $message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Falha ao escrever log: $e');
    }
  }

  Future<void> _savePersistedData(PedidoState pedido) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _pedidos.indexOf(pedido);
    if (index >= 0) {
      await prefs.setString('phone_$index', pedido.phoneController.text);
      await prefs.setString('name_$index', pedido.nameController.text);
      await prefs.setString('email_$index', pedido.emailController.text);
      await prefs.setString('cep_$index', pedido.cepController.text);
      await prefs.setString('address_$index', pedido.addressController.text);
      await prefs.setString('number_$index', pedido.numberController.text);
      await prefs.setString('complement_$index', pedido.complementController.text);
      await prefs.setString('neighborhood_$index', pedido.neighborhoodController.text);
      await prefs.setString('city_$index', pedido.cityController.text);
      await prefs.setString('notes_$index', pedido.notesController.text);
      await prefs.setString('coupon_$index', pedido.couponController.text);
      await prefs.setString('products_$index', jsonEncode(pedido.products));
      await prefs.setString('shippingMethod_$index', pedido.shippingMethod);
      await prefs.setString('paymentMethod_$index', pedido.selectedPaymentMethod);
      await prefs.setString('availablePaymentMethods_$index', jsonEncode(pedido.availablePaymentMethods));
      await prefs.setString('paymentAccounts_$index', jsonEncode(pedido.paymentAccounts));
      await prefs.setDouble('shippingCost_$index', pedido.shippingCost);
      await prefs.setString('storeFinal_$index', pedido.storeFinal);
      await prefs.setString('pickupStoreId_$index', pedido.pickupStoreId);
      await prefs.setBool('showNotesField_$index', pedido.showNotesField);
      await prefs.setBool('showCouponField_$index', pedido.showCouponField);
      await prefs.setString('schedulingDate_$index', pedido.schedulingDate);
      await prefs.setString('schedulingTime_$index', pedido.schedulingTime);
      await prefs.setBool('isCustomerSectionExpanded_$index', pedido.isCustomerSectionExpanded);
      await prefs.setBool('isAddressSectionExpanded_$index', pedido.isAddressSectionExpanded);
      await prefs.setBool('isProductsSectionExpanded_$index', pedido.isProductsSectionExpanded);
      await prefs.setBool('isShippingSectionExpanded_$index', pedido.isShippingSectionExpanded);
      await _savePedidos();
    }
  }

  @override
  void initState() {
    super.initState();
    logToFile('Teste de log no initState de CriarPedidoPage');
    _initializePedidos();
    _tabController = TabController(length: _pedidos.length, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  Future<void> _initializePedidos() async {
    await _restorePedidos();
    if (mounted) {
      setState(() {
        _isInitialized = true;
        _tabController = TabController(length: _pedidos.length, vsync: this);
        _tabController.addListener(_handleTabSelection);
      });
    }
  }

  @override
  void dispose() {
    _savePedidos();
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _debounce?.cancel();
    for (var pedido in _pedidos) {
      pedido.nameController.removeListener(_updateTabs);
      pedido.dispose();
    }
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.index != _currentTabIndex && mounted) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  void _updateTabs() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _restorePedidos() async {
    final prefs = await SharedPreferences.getInstance();
    final pedidosJson = prefs.getStringList('pedidos') ?? ['{}'];
    for (var json in pedidosJson) {
      final pedidoData = jsonDecode(json) as Map<String, dynamic>;
      final pedido = PedidoState.fromJson(pedidoData);
      final pedidoWithCallback = PedidoState(onCouponValidated: _onCouponValidated);
      pedidoWithCallback.phoneController.text = pedido.phoneController.text;
      pedidoWithCallback.nameController.text = pedido.nameController.text;
      pedidoWithCallback.emailController.text = pedido.emailController.text;
      pedidoWithCallback.cepController.text = pedido.cepController.text;
      pedidoWithCallback.addressController.text = pedido.addressController.text;
      pedidoWithCallback.numberController.text = pedido.numberController.text;
      pedidoWithCallback.complementController.text = pedido.complementController.text;
      pedidoWithCallback.neighborhoodController.text = pedido.neighborhoodController.text;
      pedidoWithCallback.cityController.text = pedido.cityController.text;
      pedidoWithCallback.notesController.text = pedido.notesController.text;
      pedidoWithCallback.couponController.text = pedido.couponController.text;
      pedidoWithCallback.shippingCostController.text = pedido.shippingCostController.text;
      pedidoWithCallback.products = List<Map<String, dynamic>>.from(pedido.products);
      pedidoWithCallback.shippingMethod = pedido.shippingMethod;
      pedidoWithCallback.selectedVendedor = pedido.selectedVendedor;
      pedidoWithCallback.shippingCost = pedido.shippingCost;
      pedidoWithCallback.storeFinal = pedido.storeFinal;
      pedidoWithCallback.pickupStoreId = pedido.pickupStoreId;
      pedidoWithCallback.selectedPaymentMethod = _validPaymentMethods.contains(pedido.selectedPaymentMethod)
          ? pedido.selectedPaymentMethod
          : '';
      pedidoWithCallback.availablePaymentMethods = List<Map<String, String>>.from(pedido.availablePaymentMethods);
      pedidoWithCallback.paymentAccounts = Map<String, String>.from(pedido.paymentAccounts);
      pedidoWithCallback.showNotesField = pedido.showNotesField;
      pedidoWithCallback.showCouponField = pedido.showCouponField;
      pedidoWithCallback.schedulingDate = normalizeYmd(pedido.schedulingDate.isEmpty
          ? DateFormat('yyyy-MM-dd').format(DateTime.now())
          : pedido.schedulingDate);
      final isSunday = DateTime.now().weekday == DateTime.sunday;
      final defaultTimeSlot = pedido.shippingMethod == 'pickup' && isSunday
          ? '09:00 - 12:00'
          : '14:00 - 17:00';
      pedidoWithCallback.schedulingTime = ensureTimeRange(
          pedido.schedulingTime.isEmpty ? defaultTimeSlot : pedido.schedulingTime);
      pedidoWithCallback.isCustomerSectionExpanded = pedido.isCustomerSectionExpanded;
      pedidoWithCallback.isAddressSectionExpanded = pedido.isAddressSectionExpanded;
      pedidoWithCallback.isProductsSectionExpanded = pedido.isProductsSectionExpanded;
      pedidoWithCallback.isShippingSectionExpanded = pedido.isShippingSectionExpanded;
      pedidoWithCallback.paymentInstructions = pedido.paymentInstructions;
      pedidoWithCallback.couponErrorMessage = pedido.couponErrorMessage;
      pedidoWithCallback.discountAmount = pedido.discountAmount;
      pedidoWithCallback.isCouponValid = pedido.isCouponValid;
      pedidoWithCallback.storeIndication = pedido.storeIndication;
      pedidoWithCallback.isFetchingStore = pedido.isFetchingStore;
      pedidoWithCallback.lastPhoneNumber = pedido.lastPhoneNumber;
      pedidoWithCallback.nameController.addListener(_updateTabs);
      _pedidos.add(pedidoWithCallback);
    }
    if (_pedidos.isEmpty) {
      final newPedido = PedidoState(onCouponValidated: _onCouponValidated);
      newPedido.nameController.addListener(_updateTabs);
      newPedido.schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      newPedido.schedulingTime = '09:00 - 12:00';
      newPedido.shippingMethod = 'delivery';
      _pedidos.add(newPedido);
    }
  }

  Future<void> _savePedidos() async {
    final prefs = await SharedPreferences.getInstance();
    final pedidosJson = _pedidos.map((pedido) => jsonEncode(pedido.toJson())).toList();
    await prefs.setStringList('pedidos', pedidosJson);
  }

  Future<void> _loadPersistedData(PedidoState pedido) async {
    final prefs = await SharedPreferences.getInstance();
    final index = _pedidos.indexOf(pedido);
    if (index >= 0 && prefs.getString('phone_$index') == null) {
      pedido.phoneController.text = '';
      pedido.nameController.text = '';
      pedido.emailController.text = '';
      pedido.cepController.text = '';
      pedido.addressController.text = '';
      pedido.numberController.text = '';
      pedido.complementController.text = '';
      pedido.neighborhoodController.text = '';
      pedido.cityController.text = '';
      pedido.notesController.text = '';
      pedido.couponController.text = '';
      pedido.products = [];
      pedido.shippingMethod = '';
      pedido.selectedPaymentMethod = '';
      pedido.availablePaymentMethods = [];
      pedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
      pedido.shippingCost = 0.0;
      pedido.shippingCostController.text = '0.00';
      pedido.storeFinal = '';
      pedido.pickupStoreId = '';
      pedido.showNotesField = false;
      pedido.showCouponField = false;
      pedido.schedulingDate = '';
      pedido.schedulingTime = '';
      pedido.isCustomerSectionExpanded = true;
      pedido.isAddressSectionExpanded = true;
      pedido.isProductsSectionExpanded = true;
      pedido.isShippingSectionExpanded = true;
      return;
    }
    pedido.phoneController.text = prefs.getString('phone_$index') ?? '';
    pedido.nameController.text = prefs.getString('name_$index') ?? '';
    pedido.emailController.text = prefs.getString('email_$index') ?? '';
    pedido.cepController.text = prefs.getString('cep_$index') ?? '';
    pedido.addressController.text = prefs.getString('address_$index') ?? '';
    pedido.numberController.text = prefs.getString('number_$index') ?? '';
    pedido.complementController.text = prefs.getString('complement_$index') ?? '';
    pedido.neighborhoodController.text = prefs.getString('neighborhood_$index') ?? '';
    pedido.cityController.text = prefs.getString('city_$index') ?? '';
    pedido.notesController.text = prefs.getString('notes_$index') ?? '';
    pedido.couponController.text = prefs.getString('coupon_$index') ?? '';
    pedido.products = (jsonDecode(prefs.getString('products_$index') ?? '[]') as List)
        .cast<Map<String, dynamic>>();
    pedido.shippingMethod = prefs.getString('shippingMethod_$index') ?? '';
    String? savedPaymentMethod = prefs.getString('paymentMethod_$index');
    pedido.selectedPaymentMethod = _validPaymentMethods.contains(savedPaymentMethod)
        ? savedPaymentMethod ?? ''
        : '';
    pedido.availablePaymentMethods = List<Map<String, String>>.from(
        jsonDecode(prefs.getString('availablePaymentMethods_$index') ?? '[]'));
    pedido.paymentAccounts = Map<String, String>.from(
        jsonDecode(prefs.getString('paymentAccounts_$index') ?? '{"stripe":"stripe","pagarme":"central"}'));
    pedido.shippingCost = (pedido.shippingMethod == 'pickup')
        ? 0.0
        : prefs.getDouble('shippingCost_$index') ?? 0.0;
    pedido.shippingCostController.text = pedido.shippingCost.toStringAsFixed(2);
    pedido.storeFinal = prefs.getString('storeFinal_$index') ?? '';
    pedido.pickupStoreId = prefs.getString('pickupStoreId_$index') ?? '';
    pedido.showNotesField = prefs.getBool('showNotesField_$index') ?? false;
    pedido.showCouponField = prefs.getBool('showCouponField_$index') ?? false;
    pedido.schedulingDate = prefs.getString('schedulingDate_$index') ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    pedido.schedulingTime = ensureTimeRange(prefs.getString('schedulingTime_$index') ?? '09:00 - 12:00');
    pedido.isCustomerSectionExpanded = prefs.getBool('isCustomerSectionExpanded_$index') ?? true;
    pedido.isAddressSectionExpanded = prefs.getBool('isAddressSectionExpanded_$index') ?? true;
    pedido.isProductsSectionExpanded = prefs.getBool('isProductsSectionExpanded_$index') ?? true;
    pedido.isShippingSectionExpanded = prefs.getBool('isShippingSectionExpanded_$index') ?? true;
  }

  Future<void> _addNewPedido() async {
    if (_isAddingTab) return;
    setState(() {
      _isAddingTab = true;
    });
    try {
      final newPedido = PedidoState(onCouponValidated: _onCouponValidated);
      newPedido.schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      newPedido.schedulingTime = '09:00 - 12:00';
      newPedido.shippingMethod = 'delivery';
      newPedido.nameController.addListener(_updateTabs);
      await _loadPersistedData(newPedido);
      await logToFile('Novo pedido criado: shippingMethod=${newPedido.shippingMethod}, selectedPaymentMethod=${newPedido.selectedPaymentMethod}');
      setState(() {
        _pedidos.add(newPedido);
        _currentTabIndex = _pedidos.length - 1;
        _tabController.dispose();
        _tabController = TabController(
          length: _pedidos.length,
          vsync: this,
          initialIndex: _currentTabIndex,
        );
        _tabController.addListener(_handleTabSelection);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar novo pedido: $e')),
      );
    } finally {
      setState(() {
        _isAddingTab = false;
      });
    }
  }

  void _removeCurrentPedido() {
    if (_pedidos.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não é possível remover o último pedido')),
      );
      return;
    }
    setState(() {
      _pedidos[_currentTabIndex].nameController.removeListener(_updateTabs);
      _pedidos[_currentTabIndex].dispose();
      _pedidos.removeAt(_currentTabIndex);
      _currentTabIndex = _currentTabIndex.clamp(0, _pedidos.length - 1);
      _tabController.dispose();
      _tabController = TabController(
        length: _pedidos.length,
        vsync: this,
        initialIndex: _currentTabIndex,
      );
      _tabController.addListener(_handleTabSelection);
    });
  }

  Future<void> _fetchCustomer() async {
  if (_debounce?.isActive ?? false) return; // Evita chamadas repetidas
  _debounce = Timer(const Duration(milliseconds: 500), () async {
    await logToFile('Iniciando _fetchCustomer');
    final currentPedido = _pedidos[_currentTabIndex];
    final phone = currentPedido.phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
    await logToFile('Phone: ${currentPedido.phoneController.text}, Cleaned: $phone, isPhoneValid: ${phone.length == 11}');
    if (phone.length != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um número de telefone válido (11 dígitos com DDD)')),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final service = CriarPedidoService();
      final customer = await service.fetchCustomerByPhone(phone);
      if (customer != null && mounted) {
        setState(() {
          currentPedido.nameController.text = customer['first_name'] + ' ' + (customer['last_name'] ?? '');
          currentPedido.emailController.text = customer['email'] ?? '';
          currentPedido.cepController.text = customer['billing']['postcode'] ?? '';
          currentPedido.addressController.text = customer['billing']['address_1'] ?? '';
          currentPedido.numberController.text = customer['billing']['number'] ?? '';
          currentPedido.complementController.text = customer['billing']['address_2'] ?? '';
          currentPedido.neighborhoodController.text = customer['billing']['neighborhood'] ?? '';
          currentPedido.cityController.text = customer['billing']['city'] ?? '';
        });
        await _savePersistedData(currentPedido);
        final cleanCep = currentPedido.cepController.text.replaceAll(RegExp(r'\D'), '');
        if (cleanCep.length == 8 && cleanCep != currentPedido.lastCep) {
          currentPedido.lastCep = cleanCep; // Armazena o último CEP verificado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _checkStoreByCep();
            }
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente não encontrado. Preencha os dados manualmente.')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar cliente: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  });
}

Future<void> _checkStoreByCep() async {
  final currentPedido = _pedidos[_currentTabIndex];
  final cep = currentPedido.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
  await logToFile('Checking CEP: $cep, shippingMethod: ${currentPedido.shippingMethod}, scheduling: ${currentPedido.schedulingDate}/${currentPedido.schedulingTime}');
  if (cep.length != 8 && currentPedido.shippingMethod != 'pickup') {
    await logToFile('CEP is incomplete, resetting store and cost.');
    setState(() {
      currentPedido.shippingCost = 0.0;
      currentPedido.shippingCostController.text = '0.00';
      currentPedido.storeFinal = '';
      currentPedido.pickupStoreId = '';
      currentPedido.availablePaymentMethods = [];
      currentPedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
    });
    await _savePersistedData(currentPedido);
    return;
  }
  setState(() => _isLoading = true);
  try {
    final normalizedDate = normalizeYmd(currentPedido.schedulingDate);
    final requestBody = {
      'cep': cep,
      'shipping_method': currentPedido.shippingMethod,
      'pickup_store': currentPedido.shippingMethod == 'pickup' ? currentPedido.storeFinal : '',
      'delivery_date': currentPedido.shippingMethod == 'delivery' ? normalizedDate : '',
      'pickup_date': currentPedido.shippingMethod == 'pickup' ? normalizedDate : '',
    };
    await logToFile('Sending request to store-decision endpoint: ${jsonEncode(requestBody)}');
    final storeResponse = await http.post(
      Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/store-decision'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(Duration(seconds: 15), onTimeout: () {
      throw Exception('Timeout ao buscar opções de entrega');
    });
    await logToFile('Store decision response status: ${storeResponse.statusCode}, body: ${storeResponse.body}');
    double shippingCost = 0.0;
    if (currentPedido.shippingMethod == 'delivery') {
      await logToFile('Fetching shipping cost for CEP: $cep');
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
        } else {
          await logToFile('Nenhuma opção de frete válida retornada para CEP: $cep');
          shippingCost = 0.0;
        }
      } else {
        throw Exception('Erro ao buscar custo de frete: ${costResponse.statusCode} - ${costResponse.body}');
      }
    }
    if (storeResponse.statusCode == 200) {
      final data = jsonDecode(storeResponse.body);
      final newStoreFinal = data['effective_store_final']?.toString() ?? data['store_final']?.toString();
      if (newStoreFinal == null) {
        throw Exception('Nenhuma loja válida retornada pelo endpoint store-decision.');
      }
      if (newStoreFinal != currentPedido.storeFinal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loja ajustada para $newStoreFinal devido ao horário')),
        );
      }
      setState(() {
        currentPedido.storeFinal = newStoreFinal;
        currentPedido.pickupStoreId = data['pickup_store_id']?.toString() ?? StoreNormalize.getId(newStoreFinal);
        currentPedido.shippingCost = shippingCost;
        currentPedido.shippingCostController.text = shippingCost.toStringAsFixed(2);
        final rawPaymentMethods = List<Map>.from(data['payment_methods'] ?? []);
        currentPedido.availablePaymentMethods = [];
        final seenTitles = <String>{};
        for (var m in rawPaymentMethods) {
          final id = m['id']?.toString() ?? '';
          final title = m['title']?.toString() ?? '';
          if (id == 'woo_payment_on_delivery' && !seenTitles.contains('Dinheiro na Entrega')) {
            currentPedido.availablePaymentMethods.add({'id': 'cod', 'title': 'Dinheiro na Entrega'});
            seenTitles.add('Dinheiro na Entrega');
          } else if ((id == 'stripe' || id == 'stripe_cc' || id == 'eh_stripe_pay') && !seenTitles.contains('Cartão de Crédito On-line')) {
            currentPedido.availablePaymentMethods.add({
              'id': data['payment_accounts']['stripe'] ?? 'stripe',
              'title': 'Cartão de Crédito On-line'
            });
            seenTitles.add('Cartão de Crédito On-line');
          } else if (!seenTitles.contains(title)) {
            currentPedido.availablePaymentMethods.add({'id': id, 'title': title});
            seenTitles.add(title);
          }
        }
        final paymentAccounts = data['payment_accounts'] as Map?;
        currentPedido.paymentAccounts = paymentAccounts != null
            ? paymentAccounts.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
            : {
                'stripe': newStoreFinal == 'Unidade Barreiro' ? 'stripe_cc' : newStoreFinal == 'Unidade Sion' ? 'eh_stripe_pay' : 'stripe',
                'pagarme': newStoreFinal == 'Unidade Barreiro' ? 'barreiro' : newStoreFinal == 'Unidade Sion' ? 'sion' : 'central'
              };
        if (currentPedido.selectedPaymentMethod.isNotEmpty &&
            !currentPedido.availablePaymentMethods.any((m) => m['title'] == currentPedido.selectedPaymentMethod)) {
          currentPedido.selectedPaymentMethod = currentPedido.availablePaymentMethods.isNotEmpty
              ? currentPedido.availablePaymentMethods.first['title'] ?? ''
              : '';
        }
      });
      await _savePersistedData(currentPedido);
    } else {
      throw Exception('Erro ao buscar opções de entrega: ${storeResponse.statusCode} - ${storeResponse.body}');
    }
  } catch (e, stackTrace) {
    await logToFile('Exceção em _checkStoreByCep: $e, StackTrace: $stackTrace');
    setState(() {
      currentPedido.storeFinal = 'Central Distribuição (Sagrada Família)';
      currentPedido.pickupStoreId = '86261';
      currentPedido.shippingCost = 0.0;
      currentPedido.shippingCostController.text = '0.00';
      currentPedido.availablePaymentMethods = [
        {'id': 'pagarme_custom_pix', 'title': 'Pix'},
        {'id': 'stripe', 'title': 'Cartão de Crédito On-line'},
        {'id': 'cod', 'title': 'Dinheiro na Entrega'},
        {'id': 'custom_729b8aa9fc227ff', 'title': 'Cartão na Entrega'},
        {'id': 'custom_e876f567c151864', 'title': 'Vale Alimentação'},
      ];
      currentPedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
      if (currentPedido.selectedPaymentMethod.isNotEmpty &&
          !currentPedido.availablePaymentMethods.any((m) => m['title'] == currentPedido.selectedPaymentMethod)) {
        currentPedido.selectedPaymentMethod = currentPedido.availablePaymentMethods.isNotEmpty
            ? currentPedido.availablePaymentMethods.first['title'] ?? ''
            : '';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Não foi possível identificar a loja para o CEP. Usando Central Distribuição como padrão.')),
    );
  } finally {
    setState(() => _isLoading = false);
    await _savePersistedData(currentPedido);
  }
}


  Future<void> _createOrder() async {
  final currentPedido = _pedidos[_currentTabIndex];
  final errors = <String>[];
  final normalizedDate = normalizeYmd(currentPedido.schedulingDate);
  final normalizedTime = ensureTimeRange(currentPedido.schedulingTime);
  final phone = currentPedido.phoneController.text.replaceAll(RegExp(r'\D'), '').trim();
  if (phone.length != 11) {
    errors.add('Insira um número de telefone válido (11 dígitos com DDD)');
    await logToFile('Erro de validação - Telefone: $phone, Cleaned: ${phone.replaceAll(RegExp(r'\D'), '')}, isPhoneValid: false');
  }
  if (currentPedido.nameController.text.isEmpty) errors.add('O nome do cliente é obrigatório');
  if (currentPedido.selectedVendedor.isEmpty) errors.add('Selecione um vendedor');
  if (currentPedido.shippingMethod == 'delivery' && currentPedido.cepController.text.replaceAll(RegExp(r'\D'), '').length != 8) {
    errors.add('Digite um CEP válido (8 dígitos) para entrega');
  }
  if (currentPedido.shippingMethod == 'delivery' && currentPedido.addressController.text.isEmpty) {
    errors.add('O endereço é obrigatório para entrega');
  }
  if (currentPedido.shippingMethod == 'delivery' && currentPedido.numberController.text.isEmpty) {
    errors.add('O número do endereço é obrigatório para entrega');
  }
  if (currentPedido.shippingMethod == 'delivery' && currentPedido.neighborhoodController.text.isEmpty) {
    errors.add('O bairro é obrigatório para entrega');
  }
  if (currentPedido.shippingMethod == 'delivery' && currentPedido.cityController.text.isEmpty) {
    errors.add('A cidade é obrigatória para entrega');
  }
  if (currentPedido.shippingMethod == 'pickup' && currentPedido.pickupStoreId.isEmpty) {
    errors.add('Selecione uma loja para retirada');
  }
  if (currentPedido.products.isEmpty) errors.add('Adicione pelo menos um produto ao pedido');
  if (currentPedido.shippingMethod.isEmpty) errors.add('Selecione o método de entrega');
  if (currentPedido.selectedPaymentMethod.isEmpty) errors.add('Selecione um método de pagamento');
  if (normalizedDate.isEmpty || normalizedTime.isEmpty) errors.add('Selecione a data e o horário de entrega/retirada');
  if (errors.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errors.join('\n')), duration: const Duration(seconds: 5)),
    );
    await logToFile('Erro de validação: ${errors.join(', ')}');
    setState(() => _isLoading = false);
    return;
  }
  setState(() => _isLoading = true);
  String? savedPaymentInstructions;
  try {
    final cep = currentPedido.cepController.text.replaceAll(RegExp(r'\D'), '').trim();
    final requestBody = {
      'cep': cep,
      'shipping_method': currentPedido.shippingMethod,
      'pickup_store': currentPedido.shippingMethod == 'pickup' ? currentPedido.storeFinal : '',
      'delivery_date': currentPedido.shippingMethod == 'delivery' ? normalizedDate : '',
      'pickup_date': currentPedido.shippingMethod == 'pickup' ? normalizedDate : '',
    };
    await logToFile('Sending request to store-decision endpoint: ${jsonEncode(requestBody)}');
    final storeResponse = await http.post(
      Uri.parse('https://aogosto.com.br/delivery/wp-json/custom/v1/store-decision'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(Duration(seconds: 15), onTimeout: () {
      throw Exception('Timeout ao buscar opções de entrega');
    });
    await logToFile('Store decision response status: ${storeResponse.statusCode}, body: ${storeResponse.body}');
    double shippingCost = 0.0;
    if (currentPedido.shippingMethod == 'delivery') {
      await logToFile('Fetching shipping cost for CEP: $cep');
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
        } else {
          await logToFile('Nenhuma opção de frete válida retornada para CEP: $cep');
          shippingCost = 0.0;
        }
      } else {
        throw Exception('Erro ao buscar custo de frete: ${costResponse.statusCode} - ${costResponse.body}');
      }
    }
    if (storeResponse.statusCode == 200) {
      final data = jsonDecode(storeResponse.body);
      final newStoreFinal = data['effective_store_final']?.toString() ?? data['store_final']?.toString();
      if (newStoreFinal == null) {
        throw Exception('Nenhuma loja válida retornada pelo endpoint store-decision.');
      }
      if (newStoreFinal != currentPedido.storeFinal) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loja ajustada para $newStoreFinal devido ao horário')),
        );
      }
      setState(() {
        currentPedido.storeFinal = newStoreFinal;
        currentPedido.pickupStoreId = data['pickup_store_id']?.toString() ?? StoreNormalize.getId(newStoreFinal);
        currentPedido.shippingCost = shippingCost;
        currentPedido.shippingCostController.text = shippingCost.toStringAsFixed(2);
        final rawPaymentMethods = List<Map>.from(data['payment_methods'] ?? []);
        currentPedido.availablePaymentMethods = [];
        final seenTitles = <String>{};
        for (var m in rawPaymentMethods) {
          final id = m['id']?.toString() ?? '';
          final title = m['title']?.toString() ?? '';
          if (id == 'woo_payment_on_delivery' && !seenTitles.contains('Dinheiro na Entrega')) {
            currentPedido.availablePaymentMethods.add({'id': 'cod', 'title': 'Dinheiro na Entrega'});
            seenTitles.add('Dinheiro na Entrega');
          } else if ((id == 'stripe' || id == 'stripe_cc' || id == 'eh_stripe_pay') && !seenTitles.contains('Cartão de Crédito On-line')) {
            currentPedido.availablePaymentMethods.add({
              'id': data['payment_accounts']['stripe'] ?? 'stripe',
              'title': 'Cartão de Crédito On-line'
            });
            seenTitles.add('Cartão de Crédito On-line');
          } else if (!seenTitles.contains(title)) {
            currentPedido.availablePaymentMethods.add({'id': id, 'title': title});
            seenTitles.add(title);
          }
        }
        final paymentAccounts = data['payment_accounts'] as Map?;
        currentPedido.paymentAccounts = paymentAccounts != null
            ? paymentAccounts.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''))
            : {
                'stripe': newStoreFinal == 'Unidade Barreiro' ? 'stripe_cc' : newStoreFinal == 'Unidade Sion' ? 'eh_stripe_pay' : 'stripe',
                'pagarme': newStoreFinal == 'Unidade Barreiro' ? 'barreiro' : newStoreFinal == 'Unidade Sion' ? 'sion' : 'central'
              };
        if (currentPedido.selectedPaymentMethod.isNotEmpty &&
            !currentPedido.availablePaymentMethods.any((m) => m['title'] == currentPedido.selectedPaymentMethod)) {
          currentPedido.selectedPaymentMethod = currentPedido.availablePaymentMethods.isNotEmpty
              ? currentPedido.availablePaymentMethods.first['title'] ?? ''
              : '';
        }
      });
      await _savePersistedData(currentPedido);
    } else {
      throw Exception('Erro ao buscar opções de entrega: ${storeResponse.statusCode} - ${storeResponse.body}');
    }
    if (currentPedido.shippingMethod == 'pickup') {
      currentPedido.shippingCost = 0.0;
      currentPedido.shippingCostController.text = '0.00';
    }
    await logToFile('[agendamento] date(raw)="${currentPedido.schedulingDate}" '
        'time(raw)="${currentPedido.schedulingTime}" '
        '-> date(norm)="$normalizedDate" time(norm)="$normalizedTime"');
    final storeFinal = currentPedido.storeFinal.isEmpty ? 'Central Distribuição (Sagrada Família)' : currentPedido.storeFinal;
    final storeId = StoreNormalize.getId(storeFinal);
    final normalizedStoreFinal = StoreNormalize.getName(storeId);
    final service = CriarPedidoService();
    final billingCompany = {'Alline': '7', 'Cássio Vinicius': '78', 'Maria Eduarda': '77'}
        .entries
        .firstWhere((entry) => entry.key == currentPedido.selectedVendedor, orElse: () => MapEntry('', ''))
        .value;
    final methodSlug = _paymentSlugFromLabel(currentPedido.selectedPaymentMethod);
    await logToFile('[_createOrder] Selecionado (label): ${currentPedido.selectedPaymentMethod} -> slug="$methodSlug"');
    final order = await service.createOrder(
      customerName: currentPedido.nameController.text,
      customerEmail: currentPedido.emailController.text,
      customerPhone: phone,
      billingCompany: billingCompany,
      products: currentPedido.products,
      shippingMethod: currentPedido.shippingMethod,
      storeFinal: normalizedStoreFinal,
      pickupStoreId: storeId,
      billingPostcode: cep,
      billingAddress1: currentPedido.addressController.text,
      billingNumber: currentPedido.numberController.text,
      billingAddress2: currentPedido.complementController.text,
      billingNeighborhood: currentPedido.neighborhoodController.text,
      billingCity: currentPedido.cityController.text,
      shippingCost: currentPedido.shippingCost,
      paymentMethod: methodSlug,
      customerNotes: currentPedido.showNotesField ? currentPedido.notesController.text : '',
      schedulingDate: normalizedDate,
      schedulingTime: normalizedTime,
      couponCode: currentPedido.showCouponField ? currentPedido.couponController.text : '',
      paymentAccountStripe: currentPedido.paymentAccounts['stripe'] ?? 'stripe',
      paymentAccountPagarme: currentPedido.paymentAccounts['pagarme'] ?? 'central',
    );
    await logToFile('Order created: #${order['id']}, store: ${currentPedido.storeFinal}, payment: $methodSlug');
    currentPedido.updateLastPhoneNumber(currentPedido.phoneController.text);
    final isPix = (methodSlug == 'pagarme_custom_pix');
    final isStripe = (methodSlug == currentPedido.paymentAccounts['stripe']);
    String? savedPaymentInstructions;
    if (isPix || isStripe) {
      final totalBeforeDiscount = currentPedido.products.fold<double>(
        0.0,
        (sum, product) => sum + (product['price'] * (product['quantity'] ?? 1)),
      ) + currentPedido.shippingCost;
      final discountAmount = currentPedido.isCouponValid ? currentPedido.discountAmount : 0.0;
      final totalAmount = totalBeforeDiscount - discountAmount;
      final paymentLinkResult = await _generatePaymentLink(
        customerName: currentPedido.nameController.text,
        phoneNumber: currentPedido.phoneController.text,
        amount: totalAmount,
        storeUnit: normalizedStoreFinal,
        paymentMethod: isPix ? 'Pix' : 'Stripe',
        orderId: order['id'].toString(),
      );
      if (paymentLinkResult != null) {
        savedPaymentInstructions = isPix
            ? jsonEncode({
                'type': 'pix',
                'text': paymentLinkResult['text'] ?? ''
              })
            : jsonEncode({
                'type': 'stripe',
                'url': paymentLinkResult['url'] ?? ''
              });
        await logToFile('Payment instructions generated: $savedPaymentInstructions');
      } else {
        await logToFile('Erro: paymentLinkResult is null for payment method: $methodSlug');
      }
    }
    if (mounted) {
      setState(() {
        _resultMessage = 'Pedido #${order['id']} criado com sucesso!${savedPaymentInstructions != null ? '\nInstruções de pagamento geradas.' : ''}';
        currentPedido.paymentInstructions = savedPaymentInstructions;
        currentPedido.resetControllers();
        currentPedido.products.clear();
        currentPedido.shippingMethod = '';
        currentPedido.selectedPaymentMethod = '';
        currentPedido.storeFinal = '';
        currentPedido.pickupStoreId = '';
        currentPedido.shippingCost = 0.0;
        currentPedido.shippingCostController.text = '0.00';
        currentPedido.showNotesField = false;
        currentPedido.showCouponField = false;
        currentPedido.schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        currentPedido.schedulingTime = '09:00 - 12:00';
        currentPedido.isCouponValid = false;
        currentPedido.discountAmount = 0.0;
        currentPedido.couponErrorMessage = null;
        currentPedido.availablePaymentMethods = [];
        currentPedido.paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
      });
      await _savePersistedData(currentPedido);
    }
  } catch (error, stackTrace) {
    await logToFile('Erro ao criar pedido: $error, StackTrace: $stackTrace');
    if (mounted) {
      setState(() {
        _resultMessage = 'Erro ao criar pedido: $error';
      });
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
      final tabState = context.findAncestorStateOfType<_KeepAliveTabState>();
      if (tabState != null) {
        tabState.resetAddressSection();
      }
      await _savePersistedData(currentPedido);
    }
  }
}

  Future<void> _sendWhatsAppMessage(String phoneNumber, String message) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final cleanMessage = message.trim();
    final url = Uri.parse('https://api.wzap.chat/v1/messages');
    final payload = {
      "phone": "+55$cleanPhone",
      "message": cleanMessage,
    };
    final headers = {
      "Token": "7343607cd11509da88407ea89353ebdd8a79bdf9c3152da4025274c08c370b7b90ab0b68307d28cf",
      "Content-Type": "application/json",
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(payload),
      );
      await logToFile('WhatsApp Response: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensagem enviada com sucesso!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na conexão: $e')),
      );
    }
  }

  Future<Map<String, String>?> _generatePaymentLink({
  required String customerName,
  required String phoneNumber,
  required double amount,
  required String storeUnit,
  required String paymentMethod,
  required String orderId,
}) async {
  final rawPhone = phoneNumber.replaceAll(RegExp(r'\D'), '').trim();
  final areaCode = rawPhone.length >= 2 ? rawPhone.substring(0, 2) : '31';
  final phone = rawPhone.length >= 9 ? rawPhone.substring(2) : rawPhone;
  if (amount < 0.50) {
    throw Exception('Erro ao gerar link de pagamento: O valor total do pedido deve ser maior ou igual a R\$ 0,50.');
  }
  final amountInCents = (amount * 100).toInt(); // Sempre em centavos para Stripe e Pagar.me
  final storeId = StoreNormalize.getId(storeUnit);
  final normalizedStoreUnit = StoreNormalize.getName(storeId);
  final proxyUnit = StoreNormalize.getProxyUnit(normalizedStoreUnit);
  String endpoint;
  String proxyPath = paymentMethod == 'Pix' ? 'pagarme.php' : 'stripe.php';
  endpoint = 'https://aogosto.com.br/proxy/${Uri.encodeComponent(proxyUnit)}/$proxyPath';
  await logToFile('Gerando link de pagamento: paymentMethod=$paymentMethod, storeUnit=$storeUnit, proxyUnit=$proxyUnit, endpoint=$endpoint, amountInCents=$amountInCents');
  try {
    if (paymentMethod == 'Pix') {
      final payloadPagarMe = {
        'items': [
          {'amount': amountInCents, 'description': 'Produtos Ao Gosto Carnes', 'quantity': 1},
        ],
        'customer': {
          'name': customerName,
          'email': 'app+${DateTime.now().millisecondsSinceEpoch}@aogosto.com.br',
          'document': '06275992000570',
          'type': 'company',
          'phones': {
            'home_phone': {'country_code': '55', 'number': phone, 'area_code': areaCode}
          },
        },
        'payments': [
          {
            'payment_method': 'pix',
            'pix': {'expires_in': 3600}
          }
        ],
        'metadata': {'order_id': orderId, 'unidade': normalizedStoreUnit},
      };
      await logToFile('Payload PagarMe: ${jsonEncode(payloadPagarMe)}');
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payloadPagarMe),
      );
      await logToFile('Resposta do proxy PagarMe: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode != 200) {
        throw Exception('Erro ao criar pedido PIX: ${jsonDecode(response.body)}');
      }
      final data = jsonDecode(response.body);
      if (data['charges'] != null && data['charges'].isNotEmpty && data['charges'][0]['last_transaction'] != null) {
        final pixInfo = data['charges'][0]['last_transaction'];
        final pixText = pixInfo['text']?.toString() ?? '';
        if (pixText.isEmpty) {
          await logToFile('Aviso: pixText vazio, usando qr_code como fallback: ${pixInfo['qr_code'] ?? 'null'}');
          final fallbackText = pixInfo['qr_code']?.toString() ?? '';
          if (fallbackText.isEmpty) {
            throw Exception('Nenhuma linha digitável ou QR code retornado para Pix.');
          }
          return {
            'type': 'pix',
            'text': fallbackText
          };
        }
        await logToFile('Pix text extraído: $pixText');
        return {
          'type': 'pix',
          'text': pixText
        };
      } else {
        throw Exception('Nenhuma transação PIX retornada ou estrutura de resposta inválida: ${jsonEncode(data)}');
      }
    } else {
      final payloadStripe = {
        'product_name': customerName,
        'product_description': 'Produtos Ao Gosto Carnes',
        'amount': amountInCents,
        'phone_number': '($areaCode) $phone',
        'metadata': {'order_id': orderId, 'unidade': normalizedStoreUnit},
      };
      await logToFile('Payload Stripe: ${jsonEncode(payloadStripe)}');
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payloadStripe),
      );
      await logToFile('Resposta do proxy Stripe: ${response.body}');
      if (response.body.isEmpty) {
        throw Exception('Resposta do proxy está vazia. Status: ${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      if (response.statusCode != 200) {
        throw Exception('Erro ao criar link Stripe: ${jsonEncode(data)}');
      }
      if (data['payment_link'] != null && data['payment_link']['url'] != null) {
        await logToFile('Stripe URL gerada: ${data['payment_link']['url']}');
        return {'type': 'stripe', 'url': data['payment_link']['url']};
      } else {
        throw Exception('Nenhuma URL de checkout retornada.');
      }
    }
  } catch (error) {
    await logToFile('Erro ao gerar link de pagamento: $error');
    throw error;
  }
}

  void _onCouponValidated() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      setState(() {
        for (var pedido in _pedidos) {
          pedido.nameController.removeListener(_updateTabs);
          pedido.dispose();
        }
        _pedidos.clear();
        final newPedido = PedidoState(onCouponValidated: _onCouponValidated);
        newPedido.nameController.addListener(_updateTabs);
        newPedido.schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        newPedido.schedulingTime = '09:00 - 12:00';
        newPedido.shippingMethod = 'delivery';
        _pedidos.add(newPedido);
        _currentTabIndex = 0;
        _tabController.dispose();
        _tabController = TabController(length: _pedidos.length, vsync: this);
        _tabController.addListener(_handleTabSelection);
        _isLoading = false;
        _resultMessage = null;
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dados locais limpos com sucesso')),
    );
    await logToFile('Dados locais limpos pelo usuário');
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFFF28C38);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black.withOpacity(0.2) : Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.1),
        title: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: primaryColor,
          unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.grey.shade600,
          indicator: BoxDecoration(
            border: Border(bottom: BorderSide(color: primaryColor, width: 2)),
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          tabs: List.generate(_pedidos.length, (index) {
            final pedido = _pedidos[index];
            final tabLabel = pedido.nameController.text.trim().isEmpty
                ? 'Pedido ${index + 1}'
                : 'Pedido de ${pedido.nameController.text.trim()}';
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tabLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_pedidos.length > 1) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (_currentTabIndex == index) {
                          _removeCurrentPedido();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentTabIndex == index
                              ? primaryColor.withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: _currentTabIndex == index
                              ? primaryColor
                              : isDarkMode
                                  ? Colors.white70
                                  : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isAddingTab ? null : _addNewPedido,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isAddingTab
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : Icon(Icons.add, color: primaryColor, size: 24),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              backgroundColor: primaryColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
          Expanded(
            child: _isInitialized
                ? TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _pedidos.asMap().entries.map<Widget>((entry) {
                      final index = entry.key;
                      final pedido = entry.value;
                      return KeepAliveTab(
                        key: ValueKey('tab_$index'),
                        pedido: pedido,
                        fetchCustomer: _fetchCustomer,
                        createOrder: _createOrder,
                        savePersistedData: _savePersistedData,
                        checkStoreByCep: _checkStoreByCep,
                        isLoading: _isLoading,
                        resultMessage: _resultMessage,
                        setStateCallback: () {
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        clearLocalData: _clearLocalData,
                      );
                    }).toList(),
                  )
                : Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class KeepAliveTab extends StatefulWidget {
  final PedidoState pedido;
  final Future<void> Function() fetchCustomer;
  final Future<void> Function() createOrder;
  final Future<void> Function(PedidoState) savePersistedData;
  final Future<void> Function() checkStoreByCep;
  final bool isLoading;
  final String? resultMessage;
  final VoidCallback setStateCallback;
  final Future<void> Function() clearLocalData;

  const KeepAliveTab({
    Key? key,
    required this.pedido,
    required this.fetchCustomer,
    required this.createOrder,
    required this.savePersistedData,
    required this.checkStoreByCep,
    required this.isLoading,
    required this.resultMessage,
    required this.setStateCallback,
    required this.clearLocalData,
  }) : super(key: key);

  @override
  _KeepAliveTabState createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab> with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _addressSectionKey = GlobalKey();
  final primaryColor = const Color(0xFFF28C38);
  bool _isEditingShippingCost = false;
  double _tempShippingCost = 0.0;
  final _shippingCostController = TextEditingController();

  void resetAddressSection() {
    final addressState = _addressSectionKey.currentState;
    if (addressState != null) {
      (addressState as dynamic).resetSection();
      widget.pedido.cepController.clear();
      widget.pedido.addressController.clear();
      widget.pedido.numberController.clear();
      widget.pedido.complementController.clear();
      widget.pedido.neighborhoodController.clear();
      widget.pedido.cityController.clear();
      widget.setStateCallback();
      widget.savePersistedData(widget.pedido);
    } else {
      debugPrint('Erro: Estado do AddressSection não encontrado.');
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.pedido.addListener(_updateState);
    _shippingCostController.text = widget.pedido.shippingCostController.text;
  }

  @override
  void dispose() {
    _shippingCostController.dispose();
    widget.pedido.removeListener(_updateState);
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  void _startEditingShippingCost() {
    setState(() {
      _isEditingShippingCost = true;
      _tempShippingCost = widget.pedido.shippingCost;
      _shippingCostController.text = _tempShippingCost.toStringAsFixed(2);
    });
  }

  void _saveShippingCost() {
    final newCost = double.tryParse(_shippingCostController.text.replaceAll(',', '.')) ?? 0.0;
    if (newCost >= 0) {
      widget.setStateCallback();
      widget.pedido.shippingCost = newCost;
      widget.pedido.shippingCostController.text = newCost.toStringAsFixed(2);
      widget.savePersistedData(widget.pedido);
    }
    setState(() => _isEditingShippingCost = false);
  }

  void _cancelEditingShippingCost() {
    setState(() {
      _isEditingShippingCost = false;
      _shippingCostController.text = widget.pedido.shippingCostController.text;
    });
  }

  DateTime? _parseInitialDate(String? dateString, String shippingMethod) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd').parse(dateString);
    } catch (e) {
      try {
        return DateFormat('MMMM d, yyyy', 'en_US').parse(dateString);
      } catch (e) {
        try {
          return DateFormat('dd/MM/yyyy').parse(dateString);
        } catch (e) {
          debugPrint('Erro ao parsear data: $dateString, erro: $e');
          return null;
        }
      }
    }
  }

  @override
Widget build(BuildContext context) {
  super.build(context);
  final totalOriginal = widget.pedido.calculateTotal(applyDiscount: false);
  final totalWithDiscount = widget.pedido.calculateTotal(applyDiscount: true);
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;
  final primaryColor = const Color(0xFFF28C38);
  return Container(
    color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomerSection(
                      phoneController: widget.pedido.phoneController,
                      onPhoneChanged: (String value) {
                        print('Telefone inserido: $value');
                        widget.savePersistedData(widget.pedido);
                      },
                      onFetchCustomer: widget.fetchCustomer,
                      nameController: widget.pedido.nameController,
                      onNameChanged: (String value) {
                        widget.savePersistedData(widget.pedido);
                      },
                      emailController: widget.pedido.emailController,
                      onEmailChanged: (String value) {
                        widget.savePersistedData(widget.pedido);
                      },
                      selectedVendedor: widget.pedido.selectedVendedor,
                      onVendedorChanged: (value) {
                        widget.setStateCallback();
                        widget.pedido.selectedVendedor = value ?? 'Alline';
                        widget.savePersistedData(widget.pedido);
                      },
                      validator: (value) => null,
                      isLoading: widget.isLoading,
                    ),
                    const SizedBox(height: 16),
                    ExpansionPanelList(
                      elevation: 0,
                      expandedHeaderPadding: EdgeInsets.zero,
                      expansionCallback: (panelIndex, isExpanded) {
                        widget.setStateCallback();
                        widget.pedido.isAddressSectionExpanded = !widget.pedido.isAddressSectionExpanded;
                        widget.savePersistedData(widget.pedido);
                      },
                      children: [
                        ExpansionPanel(
                          headerBuilder: (context, isExpanded) => ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            title: Text(
                              'Endereço do Cliente',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            trailing: AnimatedRotation(
                              turns: isExpanded ? 0.5 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                          ),
                          body: AddressSection(
                            key: _addressSectionKey,
                            cepController: widget.pedido.cepController,
                            addressController: widget.pedido.addressController,
                            numberController: widget.pedido.numberController,
                            complementController: widget.pedido.complementController,
                            neighborhoodController: widget.pedido.neighborhoodController,
                            cityController: widget.pedido.cityController,
                            onChanged: (value) {
                              widget.setStateCallback();
                              widget.savePersistedData(widget.pedido);
                              if (widget.pedido.cepController.text.replaceAll(RegExp(r'\D'), '').length == 8) {
                                widget.checkStoreByCep();
                              }
                            },
                            onShippingCostUpdated: (cost) {
                              widget.setStateCallback();
                              widget.pedido.shippingCost = cost;
                              widget.pedido.shippingCostController.text = cost.toStringAsFixed(2);
                              widget.savePersistedData(widget.pedido);
                            },
                            onStoreUpdated: (storeFinal, pickupStoreId) {
                              widget.setStateCallback();
                              widget.pedido.storeFinal = storeFinal;
                              widget.pedido.pickupStoreId = pickupStoreId;
                              widget.savePersistedData(widget.pedido);
                              widget.checkStoreByCep();
                            },
                            externalShippingCost: widget.pedido.shippingCost,
                            shippingMethod: widget.pedido.shippingMethod,
                            setStateCallback: widget.setStateCallback,
                            savePersistedData: () => widget.savePersistedData(widget.pedido),
                            checkStoreByCep: widget.checkStoreByCep,
                            pedido: widget.pedido,
                            onReset: resetAddressSection,
                          ),
                          isExpanded: widget.pedido.isAddressSectionExpanded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: ValueKey(widget.pedido.products.length),
                      child: ProductSection(
                        products: widget.pedido.products,
                        onRemoveProduct: (index) {
                          if (index >= 0 && index < widget.pedido.products.length) {
                            widget.pedido.products.removeAt(index);
                            widget.setStateCallback();
                            widget.pedido.notifyListeners();
                            widget.savePersistedData(widget.pedido);
                          }
                        },
                        onAddProduct: () async {
                          final selectedProduct = await showDialog<Map<String, dynamic>>(
                            context: context,
                            builder: (context) => ProductSelectionDialog(),
                          );
                          if (selectedProduct != null && mounted) {
                            widget.setStateCallback();
                            widget.pedido.products.add({
                              'id': selectedProduct['id'],
                              'name': selectedProduct['name'],
                              'quantity': 1,
                              'price': double.tryParse(selectedProduct['price'].toString()) ?? 0.0,
                              'variation_id': selectedProduct['variation_id'],
                              'variation_attributes': selectedProduct['variation_attributes'],
                              'image': selectedProduct['image'],
                            });
                            widget.savePersistedData(widget.pedido);
                          }
                        },
                        onUpdateQuantity: (index, quantity) {
                          if (index >= 0 && index < widget.pedido.products.length) {
                            widget.pedido.updateProductQuantity(index, quantity);
                            widget.savePersistedData(widget.pedido);
                          }
                        },
                        onUpdatePrice: (index, price) {
                          if (index >= 0 && index < widget.pedido.products.length) {
                            widget.pedido.products[index]['price'] = price;
                            widget.pedido.notifyListeners();
                            widget.savePersistedData(widget.pedido);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ShippingSection(
                      cep: widget.pedido.cepController.text.replaceAll(RegExp(r'\D'), '').trim(),
                      onStoreUpdated: (storeFinal, pickupStoreId) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            widget.setStateCallback();
                            final normalizedId = StoreNormalize.getId(storeFinal);
                            widget.pedido.storeFinal = StoreNormalize.getName(normalizedId);
                            widget.pedido.pickupStoreId = normalizedId;
                            widget.savePersistedData(widget.pedido);
                            widget.checkStoreByCep();
                          }
                        });
                      },
                      onShippingMethodUpdated: (method) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            widget.setStateCallback();
                            widget.pedido.shippingMethod = method;
                            if (method == 'pickup') {
                              widget.pedido.shippingCost = 0.0;
                              widget.pedido.shippingCostController.text = '0.00';
                              widget.pedido.storeFinal = 'Central Distribuição (Sagrada Família)';
                              widget.pedido.pickupStoreId = StoreNormalize.getId(widget.pedido.storeFinal);
                            }
                            widget.savePersistedData(widget.pedido);
                            widget.checkStoreByCep();
                          }
                        });
                      },
                      onShippingCostUpdated: (cost) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            widget.setStateCallback();
                            widget.pedido.shippingCost = cost;
                            widget.pedido.shippingCostController.text = cost.toStringAsFixed(2);
                            widget.savePersistedData(widget.pedido);
                          }
                        });
                      },
                      pedido: widget.pedido,
                      onSchedulingChanged: widget.checkStoreByCep,
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
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
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.calendar_today, color: primaryColor),
                              title: Text(
                                'Data e Horário de Entrega/Retirada',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            SchedulingSection(
                              shippingMethod: widget.pedido.shippingMethod,
                              storeFinal: widget.pedido.storeFinal,
                              onDateTimeUpdated: (date, time) {
                                widget.setStateCallback();
                                widget.pedido.schedulingDate = date;
                                widget.pedido.schedulingTime = ensureTimeRange(time);
                                widget.savePersistedData(widget.pedido);
                                widget.checkStoreByCep();
                              },
                              onSchedulingChanged: widget.checkStoreByCep,
                              initialDate: _parseInitialDate(widget.pedido.schedulingDate, widget.pedido.shippingMethod),
                              initialTimeSlot: widget.pedido.schedulingTime.isNotEmpty ? widget.pedido.schedulingTime : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.note, color: primaryColor),
                            title: Text(
                              'Observações do Cliente',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            trailing: Checkbox(
                              value: widget.pedido.showNotesField,
                              onChanged: (value) {
                                widget.setStateCallback();
                                widget.pedido.showNotesField = value ?? false;
                                if (!widget.pedido.showNotesField) {
                                  widget.pedido.notesController.text = '';
                                }
                                widget.savePersistedData(widget.pedido);
                              },
                              activeColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState: widget.pedido.showNotesField ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextFormField(
                                controller: widget.pedido.notesController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  labelText: 'Observações',
                                  labelStyle: GoogleFonts.poppins(
                                    color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
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
                                  prefixIcon: Icon(Icons.note_alt, color: primaryColor),
                                  filled: true,
                                  fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                onChanged: (value) {
                                  widget.savePersistedData(widget.pedido);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(Icons.discount, color: primaryColor),
                            title: Text(
                              'Cupom de Desconto',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            trailing: Checkbox(
                              value: widget.pedido.showCouponField,
                              onChanged: (value) {
                                widget.setStateCallback();
                                widget.pedido.showCouponField = value ?? false;
                                if (!widget.pedido.showCouponField) {
                                  widget.pedido.couponController.text = '';
                                  widget.pedido.isCouponValid = false;
                                  widget.pedido.discountAmount = 0.0;
                                  widget.pedido.couponErrorMessage = null;
                                }
                                widget.savePersistedData(widget.pedido);
                              },
                              activeColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState: widget.pedido.showCouponField ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextFormField(
                                controller: widget.pedido.couponController,
                                decoration: InputDecoration(
                                  labelText: 'Código do Cupom',
                                  labelStyle: GoogleFonts.poppins(
                                    color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
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
                                  prefixIcon: Icon(Icons.discount, color: primaryColor),
                                  filled: true,
                                  fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  suffixIcon: widget.pedido.isCouponValid
                                      ? Icon(Icons.check_circle, color: Colors.green.shade600)
                                      : widget.pedido.couponController.text.isNotEmpty
                                          ? Icon(Icons.error, color: Colors.red.shade600)
                                          : null,
                                ),
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                onChanged: (value) {
                                  widget.savePersistedData(widget.pedido);
                                },
                                validator: (value) => null,
                              ),
                            ),
                          ),
                          if (widget.pedido.couponErrorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              widget.pedido.couponErrorMessage!,
                              style: GoogleFonts.poppins(
                                color: Colors.red.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SummarySection(
                      totalOriginal: totalOriginal,
                      isCouponValid: widget.pedido.isCouponValid,
                      couponCode: widget.pedido.couponController.text,
                      discountAmount: widget.pedido.discountAmount,
                      totalWithDiscount: totalWithDiscount,
                      isLoading: widget.isLoading,
                      onCreateOrder: widget.createOrder,
                      pedido: widget.pedido,
                      paymentInstructions: widget.pedido.paymentInstructions,
                      resultMessage: widget.resultMessage,
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: widget.clearLocalData,
                      icon: Icon(Icons.refresh, size: 16, color: primaryColor),
                      label: Text(
                        'Limpar Dados',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
