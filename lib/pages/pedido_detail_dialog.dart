import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class PedidoDetailDialog extends StatelessWidget {
  final dynamic pedido;
  final List<Map<String, String>> produtosParsed;

  const PedidoDetailDialog({
    Key? key,
    required this.pedido,
    required this.produtosParsed,
  }) : super(key: key);

  // Função para formatar o número de telefone
  String formatPhoneNumber(String phone) {
    if (phone.length != 13) return phone; // Verifica se tem o tamanho esperado (incluindo +55)
    final ddd = phone.substring(2, 4); // "31"
    final numberPart1 = phone.substring(4, 9); // "97353"
    final numberPart2 = phone.substring(9, 13); // "7287"
    return '($ddd) $numberPart1-$numberPart2'; // Ex.: "(31) 97353-7287"
  }

  // Função para formatar a data
  String formatDate(String date) {
    if (date.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(date);
      return DateFormat('dd-MM').format(dt);
    } catch (e) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Concatenar o endereço completo
    final enderecoCompleto = '${pedido['rua'] ?? ''}, ${pedido['numero'] ?? ''}, '
        '${pedido['complemento'] ?? ''}, ${pedido['bairro'] ?? ''}, '
        '${pedido['cidade'] ?? ''} - CEP: ${pedido['cep'] ?? ''}'.trim();

    // Formatar o telefone
    final telefoneFormatado = formatPhoneNumber(pedido['telefone']?.toString() ?? '');

    // Formatar a data de criação
    final dataCriacaoFormatada = formatDate(pedido['data'] ?? '');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(20.0),
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título do pedido
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedido #${pedido['id'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Conteúdo do diálogo
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Seção: Detalhes do Pedido
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detalhes do Pedido',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildDetailRow('Data de Criação', dataCriacaoFormatada),
                          _buildDetailRow('Cliente', (pedido['nome'] ?? 'N/A').toString().toUpperCase()),
                          _buildDetailRow('Telefone', telefoneFormatado),
                          _buildDetailRow('Pagamento', pedido['pagamento'] ?? 'N/A'),
                          _buildDetailRow('Endereço', enderecoCompleto.isNotEmpty ? enderecoCompleto : 'N/A'),
                          _buildDetailRow(
                              'Agendamento', '${pedido['data_agendamento'] ?? ''} - ${pedido['horario_agendamento'] ?? ''}'),
                          _buildDetailRow('Tipo de Entrega', pedido['tipo_entrega']?.toString().toLowerCase() ?? 'N/A'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Seção: Produtos
                    const Text(
                      'Produtos',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildProdutosTable(produtosParsed),
                    const SizedBox(height: 16),

                    // Seção: Totais
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Subtotal: R\$ ${pedido['subTotal']?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Taxa de Entrega: R\$ ${pedido['taxa_entrega']?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total: R\$ ${pedido['total']?.toStringAsFixed(2) ?? '0.00'}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Botões
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Fechar', style: TextStyle(color: Colors.orange)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    await _generateAndSavePDF(context, pedido, produtosParsed);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Imprimir'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProdutosTable(List<Map<String, String>> produtos) {
    return Table(
      border: TableBorder.all(color: Colors.grey.shade200),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: Colors.orange.shade100),
          children: const [
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Produto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Qtd',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
        ...produtos.asMap().entries.map((entry) {
          final index = entry.key;
          final produto = entry.value;
          return TableRow(
            decoration: BoxDecoration(
              color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(produto['nome']!, style: const TextStyle(fontSize: 14)),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(produto['qtd']!, style: const TextStyle(fontSize: 14)),
              ),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _generateAndSavePDF(
      BuildContext context, dynamic pedido, List<Map<String, String>> produtosParsed) async {
    final pdf = pw.Document();

    // Concatenar o endereço completo para o PDF
    final enderecoCompleto = '${pedido['rua'] ?? ''}, ${pedido['numero'] ?? ''}, '
        '${pedido['complemento'] ?? ''}, ${pedido['bairro'] ?? ''}, '
        '${pedido['cidade'] ?? ''} - CEP: ${pedido['cep'] ?? ''}'.trim();

    // Formatar o telefone para o PDF
    final telefoneFormatado = formatPhoneNumber(pedido['telefone']?.toString() ?? '');

    // Formatar a data de criação para o PDF
    final dataCriacaoFormatada = formatDate(pedido['data'] ?? '');

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Título
              pw.Text(
                'Pedido #${pedido['id'] ?? 'N/A'}',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 10),

              // Seção: Detalhes do Pedido
              pw.Text(
                'Detalhes do Pedido',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Data de Criação: $dataCriacaoFormatada'),
              pw.Text('Cliente: ${(pedido['nome'] ?? 'N/A').toString().toUpperCase()}'),
              pw.Text('Telefone: $telefoneFormatado'),
              pw.Text('Pagamento: ${pedido['pagamento'] ?? 'N/A'}'),
              pw.Text('Endereço: ${enderecoCompleto.isNotEmpty ? enderecoCompleto : 'N/A'}'),
              pw.Text(
                  'Agendamento: ${pedido['data_agendamento'] ?? ''} - ${pedido['horario_agendamento'] ?? ''}'),
              pw.Text('Tipo de Entrega: ${pedido['tipo_entrega']?.toString().toLowerCase() ?? 'N/A'}'),
              pw.SizedBox(height: 20),

              // Seção: Produtos
              pw.Text(
                'Produtos',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Produto', 'Qtd'],
                data: produtosParsed.map((p) => [p['nome']!, p['qtd']!]).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey400),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellPadding: const pw.EdgeInsets.all(5),
                cellStyle: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 20),

              // Seção: Totais
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Subtotal: R\$ ${pedido['subTotal']?.toStringAsFixed(2) ?? '0.00'}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Taxa de Entrega: R\$ ${pedido['taxa_entrega']?.toStringAsFixed(2) ?? '0.00'}',
                      style: const pw.TextStyle(fontSize: 14),
                    ),
                    pw.Text(
                      'Total: R\$ ${pedido['total']?.toStringAsFixed(2) ?? '0.00'}',
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/pedido_${pedido['id'] ?? 'N/A'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    await OpenFile.open(filePath);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('PDF gerado e salvo em: $filePath. Mova manualmente para o Desktop, se desejar.'),
      duration: const Duration(seconds: 5),
    ));
  }
}