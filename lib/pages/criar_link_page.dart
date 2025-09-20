import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Classe StoreNormalize movida para o nível superior
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

class CriarLinkPage extends StatefulWidget {
  const CriarLinkPage({Key? key}) : super(key: key);

  @override
  State<CriarLinkPage> createState() => _CriarLinkPageState();
}

class _CriarLinkPageState extends State<CriarLinkPage> {
  final _formKey = GlobalKey<FormState>();
  String _paymentMethod = 'pix';
  final _orderIdController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _storeUnitController = TextEditingController();
  bool _isLoading = false;
  bool _isFetchingOrder = false;
  String? _resultMessage;
  String? _qrCodeUrl;
  String? _pixQrCode;
  String? _stripeCheckoutUrl;

  final _phoneMaskFormatter = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  Future<void> logToFile(String message) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_logs.txt');
      await file.writeAsString('${DateTime.now()} - $message\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Falha ao escrever log: $e');
    }
  }

  Future<void> _fetchOrder() async {
    final orderId = _orderIdController.text;
    if (orderId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira o ID do pedido')),
      );
      return;
    }

    setState(() {
      _isFetchingOrder = true;
      _customerNameController.clear();
      _phoneNumberController.clear();
      _amountController.clear();
      _storeUnitController.clear();
      _resultMessage = null;
      _qrCodeUrl = null;
      _pixQrCode = null;
      _stripeCheckoutUrl = null;
    });

    try {
      if (orderId.length == 5) {
        print('Buscando no App com ID: $orderId');
        final appListResponse = await http.get(
          Uri.parse('https://shop.fabapp.com/panel/stores/26682591/orders'),
        );

        if (appListResponse.statusCode != 200) {
          throw Exception('Erro ao buscar lista de pedidos do app: ${appListResponse.body}');
        }

        final appData = jsonDecode(appListResponse.body);
        final orders = appData['data'] as List<dynamic>;
        final order = orders.firstWhere(
          (o) => o['orderNumber'].toString() == orderId,
          orElse: () => null,
        );

        if (order == null) {
          throw Exception('Pedido não encontrado no app');
        }

        final orderIdApp = order['id'];
        final orderDetailsResponse = await http.get(
          Uri.parse('https://shop.fabapp.com/panel/stores/26682591/orders/$orderIdApp'),
        );

        if (orderDetailsResponse.statusCode != 200) {
          throw Exception('Erro ao buscar detalhes do pedido do app: ${orderDetailsResponse.body}');
        }

        final orderDetails = jsonDecode(orderDetailsResponse.body);

        final amountInCents = double.parse(orderDetails['amountFinal']);
        final amountInReais = (amountInCents / 100).toStringAsFixed(2);

        final rawPhone = orderDetails['userPhone'];
        final formattedPhone = rawPhone.length >= 11
            ? '(${rawPhone.substring(2, 4)}) ${rawPhone.substring(4, 9)}-${rawPhone.substring(9)}'
            : rawPhone;

        setState(() {
          _customerNameController.text = orderDetails['userName'];
          _phoneNumberController.text = formattedPhone;
          _amountController.text = amountInReais;
          _storeUnitController.text = 'Central Distribuição (Sagrada Família)';
        });
      } else if (orderId.length == 6) {
        print('Buscando no WooCommerce com ID: $orderId');
        final wooResponse = await http.get(
          Uri.parse('https://aogosto.com.br/delivery/wp-json/wc/v3/orders/$orderId'),
          headers: {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('ck_5156e2360f442f2585c8c9a761ef084b710e811f:cs_c62f9d8f6c08a1d14917e2a6db5dccce2815de8c'))}',
          },
        );

        if (wooResponse.statusCode != 200) {
          throw Exception('Erro ao buscar pedido no WooCommerce: ${wooResponse.body}');
        }

        final data = jsonDecode(wooResponse.body);
        final billing = data['billing'];
        final metaData = data['meta_data'] as List<dynamic>;
        final storeFinal = metaData.firstWhere(
          (meta) => meta['key'] == '_store_final',
          orElse: () => null,
        )?['value'];

        // Validar unidade da loja
        final normalizedStore = storeFinal != null ? StoreNormalize.getName(StoreNormalize.getId(storeFinal)) : 'Central Distribuição (Sagrada Família)';

        setState(() {
          _customerNameController.text = '${billing['first_name']} ${billing['last_name']}';
          _phoneNumberController.text = billing['phone'];
          _amountController.text = data['total'];
          _storeUnitController.text = normalizedStore;
        });
      } else {
        throw Exception('ID do pedido inválido: use 5 dígitos para o app ou 6 dígitos para o WooCommerce');
      }
    } catch (error) {
      await logToFile('Erro ao buscar pedido: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao buscar pedido: $error')),
      );
    } finally {
      setState(() {
        _isFetchingOrder = false;
      });
    }
  }

  Future<Map<String, String>?> _generatePaymentLinkInternal({
    required String customerName,
    required String phoneNumber,
    required double amount,
    required String storeUnit,
    required String paymentMethod,
    required String orderId,
  }) async {
    final rawPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (rawPhone.length < 10 || rawPhone.length > 11) {
      throw Exception('Número de telefone inválido: deve ter 10 ou 11 dígitos.');
    }
    final areaCode = rawPhone.length >= 2 ? rawPhone.substring(0, 2) : '31';
    final phone = rawPhone.length >= 9 ? rawPhone.substring(2) : rawPhone;
    final amountInCents = (amount * 100).toInt();

    if (amountInCents <= 0) {
      throw Exception('Erro ao gerar link de pagamento: O valor total do pedido deve ser maior que zero.');
    }

    // Normaliza a loja
    final storeId = StoreNormalize.getId(storeUnit);
    final normalizedStoreUnit = StoreNormalize.getName(storeId);
    if (storeUnit != normalizedStoreUnit) {
      throw Exception('Unidade da loja inválida: $storeUnit não é suportada.');
    }
    final proxyUnit = StoreNormalize.getProxyUnit(normalizedStoreUnit);

    // Define o endpoint do proxy com base no método de pagamento
    String proxyPath = paymentMethod == 'pix' ? 'pagarme.php' : 'stripe.php';
    final endpoint = 'https://aogosto.com.br/proxy/${Uri.encodeComponent(proxyUnit)}/$proxyPath';

    try {
      if (paymentMethod == 'pix') {
        final payloadPagarMe = {
          'items': [
            {
              'amount': amountInCents,
              'description': 'Produtos Ao Gosto Carnes',
              'quantity': 1,
            }
          ],
          'customer': {
            'name': customerName,
            'email': 'app+${DateTime.now().millisecondsSinceEpoch}@aogosto.com.br',
            'document': '06275992000570',
            'type': 'company',
            'phones': {
              'home_phone': {
                'country_code': '55',
                'number': phone,
                'area_code': areaCode,
              }
            }
          },
          'payments': [
            {
              'payment_method': 'pix',
              'pix': {'expires_in': 3600}
            }
          ],
          'metadata': {
            'order_id': orderId,
            'unidade': normalizedStoreUnit,
          },
        };

        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payloadPagarMe),
        );

        if (response.statusCode != 200) {
          final errorData = jsonDecode(response.body);
          await logToFile('Erro ao criar pedido PIX: ${jsonEncode(errorData)}');
          throw Exception('Erro ao criar pedido PIX: ${jsonEncode(errorData)}');
        }

        final data = jsonDecode(response.body);
        if (data['charges'] != null && data['charges'][0]['last_transaction'] != null) {
          final pixInfo = data['charges'][0]['last_transaction'];
          return {
            'type': 'pix',
            'qr_code': pixInfo['qr_code'],
            'qr_code_url': pixInfo['qr_code_url'],
          };
        } else {
          await logToFile('Nenhuma transação PIX retornada.');
          throw Exception('Nenhuma transação PIX retornada.');
        }
      } else if (paymentMethod == 'credit_card') {
        final payloadStripe = {
          'product_name': customerName,
          'product_description': 'Produtos Ao Gosto Carnes',
          'amount': amountInCents, // Enviar em centavos
          'phone_number': '($areaCode) $phone',
          'metadata': {
            'order_id': orderId,
            'unidade': normalizedStoreUnit,
          },
        };

        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payloadStripe),
        );

        if (response.body.isEmpty) {
          await logToFile('Resposta do proxy está vazia. Status: ${response.statusCode}');
          throw Exception('Resposta do proxy está vazia. Status: ${response.statusCode}');
        }

        final data = jsonDecode(response.body);
        if (response.statusCode != 200) {
          await logToFile('Erro ao criar link Stripe: ${jsonEncode(data)}');
          throw Exception('Erro ao criar link Stripe: ${jsonEncode(data)}');
        }

        if (data['payment_link'] != null && data['payment_link']['url'] != null) {
          return {
            'type': 'stripe',
            'url': data['payment_link']['url'],
          };
        } else {
          await logToFile('Nenhuma URL de checkout retornada pelo Stripe.');
          throw Exception('Nenhuma URL de checkout retornada pelo Stripe.');
        }
      } else {
        await logToFile('Método de pagamento não suportado: $paymentMethod');
        throw Exception('Método de pagamento não suportado: $paymentMethod');
      }
    } catch (error) {
      await logToFile('Erro ao gerar link de pagamento: $error');
      throw Exception('Erro ao gerar link de pagamento: $error');
    }
  }

  Future<void> _generatePaymentLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _resultMessage = null;
      _qrCodeUrl = null;
      _pixQrCode = null;
      _stripeCheckoutUrl = null;
    });

    try {
      final customerName = _customerNameController.text.trim();
      final phoneNumber = _phoneNumberController.text.trim();
      final amount = double.parse(_amountController.text.trim());
      final storeUnit = _storeUnitController.text.trim();
      final paymentMethod = _paymentMethod;
      final orderId = _orderIdController.text.trim();

      final paymentLinkResult = await _generatePaymentLinkInternal(
        customerName: customerName,
        phoneNumber: phoneNumber,
        amount: amount,
        storeUnit: storeUnit,
        paymentMethod: paymentMethod,
        orderId: orderId,
      );

      if (paymentLinkResult != null) {
        if (paymentLinkResult['type'] == 'pix') {
          setState(() {
            _resultMessage = 'Pagamento PIX criado com sucesso!';
            _qrCodeUrl = paymentLinkResult['qr_code_url'];
            _pixQrCode = paymentLinkResult['qr_code'];
          });
        } else if (paymentLinkResult['type'] == 'stripe') {
          setState(() {
            _resultMessage = 'Link de pagamento Stripe criado com sucesso!';
            _stripeCheckoutUrl = paymentLinkResult['url'];
          });
        }
      }
    } catch (error) {
      setState(() {
        _resultMessage = 'Erro: $error';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.shade600,
                        Colors.orange.shade400,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Criar Link de Pagamento',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: const Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Busque o pedido para criar um link de pagamento:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.orange.shade50.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _orderIdController,
                              decoration: InputDecoration(
                                labelText: 'ID do Pedido',
                                labelStyle: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.orange.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.orange.shade600,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.orange.shade600,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Por favor, insira o ID do pedido';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            child: ElevatedButton(
                              onPressed: _isFetchingOrder ? null : _fetchOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange.shade600,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                                shadowColor: Colors.orange.withOpacity(0.3),
                              ),
                              child: _isFetchingOrder
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    )
                                  : Text(
                                      'Buscar',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<String>(
                        value: _paymentMethod,
                        decoration: InputDecoration(
                          labelText: 'Método de Pagamento',
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade600,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.payment,
                            color: Colors.orange.shade600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'pix',
                            child: Text('Pix'),
                          ),
                          DropdownMenuItem(
                            value: 'credit_card',
                            child: Text('Cartão de Crédito On-line'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _paymentMethod = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _customerNameController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Nome do Cliente',
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade600,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.person,
                            color: Colors.orange.shade600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, busque o pedido para preencher este campo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _phoneNumberController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Telefone (DDD + Número)',
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade600,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.phone,
                            color: Colors.orange.shade600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, busque o pedido para preencher este campo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _amountController,
                        decoration: InputDecoration(
                          labelText: 'Valor (R\$)',
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade600,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.money,
                            color: Colors.orange.shade600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, insira o valor';
                          }
                          if (double.tryParse(value) == null || double.parse(value) <= 0) {
                            return 'Por favor, insira um valor válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _storeUnitController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Unidade da Loja',
                          labelStyle: GoogleFonts.poppins(
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade200,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Colors.orange.shade600,
                              width: 2,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.store,
                            color: Colors.orange.shade600,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor, busque o pedido para preencher este campo';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _generatePaymentLink,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                              shadowColor: Colors.orange.withOpacity(0.3),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(
                                    'Gerar Link',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_resultMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          Colors.orange.shade50.withOpacity(0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    _resultMessage!.startsWith('Erro')
                                        ? Colors.red.shade600
                                        : Colors.green.shade600,
                                    _resultMessage!.startsWith('Erro')
                                        ? Colors.red.shade400
                                        : Colors.green.shade400,
                                  ],
                                ),
                              ),
                              child: Icon(
                                _resultMessage!.startsWith('Erro')
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _resultMessage!,
                                style: GoogleFonts.poppins(
                                  color: _resultMessage!.startsWith('Erro')
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_qrCodeUrl != null && _pixQrCode != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'QR Code:',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.network(
                                _qrCodeUrl!,
                                width: 200,
                                height: 200,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Linha Digitável (Pix):',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade50,
                                  Colors.orange.shade100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _pixQrCode!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _pixQrCode!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Linha digitável copiada para a área de transferência!')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_stripeCheckoutUrl != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Link de Pagamento (Cartão de Crédito):',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade50,
                                  Colors.orange.shade100,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.2),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final url = Uri.parse(_stripeCheckoutUrl!);
                                      if (await canLaunchUrl(url)) {
                                        await launchUrl(url, mode: LaunchMode.externalApplication);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Não foi possível abrir o link')),
                                        );
                                      }
                                    },
                                    child: Text(
                                      _stripeCheckoutUrl!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.blue.shade600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _stripeCheckoutUrl!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Link copiado para a área de transferência!')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    _customerNameController.dispose();
    _phoneNumberController.dispose();
    _amountController.dispose();
    _storeUnitController.dispose();
    super.dispose();
  }
}