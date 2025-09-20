import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:erp_painel_delivery/models/pedido_state.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart'; // Para Clipboard

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
  }) : super(key: key);

  Future<void> _sendPaymentMessage(BuildContext context) async {
    // Usar o último número de telefone armazenado, com fallback para o campo atual
    String? phoneNumber = pedido.lastPhoneNumber ?? pedido.phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira o número de telefone do cliente.')),
      );
      return;
    }

    // Formatar no padrão E.164 (ex.: +5511987654321 para Brasil)
    phoneNumber = '+55$phoneNumber'; // Adiciona o código de país do Brasil
    print('Enviando mensagem para número: $phoneNumber');

    if (paymentInstructions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma instrução de pagamento disponível.')),
      );
      return;
    }

    // Usar paymentInstructions diretamente, sem adicionar prefixo ou formatação
    final formattedMessage = paymentInstructions!.trim(); // Remove espaços ou quebras de linha indesejadas

    final url = Uri.parse('https://api.wzap.chat/v1/messages');
    final payload = {
      "phone": phoneNumber,
      "message": formattedMessage,
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
      print('Resposta da API: ${response.statusCode} - ${response.body}');
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201 || (response.statusCode == 400 && data['status'] == 'queued')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensagem enviada com sucesso!')),
        );
        print('Mensagem enfileirada com sucesso: $data');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar mensagem: ${response.body}')),
        );
        print('Erro na resposta: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na conexão: $e')),
      );
      print('Exceção ao enviar mensagem: $e');
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    if (paymentInstructions == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma instrução de pagamento disponível para copiar.')),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: paymentInstructions!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instruções copiadas para a área de transferência!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resumo do Pedido',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total dos Produtos',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
              ),
              Text(
                'R\$ ${totalOriginal.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
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
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.green),
                ),
                Text(
                  '- R\$ ${discountAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.green),
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
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                'R\$ ${totalWithDiscount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : onCreateOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      'Criar Pedido',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          if (paymentInstructions != null) ...[
            const SizedBox(height: 16),
            SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instruções de Pagamento',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      paymentInstructions!,
                      style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy, size: 24),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: 'Copiar Instruções',
                  color: Colors.blue.shade600,
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 48) / 2 - 8,
                  child: ElevatedButton.icon(
                    onPressed: () => _sendPaymentMessage(context),
                    icon: const Icon(Icons.message, size: 20, color: Colors.white),
                    label: Text(
                      'Enviar via WhatsApp',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}