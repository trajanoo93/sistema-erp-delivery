import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductSection extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Function(int) onRemoveProduct;
  final VoidCallback onAddProduct;
  final Function(int, int) onUpdateQuantity;
  final Function(int, double)? onUpdatePrice;

  const ProductSection({
    super.key,
    required this.products,
    required this.onRemoveProduct,
    required this.onAddProduct,
    required this.onUpdateQuantity,
    this.onUpdatePrice,
  });

  @override
  State<ProductSection> createState() => _ProductSectionState();
}

class _ProductSectionState extends State<ProductSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...widget.products.asMap().entries.map((entry) {
          final index = entry.key;
          final product = Map<String, dynamic>.from(entry.value); // Cópia para renderização
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.orange.shade50.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product['image'] != null && product['image'].toString().isNotEmpty)
  ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: CachedNetworkImage(
      imageUrl: product['image'],
      width: 50,
      height: 50,
      fit: BoxFit.cover,
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) => Container(
        width: 50,
        height: 50,
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 30,
        ),
      ),
    ),
  )
else
  Container(
    width: 50,
    height: 50,
    color: Colors.grey.shade200,
    child: const Icon(
      Icons.image_not_supported,
      color: Colors.grey,
      size: 30,
    ),
  ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  product['name'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => widget.onRemoveProduct(index),
                              ),
                            ],
                          ),
                          if (product['variation_attributes'] != null &&
                              product['variation_attributes'] is List &&
                              product['variation_attributes'].isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ...product['variation_attributes'].map<Widget>((attr) {
                              return Text(
                                '${attr['name'] ?? 'Atributo'}: ${attr['option'] ?? 'Desconhecido'}',
                                style: GoogleFonts.poppins(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              );
                            }).toList(),
                          ] else
                            const SizedBox.shrink(),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: product['price'].toStringAsFixed(2),
                                  decoration: InputDecoration(
                                    labelText: 'Preço (R\$)',
                                    labelStyle: GoogleFonts.poppins(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.orange.shade200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.orange.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.orange.shade600,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                                  onChanged: (value) {
                                    final newPrice = double.tryParse(value) ?? product['price'];
                                    if (widget.onUpdatePrice != null) {
                                      widget.onUpdatePrice!(index, newPrice); // Atualiza o PedidoState
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, insira o preço';
                                    }
                                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                                      return 'Preço deve ser maior que 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: product['quantity'].toString(),
                                  decoration: InputDecoration(
                                    labelText: 'Quantidade',
                                    labelStyle: GoogleFonts.poppins(
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.orange.shade200),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.orange.shade200),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.orange.shade600,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    final newQuantity = int.tryParse(value) ?? product['quantity'];
                                    widget.onUpdateQuantity(index, newQuantity); // Notifica a mudança
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor, insira a quantidade';
                                    }
                                    if (int.tryParse(value) == null || int.parse(value) <= 0) {
                                      return 'Quantidade deve ser maior que 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onAddProduct,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 5,
              shadowColor: Colors.green.withOpacity(0.3),
            ),
            child: Text(
              'Adicionar Produto',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}