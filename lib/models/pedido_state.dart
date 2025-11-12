
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class PedidoState with ChangeNotifier {
  // Controladores de texto para os campos do formulário
  TextEditingController phoneController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController cepController = TextEditingController();
  TextEditingController addressController = TextEditingController();
  TextEditingController numberController = TextEditingController();
  TextEditingController complementController = TextEditingController();
  TextEditingController neighborhoodController = TextEditingController();
  TextEditingController cityController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  TextEditingController couponController = TextEditingController();
  TextEditingController shippingCostController = TextEditingController();

  // Estado do pedido
  List<Map<String, dynamic>> products = [];
  String shippingMethod = '';
  String selectedVendedor = 'Alline';
  double shippingCost = 0.0;
  String storeFinal = '';
  String pickupStoreId = '';
  String selectedPaymentMethod = '';
  bool showNotesField = false;
  bool showCouponField = false;
  String schedulingDate = '';
  String schedulingTime = '';
  bool isShippingCostManuallyEdited = false;
  bool isCustomerSectionExpanded = true;
  bool isAddressSectionExpanded = true;
  bool isProductsSectionExpanded = true;
  bool isShippingSectionExpanded = true;
  String? paymentInstructions;
  String? couponErrorMessage;
  double _originalShippingCost = 0.0;
  double get originalShippingCost => _originalShippingCost;
  set originalShippingCost(double value) {
  _originalShippingCost = value;
  notifyListeners(); // ESSENCIAL!
}
  double discountAmount = 0.0;
  bool isCouponValid = false;
  Timer? debounce;
  String? storeIndication;
  bool isFetchingStore = false;
  String? lastPhoneNumber;
  String lastCep = '';
  List<Map<String, dynamic>> availablePaymentMethods = []; // Alterado para dynamic
  Map<String, dynamic> paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'}; // Alterado para dynamic

  final VoidCallback? onCouponValidated;

  // Credenciais do WooCommerce
  static const String _woocommerceBaseUrl = 'https://aogosto.com.br/delivery/wp-json/wc/v3';
  static const String _consumerKey = 'ck_5156e2360f442f2585c8c9a761ef084b710e811f';
  static const String _consumerSecret = 'cs_c62f9d8f6c08a1d14917e2a6db5dccce2815de8c';

  PedidoState({this.onCouponValidated}) {
    shippingCostController.text = shippingCost.toStringAsFixed(2);
    couponController.addListener(_onCouponChanged);
    selectedPaymentMethod = '';
    schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void reset() {
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    cepController.dispose();
    addressController.dispose();
    numberController.dispose();
    complementController.dispose();
    neighborhoodController.dispose();
    cityController.dispose();
    notesController.dispose();
    couponController.removeListener(_onCouponChanged);
    couponController.dispose();
    shippingCostController.dispose();

    _initializeControllers();
    shippingCostController.text = shippingCost.toStringAsFixed(2);
    couponController.addListener(_onCouponChanged);
    selectedPaymentMethod = '';
    availablePaymentMethods = [];
    paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
    schedulingDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    lastCep = '';
    notifyListeners();
  }

  void _initializeControllers() {
    phoneController = TextEditingController();
    nameController = TextEditingController();
    emailController = TextEditingController();
    cepController = TextEditingController();
    addressController = TextEditingController();
    numberController = TextEditingController();
    complementController = TextEditingController();
    neighborhoodController = TextEditingController();
    cityController = TextEditingController();
    notesController = TextEditingController();
    couponController = TextEditingController();
    shippingCostController = TextEditingController();
  }

  void resetControllers() {
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    cepController.dispose();
    addressController.dispose();
    numberController.dispose();
    complementController.dispose();
    neighborhoodController.dispose();
    cityController.dispose();
    notesController.dispose();
    couponController.removeListener(_onCouponChanged);
    couponController.dispose();
    shippingCostController.dispose();
    _originalShippingCost = 0.0;

    _initializeControllers();
    shippingCostController.text = shippingCost.toStringAsFixed(2);
    couponController.addListener(_onCouponChanged);
    selectedPaymentMethod = '';
    availablePaymentMethods = [];
    paymentAccounts = {'stripe': 'stripe', 'pagarme': 'central'};
    lastCep = '';
    notifyListeners();
  }

  void updateLastPhoneNumber(String phone) {
    lastPhoneNumber = phone.replaceAll(RegExp(r'\D'), '');
    notifyListeners();
  }

  double calculateTotal({bool applyDiscount = true}) {
    double total = products.fold<double>(
      0.0,
      (sum, product) => sum + (product['price'] * (product['quantity'] ?? 1)),
    ) + shippingCost;
    if (applyDiscount && isCouponValid) {
      total -= discountAmount;
    }
    return total < 0 ? 0.0 : total;
  }

  void updateProductQuantity(int index, int quantity) {
    if (index >= 0 && index < products.length) {
      products[index]['quantity'] = quantity > 0 ? quantity : 1;
      notifyListeners();
    }
  }

  Future<void> _validateCoupon() async {
    if (couponController.text.isEmpty || !showCouponField) {
      isCouponValid = false;
      discountAmount = 0.0;
      couponErrorMessage = null;
      _notifyCouponValidation();
      return;
    }
    final startTime = DateTime.now();
    try {
      final response = await http.get(
        Uri.parse('$_woocommerceBaseUrl/coupons?code=${Uri.encodeComponent(couponController.text)}'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
      );
      final endTime = DateTime.now();
      debugPrint('API Response - Status: ${response.statusCode}, Body: ${response.body}, Time: ${endTime.difference(startTime).inMilliseconds}ms');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final coupon = data[0];
          debugPrint('Coupon data: $coupon, amount type: ${coupon['amount'].runtimeType}, discount_type: ${coupon['discount_type']}');
          isCouponValid = true;
          if (coupon['discount_type'] == 'percent') {
            final total = products.fold<double>(
              0.0,
              (sum, product) => sum + (product['price'] * product['quantity']),
            ) + shippingCost;
            discountAmount = total * (double.parse(coupon['amount'].toString()) / 100);
          } else {
            discountAmount = double.parse(coupon['amount'].toString());
          }
          couponErrorMessage = null;
        } else {
          isCouponValid = false;
          discountAmount = 0.0;
          couponErrorMessage = 'Cupom não encontrado ou inválido';
        }
      } else {
        isCouponValid = false;
        discountAmount = 0.0;
        couponErrorMessage = 'Erro na API: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      isCouponValid = false;
      discountAmount = 0.0;
      couponErrorMessage = 'Erro na conexão: $e';
    }
    debugPrint('Coupon validation result - isValid: $isCouponValid, amount: $discountAmount, error: $couponErrorMessage');
    _notifyCouponValidation();
    notifyListeners();
  }

  void _notifyCouponValidation() {
    onCouponValidated?.call();
  }

  void _onCouponChanged() {
    if (debounce?.isActive ?? false) debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 500), () async {
      await _validateCoupon();
    });
  }

  Map<String, dynamic> toJson() {
    return {
      'phone': phoneController.text,
      'name': nameController.text,
      'email': emailController.text,
      'cep': cepController.text,
      'address': addressController.text,
      'number': numberController.text,
      'complement': complementController.text,
      'neighborhood': neighborhoodController.text,
      'city': cityController.text,
      'notes': notesController.text,
      'coupon': couponController.text,
      'products': products,
      'shippingMethod': shippingMethod,
      'selectedVendedor': selectedVendedor,
      'shippingCost': shippingCost,
      'shippingCostController': shippingCostController.text,
      'storeFinal': storeFinal,
      'pickupStoreId': pickupStoreId,
      'selectedPaymentMethod': selectedPaymentMethod,
      'showNotesField': showNotesField,
      'showCouponField': showCouponField,
      'schedulingDate': schedulingDate,
      'schedulingTime': schedulingTime,
      'isCustomerSectionExpanded': isCustomerSectionExpanded,
      'isAddressSectionExpanded': isAddressSectionExpanded,
      'isProductsSectionExpanded': isProductsSectionExpanded,
      'isShippingSectionExpanded': isShippingSectionExpanded,
      'paymentInstructions': paymentInstructions,
      'couponErrorMessage': couponErrorMessage,
      'discountAmount': discountAmount,
      'isCouponValid': isCouponValid,
      'storeIndication': storeIndication,
      'isFetchingStore': isFetchingStore,
      'lastPhoneNumber': lastPhoneNumber,
      'lastCep': lastCep,
      'availablePaymentMethods': availablePaymentMethods,
      'paymentAccounts': paymentAccounts,
    };
  }

  factory PedidoState.fromJson(Map<String, dynamic> json) {
    final pedido = PedidoState(onCouponValidated: () {});
    pedido.phoneController.text = json['phone']?.toString() ?? '';
    pedido.nameController.text = json['name']?.toString() ?? '';
    pedido.emailController.text = json['email']?.toString() ?? '';
    pedido.cepController.text = json['cep']?.toString() ?? '';
    pedido.addressController.text = json['address']?.toString() ?? '';
    pedido.numberController.text = json['number']?.toString() ?? '';
    pedido.complementController.text = json['complement']?.toString() ?? '';
    pedido.neighborhoodController.text = json['neighborhood']?.toString() ?? '';
    pedido.cityController.text = json['city']?.toString() ?? '';
    pedido.notesController.text = json['notes']?.toString() ?? '';
    pedido.couponController.text = json['coupon']?.toString() ?? '';
    pedido.products = List<Map<String, dynamic>>.from(json['products'] ?? []);
    pedido.shippingMethod = json['shippingMethod']?.toString() ?? '';
    pedido.selectedVendedor = json['selectedVendedor']?.toString() ?? 'Alline';
    pedido.shippingCost = (json['shippingCost'] as num?)?.toDouble() ?? 0.0;
    pedido.shippingCostController.text = json['shippingCostController']?.toString() ?? '0.00';
    pedido.storeFinal = json['storeFinal']?.toString() ?? '';
    pedido.pickupStoreId = json['pickupStoreId']?.toString() ?? '';
    pedido.selectedPaymentMethod = json['selectedPaymentMethod']?.toString() ?? '';
    pedido.showNotesField = json['showNotesField'] as bool? ?? false;
    pedido.showCouponField = json['showCouponField'] as bool? ?? false;
    pedido.schedulingDate = json['schedulingDate']?.toString() ?? '';
    pedido.schedulingTime = json['schedulingTime']?.toString() ?? '';
    pedido.isCustomerSectionExpanded = json['isCustomerSectionExpanded'] as bool? ?? true;
    pedido.isAddressSectionExpanded = json['isAddressSectionExpanded'] as bool? ?? true;
    pedido.isProductsSectionExpanded = json['isProductsSectionExpanded'] as bool? ?? true;
    pedido.isShippingSectionExpanded = json['isShippingSectionExpanded'] as bool? ?? true;
    pedido.paymentInstructions = json['paymentInstructions']?.toString();
    pedido.couponErrorMessage = json['couponErrorMessage']?.toString();
    pedido.discountAmount = (json['discountAmount'] as num?)?.toDouble() ?? 0.0;
    pedido.isCouponValid = json['isCouponValid'] as bool? ?? false;
    pedido.storeIndication = json['storeIndication']?.toString();
    pedido.isFetchingStore = json['isFetchingStore'] as bool? ?? false;
    pedido.lastPhoneNumber = json['lastPhoneNumber']?.toString();
    pedido.lastCep = json['lastCep']?.toString() ?? '';
    pedido.availablePaymentMethods = (json['availablePaymentMethods'] as List<dynamic>?)
        ?.map((m) => Map<String, dynamic>.from(m as Map))
        .toList() ?? [];
    pedido.paymentAccounts = (json['paymentAccounts'] as Map<dynamic, dynamic>?)
        ?.map((k, v) => MapEntry(k.toString(), v)) ?? {'stripe': 'stripe', 'pagarme': 'central'};
    return pedido;
  }

  @override
  void dispose() {
    debounce?.cancel();
    phoneController.dispose();
    nameController.dispose();
    emailController.dispose();
    cepController.dispose();
    addressController.dispose();
    numberController.dispose();
    complementController.dispose();
    neighborhoodController.dispose();
    cityController.dispose();
    notesController.dispose();
    couponController.removeListener(_onCouponChanged);
    couponController.dispose();
    shippingCostController.dispose();
    super.dispose();
  }
}
