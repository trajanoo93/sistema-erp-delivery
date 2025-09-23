import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:erp_painel_delivery/models/pedido_state.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/log_utils.dart';

class SummarySection extends StatelessWidget {
  final double totalOriginal;
  final bool isCouponValid;
  final String couponCode;
  final double discountAmount;
  final double totalWithDiscount;
  final bool isLoading;
  final Future<void> Function() onCreateOrder;
  final PedidoState pedido;
  final String? paymentInstructions;
  final String? resultMessage;

  const SummarySection({
    Key? key,
    required this.totalOriginal,
    required this.isCouponValid,
    required this.couponCode,
    required this.discountAmount,
    required this.totalWithDiscount,
    required this.isLoading,
    required this.onCreateOrder,
    required this.pedido,
    this.paymentInstructions,
    this.resultMessage,
  }) : super(key: key);

  Future<void> _sendPaymentMessage(BuildContext context) async {
    String? phoneNumber = pedido.lastPhoneNumber ?? pedido.phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira o número de telefone do cliente.')),
      );
      return;
    }

    phoneNumber = '+55$phoneNumber';
    if (paymentInstructions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma instrução de pagamento disponível.')),
      );
      await logToFile('Erro: paymentInstructions is null in _sendPaymentMessage');
      return;
    }

    String formattedMessage;
    try {
      final paymentData = jsonDecode(paymentInstructions!);
      formattedMessage = paymentData['type'] == 'pix' ? paymentData['text'] ?? '' : paymentData['url'] ?? '';
      await logToFile('Parsed paymentInstructions: $paymentData, formattedMessage: $formattedMessage');
    } catch (e) {
      formattedMessage = paymentInstructions!;
      await logToFile('Erro ao parsear paymentInstructions: $e, usando fallback: $formattedMessage');
    }

    final url = Uri.parse('https://api.wzap.chat/v1/messages');
    final payload = {
      "phone": phoneNumber,
      "message": formattedMessage.trim(),
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
      await logToFile('Resposta da API WhatsApp: status=${response.statusCode}, body=${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201 || (response.statusCode == 400 && jsonDecode(response.body)['status'] == 'queued')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensagem enviada com sucesso!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: ${response.body}')),
        );
      }
    } catch (e) {
      await logToFile('Erro na conexão com WhatsApp API: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na conexão: $e')),
      );
    }
  }

  Future<void> _copyToClipboard(BuildContext context, String? text) async {
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma instrução de pagamento disponível para copiar.')),
      );
      await logToFile('Erro: text is null or empty in _copyToClipboard');
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instruções copiadas para a área de transferência!')),
    );
    await logToFile('Texto copiado para a área de transferência: $text');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFF28C38);
    final successColor = Colors.green.shade600;

    String? paymentText;
    bool isPix = false;
    if (paymentInstructions != null) {
      try {
        final paymentData = jsonDecode(paymentInstructions!);
        paymentText = paymentData['type'] == 'pix' ? paymentData['text'] : paymentData['url'];
        isPix = paymentData['type'] == 'pix';
        logToFile('Payment instructions parsed: type=${paymentData['type']}, text=${paymentData['text']}, url=${paymentData['url']}');
      } catch (e) {
        paymentText = paymentInstructions;
        isPix = !paymentInstructions!.contains('checkout.stripe.com');
        logToFile('Erro ao parsear paymentInstructions: $e, usando fallback: $paymentText, isPix: $isPix');
      }
    } else {
      logToFile('paymentInstructions is null in SummarySection');
    }

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
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do Pedido',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Loja Selecionada',
                style: GoogleFonts.poppins(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black54),
              ),
              Text(
                pedido.storeFinal.isNotEmpty ? pedido.storeFinal : 'Aguardando cálculo',
                style: GoogleFonts.poppins(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total dos Produtos',
                style: GoogleFonts.poppins(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black54),
              ),
              Text(
                'R\$ ${totalOriginal.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Custo de Envio',
                style: GoogleFonts.poppins(fontSize: 16, color: isDarkMode ? Colors.white70 : Colors.black54),
              ),
              Text(
                'R\$ ${pedido.shippingCost.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87),
              ),
            ],
          ),
          if (isCouponValid) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Desconto ($couponCode)',
                  style: GoogleFonts.poppins(fontSize: 16, color: successColor),
                ),
                Text(
                  '- R\$ ${discountAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontSize: 16, color: successColor),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total com Desconto',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87),
              ),
              Text(
                'R\$ ${totalWithDiscount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: pedido.availablePaymentMethods.isNotEmpty &&
                    pedido.availablePaymentMethods.any((m) => m['title'] == pedido.selectedPaymentMethod)
                ? pedido.selectedPaymentMethod
                : null,
            decoration: InputDecoration(
              labelText: 'Método de Pagamento',
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
              prefixIcon: Icon(Icons.payment, color: primaryColor),
              filled: true,
              fillColor: isDarkMode ? Colors.grey[800] : Colors.white,
              enabled: pedido.schedulingDate.isNotEmpty && pedido.schedulingTime.isNotEmpty,
            ),
            items: pedido.availablePaymentMethods.map((method) {
              return DropdownMenuItem<String>(
                value: method['title'],
                child: Text(
                  method['title'] ?? '',
                  style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                pedido.selectedPaymentMethod = value;
                pedido.notifyListeners();
              }
            },
            validator: (value) => value == null ? 'Selecione um método de pagamento' : null,
            hint: Text(
              pedido.schedulingDate.isEmpty || pedido.schedulingTime.isEmpty
                  ? 'Selecione data e horário primeiro'
                  : 'Selecione o método de pagamento',
              style: GoogleFonts.poppins(color: isDarkMode ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading || pedido.selectedPaymentMethod.isEmpty ? null : onCreateOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Criar Pedido',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          if (resultMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: resultMessage!.contains('Erro') ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: resultMessage!.contains('Erro') ? Colors.red.shade200 : Colors.green.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    resultMessage!.contains('Erro') ? Icons.error : Icons.check_circle,
                    color: resultMessage!.contains('Erro') ? Colors.red.shade600 : successColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      resultMessage!,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: resultMessage!.contains('Erro') ? Colors.red.shade800 : Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (paymentInstructions != null && paymentText != null && paymentText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPix ? 'Pagamento via Pix' : 'Pagamento via Cartão de Crédito',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: successColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPix ? 'Código Pix:' : 'Link de Pagamento:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          paymentText,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 20),
                        onPressed: () => _copyToClipboard(context, paymentText),
                        tooltip: isPix ? 'Copiar Código Pix' : 'Copiar Link de Pagamento',
                        color: Colors.blue.shade600,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _sendPaymentMessage(context),
                      icon: const Icon(Icons.message, size: 20, color: Colors.white),
                      label: Text(
                        'Enviar via WhatsApp',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: successColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}