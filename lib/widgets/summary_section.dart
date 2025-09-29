import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/log_utils.dart';
import '../models/pedido_state.dart';

class SummarySection extends StatefulWidget {
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

  @override
  _SummarySectionState createState() => _SummarySectionState();
}

class _SummarySectionState extends State<SummarySection> {
  bool _isPressed = false;

  Future<void> _sendPaymentMessage(BuildContext context) async {
    String? phoneNumber = widget.pedido.lastPhoneNumber ?? widget.pedido.phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira o número de telefone do cliente.')),
      );
      await logToFile('Erro: phoneNumber is empty in _sendPaymentMessage');
      return;
    }

    phoneNumber = '+55$phoneNumber';
    if (widget.paymentInstructions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma instrução de pagamento disponível.')),
      );
      await logToFile('Erro: paymentInstructions is null in _sendPaymentMessage');
      return;
    }

    String formattedMessage;
    try {
      final paymentData = jsonDecode(widget.paymentInstructions!);
      formattedMessage = paymentData['type'] == 'pix' ? paymentData['text'] ?? '' : paymentData['url'] ?? '';
      await logToFile('Parsed paymentInstructions: $paymentData, formattedMessage: $formattedMessage');
    } catch (e) {
      formattedMessage = widget.paymentInstructions!;
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
    if (widget.paymentInstructions != null) {
      try {
        final paymentData = jsonDecode(widget.paymentInstructions!);
        paymentText = paymentData['type'] == 'pix' ? paymentData['text'] : paymentData['url'];
        isPix = paymentData['type'] == 'pix';
        logToFile('Payment instructions parsed: type=${paymentData['type']}, text=${paymentData['text']}, url=${paymentData['url']}');
      } catch (e) {
        paymentText = widget.paymentInstructions;
        isPix = !widget.paymentInstructions!.contains('checkout.stripe.com');
        logToFile('Erro ao parsear paymentInstructions: $e, usando fallback: $paymentText, isPix: $isPix');
      }
    } else {
      logToFile('paymentInstructions is null in SummarySection');
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.1)]
              : [Colors.white, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do Pedido',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            context,
            primaryColor: primaryColor,
            icon: Icons.store,
            label: 'Loja Selecionada',
            value: widget.pedido.storeFinal.isNotEmpty ? '📍 ${widget.pedido.storeFinal}' : 'Aguardando cálculo',
            isDarkMode: isDarkMode,
            valueStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
  context,
  primaryColor: primaryColor,
  label: 'Total dos Produtos',
  value: 'R\$ ${widget.pedido.products.fold<double>(0.0, (sum, product) => sum + (product['price'] * (product['quantity'] ?? 1))).toStringAsFixed(2)}',
  isDarkMode: isDarkMode,
),
          _buildSummaryRow(
            context,
            primaryColor: primaryColor,
            label: 'Custo de Envio',
            value: 'R\$ ${widget.pedido.shippingCost.toStringAsFixed(2)}',
            isDarkMode: isDarkMode,
          ),
          if (widget.isCouponValid) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              context,
              primaryColor: primaryColor,
              icon: Icons.discount_outlined,
              label: 'Desconto (${widget.couponCode})',
              value: '- R\$ ${widget.discountAmount.toStringAsFixed(2)}',
              isDarkMode: isDarkMode,
              valueStyle: GoogleFonts.poppins(fontSize: 16, color: successColor, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          AnimatedOpacity(
            opacity: widget.totalWithDiscount > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: _buildSummaryRow(
              context,
              primaryColor: primaryColor,
              label: 'Total com Desconto',
              value: 'R\$ ${widget.totalWithDiscount.toStringAsFixed(2)}',
              isDarkMode: isDarkMode,
              valueStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: widget.pedido.availablePaymentMethods.isNotEmpty &&
                    widget.pedido.availablePaymentMethods.any((m) => m['title'] == widget.pedido.selectedPaymentMethod)
                ? widget.pedido.selectedPaymentMethod
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            items: widget.pedido.availablePaymentMethods.map((method) {
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
                widget.pedido.selectedPaymentMethod = value;
                widget.pedido.notifyListeners();
                logToFile('Método de pagamento selecionado: $value');
              }
            },
            validator: (value) => value == null ? 'Selecione um método de pagamento' : null,
            hint: Text(
              widget.pedido.schedulingDate.isEmpty || widget.pedido.schedulingTime.isEmpty
                  ? 'Selecione data e horário primeiro'
                  : 'Selecione o método de pagamento',
              style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black54),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTapDown: (_) => widget.isLoading || widget.pedido.selectedPaymentMethod.isEmpty
                  ? null
                  : setState(() => _isPressed = true),
              onTapUp: (_) => setState(() => _isPressed = false),
              onTapCancel: () => setState(() => _isPressed = false),
              onTap: widget.isLoading || widget.pedido.selectedPaymentMethod.isEmpty
                  ? null
                  : () async {
                      await widget.onCreateOrder();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Criando pedido...',
                            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
                          ),
                          backgroundColor: primaryColor,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
              child: AnimatedScale(
                scale: _isPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Criar Pedido',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.resultMessage != null) ...[
            const SizedBox(height: 20),
            AnimatedSlide(
              offset: widget.resultMessage!.isNotEmpty ? Offset.zero : const Offset(0, 0.2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.resultMessage!.contains('Erro') ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: widget.resultMessage!.contains('Erro') ? Colors.red.shade200 : Colors.green.shade200),
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
                      widget.resultMessage!.contains('Erro') ? Icons.error : Icons.check_circle,
                      color: widget.resultMessage!.contains('Erro') ? Colors.red.shade600 : successColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.resultMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: widget.resultMessage!.contains('Erro') ? Colors.red.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (widget.paymentInstructions != null && paymentText != null && paymentText.isNotEmpty) ...[
            const SizedBox(height: 20),
            AnimatedSlide(
              offset: paymentText!.isNotEmpty ? Offset.zero : const Offset(0, 0.2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPix ? Colors.blue.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isPix ? Colors.blue.shade200 : Colors.green.shade200),
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
                    Row(
                      children: [
                        Icon(
                          isPix ? Icons.qr_code_scanner : Icons.credit_card,
                          color: isPix ? Colors.blue.shade600 : successColor,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isPix ? 'Pagamento via Pix' : 'Pagamento via Cartão',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isPix ? Colors.blue.shade200 : Colors.green.shade200),
                      ),
                      child: Row(
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
                            icon: Icon(Icons.copy, size: 20, color: isPix ? Colors.blue.shade600 : successColor),
                            onPressed: () => _copyToClipboard(context, paymentText),
                            tooltip: isPix ? 'Copiar Código Pix' : 'Copiar Link de Pagamento',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _sendPaymentMessage(context),
                        icon: Icon(Icons.send, size: 20, color: Colors.white),
                        label: Text(
                          'Enviar via WhatsApp',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPix ? Colors.blue.shade600 : successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 3,
                          shadowColor: Colors.black.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required Color primaryColor,
    IconData? icon,
    required String label,
    required String value,
    required bool isDarkMode,
    TextStyle? valueStyle,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: primaryColor, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        Flexible(
          child: Text(
            value,
            style: valueStyle ??
                GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}