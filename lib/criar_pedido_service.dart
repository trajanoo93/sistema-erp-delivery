import 'dart:convert';
import 'package:http/http.dart' as http;

class CriarPedidoService {
  static const String _baseUrl = 'https://aogosto.com.br/delivery/';
  static const String _proxyUrl = 'https://aogosto.com.br/afonsos/proxy/buscar-cliente-por-telefone.php';
  static const String _consumerKey = 'ck_5156e2360f442f2585c8c9a761ef084b710e811f';
  static const String _consumerSecret = 'cs_c62f9d8f6c08a1d14917e2a6db5dccce2815de8c';

  Future<Map<String, dynamic>?> fetchCustomerByPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    print('Telefone original limpo: $cleanPhone');

    String searchPhone = cleanPhone.startsWith('55') ? cleanPhone.substring(2) : cleanPhone;
    print('Telefone para busca (sem código de país): $searchPhone');

    try {
      final response = await http.post(
        Uri.parse(_proxyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'phone': searchPhone}),
      );

      print('Status da resposta: ${response.statusCode}');
      print('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200) {
        final customer = jsonDecode(response.body);
        print('Cliente encontrado: ID=${customer['id']}, Telefone no banco: ${customer['billing']['phone']}, Último pedido ID: ${customer['last_order_id']}');
        return customer;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Erro ao buscar cliente: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      print('Erro ao buscar cliente: $error');
      throw Exception('Erro ao buscar cliente: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProducts(String searchTerm) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wp-json/wc/v3/products?search=$searchTerm&per_page=20'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> products = jsonDecode(response.body);
        return products.map((product) {
          return {
            'id': product['id'],
            'name': product['name'],
            'price': double.tryParse(product['price']) ?? 0.0,
            'image': product['images'].isNotEmpty ? product['images'][0]['src'] : null,
            'type': product['type'],
            'variations': product['variations'],
            'stock_status': product['stock_status'] ?? 'outofstock',
          };
        }).toList();
      } else {
        throw Exception('Erro ao buscar produtos: ${response.body}');
      }
    } catch (error) {
      throw Exception('Erro ao buscar produtos: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductAttributes(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wp-json/wc/v3/products/$productId'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
      );

      print('Buscando atributos para o produto ID $productId');
      print('Status da resposta: ${response.statusCode}');
      print('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200) {
        final product = jsonDecode(response.body);
        final attributes = product['attributes'] as List<dynamic>? ?? [];
        return attributes.map((attr) {
          return {
            'name': attr['name'],
            'options': attr['options'] as List<dynamic>,
          };
        }).toList();
      } else {
        throw Exception('Erro ao buscar atributos do produto: ${response.body}');
      }
    } catch (error) {
      print('Erro ao buscar atributos do produto: $error');
      throw Exception('Erro ao buscar atributos do produto: $error');
    }
  }

  Future<List<Map<String, dynamic>>> fetchProductVariations(int productId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/wp-json/wc/v3/products/$productId/variations'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
      );

      print('Buscando variações para o produto ID $productId');
      print('Status da resposta: ${response.statusCode}');
      print('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> variations = jsonDecode(response.body);
        return variations.map((variation) {
          return {
            'id': variation['id'],
            'attributes': variation['attributes'],
            'price': double.tryParse(variation['price']) ?? 0.0,
            'stock_status': variation['stock_status'] ?? 'outofstock',
          };
        }).toList();
      } else {
        throw Exception('Erro ao buscar variações: ${response.body}');
      }
    } catch (error) {
      print('Erro ao buscar variações: $error');
      throw Exception('Erro ao buscar variações: $error');
    }
  }

  Future<Map<String, dynamic>> fetchStoreDecision({
    required String cep,
    required String shippingMethod,
    String pickupStore = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/wp-json/custom/v1/store-decision'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'cep': cep,
          'shipping_method': shippingMethod,
          'pickup_store': pickupStore,
        }),
      );

      print('Buscando decisão da loja para CEP $cep e método $shippingMethod');
      print('Status da resposta: ${response.statusCode}');
      print('Corpo da resposta: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erro ao determinar a loja: ${response.body}');
      }
    } catch (error) {
      print('Erro ao determinar a loja: $error');
      throw Exception('Erro ao determinar a loja: $error');
    }
  }

  Future<Map<String, dynamic>> validateCoupon({
    required String couponCode,
    required List<Map<String, dynamic>> products,
    required double shippingCost,
  }) async {
    try {
      print('Produtos enviados para validação do cupom: ${jsonEncode(products)}');

      final validLineItems = products.map((product) {
        final productId = product['id'];
        final quantity = product['quantity'] ?? 1;
        final price = product['price'] ?? 0.0;
        final variationId = product['variation_id'] != null && product['variation_id'] != 0 ? product['variation_id'] : null;

        if (productId == null || productId is! int || productId <= 0) {
          throw Exception('ID do produto inválido: $productId');
        }
        if (quantity is! int || quantity <= 0) {
          throw Exception('Quantidade inválida para o produto ID $productId: $quantity');
        }
        if (price is! num || price <= 0) {
          throw Exception('Preço inválido para o produto ID $productId: $price');
        }
        if (variationId != null && (variationId is! int || variationId <= 0)) {
          throw Exception('ID da variação inválido para o produto ID $productId: $variationId');
        }

        final lineItem = <String, dynamic>{
          'product_id': productId,
          'quantity': quantity,
          'subtotal': (price * quantity).toString(),
          'total': (price * quantity).toString(),
        };

        if (variationId != null) {
          lineItem['variation_id'] = variationId;
        }

        return lineItem;
      }).toList();

      final payload = {
        'line_items': validLineItems,
        'shipping_lines': [
          {
            'method_id': 'flat_rate',
            'method_title': 'Taxa de Entrega',
            'total': shippingCost.toString(),
          }
        ],
        'coupon_lines': [
          {
            'code': couponCode,
          }
        ],
      };

      print('Payload enviado para validar cupom: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/wp-json/wc/v3/orders'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
        },
        body: jsonEncode(payload),
      );

      print('Resposta da API ao validar cupom: Status ${response.statusCode}, Body ${response.body}');

      if (response.statusCode == 201) {
        final order = jsonDecode(response.body);
        final subtotal = products.fold<double>(0.0, (sum, product) => sum + ((product['price'] ?? 0.0) * (product['quantity'] ?? 1))) + shippingCost;
        final totalWithDiscount = double.tryParse(order['total']) ?? subtotal;
        final discount = subtotal - totalWithDiscount;

        await http.delete(
          Uri.parse('$_baseUrl/wp-json/wc/v3/orders/${order['id']}'),
          headers: {
            'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
          },
        );

        print('Cupom validado: subtotal=$subtotal, totalWithDiscount=$totalWithDiscount, discount=$discount');

        return {
          'is_valid': true,
          'discount_amount': discount,
          'total_with_discount': totalWithDiscount,
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'is_valid': false,
          'error_message': error['message'] ?? 'Cupom inválido ou não aplicável',
        };
      }
    } catch (error) {
      print('Erro ao validar cupom: $error');
      return {
        'is_valid': false,
        'error_message': 'Erro ao validar o cupom: $error',
      };
    }
  }

  Future<Map<String, dynamic>> createOrder({
  required String customerName,
  required String customerEmail,
  required String customerPhone,
  required String billingCompany,
  required List<Map<String, dynamic>> products,
  required String shippingMethod,
  required String storeFinal,
  required String pickupStoreId,
  required String billingPostcode,
  required String billingAddress1,
  required String billingNumber,
  required String billingAddress2,
  required String billingNeighborhood,
  required String billingCity,
  required double shippingCost,
  required String paymentMethod,
  required String customerNotes,
  required String schedulingDate,
  required String schedulingTime,
  required String couponCode,
}) async {
  try {
    // Validação do shippingMethod
    if (shippingMethod != 'delivery' && shippingMethod != 'pickup') {
      throw Exception('Método de entrega inválido: $shippingMethod. Deve ser "delivery" ou "pickup".');
    }

    // Forçar shippingCost a 0.0 para pickup
    final effectiveShippingCost = shippingMethod == 'pickup' ? 0.0 : shippingCost;

    // Mapeamento explícito dos métodos de pagamento com depuração
    String mappedPaymentMethod;
    String paymentMethodTitle;
    print('Received paymentMethod in createOrder: $paymentMethod'); // Log do valor recebido
   switch (paymentMethod) {
  // === PIX ===
  case 'Pix':
  case 'pagarme_custom_pix':
    mappedPaymentMethod = 'pagarme_custom_pix';
    paymentMethodTitle = 'Pix On-line (Aprovação Imediata)';
    break;

  // === Cartão de Crédito Online (Stripe) ===
  case 'Cartão de Crédito On-line':
  case 'stripe':
  case 'stripe_cc':
    mappedPaymentMethod = 'stripe';
    paymentMethodTitle = 'Cartão de Crédito On-line';
    break;

  // === Dinheiro ===
  case 'Dinheiro':
  case 'woo_payment_on_delivery':
  case 'cod':
    mappedPaymentMethod = 'woo_payment_on_delivery';
    paymentMethodTitle = 'Pagamento no Dinheiro';
    break;

  // === Cartão na Entrega ===
  case 'Cartão na Entrega':
  case 'custom_729b8aa9fc227ff':
  case 'cartão_na_entrega':
    mappedPaymentMethod = 'custom_729b8aa9fc227ff';
    paymentMethodTitle = 'Cartão na Entrega';
    break;

  // === Vale Alimentação ===
  case 'Vale Alimentação':
  case 'custom_e876f567c151864':
  case 'voucher':
    mappedPaymentMethod = 'custom_e876f567c151864';
    paymentMethodTitle = 'Vale Alimentação';
    break;

  default:
    throw Exception('Método de pagamento inválido: $paymentMethod');
}


    print('Mapping payment method: $paymentMethod -> mappedPaymentMethod: $mappedPaymentMethod, paymentMethodTitle: $paymentMethodTitle'); // Log do mapeamento

    // Define o status do pedido com base no método de pagamento (online = pendente)
String orderStatus;
if (mappedPaymentMethod == 'pagarme_custom_pix' || mappedPaymentMethod == 'stripe') {
  orderStatus = 'pending'; // aguardando pagamento
} else {
  orderStatus = 'processing'; // métodos presenciais
}

    // Limpa e normaliza o customerName
    final cleanedCustomerName = customerName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final nameParts = cleanedCustomerName.split(' ').where((part) => part.isNotEmpty).toList();
    final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    // Valida line_items
    final lineItems = products.map((product) {
      final productId = product['id'];
      final quantity = product['quantity'] ?? 1;
      final price = product['price'] ?? 0.0;
      final variationId = product['variation_id'] != null && product['variation_id'] != 0 ? product['variation_id'] : null;

      if (productId == null || productId is! int || productId <= 0) {
        throw Exception('ID do produto inválido: $productId');
      }
      if (quantity is! int || quantity <= 0) {
        throw Exception('Quantidade inválida para o produto ID $productId: $quantity');
      }
      if (price is! num || price <= 0) {
        throw Exception('Preço inválido para o produto ID $productId: $price');
      }

      final lineItem = {
        'product_id': productId,
        'name': product['name'],
        'quantity': quantity,
        'subtotal': (price * quantity).toStringAsFixed(2),
        'total': (price * quantity).toStringAsFixed(2),
      };

      if (variationId != null) {
        lineItem['variation_id'] = variationId;
        lineItem['meta_data'] = (product['variation_attributes'] as List<dynamic>?)?.map((attr) {
          return {
            'key': attr['name'],
            'value': attr['option'],
          };
        })?.toList() ?? [];
      }

      return lineItem;
    }).toList();

    final effectiveEmail = customerEmail.isNotEmpty ? customerEmail : 'orders@aogosto.com.br';

    final payload = {
      'payment_method': mappedPaymentMethod,
      'payment_method_title': paymentMethodTitle,
      'billing': {
        'first_name': firstName,
        'last_name': lastName,
        'company': billingCompany,
        'postcode': billingPostcode,
        'address_1': billingAddress1,
        'address_2': billingAddress2,
        'city': billingCity,
        'state': 'MG',
        'country': 'BR',
        'email': effectiveEmail,
        'phone': customerPhone,
      },
      'shipping': {
        'first_name': firstName,
        'last_name': lastName,
        'postcode': billingPostcode,
        'address_1': billingAddress1,
        'number': billingNumber,
        'address_2': billingAddress2,
        'neighborhood': billingNeighborhood,
        'city': billingCity,
        'state': 'MG',
        'country': 'BR',
      },
      'line_items': lineItems,
      'shipping_lines': [
        {
          'method_id': shippingMethod == 'delivery' ? 'flat_rate' : 'local_pickup',
          'method_title': shippingMethod == 'delivery' ? 'Motoboy' : 'Retirada na Unidade',
          'total': effectiveShippingCost.toStringAsFixed(2),
        }
      ],
      'meta_data': [
        {
          'key': '_store_final',
          'value': storeFinal,
        },
        {
          'key': '_billing_number',
          'value': billingNumber,
        },
        {
          'key': '_billing_neighborhood',
          'value': billingNeighborhood,
        },
        if (shippingMethod == 'pickup') ...[
          {
            'key': '_shipping_pickup_stores',
            'value': storeFinal,
          },
          {
            'key': '_shipping_pickup_store_id',
            'value': pickupStoreId,
          },
          {
            'key': 'pickup_date',
            'value': schedulingDate,
          },
          {
            'key': 'pickup_time',
            'value': schedulingTime,
          },
        ],
        if (shippingMethod == 'delivery') ...[
          {
            'key': 'delivery_date',
            'value': schedulingDate,
          },
          {
            'key': 'delivery_time',
            'value': schedulingTime,
          },
        ],
        {
          'key': 'delivery_type',
          'value': shippingMethod,
        },
      ],
      'customer_note': customerNotes.isNotEmpty ? customerNotes : null,
      'status': orderStatus,
      if (couponCode.isNotEmpty)
        'coupon_lines': [
          {
            'code': couponCode,
          },
        ],
    };

    print('Payload final para criar pedido: ${jsonEncode(payload)}');

    final response = await http.post(
      Uri.parse('$_baseUrl/wp-json/wc/v3/orders'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}',
      },
      body: jsonEncode(payload),
    );

    print('Resposta da API ao criar pedido: Status ${response.statusCode}, Body ${response.body}');

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Erro ao criar pedido: ${response.statusCode} - ${response.body}');
    }
  } catch (error) {
    print('Erro ao criar pedido: $error');
    throw Exception('Erro ao criar pedido: $error');
  }
}}