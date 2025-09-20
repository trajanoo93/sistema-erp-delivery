import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PedidoState with ChangeNotifier {
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
  bool isCustomerSectionExpanded = true;
  bool isAddressSectionExpanded = true;
  bool isProductsSectionExpanded = true;
  bool isShippingSectionExpanded = true;
  String? paymentInstructions;
  String? couponErrorMessage;
  double discountAmount = 0.0;
  bool isCouponValid = false;
  Timer? debounce;
  String? storeIndication;
  bool isFetchingStore = false;
  String? lastPhoneNumber;

  final VoidCallback? onCouponValidated;

  static const String _woocommerceBaseUrl = 'https://aogosto.com.br/delivery/wp-json/wc/v3';
  static const String _consumerKey = 'ck_5156e2360f442f2585c8c9a761ef084b710e811f';
  static const String _consumerSecret = 'cs_c62f9d8f6c08a1d14917e2a6db5dccce2815de8c';

  PedidoState({this.onCouponValidated}) {
  shippingCostController.text = shippingCost.toStringAsFixed(2);
  couponController.addListener(_onCouponChanged);
  selectedPaymentMethod = ''; // Inicialização explícita como string vazia
  schedulingDate = DateTime.now().toIso8601String().split('T')[0]; // Define como hoje por padrão
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
  schedulingDate = DateTime.now().toIso8601String().split('T')[0]; // Reseta para hoje
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

    _initializeControllers();
    shippingCostController.text = shippingCost.toStringAsFixed(2);
    couponController.addListener(_onCouponChanged);
    selectedPaymentMethod = ''; // Resetar explicitamente para string vazia
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
    return total;
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
      print('API Response - Status: ${response.statusCode}, Body: ${response.body}, Time: ${endTime.difference(startTime).inMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          final coupon = data[0];
          print('Coupon data: $coupon, amount type: ${coupon['amount'].runtimeType}, discount_type: ${coupon['discount_type']}');
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
    print('Coupon validation result - isValid: $isCouponValid, amount: $discountAmount, error: $couponErrorMessage');
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

  void updateProductQuantity(int index, int quantity) {
    if (index >= 0 && index < products.length) {
      products[index]['quantity'] = quantity > 0 ? quantity : 1;
      notifyListeners();
    }
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
    };
  }

  factory PedidoState.fromJson(Map<String, dynamic> json) {
    final pedido = PedidoState();
    pedido.phoneController.text = json['phone'] ?? '';
    pedido.nameController.text = json['name'] ?? '';
    pedido.emailController.text = json['email'] ?? '';
    pedido.cepController.text = json['cep'] ?? '';
    pedido.addressController.text = json['address'] ?? '';
    pedido.numberController.text = json['number'] ?? '';
    pedido.complementController.text = json['complement'] ?? '';
    pedido.neighborhoodController.text = json['neighborhood'] ?? '';
    pedido.cityController.text = json['city'] ?? '';
    pedido.notesController.text = json['notes'] ?? '';
    pedido.couponController.text = json['coupon'] ?? '';
    pedido.products = List<Map<String, dynamic>>.from(json['products'] ?? []);
    pedido.shippingMethod = json['shippingMethod'] ?? '';
    pedido.selectedVendedor = json['selectedVendedor'] ?? 'Alline';
    pedido.shippingCost = (json['shippingCost'] ?? 0.0).toDouble();
    pedido.shippingCostController.text = json['shippingCostController'] ?? '0.00';
    pedido.storeFinal = json['storeFinal'] ?? '';
    pedido.pickupStoreId = json['pickupStoreId'] ?? '';
    pedido.selectedPaymentMethod = json['selectedPaymentMethod'] ?? '';
    pedido.showNotesField = json['showNotesField'] ?? false;
    pedido.showCouponField = json['showCouponField'] ?? false;
    pedido.schedulingDate = json['schedulingDate'] ?? '';
    pedido.schedulingTime = json['schedulingTime'] ?? '';
    pedido.isCustomerSectionExpanded = json['isCustomerSectionExpanded'] ?? true;
    pedido.isAddressSectionExpanded = json['isAddressSectionExpanded'] ?? true;
    pedido.isProductsSectionExpanded = json['isProductsSectionExpanded'] ?? true;
    pedido.isShippingSectionExpanded = json['isShippingSectionExpanded'] ?? true;
    pedido.paymentInstructions = json['paymentInstructions'];
    pedido.couponErrorMessage = json['couponErrorMessage'];
    pedido.discountAmount = (json['discountAmount'] ?? 0.0).toDouble();
    pedido.isCouponValid = json['isCouponValid'] ?? false;
    pedido.storeIndication = json['storeIndication'] ?? '';
    pedido.isFetchingStore = json['isFetchingStore'] ?? false;
    pedido.lastPhoneNumber = json['lastPhoneNumber'];
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